defmodule Loop.Patterns.Helpers do
  @moduledoc false

  # The callback set handed to Loop.Patterns.Advanced / Collection matchers.
  def standard_callbacks do
    [
      decrement_by_one: &decrement_by_one?/2,
      empty_list_check: &empty_list_check?/1,
      enum_reverse_arg: &enum_reverse_arg/1,
      has_var: &has_var?/2,
      list_loop_ir: &list_loop_ir/1,
      list_or_zero_check: &list_or_zero_check?/1,
      list_prepend: &list_prepend?/3,
      map_destructure: &map_destructure/1,
      next_step: &next_step/1,
      normalize: &Loop.Normalize.normalize/1,
      replace_var: &replace_var/3,
      vars_equal: &vars_equal?/2
    ]
  end

  def find_break_continue_clauses(clauses) do
    break_clause =
      Enum.find_value(clauses, fn
        {:->, _, [[[]], {:break, _, [break_expr]}]} -> {:empty, break_expr}
        _ -> nil
      end)

    continue_clause =
      Enum.find_value(clauses, fn
        # P053: [h | rest] when guard -> continue_expr (guard hoisted as conditional step)
        {:->, _, [[{:when, _, [[{:|, _, [elem_var, rest_var]}], guard]}], continue_expr]} ->
          {:cons_guarded, elem_var, rest_var, guard, continue_expr}

        # [h | rest] -> continue_expr
        {:->, _, [[[{:|, _, [elem_var, rest_var]}]], continue_expr]} ->
          {:cons, elem_var, rest_var, continue_expr}

        # _ -> continue_expr (but not the [] -> break clause)
        {:->, _, [[{:_, _, _}], continue_expr]} ->
          {:wildcard, continue_expr}

        # var -> continue_expr (catch-all variable binding, not [])
        {:->, _, [[{name, _, ctx}], continue_expr]}
        when is_atom(name) and is_atom(ctx) ->
          {:wildcard, continue_expr}

        _ ->
          nil
      end)

    {break_clause, continue_clause}
  end

  # Check if expr is tl(var)
  def tl_of?({:tl, _, [arg]}, var), do: arg == var
  def tl_of?(_, _), do: false

  # Replace hd(list_var) with replacement in AST
  def replace_hd(ast, list_var, replacement) do
    Macro.prewalk(ast, fn
      {:hd, _, [arg]} = node ->
        if arg == list_var, do: replacement, else: node

      node ->
        node
    end)
  end

  # Comprehensive helper to recognize various forms of "is list non-empty?" checks
  # Returns {list_var, list_var} if recognized, nil otherwise
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def non_empty_list_check?(condition) do
    case condition do
      # list != [] or [] != list
      {:!=, _, [list, []]} ->
        {list, list}

      {:!=, _, [[], list]} ->
        {list, list}

      # list !== [] or [] !== list
      {:!==, _, [list, []]} ->
        {list, list}

      {:!==, _, [[], list]} ->
        {list, list}

      # Kernel.!=(list, []) or Kernel.!=([], list)
      {{:., _, [{:__aliases__, _, [:Kernel]}, :!=]}, _, [list, []]} ->
        {list, list}

      {{:., _, [{:__aliases__, _, [:Kernel]}, :!=]}, _, [[], list]} ->
        {list, list}

      # Kernel.!==(list, []) or Kernel.!==([], list)
      {{:., _, [{:__aliases__, _, [:Kernel]}, :!==]}, _, [list, []]} ->
        {list, list}

      {{:., _, [{:__aliases__, _, [:Kernel]}, :!==]}, _, [[], list]} ->
        {list, list}

      # !Enum.empty?(list)
      {:!, _, [{{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]}]} ->
        {list, list}

      # not Enum.empty?(list)
      {:not, _, [{{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]}]} ->
        {list, list}

      # match?([_ | _], list)
      {:match?, _, [[{:|, _, [{:_, _, _}, {:_, _, _}]}], list]} ->
        {list, list}

      # length(list) > 0
      {:>, _, [{:length, _, [list]}, 0]} ->
        {list, list}

      {:<, _, [0, {:length, _, [list]}]} ->
        {list, list}

      # length(list) >= 1
      {:>=, _, [{:length, _, [list]}, 1]} ->
        {list, list}

      {:<=, _, [1, {:length, _, [list]}]} ->
        {list, list}

      # length(list) != 0
      {:!=, _, [{:length, _, [list]}, 0]} ->
        {list, list}

      {:!=, _, [0, {:length, _, [list]}]} ->
        {list, list}

      _ ->
        nil
    end
  end

  # Canonical IR for list-processing loops.
  # Returns %{list_var, elem_var, break_expr, steps} or nil.
  def list_loop_ir(body) do
    case body do
      {:__block__, _, exprs} ->
        list_loop_ir_from_block(exprs)

      {:case, _, [scrutinee, [do: clauses]]} ->
        list_loop_ir_from_case(scrutinee, clauses)

      {:cond, _, [[do: clauses]]} ->
        list_loop_ir_from_cond(clauses)

      # P045: two-branch cond → if (produced by normalize); handle if as loop body
      {:if, _, [condition, [do: do_branch, else: else_body]]} ->
        list_loop_ir_from_if_else(condition, do_branch, else_body)

      _ ->
        nil
    end
  end

  # Handle `if empty?(list), do: break(x), else: continuation` as loop IR.
  # This is the canonical output of P045 for cond-body loops.
  def list_loop_ir_from_if_else(condition, do_branch, else_body) do
    with {list_var, _} <- empty_list_check?(condition),
         {:break, _, [break_expr]} <- do_branch,
         {elem_var, steps} <- parse_continue_expr(list_var, else_body) do
      %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps}
    else
      _ -> nil
    end
  end

  def list_loop_ir_from_block([exit_expr | tail]) do
    with {list_var, break_expr} <- empty_break_clause(exit_expr),
         {elem_var, steps} <- parse_continue_expr(list_var, tail) do
      %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps}
    else
      _ -> nil
    end
  end

  def list_loop_ir_from_block(_), do: nil

  def list_loop_ir_from_case(scrutinee, clauses) when is_list(clauses) do
    with {{:empty, break_expr}, continue_clause} <- find_break_continue_clauses(clauses),
         {elem_var, steps} <- case_continue_to_steps(scrutinee, continue_clause) do
      %{list_var: scrutinee, elem_var: elem_var, break_expr: break_expr, steps: steps}
    else
      _ -> nil
    end
  end

  def list_loop_ir_from_case(_, _), do: nil

  def list_loop_ir_from_cond(clauses) when is_list(clauses) do
    with {break_condition, break_expr} <- cond_break_clause(clauses),
         {list_var, _} <- empty_list_check?(break_condition),
         continue_expr when not is_nil(continue_expr) <-
           cond_continue_clause(clauses, break_condition),
         {elem_var, steps} <- parse_continue_expr(list_var, continue_expr) do
      %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps}
    else
      _ -> nil
    end
  end

  def list_loop_ir_from_cond(_), do: nil

  def case_continue_to_steps(list_var, {:cons, elem_var, rest_var, continue_expr}) do
    steps =
      continue_expr
      |> block_exprs()
      |> Enum.map(&replace_var(&1, rest_var, list_var))

    {elem_var, steps}
  end

  # P053: guarded cons — hoist guard as conditional step wrapping the body.
  # e.g. `[h | t] when pred(h) -> break(h)` becomes steps: [if pred(h), do: break(h)]
  def case_continue_to_steps(list_var, {:cons_guarded, elem_var, rest_var, guard, continue_expr}) do
    guard_step = replace_var(guard, rest_var, list_var)

    inner_steps =
      continue_expr
      |> block_exprs()
      |> Enum.map(&replace_var(&1, rest_var, list_var))

    wrapped =
      case inner_steps do
        [single] -> {:if, [], [guard_step, [do: single]]}
        _ -> {:if, [], [guard_step, [do: {:__block__, [], inner_steps}]]}
      end

    {elem_var, [wrapped]}
  end

  def case_continue_to_steps(list_var, {:wildcard, continue_expr}) do
    parse_continue_expr(list_var, continue_expr)
  end

  def case_continue_to_steps(_, _), do: nil

  # if empty?(list), do: break(x)
  # unless non_empty?(list), do: break(x)
  def empty_break_clause({:if, _, [condition, [do: {:break, _, [break_expr]}]]}) do
    case empty_list_check?(condition) do
      {list_var, _} -> {list_var, break_expr}
      _ -> nil
    end
  end

  def empty_break_clause({:unless, _, [condition, [do: {:break, _, [break_expr]}]]}) do
    case non_empty_list_check?(condition) do
      {list_var, _} -> {list_var, break_expr}
      _ -> nil
    end
  end

  def empty_break_clause(_), do: nil

  def cond_break_clause(clauses) do
    Enum.find_value(clauses, fn
      {:->, _, [[condition], {:break, _, [break_expr]}]} -> {condition, break_expr}
      _ -> nil
    end)
  end

  def cond_continue_clause(clauses, break_condition) do
    Enum.find_value(clauses, fn
      {:->, _, [[condition], expr]} when condition != break_condition -> expr
      _ -> nil
    end)
  end

  def parse_continue_expr(list_var, exprs) when is_list(exprs) do
    case exprs do
      [destructure | steps] ->
        case map_destructure(destructure) do
          {^list_var, elem_var} -> {elem_var, steps}
          _ -> parse_continue_hd_tl(list_var, exprs)
        end

      _ ->
        nil
    end
  end

  def parse_continue_expr(list_var, continue_expr) do
    parse_continue_expr(list_var, block_exprs(continue_expr))
  end

  # P051: explicit element binding as first step — h = hd(list) followed by list = tl(list)
  # anywhere in the remaining steps.  h becomes the canonical elem_var directly.
  def parse_continue_hd_tl(list_var, [first | rest] = exprs) do
    case first do
      {:=, _, [{name, _, ctx} = h_var, {:hd, _, [^list_var]}]}
      when is_atom(name) and is_atom(ctx) ->
        tl_idx =
          Enum.find_index(rest, fn
            {:=, _, [^list_var, {:tl, _, [^list_var]}]} -> true
            _ -> false
          end)

        if tl_idx != nil do
          {h_var, List.delete_at(rest, tl_idx)}
        else
          parse_continue_hd_tl_impl(list_var, exprs)
        end

      _ ->
        parse_continue_hd_tl_impl(list_var, exprs)
    end
  end

  def parse_continue_hd_tl(_, _), do: nil

  # Original hd/tl form: list = tl(list) must be the last step;
  # hd(list) used inline in the preceding steps is replaced with a fresh elem_var.
  def parse_continue_hd_tl_impl(list_var, exprs) do
    {middle, [advance]} = Enum.split(exprs, -1)

    case next_step(advance) do
      ^list_var ->
        elem_var = {:elem, [], Elixir}
        hd_expr = {:hd, [], [list_var]}
        steps = Enum.map(middle, &replace_var(&1, hd_expr, elem_var))
        {elem_var, steps}

      _ ->
        nil
    end
  end

  def block_exprs({:__block__, _, exprs}), do: exprs
  def block_exprs(expr), do: [expr]

  # Returns {condition, payload} for if/unless conditional breaks.
  def conditional_break({:if, _, [condition, [do: {:break, _, [payload]}]]}) do
    {condition, payload}
  end

  # P040: if pred, do: break(payload), else: literal — produced by normalising
  # `cond do pred -> break(h); true -> nil end` (P045) and
  # `case pred do true -> break(h); false -> nil end` (P046).
  # Guardrail: else branch must be a literal so it has no side effects.
  def conditional_break({:if, _, [condition, [do: {:break, _, [payload]}, else: else_expr]]}) do
    if Macro.quoted_literal?(else_expr), do: {condition, payload}
  end

  def conditional_break({:unless, _, [condition, [do: {:break, _, [payload]}]]}) do
    {{:not, [], [condition]}, payload}
  end

  def conditional_break(_), do: nil

  def has_any_var?(ast, vars) when is_list(vars), do: Enum.any?(vars, &has_var?(ast, &1))

  def elem_aliases(steps, elem_var) do
    steps
    |> Enum.reduce([elem_var], fn
      {:=, _, [{name, _, ctx} = var, rhs]}, aliases when is_atom(name) and is_atom(ctx) ->
        if Enum.any?(aliases, &(&1 == rhs)), do: [var | aliases], else: aliases

      _, aliases ->
        aliases
    end)
    |> Enum.uniq()
  end

  def map_exit_strategy({:if, _, [condition, [do: {:break, _, [reverse_expr]}]]}) do
    with {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [acc]} <- reverse_expr,
         {list, _} <- empty_list_check?(condition) do
      {list, acc}
    else
      _ -> nil
    end
  end

  def map_exit_strategy(_), do: nil

  def map_destructure({:=, _, [[{:|, _, [h, list]}], list]}) do
    {list, h}
  end

  def map_destructure(_), do: nil
  # acc = [elem | acc]
  def list_prepend?({:=, _, [acc, [{:|, _, [elem, acc]}]]}, acc_var, elem_var) do
    acc == acc_var and elem == elem_var
  end

  def list_prepend?(_, _, _), do: false

  # Enum.reverse(acc)
  def enum_reverse_arg({{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [arg]}), do: arg

  def enum_reverse_arg(_), do: nil

  # n = n - 1
  def decrement_by_one?({:=, _, [n, {:-, _, [n, 1]}]}, n_var), do: n == n_var

  def decrement_by_one?(_, _), do: false

  # if list empty OR n == 0
  def list_or_zero_check?({op, _, [c1, c2]}) when op in [:or, :||] do
    cond do
      match = empty_list_check?(c1) ->
        with {list_var, _} <- match,
             count_var when not is_nil(count_var) <- zero_check?(c2) do
          {list_var, count_var}
        else
          _ -> nil
        end

      match = empty_list_check?(c2) ->
        with {list_var, _} <- match,
             count_var when not is_nil(count_var) <- zero_check?(c1) do
          {list_var, count_var}
        else
          _ -> nil
        end

      true ->
        nil
    end
  end

  def list_or_zero_check?(_), do: nil

  # n == 0 variants
  def zero_check?({:==, _, [n, 0]}), do: maybe_var_ast(n)
  def zero_check?({:==, _, [0, n]}), do: maybe_var_ast(n)
  def zero_check?({:===, _, [n, 0]}), do: maybe_var_ast(n)
  def zero_check?({:===, _, [0, n]}), do: maybe_var_ast(n)

  def zero_check?({{:., _, [{:__aliases__, _, [:Kernel]}, :==]}, _, [n, 0]}),
    do: maybe_var_ast(n)

  def zero_check?({{:., _, [{:__aliases__, _, [:Kernel]}, :==]}, _, [0, n]}),
    do: maybe_var_ast(n)

  def zero_check?({{:., _, [{:__aliases__, _, [:Kernel]}, :===]}, _, [n, 0]}),
    do: maybe_var_ast(n)

  def zero_check?({{:., _, [{:__aliases__, _, [:Kernel]}, :===]}, _, [0, n]}),
    do: maybe_var_ast(n)

  def zero_check?(_), do: nil

  def maybe_var_ast({name, _, ctx} = ast) when is_atom(name) and is_atom(ctx), do: ast

  def maybe_var_ast(_), do: nil

  # Helper to check if AST contains a break call
  def has_break?(ast) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        {:break, _, _}, _acc -> {{:break, [], []}, true}
        node, acc -> {node, acc}
      end)

    found
  end

  # Helper to check if AST contains a variable
  def has_var?(ast, var) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        ^var, _acc -> {var, true}
        node, acc -> {node, acc}
      end)

    found
  end

  def has_var_name?(ast, {name, _, _}) when is_atom(name) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        {^name, _, ctx} = node, _acc when ctx in [nil, Elixir] -> {node, true}
        node, acc -> {node, acc}
      end)

    found
  end

  def has_var_name?(_ast, _var), do: false

  # Helper to replace a variable/expression in AST
  def replace_var(ast, old_var, new_var) do
    Macro.prewalk(ast, fn
      node when node == old_var -> new_var
      node -> node
    end)
  end

  # Helper to check if two variable AST nodes refer to the same variable
  def vars_equal?({name, _, ctx1}, {name, _, ctx2})
      when ctx1 in [nil, Elixir] and ctx2 in [nil, Elixir] do
    true
  end

  def vars_equal?(_, _), do: false

  def same_var_ast?(left, right) do
    case {maybe_var_ast(left), maybe_var_ast(right)} do
      {left_var, right_var} when not is_nil(left_var) and not is_nil(right_var) ->
        vars_equal?(left_var, right_var)

      _ ->
        left == right
    end
  end

  # Comprehensive helper to recognize various forms of "is list empty?" checks
  # Returns {list_var, list_var} if recognized, nil otherwise
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def empty_list_check?(condition) do
    case condition do
      # list == [] or [] == list
      {:==, _, [list, []]} ->
        {list, list}

      {:==, _, [[], list]} ->
        {list, list}

      # list === [] or [] === list
      {:===, _, [list, []]} ->
        {list, list}

      {:===, _, [[], list]} ->
        {list, list}

      # Kernel.==(list, []) or Kernel.==([], list)
      {{:., _, [{:__aliases__, _, [:Kernel]}, :==]}, _, [list, []]} ->
        {list, list}

      {{:., _, [{:__aliases__, _, [:Kernel]}, :==]}, _, [[], list]} ->
        {list, list}

      # Kernel.===(list, []) or Kernel.===([], list)
      {{:., _, [{:__aliases__, _, [:Kernel]}, :===]}, _, [list, []]} ->
        {list, list}

      {{:., _, [{:__aliases__, _, [:Kernel]}, :===]}, _, [[], list]} ->
        {list, list}

      # Enum.empty?(list)
      {{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]} ->
        {list, list}

      # not match?([_ | _], list)
      {:not, _, [{{:match?, _, [[{:|, _, [{:_, _, _}, {:_, _, _}]}], list]}}]} ->
        {list, list}

      # not Kernel.match?([_ | _], list)
      {:not, _,
       [
         {{:., _, [{:__aliases__, _, [:Kernel]}, :match?]}, _,
          [[{:|, _, [{:_, _, _}, {:_, _, _}]}], list]}
       ]} ->
        {list, list}

      # match?([], list)
      {:match?, _, [[], list]} ->
        {list, list}

      # Kernel.match?([], list)
      {{:., _, [{:__aliases__, _, [:Kernel]}, :match?]}, _, [[], list]} ->
        {list, list}

      # length(list) == 0 or 0 == length(list)
      {:==, _, [{:length, _, [list]}, 0]} ->
        {list, list}

      {:==, _, [0, {:length, _, [list]}]} ->
        {list, list}

      # length(list) <= 0 or 0 >= length(list)
      {:<=, _, [{:length, _, [list]}, 0]} ->
        {list, list}

      {:>=, _, [0, {:length, _, [list]}]} ->
        {list, list}

      # length(list) < 1 or 1 > length(list)
      {:<, _, [{:length, _, [list]}, 1]} ->
        {list, list}

      {:>, _, [1, {:length, _, [list]}]} ->
        {list, list}

      # Enum.count(list) == 0 or 0 == Enum.count(list)
      {:==, _, [{{:., _, [{:__aliases__, _, [:Enum]}, :count]}, _, [list]}, 0]} ->
        {list, list}

      {:==, _, [0, {{:., _, [{:__aliases__, _, [:Enum]}, :count]}, _, [list]}]} ->
        {list, list}

      # Enum.count(list) <= 0 or 0 >= Enum.count(list)
      {:<=, _, [{{:., _, [{:__aliases__, _, [:Enum]}, :count]}, _, [list]}, 0]} ->
        {list, list}

      {:>=, _, [0, {{:., _, [{:__aliases__, _, [:Enum]}, :count]}, _, [list]}]} ->
        {list, list}

      # Enum.count(list) < 1 or 1 > Enum.count(list)
      {:<, _, [{{:., _, [{:__aliases__, _, [:Enum]}, :count]}, _, [list]}, 1]} ->
        {list, list}

      {:>, _, [1, {{:., _, [{:__aliases__, _, [:Enum]}, :count]}, _, [list]}]} ->
        {list, list}

      # case list do [] -> true; _ -> false end
      {:case, _, [list, [do: [{:->, _, [[[], true]], _}]]]} ->
        {list, list}

      # List.flatten(list) == [] or [] == List.flatten(list)
      {:==, _, [{{:., _, [{:__aliases__, _, [:List]}, :flatten]}, _, [list]}, []]} ->
        {list, list}

      {:==, _, [[], {{:., _, [{:__aliases__, _, [:List]}, :flatten]}, _, [list]}]} ->
        {list, list}

      # :lists.flatten(list) == [] or [] == :lists.flatten(list)
      {:==, _, [{{:., _, [:lists, :flatten]}, _, [list]}, []]} ->
        {list, list}

      {:==, _, [[], {{:., _, [:lists, :flatten]}, _, [list]}]} ->
        {list, list}

      # match?([], list) (might be wrapped differently)
      {{:., _, [:erlang, :match?]}, _, [[], list]} ->
        {list, list}

      _ ->
        nil
    end
  end

  # Reduce Tuple Pattern: list loop with N>=2 accumulators, break with tuple of all acc vars.
  # E.g. loop sum: 0, count: 0 do; if list==[], do: break({sum,count}); [h|list]=list; sum=sum+h; count=count+1; end

  def next_step({:=, _, [lhs, {:tl, _, [rhs]}]}),
    do: if(vars_equal?(lhs, rhs), do: lhs, else: nil)

  def next_step(_), do: nil

  def find_index_increment({:=, _, [index, {:+, _, [index, 1]}]}, index_var) do
    if index == index_var, do: index_var
  end

  def find_index_increment(_, _), do: nil
end
