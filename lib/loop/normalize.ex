defmodule Loop.Normalize do
  @moduledoc false

  import Loop.Patterns.Helpers

  # Strip metadata from AST so that variable nodes at different source
  # positions compare as equal. {:list, [line: 5, col: 12], nil} becomes
  # {:list, [], nil}, making pattern matching metadata-agnostic.
  #
  # Also applies cross-cutting canonicalizations:
  # P048: Kernel.op(a, b) → a op b  (infix form, e.g. Kernel.+(a, b) → a + b)
  # P047: a > b → b < a, a >= b → b <= a  (canonical comparison direction)
  # P044+P043: two-branch unless/if-not/if-! → if with swapped branches (positive predicate)
  # P045: cond do pred -> a; true -> b end → if pred, do: a, else: b
  # P046: case pred do true -> a; false -> b end (and reversed) → if pred, do: a, else: b
  # P049/P050: inline single-assignment, single-use intermediate variables in blocks
  def normalize(ast) do
    ast
    |> Macro.prewalk(fn
      # P048: Kernel-qualified arithmetic / comparison operators → infix form
      {{:., _, [{:__aliases__, _, [:Kernel]}, op]}, _, args}
      when op in [:+, :-, :*, :/, :++, :<>, :rem, :div, :==, :===, :!=, :!==, :<, :>, :<=, :>=] ->
        {op, [], args}

      # P047: Flip > / >= to < / <= so matchers only need to handle one direction
      {:>, _, [a, b]} ->
        {:<, [], [b, a]}

      {:>=, _, [a, b]} ->
        {:<=, [], [b, a]}

      # P044+P043: two-branch unless → if with swapped branches (eliminates `unless` with else)
      {:unless, _, [cond_expr, [do: a, else: b]]} ->
        {:if, [], [cond_expr, [do: b, else: a]]}

      # P043: if not cond, do: a, else: b → if cond, do: b, else: a
      {:if, _, [{:not, _, [inner]}, [do: a, else: b]]} ->
        {:if, [], [inner, [do: b, else: a]]}

      # P043: if !cond, do: a, else: b → if cond, do: b, else: a
      {:if, _, [{:!, _, [inner]}, [do: a, else: b]]} ->
        {:if, [], [inner, [do: b, else: a]]}

      # P045: cond do pred -> a; true -> b end → if pred, do: a, else: b
      {:cond, _, [[do: [{:->, _, [[pred], a]}, {:->, _, [[true], b]}]]]} ->
        {:if, [], [pred, [do: a, else: b]]}

      # P046: case pred do true -> a; false -> b end → if pred, do: a, else: b
      {:case, _, [pred, [do: [{:->, _, [[true], a]}, {:->, _, [[false], b]}]]]} ->
        {:if, [], [pred, [do: a, else: b]]}

      # P046: case pred do false -> b; true -> a end → if pred, do: a, else: b
      {:case, _, [pred, [do: [{:->, _, [[false], b]}, {:->, _, [[true], a]}]]]} ->
        {:if, [], [pred, [do: a, else: b]]}

      # List.first(x) → hd(x)  (P058)
      {{:., _, [{:__aliases__, _, [:List]}, :first]}, _, [arg]} ->
        {:hd, [], [arg]}

      # Enum.reverse(Enum.reverse(x)) → x  (P059: double reverse cancels)
      {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _,
       [{{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [inner]}]} ->
        inner

      # :lists.reverse(x) → Enum.reverse(x)  (P060: Erlang stdlib alias)
      {{:., _, [:lists, :reverse]}, _, [arg]} ->
        {{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [arg]}

      # [x] ++ rest → [x | rest]  (P061: single-element prepend via ++ is a cons)
      {:++, _, [[single_elem], rest_expr]} ->
        [{:|, [], [single_elem, rest_expr]}]

      # Strip metadata from remote-call nodes ({{:., _, _}, meta, args}) so that
      # matchers comparing sub-expressions with structural == succeed against
      # freshly built []-meta AST (the dot node itself is stripped when walked)
      {{:., _, _} = dot, _meta, args} ->
        {dot, [], args}

      # Strip metadata from all AST nodes and canonicalize context to nil for variables
      {name, _meta, ctx} when is_atom(name) and is_atom(ctx) ->
        {name, [], nil}

      {name, _meta, ctx} when is_atom(name) and is_list(ctx) ->
        {name, [], ctx}

      other ->
        other
    end)
    |> inline_block_aliases()
    |> canonicalize_tuple_assigns()
    |> merge_split_destructures()
  end

  # ============================================================================
  # P062: Split-Destructure Merging
  # ============================================================================
  # Converts split destructuring forms back to single-line form:
  #   [h | t] = list; ...; list = t          → [h | list] = list
  #   [h | _] = list; ...; list = tl(list)   → [h | list] = list
  #
  # This allows all patterns that expect 3-statement blocks to work with the split form.
  defp merge_split_destructures(ast) do
    Macro.prewalk(ast, fn
      {:__block__, meta, exprs} -> {:__block__, meta, do_merge_split_destructures(exprs)}
      other -> other
    end)
  end

  defp do_merge_split_destructures(exprs) do
    case find_split_destructure(exprs) do
      nil ->
        exprs

      {i, list_var, elem_var, tail_var} ->
        # tail_var is nil for wildcard [h | _] case
        advance_idx = find_split_advance(exprs, list_var, tail_var, i + 1)

        if advance_idx == nil do
          exprs
        else
          # Safety: if tail_var is a named variable, ensure it's not used elsewhere
          safe? =
            tail_var == nil or
              rhs_occurrence_count(exprs, tail_var, except: advance_idx) == 0

          if safe? do
            # Create merged destructure: [h | list] = list
            merged = {:=, [], [[{:|, [], [elem_var, list_var]}], list_var]}

            new_exprs =
              exprs
              |> List.replace_at(i, merged)
              |> List.delete_at(advance_idx)

            # Recurse to handle multiple splits in the same block
            do_merge_split_destructures(new_exprs)
          else
            exprs
          end
        end
    end
  end

  # Returns {index, list_var, elem_var, tail_var_or_nil} for first split destructure
  defp find_split_destructure(exprs) do
    Enum.find_value(Enum.with_index(exprs), fn
      # [h | _] = list (wildcard tail)
      {{:=, _, [[{:|, _, [elem_var, {:_, _, _}]}], list_var]}, i} ->
        {i, list_var, elem_var, nil}

      # [h | t] = list where t ≠ list
      {{:=, _, [[{:|, _, [elem_var, tail_var]}], list_var]}, i}
      when tail_var != list_var ->
        # Only for named variable tails (atoms with nil or [] context)
        case tail_var do
          {name, _, ctx} when is_atom(name) and is_atom(ctx) ->
            {i, list_var, elem_var, tail_var}

          _ ->
            nil
        end

      _ ->
        nil
    end)
  end

  # Searches from start_idx for 'list = tail_var' or 'list = tl(list)'
  defp find_split_advance(exprs, list_var, tail_var, start_idx) do
    exprs
    |> Enum.with_index()
    |> Enum.find_value(fn
      {_, i} when i < start_idx ->
        nil

      # list = tail_var (named tail form)
      {{:=, _, [^list_var, ^tail_var]}, i} when not is_nil(tail_var) ->
        i

      # list = tl(list) (function call form)
      {{:=, _, [^list_var, {:tl, _, [^list_var]}]}, i} ->
        i

      _ ->
        nil
    end)
  end

  # Count RHS occurrences of var, excluding except_idx
  defp rhs_occurrence_count(exprs, var, except: skip_idx) do
    exprs
    |> Enum.with_index()
    |> Enum.reject(fn {_, i} -> i == skip_idx end)
    |> Enum.reduce(0, fn {expr, _}, acc ->
      acc + count_occurrences_in_rhs(expr, var)
    end)
  end

  # ============================================================================
  # P049/P050: Block-level alias inlining
  # ============================================================================
  # Inline single-assignment, single-use intermediate variables in block expressions.
  #
  # P049 (predicate alias inlining):
  #   `ok = pred(h); if ok, do: break(h)` → `if pred(h), do: break(h)`
  #
  # P050 (element alias propagation):
  #   `val = h * 2; acc = [val | acc]` → `acc = [h * 2 | acc]`
  #
  # Guardrails:
  #   - Only inline if assigned exactly once (no reassignment later)
  #   - Only inline if non-self-referential (var not in its own RHS)
  #   - Only inline if not loop-carried (var not used before its assignment)
  #   - Only inline if used exactly once after the assignment
  defp inline_block_aliases(ast) do
    Macro.prewalk(ast, fn
      {:__block__, meta, exprs} -> {:__block__, meta, do_inline_aliases(exprs)}
      other -> other
    end)
  end

  defp do_inline_aliases(exprs) do
    candidates = collect_inline_candidates(exprs)

    if map_size(candidates) == 0 do
      exprs
    else
      exprs
      |> Enum.reject(fn
        {:=, _, [{name, _, ctx} = var, _]} when is_atom(name) and is_atom(ctx) ->
          Map.has_key?(candidates, var)

        _ ->
          false
      end)
      |> Enum.map(&apply_candidates(&1, candidates))
    end
  end

  defp apply_candidates(step, candidates) do
    Enum.reduce(candidates, step, fn {var, expr}, acc -> replace_var(acc, var, expr) end)
  end

  defp collect_inline_candidates(exprs) do
    exprs
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn
      {{:=, _, [{name, _, ctx} = var, assign_expr]}, i}, candidates
      when is_atom(name) and is_atom(ctx) ->
        before_steps = Enum.slice(exprs, 0, i)
        after_steps = Enum.slice(exprs, (i + 1)..-1//1)

        cond do
          # Self-referential: var appears in its own RHS (loop-carried state like acc = [h | acc])
          has_var?(assign_expr, var) ->
            candidates

          # Loop-carried: var was used before this assignment (holds value from previous iteration)
          Enum.any?(before_steps, &used_in_rhs?(&1, var)) ->
            candidates

          # Assigned more than once in the block (e.g. reassigned later)
          lhs_count_in(exprs, var) != 1 ->
            candidates

          # Used more than once after assignment (not safe to inline: would duplicate work)
          count_occurrences_in_rhs(after_steps, var) != 1 ->
            candidates

          true ->
            Map.put(candidates, var, assign_expr)
        end

      _, candidates ->
        candidates
    end)
  end

  defp used_in_rhs?({:=, _, [_lhs, rhs]}, var), do: has_var?(rhs, var)
  defp used_in_rhs?(step, var), do: has_var?(step, var)

  defp lhs_count_in(exprs, var) do
    Enum.count(exprs, fn
      {:=, _, [lhs, _]} -> lhs == var
      _ -> false
    end)
  end

  defp count_occurrences_in_rhs(steps, var) do
    Enum.reduce(steps, 0, fn
      {:=, _, [_lhs, rhs]}, count -> count + count_ast_occurrences(rhs, var)
      step, count -> count + count_ast_occurrences(step, var)
    end)
  end

  defp count_ast_occurrences(ast, var) do
    {_ast, count} =
      Macro.prewalk(ast, 0, fn
        ^var, c -> {var, c + 1}
        node, c -> {node, c}
      end)

    count
  end

  # ============================================================================
  # P052: Tuple state update decomposition canonicalizer
  # ============================================================================
  # Decompose `{a, b} = {e1, e2}` (and n-ary variants) into sequential per-variable
  # assignments in topological order, so existing pattern matchers can recognise them.
  #
  # Only applies when:
  #   - LHS contains only simple distinct variables
  #   - The cross-reference graph among different LHS variables is acyclic
  #     (cycle = swap like `{a, b} = {b, a}` → left unchanged, falls to interpreter)
  #
  # Examples:
  #   {list, acc} = {tl(list), [hd(list) | acc]}
  #     → acc = [hd(list) | acc]; list = tl(list)   (acc before list due to cross-ref)
  #
  #   {a, b} = {a + 1, b * 2}
  #     → a = a + 1; b = b * 2   (no cross-refs, original order preserved)
  #
  #   {a, b} = {b, a}   ← cycle → left unchanged
  defp canonicalize_tuple_assigns(ast) do
    Macro.prewalk(ast, fn
      {:__block__, meta, exprs} ->
        {:__block__, meta, Enum.flat_map(exprs, &decompose_tuple_step/1)}

      other ->
        other
    end)
  end

  # 2-element tuple: {a, b} = {e1, e2}
  defp decompose_tuple_step({:=, _, [{lhs_a, lhs_b}, {rhs_a, rhs_b}]} = step)
       when is_tuple(lhs_a) and is_tuple(lhs_b) do
    decompose_tuple_or_original([lhs_a, lhs_b], [rhs_a, rhs_b], step)
  end

  # 3+-element tuple: {a, b, c, ...} = {e1, e2, e3, ...}
  defp decompose_tuple_step({:=, _, [{:{}, _, lhs_vars}, {:{}, _, rhs_exprs}]} = step)
       when length(lhs_vars) == length(rhs_exprs) and length(lhs_vars) >= 3 do
    decompose_tuple_or_original(lhs_vars, rhs_exprs, step)
  end

  defp decompose_tuple_step(step), do: [step]

  defp decompose_tuple_or_original(lhs_vars, rhs_exprs, original) do
    case safe_tuple_decomposition(lhs_vars, rhs_exprs) do
      nil -> [original]
      assigns -> assigns
    end
  end

  # Attempt safe decomposition. Returns list of assignments in the correct
  # topological order, or nil if decomposition is impossible (cyclic cross-refs).
  defp safe_tuple_decomposition(lhs_vars, rhs_exprs) do
    n = length(lhs_vars)

    # All LHS must be simple distinct variables
    if Enum.all?(lhs_vars, &simple_var?/1) and Enum.uniq(lhs_vars) == lhs_vars do
      # Build "j must come before i" edges:
      # If rhs_exprs[j] references lhs_vars[i] (i ≠ j), then assigning a_j
      # before a_i is required so that e_j still sees the old value of a_i.
      edges =
        for i <- 0..(n - 1), j <- 0..(n - 1), i != j do
          {i, j}
        end
        |> Enum.filter(fn {i, j} ->
          has_var?(Enum.at(rhs_exprs, j), Enum.at(lhs_vars, i))
        end)
        |> Enum.map(fn {i, j} -> {j, i} end)

      case topological_sort_indices(n, edges) do
        {:ok, order} -> build_index_assigns(order, lhs_vars, rhs_exprs)
        :cycle -> nil
      end
    else
      nil
    end
  end

  defp build_index_assigns(order, lhs_vars, rhs_exprs) do
    Enum.map(order, fn idx ->
      {:=, [], [Enum.at(lhs_vars, idx), Enum.at(rhs_exprs, idx)]}
    end)
  end

  defp simple_var?({name, _, ctx}) when is_atom(name) and is_atom(ctx), do: true
  defp simple_var?(_), do: false

  # Kahn's algorithm: topological sort on 0..n-1 nodes.
  # edges: [{from, to}] where from must come before to.
  # Returns {:ok, order} or :cycle.
  defp topological_sort_indices(n, edges) do
    in_degree =
      Enum.reduce(edges, List.duplicate(0, n), fn {_from, to}, acc ->
        List.update_at(acc, to, &(&1 + 1))
      end)

    queue = for i <- 0..(n - 1), Enum.at(in_degree, i) == 0, do: i
    do_topo_sort(queue, edges, in_degree, [], n)
  end

  defp do_topo_sort([], _edges, _deg, order, n) do
    if length(order) == n, do: {:ok, Enum.reverse(order)}, else: :cycle
  end

  defp do_topo_sort([node | rest], edges, deg, order, n) do
    succs = for {^node, s} <- edges, do: s

    {new_deg, new_queue} =
      Enum.reduce(succs, {deg, rest}, fn s, {d, q} ->
        d2 = List.update_at(d, s, &(&1 - 1))
        q2 = if Enum.at(d2, s) == 0, do: q ++ [s], else: q
        {d2, q2}
      end)

    do_topo_sort(new_queue, edges, new_deg, [node | order], n)
  end
end
