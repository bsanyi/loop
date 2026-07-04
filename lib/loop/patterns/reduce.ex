defmodule Loop.Patterns.Reduce do
  @moduledoc false

  import Loop.Patterns.Helpers

  # Reduce While Pattern: early exit reduce
  def reduce_while_pattern(initials, body) do
    with [{acc_name, init}] <- initials,
         {:__block__, _, [exit, destructure, check, accumulate]} <- body,
         acc_var = {acc_name, [], nil},
         {list_var, ^acc_var} <- reduce_while_exit(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {stop_condition, ^acc_var} <- reduce_while_check(check, acc_var),
         {^acc_var, transform} <- reduce_while_accumulate(accumulate, acc_var) do
      build_reduce_while(list_var, init, elem_var, acc_var, stop_condition, transform)
    else
      _ -> nil
    end
  end

  defp build_reduce_while(list_var, init, elem_var, acc_var, stop_condition, transform) do
    quote do
      Enum.reduce_while(unquote(list_var), unquote(init), fn unquote(elem_var),
                                                             unquote(acc_var) ->
        if unquote(stop_condition),
          do: {:halt, unquote(acc_var)},
          else: {:cont, unquote(transform)}
      end)
    end
  end

  defp reduce_while_exit({:if, _, [condition, [do: {:break, _, [acc]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> {list, acc}
      nil -> nil
    end
  end

  defp reduce_while_exit(_), do: nil

  # if stop_condition, do: break(acc)
  defp reduce_while_check({:if, _, [condition, [do: {:break, _, [acc]}]]}, acc_var) do
    if acc == acc_var, do: {condition, acc_var}
  end

  # P041: if stop_condition, do: break(acc), else: literal — produced by normalising
  # `cond do pred -> break(acc); true -> :cont end` (P045) and equivalent case forms.
  # Guardrail: else branch must be a literal so it has no side effects.
  defp reduce_while_check(
         {:if, _, [condition, [do: {:break, _, [acc]}, else: else_expr]]},
         acc_var
       ) do
    if acc == acc_var and Macro.quoted_literal?(else_expr), do: {condition, acc_var}
  end

  defp reduce_while_check(_, _), do: nil

  # acc = transform(h, acc)
  defp reduce_while_accumulate({:=, _, [acc, transform]}, acc_var) do
    if acc == acc_var do
      {acc_var, transform}
    else
      nil
    end
  end

  defp reduce_while_accumulate(_, _), do: nil

  # Max/Min Pattern: init with hd(list), advance, exit, update with max/min
  def max_min_pattern(initials, body) do
    with [{best_name, {:hd, _, [init_list]}}] <- initials,
         init_list_normalized <- normalize_var(init_list),
         {:__block__, _, [advance, exit, update]} <- body,
         best_var = {best_name, [], nil},
         list_var <- next_step(advance),
         # verify it's the same list
         true <- vars_equal?(init_list_normalized, list_var),
         {^list_var, ^best_var} <- max_min_exit(exit),
         {^best_var, func_or_comparator} <- max_min_update(update, best_var, list_var) do
      case func_or_comparator do
        :max ->
          quote do
            Enum.max(unquote(list_var))
          end

        :min ->
          quote do
            Enum.min(unquote(list_var))
          end

        # P069: Custom comparator for max
        {:max, comparator} ->
          quote do
            Enum.max(unquote(list_var), unquote(comparator))
          end

        # P069: Custom comparator for min
        {:min, comparator} ->
          quote do
            Enum.min(unquote(list_var), unquote(comparator))
          end
      end
    else
      _ -> nil
    end
  end

  defp max_min_exit({:if, _, [condition, [do: {:break, _, [best]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> {list, best}
      nil -> nil
    end
  end

  defp max_min_exit(_), do: nil

  # best = max(best, hd(list)) or best = min(best, hd(list))
  defp max_min_update(
         {:=, _, [best, {:max, _, [best, {:hd, _, [list]}]}]},
         best_var,
         list_var
       ) do
    if best == best_var and list == list_var, do: {best_var, :max}
  end

  defp max_min_update(
         {:=, _, [best, {:min, _, [best, {:hd, _, [list]}]}]},
         best_var,
         list_var
       ) do
    if best == best_var and list == list_var, do: {best_var, :min}
  end

  # P069: best = if compare(hd(list), best) == :gt, do: hd(list), else: best
  # or: best = if :gt == compare(hd(list), best), do: hd(list), else: best
  defp max_min_update(
         {:=, _, [best, {:if, _, [condition, [do: do_expr, else: else_expr]]}]},
         best_var,
         list_var
       ) do
    with {compare_result, comp_atom} <- extract_comparison(condition),
         {:atom, atom_type} <- comp_atom,
         true <- atom_type in [:gt, :lt],
         {comparator_fn, elem_expr, best_expr} <-
           max_min_comparator_condition(compare_result, best_var, list_var),
         true <- do_expr == elem_expr,
         true <- else_expr == best_expr,
         true <- best == best_var do
      func = if atom_type == :gt, do: :max, else: :min
      {best_var, {func, comparator_fn}}
    else
      _ -> nil
    end
  end

  defp max_min_update(_, _, _), do: nil

  # Helper: Extract comparison result and atom from condition
  # Handles both: result == atom and atom == result
  defp extract_comparison({:==, _, [left, right]}) do
    {left, right}
  end

  defp extract_comparison(_), do: nil

  # Helper: Extract comparator function from compare(hd(list), best) call
  # Returns {comparator_fn, elem_expr, best_expr}
  defp max_min_comparator_condition(compare_result, best_var, list_var) do
    case compare_result do
      {comparator_name, _, [arg1, arg2]} when is_atom(comparator_name) ->
        # Check if arg1 is hd(list) and arg2 is best, or vice versa
        with {:hd, _, [list]} <- arg1,
             true <- list == list_var,
             true <- arg2 == best_var do
          comparator_fn = {comparator_name, [], []}
          {comparator_fn, arg1, arg2}
        else
          _ ->
            # Try reversed order
            with {:hd, _, [list]} <- arg2,
                 true <- list == list_var,
                 true <- arg1 == best_var do
              comparator_fn = {comparator_name, [], []}
              {comparator_fn, arg2, arg1}
            else
              _ -> nil
            end
        end

      _ ->
        nil
    end
  end

  # Scan Pattern: two accumulators [acc: [], running: init], running = running op h, acc = [running | acc]
  def scan_pattern(initials, body) do
    with [{acc_name, []}, {running_name, init}] <- initials,
         {:__block__, _, [exit, destructure, update_running, accumulate]} <- body,
         acc_var = {acc_name, [], nil},
         running_var = {running_name, [], nil},
         {list_var, ^acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^running_var, op_or_expr} <- scan_update_running(update_running, running_var, elem_var),
         true <- scan_accumulate(accumulate, acc_var, running_var) do
      operation = scan_operation(op_or_expr, running_var, elem_var)

      quote do
        Enum.scan(unquote(list_var), unquote(init), unquote(operation))
      end
    else
      _ -> nil
    end
  end

  # Scan Tuple Pattern (P014): {running, acc} = {new_running, [new_running | acc]}.
  # Normalize P052 decomposes that tuple assign into `acc = [new_running | acc];
  # running = new_running` (accumulate first, due to the cross-reference), so both
  # the intact and the decomposed 4-statement forms are accepted.
  def scan_tuple_pattern(initials, body) do
    with [{acc_name, []}, {running_name, init}] <- initials,
         acc_var = {acc_name, [], nil},
         running_var = {running_name, [], nil},
         {exit, destructure, updates} <- scan_tuple_block(body),
         {list_var, ^acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         new_running when not is_nil(new_running) <-
           scan_tuple_new_running(updates, running_var, acc_var, elem_var) do
      operation =
        quote do
          fn unquote(elem_var), unquote(running_var) -> unquote(new_running) end
        end

      quote do
        Enum.scan(unquote(list_var), unquote(init), unquote(operation))
      end
    else
      _ -> nil
    end
  end

  defp scan_tuple_block({:__block__, _, [exit, destructure, tuple_update]}),
    do: {exit, destructure, [tuple_update]}

  defp scan_tuple_block({:__block__, _, [exit, destructure, accumulate, update_running]}),
    do: {exit, destructure, [accumulate, update_running]}

  defp scan_tuple_block(_), do: nil

  # {running, acc} = {new_running, [new_running | acc]} — both sides must use same expression
  defp scan_tuple_new_running(
         [{:=, _, [{running, acc}, {new_running, [{:|, _, [new_running2, acc]}]}]}],
         running_var,
         acc_var,
         elem_var
       ) do
    if running == running_var and acc == acc_var and new_running == new_running2 and
         has_var?(new_running, running_var) and has_var?(new_running, elem_var) do
      new_running
    else
      nil
    end
  end

  # Decomposed form: acc = [new_running | acc]; running = new_running
  defp scan_tuple_new_running(
         [
           {:=, _, [acc, [{:|, _, [new_running, acc]}]]},
           {:=, _, [running, new_running2]}
         ],
         running_var,
         acc_var,
         elem_var
       ) do
    if running == running_var and acc == acc_var and new_running == new_running2 and
         has_var?(new_running, running_var) and has_var?(new_running, elem_var) do
      new_running
    else
      nil
    end
  end

  defp scan_tuple_new_running(_, _, _, _), do: nil

  # Build the Enum.scan operation fn from either an operator atom or a full expression
  defp scan_operation(op, _running_var, _elem_var) when is_atom(op) do
    {:fn, [],
     [
       {:->, [],
        [
          [{:x, [], Elixir}, {:running, [], Elixir}],
          {op, [], [{:running, [], Elixir}, {:x, [], Elixir}]}
        ]}
     ]}
  end

  defp scan_operation(expr, running_var, elem_var) do
    quote do
      fn unquote(elem_var), unquote(running_var) -> unquote(expr) end
    end
  end

  # running = running op elem (infix form)
  defp scan_update_running({:=, _, [running, {op, _, [running, elem]}]}, running_var, elem_var) do
    if running == running_var and elem == elem_var do
      {running_var, op}
    else
      nil
    end
  end

  # running = Kernel.op(running, elem) (P012)
  defp scan_update_running(
         {:=, _, [running, {{:., _, [{:__aliases__, _, [:Kernel]}, op]}, _, [running, elem]}]},
         running_var,
         elem_var
       ) do
    if running == running_var and elem == elem_var do
      {running_var, op}
    else
      nil
    end
  end

  # running = any_expr(running, elem) — arbitrary expression (P013)
  defp scan_update_running({:=, _, [running, expr]}, running_var, elem_var) do
    if running == running_var and has_var?(expr, running_var) and has_var?(expr, elem_var) do
      {running_var, expr}
    else
      nil
    end
  end

  defp scan_update_running(_, _, _), do: nil

  # acc = [running | acc]
  defp scan_accumulate({:=, _, [acc, [{:|, _, [running, acc]}]]}, acc_var, running_var) do
    acc == acc_var and running == running_var
  end

  defp scan_accumulate(_, _, _), do: false

  # => Enum.reduce(list, {0, 0}, fn h, {sum, count} -> {sum+h, count+1} end)
  def reduce_tuple_pattern(initials, body) when length(initials) >= 2 do
    with %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         acc_vars <- Enum.map(initials, fn {name, _} -> {name, [], nil} end),
         break_elems when not is_nil(break_elems) <- tuple_elements(break_expr),
         true <- break_elems == acc_vars,
         update_exprs when not is_nil(update_exprs) <-
           extract_acc_updates(steps, acc_vars) do
      inits = Enum.map(initials, fn {_, init} -> init end)
      init_tuple = build_tuple_ast(inits)
      acc_pattern = build_tuple_ast(acc_vars)
      update_tuple = build_tuple_ast(update_exprs)

      quote do
        Enum.reduce(unquote(list_var), unquote(init_tuple), fn unquote(elem_var),
                                                               unquote(acc_pattern) ->
          unquote(update_tuple)
        end)
      end
    else
      _ -> nil
    end
  end

  def reduce_tuple_pattern(_, _), do: nil

  # Reduce Constant Pattern: list loop with no accumulators, break with a constant literal.
  # E.g. loop do; if list==[], do: break(%{sum: 6, count: 3}); [h|list]=list; end
  # => Enum.reduce(list, const, fn _, acc -> acc end)
  def reduce_constant_pattern([], body) do
    with %{list_var: list_var, elem_var: _elem_var, break_expr: break_expr, steps: []} <-
           list_loop_ir(body),
         true <- Macro.quoted_literal?(break_expr) do
      quote do
        Enum.reduce(unquote(list_var), unquote(break_expr), fn _, acc -> acc end)
      end
    else
      _ -> nil
    end
  end

  def reduce_constant_pattern(_, _), do: nil

  # While Multi Pattern: non-list loop with 3+ initial bindings, condition-based break with
  # a tuple of all state vars, and only simple assignments as body steps.
  # E.g. loop a: 1, b: 2, c: 3 do; if a>10, do: break({a,b,c}); a=a+1; b=b+2; c=c+3; end
  # => Enum.find_value(Stream.iterate({1,2,3}, fn {a,b,c} -> {a+1,b+2,c+3} end),
  #                    fn {a,b,c} -> if a>10, do: {a,b,c} end)
  def while_multi_pattern(initials, body) when length(initials) >= 3 do
    with {:__block__, _, stmts} <- body,
         [check | update_stmts] <- stmts,
         {:if, _, [condition, [do: {:break, _, [break_expr]}]]} <- check,
         true <- Enum.all?(update_stmts, &match?({:=, _, _}, &1)),
         acc_vars <- Enum.map(initials, fn {name, _} -> {name, [], nil} end),
         break_elems when not is_nil(break_elems) <- tuple_elements(break_expr),
         true <- break_elems == acc_vars,
         update_exprs when not is_nil(update_exprs) <-
           extract_acc_updates(update_stmts, acc_vars) do
      inits = Enum.map(initials, fn {_, init} -> init end)
      init_tuple = build_tuple_ast(inits)
      acc_pattern = build_tuple_ast(acc_vars)
      update_tuple = build_tuple_ast(update_exprs)

      checker_fn =
        {:fn, [], [{:->, [], [[acc_pattern], {:if, [], [condition, [do: break_expr]]}]}]}

      quote do
        Enum.find_value(
          Stream.iterate(unquote(init_tuple), fn unquote(acc_pattern) -> unquote(update_tuple) end),
          unquote(checker_fn)
        )
      end
    else
      _ -> nil
    end
  end

  def while_multi_pattern(_, _), do: nil

  defp tuple_elements({:{}, _, elems}), do: elems
  defp tuple_elements({a, b}), do: [a, b]
  defp tuple_elements(_), do: nil

  defp build_tuple_ast([a, b]), do: {a, b}
  defp build_tuple_ast(elems), do: {:{}, [], elems}

  defp extract_acc_updates(steps, acc_vars) do
    updates =
      Enum.map(acc_vars, fn acc_var ->
        Enum.find_value(steps, fn
          {:=, _, [^acc_var, update]} -> update
          _ -> nil
        end)
      end)

    if Enum.all?(updates, &(&1 != nil)), do: updates
  end

  # P078 — Filter + count (dual return):
  # loop acc: [], count: 0 do
  #   if list == [], do: break({Enum.reverse(acc), count})
  #   [h | list] = list
  #   if pred(h) do acc = [h | acc]; count = count + 1 end
  # end
  # => filtered = Enum.filter(list, fn h -> pred(h) end); {filtered, length(filtered)}
  def filter_count_pattern(initials, body) do
    with [{acc_name, []}, {count_name, 0}] <- initials,
         acc_var = {acc_name, [], nil},
         count_var = {count_name, [], nil},
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir(body),
         {^acc_var, ^count_var} <- filter_count_break(break_expr, acc_var, count_var),
         [if_step] <- steps,
         {pred, ^acc_var, ^count_var} <- filter_count_step(if_step, elem_var, acc_var, count_var) do
      quote do
        filtered = Enum.filter(unquote(list_var), fn unquote(elem_var) -> unquote(pred) end)
        {filtered, length(filtered)}
      end
    else
      _ -> filter_count_pattern_reversed(initials, body)
    end
  end

  # Try with reversed initial order: count: 0, acc: []
  defp filter_count_pattern_reversed(initials, body) do
    with [{count_name, 0}, {acc_name, []}] <- initials,
         acc_var = {acc_name, [], nil},
         count_var = {count_name, [], nil},
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir(body),
         {^acc_var, ^count_var} <- filter_count_break(break_expr, acc_var, count_var),
         [if_step] <- steps,
         {pred, ^acc_var, ^count_var} <- filter_count_step(if_step, elem_var, acc_var, count_var) do
      quote do
        filtered = Enum.filter(unquote(list_var), fn unquote(elem_var) -> unquote(pred) end)
        {filtered, length(filtered)}
      end
    else
      _ -> nil
    end
  end

  # Break must be {Enum.reverse(acc), count}
  defp filter_count_break({reverse_acc, count_check}, acc_var, count_var)
       when count_check == count_var do
    rev_arg = enum_reverse_arg(reverse_acc)

    if rev_arg == acc_var do
      {acc_var, count_var}
    else
      nil
    end
  end

  defp filter_count_break(_, _, _), do: nil

  # Step must be `if pred(h), do: {acc = [h | acc]; count = count + 1}` (single-branch)
  # After normalize, the block body is {:__block__, [], [step1, step2]}
  # Handles both orderings: acc-first or count-first
  defp filter_count_step(
         {:if, _, [pred, [do: {:__block__, [], [step1, step2]}]]},
         elem_var,
         acc_var,
         count_var
       ) do
    cons_step = {:=, [], [acc_var, [{:|, [], [elem_var, acc_var]}]]}
    incr_step = {:=, [], [count_var, {:+, [], [count_var, 1]}]}

    if has_var?(pred, elem_var) and
         ((step1 == cons_step and step2 == incr_step) or
            (step1 == incr_step and step2 == cons_step)) do
      {pred, acc_var, count_var}
    else
      nil
    end
  end

  defp filter_count_step(_, _, _, _), do: nil

  # P080 — Any-with-index (dual return):
  # loop i: 0 do
  #   if list == [], do: break({false, nil})
  #   [h | list] = list
  #   if pred(h), do: break({true, i})
  #   i = i + 1
  # Reduce Pattern: existing implementation
  def reduce_pattern(initials, body) do
    case reduce(initials, body) do
      {object, zero, :+} when zero in [0, 0.0] ->
        quote do
          Enum.sum(unquote(object))
        end

      {object, one, :*} when one in [1, 1.0] ->
        quote do
          Enum.product(unquote(object))
        end

      {enum, init, op} ->
        operation =
          {:fn, [],
           [
             {:->, [],
              [
                [{:x, [], Elixir}, {:acc, [], Elixir}],
                {op, [], [{:acc, [], Elixir}, {:x, [], Elixir}]}
              ]}
           ]}

        quote do
          Enum.reduce(unquote(enum), unquote(init), unquote(operation))
        end

      _ ->
        nil
    end
  end

  defp reduce(initials, {:__block__, _, [exit_stmt, step2, step3]}) do
    with {object, target} <- exit_strategy(exit_stmt),
         {name, _, x} when x in [nil, Elixir] <- target,
         op when not is_nil(op) <-
           hd_tl_reduce_op(step2, step3, object, target) ||
             destructure_reduce_op(step2, step3, object, target) do
      {object, Keyword.get(initials, name), op}
    else
      _ -> nil
    end
  end

  defp reduce(_initials, _body), do: nil

  # acc = acc op hd(list); list = tl(list)
  defp hd_tl_reduce_op(reducer_step, next_step_expr, object, target) do
    with {^object, ^target, op} <- reducer(reducer_step),
         ^object <- next_step(next_step_expr) do
      op
    else
      _ -> nil
    end
  end

  # [h | list] = list; acc = acc op h  (P011)
  defp destructure_reduce_op(destructure_step, reducer_step, object, target) do
    with {^object, elem_var} <- map_destructure(destructure_step),
         {^target, op} <- reducer_from_elem(reducer_step, target, elem_var) do
      op
    else
      _ -> nil
    end
  end

  defp exit_strategy({:if, _, [condition, [do: {:break, _, [target]}]]}) do
    case empty_list_check?(condition) do
      {object, _} -> {object, target}
      nil -> nil
    end
  end

  defp exit_strategy(_), do: nil

  # acc = acc op hd(list) (hd/tl form)
  defp reducer({:=, _, [target, {op, _, [target, {:hd, _, [object]}]}]}), do: {object, target, op}

  # acc = Kernel.op(acc, hd(list)) (P012, hd/tl form)
  defp reducer(
         {:=, _,
          [
            target,
            {{:., _, [{:__aliases__, _, [:Kernel]}, op]}, _, [target, {:hd, _, [object]}]}
          ]}
       ),
       do: {object, target, op}

  defp reducer(_), do: nil

  defp normalize_var({name, _meta, _ctx}) when is_atom(name), do: {name, [], nil}
  defp normalize_var(other), do: other

  # acc = acc op h (destructure form, P011)
  defp reducer_from_elem({:=, _, [target, {op, _, [target, elem]}]}, target_var, elem_var) do
    if target == target_var and elem == elem_var, do: {target_var, op}, else: nil
  end

  # acc = Kernel.op(acc, h) (destructure + Kernel form, P012)
  defp reducer_from_elem(
         {:=, _, [target, {{:., _, [{:__aliases__, _, [:Kernel]}, op]}, _, [target, elem]}]},
         target_var,
         elem_var
       ) do
    if target == target_var and elem == elem_var, do: {target_var, op}, else: nil
  end

  defp reducer_from_elem(_, _, _), do: nil
end
