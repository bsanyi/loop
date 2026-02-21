defmodule Loop.Patterns.Advanced do
  @moduledoc false

  def flat_map_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with [{acc_name, []}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         acc_var = {acc_name, [], nil},
         mapper when not is_nil(mapper) <-
           flat_map_mapper(steps, elem_var, acc_var, break_expr, enum_reverse_arg, has_var) do
      quote do
        Enum.flat_map(unquote(list_var), fn unquote(elem_var) -> unquote(mapper) end)
      end
    else
      _ -> nil
    end
  end

  defp flat_map_mapper(steps, elem_var, acc_var, break_expr, enum_reverse_arg, has_var) do
    aliases = elem_aliases(steps, elem_var)

    Enum.find_value(Enum.with_index(steps), fn
      {{:=, _, [acc, {:++, _, [acc, mapper_expr]}]}, idx} when acc == acc_var ->
        mapper = resolve_expr(mapper_expr, assignments_before(steps, idx))

        if has_any_var?(mapper, aliases, has_var) and break_expr == acc_var do
          mapper
        else
          nil
        end

      {{:=, _, [acc, {:++, _, [mapper_expr, acc]}]}, idx} when acc == acc_var ->
        mapper = resolve_expr(mapper_expr, assignments_before(steps, idx))

        with ^acc_var <- enum_reverse_arg.(break_expr),
             inner_mapper when not is_nil(inner_mapper) <- enum_reverse_arg.(mapper),
             true <- has_any_var?(inner_mapper, aliases, has_var) do
          inner_mapper
        else
          _ -> nil
        end

      _ ->
        nil
    end)
  end

  def map_reduce_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with [{name1, init1}, {name2, init2}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         var1 = {name1, [], nil},
         var2 = {name2, [], nil},
         {mapped_acc_var, state_var, state_init} <-
           map_reduce_roles({var1, init1}, {var2, init2}, break_expr, enum_reverse_arg),
         callback_tuple when not is_nil(callback_tuple) <-
           map_reduce_callback_tuple(steps, elem_var, mapped_acc_var, state_var, has_var) do
      quote do
        Enum.map_reduce(unquote(list_var), unquote(state_init), fn unquote(elem_var),
                                                                   unquote(state_var) ->
          unquote(callback_tuple)
        end)
      end
    else
      _ -> nil
    end
  end

  defp map_reduce_roles(
         {var1, init1},
         {var2, init2},
         {:{}, _, [left_expr, right_expr]},
         enum_reverse_arg
       ) do
    cond do
      enum_reverse_arg.(left_expr) == var1 and right_expr == var2 ->
        {var1, var2, init2}

      enum_reverse_arg.(left_expr) == var2 and right_expr == var1 ->
        {var2, var1, init1}

      true ->
        nil
    end
  end

  defp map_reduce_roles(_, _, _, _), do: nil

  defp map_reduce_callback_tuple(steps, elem_var, mapped_acc_var, state_var, has_var) do
    aliases = elem_aliases(steps, elem_var)

    Enum.find_value(Enum.with_index(steps), fn
      {step, idx} ->
        case cons_update(step) do
          {^mapped_acc_var, mapped_expr} ->
            map_reduce_callback_for_step(
              steps,
              idx,
              mapped_expr,
              aliases,
              mapped_acc_var,
              state_var,
              has_var
            )

          _ ->
            nil
        end
    end)
  end

  defp map_reduce_callback_for_step(
         steps,
         idx,
         mapped_expr,
         aliases,
         mapped_acc_var,
         state_var,
         has_var
       ) do
    tuple_from_tuple_assign =
      with {tuple_idx, tuple_rhs} <-
             tuple_state_assignment_for_mapped(steps, idx, mapped_expr, state_var),
           resolved_tuple <- resolve_expr(tuple_rhs, assignments_before(steps, tuple_idx)),
           true <-
             map_reduce_callback_valid?(
               resolved_tuple,
               aliases,
               mapped_acc_var,
               state_var,
               has_var
             ) do
        resolved_tuple
      else
        _ -> nil
      end

    tuple_from_tuple_assign ||
      with {state_idx, state_rhs} <- latest_state_assignment(steps, state_var),
           resolved_mapped <- resolve_expr(mapped_expr, assignments_before(steps, idx)),
           resolved_state <- resolve_expr(state_rhs, assignments_before(steps, state_idx)),
           callback_tuple = {:{}, [], [resolved_mapped, resolved_state]},
           true <-
             map_reduce_callback_valid?(
               callback_tuple,
               aliases,
               mapped_acc_var,
               state_var,
               has_var
             ) do
        callback_tuple
      else
        _ -> nil
      end
  end

  defp tuple_state_assignment_for_mapped(steps, idx, mapped_expr, state_var) do
    steps
    |> Enum.take(idx + 1)
    |> Enum.with_index()
    |> Enum.reverse()
    |> Enum.find_value(fn
      {{:=, _, [{:{}, _, [mapped_lhs, state_lhs]}, rhs]}, tuple_idx}
      when mapped_lhs == mapped_expr and state_lhs == state_var ->
        {tuple_idx, rhs}

      _ ->
        nil
    end)
  end

  defp latest_state_assignment(steps, state_var) do
    steps
    |> Enum.with_index()
    |> Enum.reverse()
    |> Enum.find_value(fn
      {{:=, _, [state_lhs, rhs]}, idx} when state_lhs == state_var -> {idx, rhs}
      _ -> nil
    end)
  end

  defp map_reduce_callback_valid?(callback_tuple, aliases, mapped_acc_var, state_var, has_var) do
    has_any_var?(callback_tuple, [state_var | aliases], has_var) and
      not has_var.(callback_tuple, mapped_acc_var)
  end

  def flat_map_reduce_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{name1, init1}, {name2, init2}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         var1 = {name1, [], nil},
         var2 = {name2, [], nil},
         {mapped_acc_var, state_var, state_init} <-
           flat_map_reduce_roles({var1, init1}, {var2, init2}, break_expr),
         callback_tuple when not is_nil(callback_tuple) <-
           flat_map_reduce_callback_tuple(steps, elem_var, mapped_acc_var, state_var, has_var) do
      quote do
        Enum.flat_map_reduce(unquote(list_var), unquote(state_init), fn unquote(elem_var),
                                                                        unquote(state_var) ->
          unquote(callback_tuple)
        end)
      end
    else
      _ -> nil
    end
  end

  defp flat_map_reduce_roles({var1, init1}, {var2, init2}, {:{}, _, [left_expr, right_expr]}) do
    cond do
      left_expr == var1 and right_expr == var2 ->
        {var1, var2, init2}

      left_expr == var2 and right_expr == var1 ->
        {var2, var1, init1}

      true ->
        nil
    end
  end

  defp flat_map_reduce_roles(_, _, _), do: nil

  defp flat_map_reduce_callback_tuple(steps, elem_var, mapped_acc_var, state_var, has_var) do
    aliases = elem_aliases(steps, elem_var)

    Enum.find_value(Enum.with_index(steps), fn
      {{:=, _, [acc, {:++, _, [acc, mapper_expr]}]}, idx} when acc == mapped_acc_var ->
        flat_map_reduce_callback_for_step(
          steps,
          idx,
          mapper_expr,
          aliases,
          mapped_acc_var,
          state_var,
          has_var
        )

      _ ->
        nil
    end)
  end

  defp flat_map_reduce_callback_for_step(
         steps,
         idx,
         mapper_expr,
         aliases,
         mapped_acc_var,
         state_var,
         has_var
       ) do
    with {state_idx, state_rhs} <- latest_state_assignment(steps, state_var),
         true <- state_idx >= idx,
         resolved_mapper <- resolve_expr(mapper_expr, assignments_before(steps, idx)),
         resolved_state <- resolve_expr(state_rhs, assignments_before(steps, state_idx)),
         true <- list_like_mapper?(resolved_mapper),
         callback_tuple = {:{}, [], [resolved_mapper, resolved_state]},
         true <-
           map_reduce_callback_valid?(
             callback_tuple,
             aliases,
             mapped_acc_var,
             state_var,
             has_var
           ) do
      callback_tuple
    else
      _ -> nil
    end
  end

  defp list_like_mapper?(expr) do
    case expr do
      [] -> true
      [single] -> not is_nil(single)
      [_, _ | _] -> true
      {:++, _, [_, _]} -> true
      _ -> false
    end
  end

  def sum_by_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{sum_name, 0}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         sum_var = {sum_name, [], nil},
         true <- break_expr == sum_var,
         {update_idx, term_expr} <- sum_by_term_expr(steps, sum_var),
         true <- update_idx == length(steps) - 1,
         aliases <- elem_aliases(steps, elem_var),
         resolved_term <- resolve_expr(term_expr, assignments_before(steps, update_idx)),
         assigned_non_alias <- assigned_non_alias_vars(steps, aliases, [sum_var]),
         true <- has_any_var?(resolved_term, aliases, has_var),
         false <- has_var.(resolved_term, sum_var),
         false <- has_var.(resolved_term, list_var),
         false <- has_any_var?(resolved_term, assigned_non_alias, has_var) do
      quote do
        Enum.sum_by(unquote(list_var), fn unquote(elem_var) -> unquote(resolved_term) end)
      end
    else
      _ -> nil
    end
  end

  defp sum_by_term_expr(steps, sum_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, rhs]}, idx} when lhs == sum_var ->
          case plus_term(rhs, sum_var) do
            nil -> []
            term_expr -> [{idx, term_expr}]
          end

        _ ->
          []
      end)

    case updates do
      [{idx, term_expr}] -> {idx, term_expr}
      _ -> nil
    end
  end

  defp plus_term({:+, _, [left, right]}, sum_var) do
    cond do
      left == sum_var -> right
      right == sum_var -> left
      true -> nil
    end
  end

  defp plus_term({{:., _, [{:__aliases__, _, [:Kernel]}, :+]}, _, [left, right]}, sum_var),
    do: plus_term({:+, [], [left, right]}, sum_var)

  defp plus_term(_, _), do: nil

  def take_every_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, idx_var} <- take_every_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         {update_idx, condition, include_when_true, selected_expr} <-
           take_every_acc_update(steps, acc_var),
         resolved_selected <- resolve_expr(selected_expr, assignments_before(steps, update_idx)),
         true <- resolved_selected == elem_var,
         true <- take_every_index_updates_valid?(steps, idx_var),
         resolved_condition <- resolve_expr(condition, assignments_before(steps, update_idx)),
         {stride_expr, condition_true_on_boundary} <-
           take_every_stride_condition(resolved_condition, idx_var),
         false <- has_var.(stride_expr, idx_var),
         false <- has_var.(stride_expr, elem_var),
         true <- condition_true_on_boundary == include_when_true do
      take_every_quote(list_var, elem_var, idx_var, stride_expr)
    else
      _ -> nil
    end
  end

  defp take_every_vars([{acc_name, []}, {idx_name, 0}]),
    do: {{acc_name, [], nil}, {idx_name, [], nil}}

  defp take_every_vars([{idx_name, 0}, {acc_name, []}]),
    do: {{acc_name, [], nil}, {idx_name, [], nil}}

  defp take_every_vars(_), do: nil

  defp take_every_acc_update(steps, acc_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, rhs]}, idx} when lhs == acc_var ->
          case take_every_update_rhs(rhs, acc_var) do
            nil -> []
            parsed -> [{idx, parsed}]
          end

        _ ->
          []
      end)

    case updates do
      [{idx, {condition, include_when_true, selected_expr}}] ->
        {idx, condition, include_when_true, selected_expr}

      _ ->
        nil
    end
  end

  defp take_every_update_rhs({:if, _, [condition, [do: do_expr, else: else_expr]]}, acc_var),
    do: take_every_update_if(condition, do_expr, else_expr, acc_var)

  defp take_every_update_rhs({:unless, _, [condition, [do: do_expr, else: else_expr]]}, acc_var) do
    case take_every_update_if(condition, do_expr, else_expr, acc_var) do
      {parsed_condition, include_when_true, selected_expr} ->
        {parsed_condition, not include_when_true, selected_expr}

      _ ->
        nil
    end
  end

  defp take_every_update_rhs(_, _), do: nil

  defp take_every_update_if(condition, do_expr, else_expr, acc_var) do
    cond do
      do_expr == acc_var and match?({:|, _, [_, ^acc_var]}, else_expr) ->
        {:|, _, [selected_expr, ^acc_var]} = else_expr
        {condition, false, selected_expr}

      else_expr == acc_var and match?({:|, _, [_, ^acc_var]}, do_expr) ->
        {:|, _, [selected_expr, ^acc_var]} = do_expr
        {condition, true, selected_expr}

      true ->
        nil
    end
  end

  defp take_every_index_updates_valid?(steps, idx_var) do
    idx_updates =
      Enum.filter(steps, fn
        {:=, _, [lhs, _]} -> lhs == idx_var
        _ -> false
      end)

    idx_updates != [] and Enum.all?(idx_updates, &increment_by_one?(&1, idx_var))
  end

  defp increment_by_one?({:=, _, [idx, {:+, _, [idx, 1]}]}, idx_var), do: idx == idx_var
  defp increment_by_one?({:=, _, [idx, {:+, _, [1, idx]}]}, idx_var), do: idx == idx_var

  defp increment_by_one?(
         {:=, _, [idx, {{:., _, [{:__aliases__, _, [:Kernel]}, :+]}, _, [idx, 1]}]},
         idx_var
       ),
       do: idx == idx_var

  defp increment_by_one?(
         {:=, _, [idx, {{:., _, [{:__aliases__, _, [:Kernel]}, :+]}, _, [1, idx]}]},
         idx_var
       ),
       do: idx == idx_var

  defp increment_by_one?(_, _), do: false

  defp take_every_stride_condition({op, _, [inner]}, idx_var) when op in [:not, :!] do
    case take_every_stride_condition(inner, idx_var) do
      {stride_expr, true_on_boundary} -> {stride_expr, not true_on_boundary}
      _ -> nil
    end
  end

  defp take_every_stride_condition({op, _, [left, right]}, idx_var)
       when op in [:==, :===, :!=, :!==] do
    take_every_stride_compare(op, left, right, idx_var)
  end

  defp take_every_stride_condition(
         {{:., _, [{:__aliases__, _, [:Kernel]}, op]}, _, [left, right]},
         idx_var
       )
       when op in [:==, :===, :!=, :!==] do
    take_every_stride_compare(op, left, right, idx_var)
  end

  defp take_every_stride_condition(_, _), do: nil

  defp take_every_stride_compare(op, left, right, idx_var) do
    eq_op = op in [:==, :===]

    cond do
      rem_call = take_every_rem_call(left, idx_var) ->
        if right == 0, do: {rem_call, eq_op}

      rem_call = take_every_rem_call(right, idx_var) ->
        if left == 0, do: {rem_call, eq_op}

      true ->
        nil
    end
  end

  defp take_every_rem_call({:rem, _, [idx, stride_expr]}, idx_var) do
    if idx == idx_var, do: stride_expr
  end

  defp take_every_rem_call(
         {{:., _, [{:__aliases__, _, [:Kernel]}, :rem]}, _, [idx, stride_expr]},
         idx_var
       ) do
    if idx == idx_var, do: stride_expr
  end

  defp take_every_rem_call(_, _), do: nil

  defp take_every_quote(list_var, _elem_var, _idx_var, stride_expr) do
    quote do
      list = unquote(list_var)
      stride = unquote(stride_expr)

      if is_integer(stride) and stride > 0 do
        Enum.take_every(list, stride)
      else
        list
        |> Enum.with_index()
        |> Enum.reduce([], fn
          {elem, idx}, acc when rem(idx, stride) == 0 -> [elem | acc]
          _, acc -> acc
        end)
        |> Enum.reverse()
      end
    end
  end

  def map_every_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, idx_var} <- take_every_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         {update_idx, condition, do_value, else_value} <- map_every_acc_update(steps, acc_var),
         resolved_do <- resolve_expr(do_value, assignments_before(steps, update_idx)),
         resolved_else <- resolve_expr(else_value, assignments_before(steps, update_idx)),
         {transform_expr, transform_when_true} <-
           map_every_transform_expr(resolved_do, resolved_else, elem_var, has_var),
         true <- take_every_index_updates_valid?(steps, idx_var),
         resolved_condition <- resolve_expr(condition, assignments_before(steps, update_idx)),
         {stride_expr, condition_true_on_boundary} <-
           take_every_stride_condition(resolved_condition, idx_var),
         true <- transform_when_true == condition_true_on_boundary,
         false <- has_var.(transform_expr, idx_var),
         false <- has_var.(transform_expr, acc_var),
         false <- has_var.(transform_expr, list_var),
         false <- has_var.(stride_expr, idx_var),
         false <- has_var.(stride_expr, elem_var) do
      map_every_quote(list_var, elem_var, stride_expr, transform_expr)
    else
      _ -> nil
    end
  end

  defp map_every_acc_update(steps, acc_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, rhs]}, idx} when lhs == acc_var ->
          case map_every_update_rhs(rhs, acc_var) do
            nil -> []
            parsed -> [{idx, parsed}]
          end

        _ ->
          []
      end)

    case updates do
      [{idx, {condition, do_value, else_value}}] -> {idx, condition, do_value, else_value}
      _ -> nil
    end
  end

  defp map_every_update_rhs({:if, _, [condition, [do: do_expr, else: else_expr]]}, acc_var),
    do: map_every_branch_values(condition, do_expr, else_expr, acc_var)

  defp map_every_update_rhs({:unless, _, [condition, [do: do_expr, else: else_expr]]}, acc_var) do
    case map_every_branch_values(condition, do_expr, else_expr, acc_var) do
      {parsed_condition, do_value, else_value} -> {parsed_condition, else_value, do_value}
      _ -> nil
    end
  end

  defp map_every_update_rhs(_, _), do: nil

  defp map_every_branch_values(condition, do_expr, else_expr, acc_var) do
    with {:|, _, [do_value, ^acc_var]} <- do_expr,
         {:|, _, [else_value, ^acc_var]} <- else_expr do
      {condition, do_value, else_value}
    else
      _ -> nil
    end
  end

  defp map_every_transform_expr(do_value, else_value, elem_var, has_var) do
    cond do
      do_value == elem_var and has_var.(else_value, elem_var) and else_value != elem_var ->
        {else_value, false}

      else_value == elem_var and has_var.(do_value, elem_var) and do_value != elem_var ->
        {do_value, true}

      true ->
        nil
    end
  end

  defp map_every_quote(list_var, elem_var, stride_expr, transform_expr) do
    fallback = map_every_fallback_quote(elem_var, transform_expr)

    quote do
      list = unquote(list_var)
      stride = unquote(stride_expr)

      if is_integer(stride) and stride > 0 do
        Enum.map_every(list, stride, fn unquote(elem_var) -> unquote(transform_expr) end)
      else
        unquote(fallback)
      end
    end
  end

  defp map_every_fallback_quote(elem_var, transform_expr) do
    quote do
      list
      |> Enum.with_index()
      |> Enum.map(fn {unquote(elem_var), idx} ->
        case rem(idx, stride) == 0 do
          true -> unquote(transform_expr)
          false -> unquote(elem_var)
        end
      end)
    end
  end

  def map_intersperse_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, first_var} <- intersperse_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         ^acc_var <- enum_reverse_arg.(break_expr),
         {update_idx, condition, do_expr, else_expr} <- intersperse_acc_update(steps, acc_var),
         {mapped_expr, separator_expr, mapped_when_true} <-
           intersperse_branch_values(do_expr, else_expr, acc_var),
         resolved_condition <- resolve_expr(condition, assignments_before(steps, update_idx)),
         true <- resolved_condition == first_var,
         true <- intersperse_first_flag_reset?(steps, first_var),
         aliases <- elem_aliases(steps, elem_var),
         resolved_mapped <- resolve_expr(mapped_expr, assignments_before(steps, update_idx)),
         resolved_separator <- resolve_expr(separator_expr, assignments_before(steps, update_idx)),
         true <- mapped_when_true,
         true <- has_any_var?(resolved_mapped, aliases, has_var),
         false <- has_var.(resolved_separator, elem_var),
         false <- has_var.(resolved_separator, first_var),
         false <- has_var.(resolved_separator, acc_var) do
      map_intersperse_quote(list_var, elem_var, resolved_mapped, resolved_separator)
    else
      _ -> nil
    end
  end

  defp intersperse_vars([{acc_name, []}, {first_name, true}]),
    do: {{acc_name, [], nil}, {first_name, [], nil}}

  defp intersperse_vars([{first_name, true}, {acc_name, []}]),
    do: {{acc_name, [], nil}, {first_name, [], nil}}

  defp intersperse_vars(_), do: nil

  defp intersperse_acc_update(steps, acc_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, {:if, _, [condition, [do: do_expr, else: else_expr]]}]}, idx}
        when lhs == acc_var ->
          [{idx, condition, do_expr, else_expr}]

        _ ->
          []
      end)

    case updates do
      [{idx, condition, do_expr, else_expr}] -> {idx, condition, do_expr, else_expr}
      _ -> nil
    end
  end

  defp intersperse_branch_values(do_expr, else_expr, acc_var) do
    case {do_expr, else_expr} do
      {{:|, _, [mapped, ^acc_var]}, {:|, _, [mapped_else, {:|, _, [sep, ^acc_var]}]}}
      when mapped == mapped_else ->
        {mapped, sep, true}

      {{:|, _, [mapped_do, {:|, _, [sep, ^acc_var]}]}, {:|, _, [mapped, ^acc_var]}}
      when mapped == mapped_do ->
        {mapped, sep, false}

      _ ->
        nil
    end
  end

  defp intersperse_first_flag_reset?(steps, first_var) do
    Enum.any?(steps, fn
      {:=, _, [lhs, false]} -> lhs == first_var
      _ -> false
    end)
  end

  defp map_intersperse_quote(list_var, elem_var, mapped_expr, separator_expr) do
    if mapped_expr == elem_var do
      quote do
        Enum.intersperse(unquote(list_var), unquote(separator_expr))
      end
    else
      quote do
        Enum.map_intersperse(
          unquote(list_var),
          unquote(separator_expr),
          fn unquote(elem_var) -> unquote(mapped_expr) end
        )
      end
    end
  end

  def map_join_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with {acc_var, first_var} <- map_join_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         true <- break_expr == acc_var,
         {update_idx, condition, do_expr, else_expr} <- map_join_acc_update(steps, acc_var),
         {mapped_expr, joiner_expr, mapped_when_true} <-
           map_join_branch_values(do_expr, else_expr, acc_var),
         resolved_condition <- resolve_expr(condition, assignments_before(steps, update_idx)),
         true <- resolved_condition == first_var,
         true <- map_join_first_flag_reset?(steps, first_var),
         aliases <- elem_aliases(steps, elem_var),
         resolved_mapped <- resolve_expr(mapped_expr, assignments_before(steps, update_idx)),
         resolved_joiner <- resolve_expr(joiner_expr, assignments_before(steps, update_idx)),
         true <- mapped_when_true,
         true <- has_any_var?(resolved_mapped, aliases, has_var),
         false <- has_var.(resolved_joiner, elem_var),
         false <- has_var.(resolved_joiner, first_var),
         false <- has_var.(resolved_joiner, acc_var) do
      quote do
        Enum.map_join(
          unquote(list_var),
          unquote(resolved_joiner),
          fn unquote(elem_var) -> unquote(resolved_mapped) end
        )
      end
    else
      _ -> nil
    end
  end

  defp map_join_vars([{acc_name, init}, {first_name, true}]) when is_binary(init),
    do: {{acc_name, [], nil}, {first_name, [], nil}}

  defp map_join_vars([{first_name, true}, {acc_name, init}]) when is_binary(init),
    do: {{acc_name, [], nil}, {first_name, [], nil}}

  defp map_join_vars(_), do: nil

  defp map_join_acc_update(steps, acc_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, {:if, _, [condition, [do: do_expr, else: else_expr]]}]}, idx}
        when lhs == acc_var ->
          [{idx, condition, do_expr, else_expr}]

        _ ->
          []
      end)

    case updates do
      [{idx, condition, do_expr, else_expr}] -> {idx, condition, do_expr, else_expr}
      _ -> nil
    end
  end

  defp map_join_branch_values(do_expr, else_expr, acc_var) do
    case {do_expr, else_expr} do
      {mapped, concat_expr} ->
        with {left, joiner, right} <- concat_parts(concat_expr, acc_var),
             true <- left == acc_var,
             true <- right == mapped do
          {mapped, joiner, true}
        else
          _ -> nil
        end
    end
  end

  defp concat_parts({:<>, _, [left, rest]}, _acc_var) do
    case concat_right(rest) do
      {joiner, right} -> {left, joiner, right}
      _ -> nil
    end
  end

  defp concat_parts(
         {{:., _, [{:__aliases__, _, [:Kernel]}, :<>]}, _, [left, rest]},
         _acc_var
       ) do
    concat_parts({:<>, [], [left, rest]}, nil)
  end

  defp concat_parts(_, _), do: nil

  defp concat_right({:<>, _, [joiner, right]}), do: {joiner, right}

  defp concat_right({{:., _, [{:__aliases__, _, [:Kernel]}, :<>]}, _, [joiner, right]}),
    do: {joiner, right}

  defp concat_right(_), do: nil

  defp map_join_first_flag_reset?(steps, first_var) do
    Enum.any?(steps, fn
      {:=, _, [lhs, false]} -> lhs == first_var
      _ -> false
    end)
  end

  def chunk_by_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {chunks_var, chunk_var, key_var, started_var} <- chunk_by_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         true <- chunk_by_break_expr?(break_expr, chunks_var, chunk_var, enum_reverse_arg),
         [{:=, _, [assigned_key_var, key_expr]}, tuple_update] <- steps,
         true <- assigned_key_var == key_var,
         true <- has_var.(key_expr, elem_var),
         false <- has_var.(key_expr, chunks_var),
         false <- has_var.(key_expr, chunk_var),
         false <- has_var.(key_expr, key_var),
         false <- has_var.(key_expr, started_var),
         true <-
           chunk_by_tuple_update?(
             tuple_update,
             chunks_var,
             chunk_var,
             key_var,
             started_var,
             elem_var
           ) do
      quote do
        Enum.chunk_by(unquote(list_var), fn unquote(elem_var) -> unquote(key_expr) end)
      end
    else
      _ -> nil
    end
  end

  defp chunk_by_vars(initials) do
    chunks_name = Enum.find_value(initials, fn {name, init} -> if init == [], do: name end)

    chunk_name =
      initials
      |> Enum.filter(fn {_name, init} -> init == [] end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.reject(&(&1 == chunks_name))
      |> List.first()

    key_name = Enum.find_value(initials, fn {name, init} -> if init == nil, do: name end)
    started_name = Enum.find_value(initials, fn {name, init} -> if init == false, do: name end)

    if chunks_name && chunk_name && key_name && started_name && length(initials) == 4 do
      {{chunks_name, [], nil}, {chunk_name, [], nil}, {key_name, [], nil},
       {started_name, [], nil}}
    end
  end

  defp chunk_by_break_expr?(break_expr, chunks_var, chunk_var, _enum_reverse_arg) do
    case break_expr do
      {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _,
       [
         {:if, _,
          [
            {:==, _, [chunk_check, []]},
            [do: do_expr, else: else_expr]
          ]}
       ]} ->
        chunk_check == chunk_var and do_expr == chunks_var and
          else_expr ==
            {:|, [],
             [{{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [chunk_var]}, chunks_var]}

      _ ->
        false
    end
  end

  defp chunk_by_tuple_update?(
         {:=, _,
          [
            {:{}, _, [chunks_lhs, chunk_lhs, key_lhs, started_lhs]},
            {:if, _, [condition, [do: do_tuple, else: else_tuple]]}
          ]},
         chunks_var,
         chunk_var,
         key_var,
         started_var,
         elem_var
       ) do
    with true <- chunks_lhs == chunks_var,
         true <- chunk_lhs == chunk_var,
         true <- key_lhs == key_var,
         true <- started_lhs == started_var,
         true <- chunk_by_condition?(condition, started_var, key_var),
         true <- do_tuple == chunk_by_do_tuple(chunks_var, chunk_var, key_var, elem_var),
         true <- else_tuple == chunk_by_else_tuple(chunks_var, chunk_var, key_var, elem_var) do
      true
    else
      _ -> false
    end
  end

  defp chunk_by_tuple_update?(_, _, _, _, _, _), do: false

  defp chunk_by_condition?({:and, _, [left, right]}, started_var, key_var),
    do: left == started_var and key_not_equal?(right, key_var)

  defp chunk_by_condition?(_, _, _), do: false

  defp key_not_equal?({:!=, _, [left, right]}, key_var), do: left == key_var or right == key_var
  defp key_not_equal?({:!==, _, [left, right]}, key_var), do: left == key_var or right == key_var
  defp key_not_equal?(_, _), do: false

  defp chunk_by_do_tuple(chunks_var, chunk_var, key_var, elem_var) do
    {:{}, [],
     [
       {:|, [],
        [{{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [chunk_var]}, chunks_var]},
       [elem_var],
       key_var,
       true
     ]}
  end

  defp chunk_by_else_tuple(chunks_var, chunk_var, key_var, elem_var) do
    {:{}, [], [chunks_var, {:|, [], [elem_var, chunk_var]}, key_var, true]}
  end

  def frequencies_by_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{freq_name, {:%{}, _, []}}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         freq_var = {freq_name, [], nil},
         true <- break_expr == freq_var,
         {update_idx, key_expr} <- frequencies_by_update_key(steps, freq_var),
         true <- update_idx == length(steps) - 1,
         aliases <- elem_aliases(steps, elem_var),
         resolved_key <- resolve_expr(key_expr, assignments_before(steps, update_idx)),
         assigned_non_alias <- assigned_non_alias_vars(steps, aliases, [freq_var]),
         true <- has_any_var?(resolved_key, aliases, has_var),
         false <- has_var.(resolved_key, freq_var),
         false <- has_var.(resolved_key, list_var),
         false <- has_any_var?(resolved_key, assigned_non_alias, has_var) do
      quote do
        Enum.frequencies_by(unquote(list_var), fn unquote(elem_var) -> unquote(resolved_key) end)
      end
    else
      _ -> nil
    end
  end

  defp frequencies_by_update_key(steps, freq_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, rhs]}, idx} when lhs == freq_var ->
          case frequencies_by_update_call(rhs, freq_var) do
            nil -> []
            key_expr -> [{idx, key_expr}]
          end

        _ ->
          []
      end)

    case updates do
      [{idx, key_expr}] -> {idx, key_expr}
      _ -> nil
    end
  end

  defp frequencies_by_update_call(
         {{:., _, [{:__aliases__, _, [:Map]}, :update]}, _, [freq, key_expr, 1, updater]},
         freq_var
       ) do
    if freq == freq_var and increment_updater?(updater), do: key_expr
  end

  defp frequencies_by_update_call(_, _), do: nil

  defp increment_updater?(updater) do
    case capture_body(updater) do
      {:+, _, [{:&, _, [1]}, 1]} -> true
      {:+, _, [1, {:&, _, [1]}]} -> true
      {{:., _, [{:__aliases__, _, [:Kernel]}, :+]}, _, [{:&, _, [1]}, 1]} -> true
      {{:., _, [{:__aliases__, _, [:Kernel]}, :+]}, _, [1, {:&, _, [1]}]} -> true
      _ -> false
    end
  end

  def unzip_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {left_acc_var, right_acc_var} <- unzip_acc_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         {^left_acc_var, ^right_acc_var} <-
           unzip_break_payload(break_expr, left_acc_var, right_acc_var, enum_reverse_arg),
         {left_idx, left_value, right_idx, right_value} <-
           unzip_update_values(steps, left_acc_var, right_acc_var),
         true <- Enum.sort([left_idx, right_idx]) == [length(steps) - 2, length(steps) - 1],
         aliases <- elem_aliases(steps, elem_var),
         resolved_left <- resolve_expr(left_value, assignments_before(steps, left_idx)),
         resolved_right <- resolve_expr(right_value, assignments_before(steps, right_idx)),
         :first <- unzip_component(resolved_left, elem_var, aliases),
         :second <- unzip_component(resolved_right, elem_var, aliases) do
      quote do
        Enum.unzip(unquote(list_var))
      end
    else
      _ -> nil
    end
  end

  defp unzip_acc_vars([{left_name, []}, {right_name, []}]),
    do: {{left_name, [], nil}, {right_name, [], nil}}

  defp unzip_acc_vars(_), do: nil

  defp unzip_break_payload(
         {:{}, _, [left_expr, right_expr]},
         left_acc_var,
         right_acc_var,
         enum_reverse_arg
       ) do
    with ^left_acc_var <- enum_reverse_arg.(left_expr),
         ^right_acc_var <- enum_reverse_arg.(right_expr) do
      {left_acc_var, right_acc_var}
    else
      _ -> nil
    end
  end

  defp unzip_break_payload(_, _, _, _), do: nil

  defp unzip_update_values(steps, left_acc_var, right_acc_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {step, idx} ->
          case cons_update(step) do
            {acc_var, value} when acc_var in [left_acc_var, right_acc_var] ->
              [{idx, acc_var, value}]

            _ ->
              []
          end
      end)

    case Enum.sort_by(updates, fn {_idx, acc_var, _value} ->
           unzip_acc_rank(acc_var, left_acc_var)
         end) do
      [{left_idx, ^left_acc_var, left_value}, {right_idx, ^right_acc_var, right_value}] ->
        {left_idx, left_value, right_idx, right_value}

      _ ->
        nil
    end
  end

  defp unzip_acc_rank(acc_var, left_acc_var) do
    if acc_var == left_acc_var, do: 0, else: 1
  end

  defp unzip_component(expr, {:{}, _, [left_var, right_var]}, _aliases) do
    cond do
      expr == left_var -> :first
      expr == right_var -> :second
      true -> nil
    end
  end

  defp unzip_component(expr, _elem_var, aliases) do
    tuple_aliases = Enum.filter(aliases, &var_ast?/1)

    case unzip_elem_access(expr) do
      {tuple_ref, 0} -> if(tuple_ref in tuple_aliases, do: :first)
      {tuple_ref, 1} -> if(tuple_ref in tuple_aliases, do: :second)
      _ -> nil
    end
  end

  defp unzip_elem_access({:elem, _, [tuple_ref, idx]}) when idx in [0, 1], do: {tuple_ref, idx}

  defp unzip_elem_access({{:., _, [{:__aliases__, _, [:Kernel]}, :elem]}, _, [tuple_ref, idx]})
       when idx in [0, 1],
       do: {tuple_ref, idx}

  defp unzip_elem_access({{:., _, [:erlang, :element]}, _, [idx, tuple_ref]}) when idx in [1, 2],
    do: {tuple_ref, idx - 1}

  defp unzip_elem_access(_), do: nil

  def zip_with_pattern(initials, body, callbacks) do
    map_destructure = callback(callbacks, :map_destructure)
    has_var = callback(callbacks, :has_var)
    empty_list_check = callback(callbacks, :empty_list_check)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with [{acc_name, []}] <- initials,
         {:__block__, _, [exit, destructure1, destructure2, accumulate]} <- body,
         acc_var = {acc_name, [], nil},
         {list1_var, list2_var, ^acc_var} <-
           zip_with_exit_strategy(exit, empty_list_check, enum_reverse_arg),
         {^list1_var, elem1_var} <- map_destructure.(destructure1),
         {^list2_var, elem2_var} <- map_destructure.(destructure2),
         {^acc_var, mapped_expr} <- cons_update(accumulate),
         true <- has_var.(mapped_expr, elem1_var),
         true <- has_var.(mapped_expr, elem2_var),
         false <- mapped_expr == {:{}, [], [elem1_var, elem2_var]} do
      quote do
        Enum.zip_with(
          unquote(list1_var),
          unquote(list2_var),
          fn unquote(elem1_var), unquote(elem2_var) -> unquote(mapped_expr) end
        )
      end
    else
      _ -> nil
    end
  end

  defp zip_with_exit_strategy(
         {:if, _, [condition, [do: {:break, _, [break_expr]}]]},
         empty_list_check,
         enum_reverse_arg
       ) do
    with acc_var when not is_nil(acc_var) <- enum_reverse_arg.(break_expr),
         {list1_var, list2_var} <- zip_with_or_lists(condition, empty_list_check) do
      {list1_var, list2_var, acc_var}
    else
      _ -> nil
    end
  end

  defp zip_with_exit_strategy(_, _, _), do: nil

  defp zip_with_or_lists({op, _, [left_cond, right_cond]}, empty_list_check)
       when op in [:or, :||] do
    with {list1_var, _} <- empty_list_check.(left_cond),
         {list2_var, _} <- empty_list_check.(right_cond) do
      {list1_var, list2_var}
    else
      _ -> nil
    end
  end

  defp zip_with_or_lists(_, _), do: nil

  def zip_reduce_pattern(initials, body, callbacks) do
    map_destructure = callback(callbacks, :map_destructure)
    has_var = callback(callbacks, :has_var)
    empty_list_check = callback(callbacks, :empty_list_check)

    with [{acc_name, init}] <- initials,
         {:__block__, _, [exit, destructure1, destructure2, update]} <- body,
         acc_var = {acc_name, [], nil},
         {list1_var, list2_var, ^acc_var} <- zip_reduce_exit_strategy(exit, empty_list_check),
         {^list1_var, elem1_var} <- map_destructure.(destructure1),
         {^list2_var, elem2_var} <- map_destructure.(destructure2),
         {^acc_var, reduce_expr} <- zip_reduce_update(update, acc_var),
         true <- has_var.(reduce_expr, elem1_var),
         true <- has_var.(reduce_expr, elem2_var),
         false <- has_var.(reduce_expr, list1_var),
         false <- has_var.(reduce_expr, list2_var) do
      quote do
        Enum.zip_reduce(
          unquote(list1_var),
          unquote(list2_var),
          unquote(init),
          fn unquote(elem1_var), unquote(elem2_var), unquote(acc_var) -> unquote(reduce_expr) end
        )
      end
    else
      _ -> nil
    end
  end

  defp zip_reduce_exit_strategy(
         {:if, _, [condition, [do: {:break, _, [break_expr]}]]},
         empty_list_check
       ) do
    with {list1_var, list2_var} <- zip_with_or_lists(condition, empty_list_check),
         true <- var_ast?(break_expr) do
      {list1_var, list2_var, break_expr}
    else
      _ -> nil
    end
  end

  defp zip_reduce_exit_strategy(_, _), do: nil

  defp zip_reduce_update({:=, _, [lhs, rhs]}, acc_var) do
    if lhs == acc_var, do: {acc_var, rhs}
  end

  defp zip_reduce_update(_, _), do: nil

  def min_max_pattern(initials, body, callbacks) do
    next_step = callback(callbacks, :next_step)
    vars_equal = callback(callbacks, :vars_equal)
    empty_list_check = callback(callbacks, :empty_list_check)

    with [{name1, {:hd, _, [init_list1]}}, {name2, {:hd, _, [init_list2]}}] <- initials,
         true <- vars_equal.(init_list1, init_list2),
         {:__block__, _, [advance, exit, update1, update2]} <- body,
         list_var <- next_step.(advance),
         true <- vars_equal.(init_list1, list_var),
         var1 = {name1, [], nil},
         var2 = {name2, [], nil},
         {^list_var, break_left, break_right} <- min_max_exit(exit, empty_list_check),
         {min_var, max_var} <- min_max_roles(update1, update2, var1, var2, list_var),
         true <- break_left == min_var,
         true <- break_right == max_var do
      quote do
        Enum.min_max(unquote(list_var))
      end
    else
      _ -> nil
    end
  end

  defp min_max_exit(
         {:if, _, [condition, [do: {:break, _, [{:{}, _, [left, right]}]}]]},
         empty_list_check
       ) do
    case empty_list_check.(condition) do
      {list_var, _} -> {list_var, left, right}
      _ -> nil
    end
  end

  defp min_max_exit(_, _), do: nil

  defp min_max_roles(update1, update2, var1, var2, list_var) do
    with {u1_var, u1_kind} <- min_max_update_kind(update1, list_var),
         {u2_var, u2_kind} <- min_max_update_kind(update2, list_var),
         true <- u1_var in [var1, var2],
         true <- u2_var in [var1, var2],
         true <- u1_var != u2_var,
         true <- Enum.sort([u1_kind, u2_kind]) == [:max, :min] do
      min_var = if(u1_kind == :min, do: u1_var, else: u2_var)
      max_var = if(u1_kind == :max, do: u1_var, else: u2_var)
      {min_var, max_var}
    else
      _ -> nil
    end
  end

  defp min_max_update_kind({:=, _, [var, {:min, _, [var, {:hd, _, [list]}]}]}, list_var)
       when list == list_var,
       do: {var, :min}

  defp min_max_update_kind({:=, _, [var, {:max, _, [var, {:hd, _, [list]}]}]}, list_var)
       when list == list_var,
       do: {var, :max}

  defp min_max_update_kind(_, _), do: nil

  def max_by_min_by_pattern(initials, body, callbacks) do
    next_step = callback(callbacks, :next_step)
    vars_equal = callback(callbacks, :vars_equal)
    empty_list_check = callback(callbacks, :empty_list_check)
    has_var = callback(callbacks, :has_var)
    replace_var = callback(callbacks, :replace_var)

    with {best_var, best_key_var, init_list, init_key_expr} <- max_by_state_vars(initials),
         {:__block__, _, [advance, exit, candidate_assign, candidate_key_assign, update_if]} <-
           body,
         list_var <- next_step.(advance),
         true <- vars_equal.(init_list, list_var),
         {^list_var, ^best_var} <- max_by_exit(exit, empty_list_check),
         {candidate_var, ^list_var} <- hd_assignment(candidate_assign),
         {candidate_key_var, candidate_key_expr} <-
           max_by_candidate_key_assignment(candidate_key_assign, candidate_var),
         true <- not has_var.(candidate_key_expr, best_var),
         true <- not has_var.(candidate_key_expr, best_key_var),
         true <- not has_var.(candidate_key_expr, list_var),
         {compare_op, ^best_var, ^best_key_var} <-
           max_by_update_tuple(
             update_if,
             best_var,
             best_key_var,
             candidate_var,
             candidate_key_var
           ),
         true <- compare_op in [:>, :<],
         expected_init <- replace_var.(candidate_key_expr, candidate_var, {:hd, [], [init_list]}),
         true <- expected_init == init_key_expr do
      max_by_min_by_quote(compare_op, list_var, candidate_var, candidate_key_expr)
    else
      _ -> nil
    end
  end

  defp max_by_state_vars([
         {best_name, {:hd, _, [init_list]}},
         {best_key_name, init_key_expr}
       ]),
       do: {{best_name, [], nil}, {best_key_name, [], nil}, init_list, init_key_expr}

  defp max_by_state_vars([
         {best_key_name, init_key_expr},
         {best_name, {:hd, _, [init_list]}}
       ]),
       do: {{best_name, [], nil}, {best_key_name, [], nil}, init_list, init_key_expr}

  defp max_by_state_vars(_), do: nil

  defp max_by_exit({:if, _, [condition, [do: {:break, _, [best]}]]}, empty_list_check) do
    case empty_list_check.(condition) do
      {list_var, _} -> {list_var, best}
      _ -> nil
    end
  end

  defp max_by_exit(_, _), do: nil

  defp hd_assignment({:=, _, [candidate_var, {:hd, _, [list_var]}]}),
    do: {candidate_var, list_var}

  defp hd_assignment(_), do: nil

  defp max_by_candidate_key_assignment(
         {:=, _, [candidate_key_var, candidate_key_expr]},
         candidate_var
       ) do
    if has_var_ast?(candidate_key_expr, candidate_var),
      do: {candidate_key_var, candidate_key_expr}
  end

  defp max_by_candidate_key_assignment(_, _), do: nil

  defp max_by_update_tuple(
         {:=, _,
          [
            {:{}, _, [best_lhs, best_key_lhs]},
            {:if, _, [condition, [do: do_tuple, else: else_tuple]]}
          ]},
         best_var,
         best_key_var,
         candidate_var,
         candidate_key_var
       ) do
    with {compare_op, left, right} <- strict_compare(condition),
         true <- best_lhs == best_var,
         true <- best_key_lhs == best_key_var,
         true <- left == candidate_key_var,
         true <- right == best_key_var,
         true <- do_tuple == {:{}, [], [candidate_var, candidate_key_var]},
         true <- else_tuple == {:{}, [], [best_var, best_key_var]} do
      {compare_op, best_var, best_key_var}
    else
      _ -> nil
    end
  end

  defp max_by_update_tuple(_, _, _, _, _), do: nil

  defp strict_compare({op, _, [left, right]}) when op in [:>, :<], do: {op, left, right}

  defp strict_compare({{:., _, [{:__aliases__, _, [:Kernel]}, op]}, _, [left, right]})
       when op in [:>, :<],
       do: {op, left, right}

  defp strict_compare(_), do: nil

  defp max_by_min_by_quote(:>, list_var, candidate_var, candidate_key_expr) do
    quote do
      list = unquote(list_var)
      _ = hd(list)
      Enum.max_by(list, fn unquote(candidate_var) -> unquote(candidate_key_expr) end)
    end
  end

  defp max_by_min_by_quote(:<, list_var, candidate_var, candidate_key_expr) do
    quote do
      list = unquote(list_var)
      _ = hd(list)
      Enum.min_by(list, fn unquote(candidate_var) -> unquote(candidate_key_expr) end)
    end
  end

  def min_max_by_pattern(initials, body, callbacks) do
    next_step = callback(callbacks, :next_step)
    vars_equal = callback(callbacks, :vars_equal)
    empty_list_check = callback(callbacks, :empty_list_check)
    has_var = callback(callbacks, :has_var)
    replace_var = callback(callbacks, :replace_var)

    with {min_var, min_key_var, max_var, max_key_var, init_list, init_key_expr} <-
           min_max_by_state_vars(initials),
         {:__block__, _,
          [advance, exit, candidate_assign, candidate_key_assign, min_update, max_update]} <-
           body,
         list_var <- next_step.(advance),
         true <- vars_equal.(init_list, list_var),
         {^list_var, break_left, break_right} <- min_max_exit(exit, empty_list_check),
         true <- break_left == min_var,
         true <- break_right == max_var,
         {candidate_var, ^list_var} <- hd_assignment(candidate_assign),
         {candidate_key_var, candidate_key_expr} <-
           max_by_candidate_key_assignment(candidate_key_assign, candidate_var),
         false <- has_var.(candidate_key_expr, min_var),
         false <- has_var.(candidate_key_expr, max_var),
         false <- has_var.(candidate_key_expr, min_key_var),
         false <- has_var.(candidate_key_expr, max_key_var),
         false <- has_var.(candidate_key_expr, list_var),
         expected_init <- replace_var.(candidate_key_expr, candidate_var, {:hd, [], [init_list]}),
         true <- expected_init == init_key_expr,
         true <-
           min_max_by_update_tuple(
             min_update,
             min_var,
             min_key_var,
             candidate_var,
             candidate_key_var,
             :<
           ),
         true <-
           min_max_by_update_tuple(
             max_update,
             max_var,
             max_key_var,
             candidate_var,
             candidate_key_var,
             :>
           ) do
      quote do
        list = unquote(list_var)
        _ = hd(list)
        Enum.min_max_by(list, fn unquote(candidate_var) -> unquote(candidate_key_expr) end)
      end
    else
      _ -> nil
    end
  end

  defp min_max_by_state_vars(initials) do
    with [_, _, _, _] <- initials,
         hd_entries <-
           Enum.filter(initials, fn
             {_name, {:hd, _, [_]}} -> true
             _ -> false
           end),
         [{min_name, {:hd, _, [init_list1]}}, {max_name, {:hd, _, [init_list2]}}] <- hd_entries,
         true <- init_list1 == init_list2,
         key_entries <- Enum.reject(initials, &match?({_name, {:hd, _, [_]}}, &1)),
         [{min_key_name, init_key_expr1}, {max_key_name, init_key_expr2}] <- key_entries,
         true <- init_key_expr1 == init_key_expr2 do
      {
        {min_name, [], nil},
        {min_key_name, [], nil},
        {max_name, [], nil},
        {max_key_name, [], nil},
        init_list1,
        init_key_expr1
      }
    else
      _ -> nil
    end
  end

  defp min_max_by_update_tuple(
         {:=, _,
          [
            {:{}, _, [best_lhs, best_key_lhs]},
            {:if, _, [condition, [do: do_tuple, else: else_tuple]]}
          ]},
         best_var,
         best_key_var,
         candidate_var,
         candidate_key_var,
         expected_compare
       ) do
    with {compare_op, left, right} <- strict_compare(condition),
         true <- compare_op == expected_compare,
         true <- best_lhs == best_var,
         true <- best_key_lhs == best_key_var,
         true <- left == candidate_key_var,
         true <- right == best_key_var,
         true <- do_tuple == {:{}, [], [candidate_var, candidate_key_var]},
         true <- else_tuple == {:{}, [], [best_var, best_key_var]} do
      true
    else
      _ -> false
    end
  end

  defp min_max_by_update_tuple(_, _, _, _, _, _), do: false

  def group_by_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{acc_name, {:%{}, _, []}}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         acc_var = {acc_name, [], nil},
         {key_expr, value_expr} when not is_nil(key_expr) <-
           group_by_key_value(steps, elem_var, acc_var, break_expr, has_var) do
      group_by_quote(list_var, elem_var, key_expr, value_expr)
    else
      _ -> nil
    end
  end

  defp group_by_quote(list_var, elem_var, key_expr, value_expr) when value_expr == elem_var do
    quote do
      Enum.group_by(unquote(list_var), fn unquote(elem_var) -> unquote(key_expr) end)
    end
  end

  defp group_by_quote(list_var, elem_var, key_expr, value_expr) do
    quote do
      Enum.group_by(
        unquote(list_var),
        fn unquote(elem_var) -> unquote(key_expr) end,
        fn unquote(elem_var) -> unquote(value_expr) end
      )
    end
  end

  defp group_by_key_value(steps, elem_var, acc_var, break_expr, has_var) do
    aliases = elem_aliases(steps, elem_var)

    Enum.find_value(Enum.with_index(steps), fn
      {{:=, _, [acc, map_update]}, idx} when acc == acc_var ->
        group_by_key_value_for_step(map_update, idx, steps, acc_var, break_expr, aliases, has_var)

      _ ->
        nil
    end)
  end

  defp group_by_key_value_for_step(map_update, idx, steps, acc_var, break_expr, aliases, has_var) do
    case map_update_call(map_update) do
      {^acc_var, key_expr, value_expr, :append} when break_expr == acc_var ->
        assignments = assignments_before(steps, idx)
        resolved_key = resolve_expr(key_expr, assignments)
        resolved_value = resolve_expr(value_expr, assignments)

        if has_any_var?(resolved_key, aliases, has_var) and
             has_any_var?(resolved_value, aliases, has_var) do
          {resolved_key, resolved_value}
        end

      _ ->
        nil
    end
  end

  def uniq_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, seen_var} <- uniq_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         key_expr when not is_nil(key_expr) <-
           uniq_by_key_expr(steps, elem_var, acc_var, seen_var, has_var),
         aliases <- elem_aliases(steps, elem_var),
         true <- key_expr in aliases do
      quote do
        Enum.uniq(unquote(list_var))
      end
    else
      _ -> nil
    end
  end

  def uniq_by_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, seen_var} <- uniq_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         key_expr when not is_nil(key_expr) <-
           uniq_by_key_expr(steps, elem_var, acc_var, seen_var, has_var) do
      quote do
        Enum.uniq_by(unquote(list_var), fn unquote(elem_var) -> unquote(key_expr) end)
      end
    else
      _ -> nil
    end
  end

  defp uniq_vars(initials) do
    case initials do
      [_, _] ->
        acc_name = Enum.find_value(initials, &empty_acc_name/1)
        seen_name = Enum.find_value(initials, &non_empty_acc_name/1)
        build_uniq_vars(acc_name, seen_name)

      _ ->
        nil
    end
  end

  defp build_uniq_vars(acc_name, seen_name) when not is_nil(acc_name) and not is_nil(seen_name),
    do: {{acc_name, [], nil}, {seen_name, [], nil}}

  defp build_uniq_vars(_, _), do: nil

  defp empty_acc_name({name, []}), do: name
  defp empty_acc_name(_), do: nil

  defp non_empty_acc_name({name, value}) when value != [], do: name
  defp non_empty_acc_name(_), do: nil

  defp uniq_by_key_expr(steps, elem_var, acc_var, seen_var, has_var) do
    aliases = elem_aliases(steps, elem_var)

    Enum.find_value(Enum.with_index(steps), fn
      {{:=, _, [acc, if_expr]}, idx} when acc == acc_var ->
        uniq_key_from_step(if_expr, idx, steps, acc_var, seen_var, aliases, has_var)

      _ ->
        nil
    end)
  end

  defp uniq_key_from_step(if_expr, idx, steps, acc_var, seen_var, aliases, has_var) do
    case uniq_acc_if(if_expr, acc_var, seen_var) do
      {member_key_expr, kept_value_expr} ->
        if kept_value_expr in aliases do
          uniq_resolved_key(member_key_expr, idx, steps, seen_var, aliases, has_var)
        end

      _ ->
        nil
    end
  end

  defp uniq_resolved_key(member_key_expr, idx, steps, seen_var, aliases, has_var) do
    resolved_key = resolve_expr(member_key_expr, assignments_before(steps, idx))

    if seen_set_updated?(steps, idx, seen_var) and has_any_var?(resolved_key, aliases, has_var) do
      resolved_key
    end
  end

  defp seen_set_updated?(steps, idx, seen_var) do
    Enum.any?(Enum.drop(steps, idx), &seen_set_put_step?(&1, seen_var))
  end

  defp seen_set_put_step?({:=, _, [seen, put_expr]}, seen_var) when seen == seen_var,
    do: match?({^seen_var, _}, mapset_put_call(put_expr))

  defp seen_set_put_step?(_, _), do: false

  defp uniq_acc_if(
         {:if, _, [condition, [do: acc, else: {:|, _, [value_expr, acc]}]]},
         acc_var,
         seen_var
       ) do
    with ^acc_var <- acc,
         {^seen_var, key_expr} <- mapset_member_call(condition) do
      {key_expr, value_expr}
    else
      _ -> nil
    end
  end

  defp uniq_acc_if(
         {:if, _, [condition, [do: {:|, _, [value_expr, acc]}, else: acc]]},
         acc_var,
         seen_var
       ) do
    with ^acc_var <- acc,
         {member_condition, _, [inner]} <- condition,
         true <- member_condition in [:not, :!],
         {^seen_var, key_expr} <- mapset_member_call(inner) do
      {key_expr, value_expr}
    else
      _ -> nil
    end
  end

  defp uniq_acc_if(_, _, _), do: nil

  def chunk_every_pattern(initials, body, callbacks) do
    empty_list_check = callback(callbacks, :empty_list_check)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with [{acc_name, []}] <- initials,
         {:__block__, _, exprs} <- body,
         acc_var = {acc_name, [], nil},
         {list_var, chunk_size, step_size, mode} <-
           chunk_every_shape(exprs, acc_var, empty_list_check, enum_reverse_arg) do
      chunk_every_quote(list_var, chunk_size, step_size, mode)
    else
      _ -> nil
    end
  end

  defp chunk_every_shape([exit_expr, step2, step3], acc_var, empty_list_check, enum_reverse_arg) do
    chunk_every_take_drop_shape(
      exit_expr,
      step2,
      step3,
      acc_var,
      empty_list_check,
      enum_reverse_arg
    ) ||
      chunk_every_split_shape(
        exit_expr,
        step2,
        step3,
        acc_var,
        empty_list_check,
        enum_reverse_arg
      )
  end

  defp chunk_every_shape(_, _, _, _), do: nil

  defp chunk_every_take_drop_shape(
         exit_expr,
         chunk_update,
         advance,
         acc_var,
         empty_list_check,
         enum_reverse_arg
       ) do
    with {condition, break_expr} <- chunk_exit_clause(exit_expr),
         ^acc_var <- enum_reverse_arg.(break_expr),
         {^acc_var, chunk_expr} <- cons_update(chunk_update),
         {list_var, chunk_size} <- enum_take_call(chunk_expr),
         {^list_var, step_size} <- enum_drop_call(advance),
         mode when not is_nil(mode) <-
           chunk_exit_mode(condition, list_var, chunk_size, empty_list_check) do
      {list_var, chunk_size, step_size, mode}
    else
      _ -> nil
    end
  end

  defp chunk_every_split_shape(
         exit_expr,
         split_step,
         chunk_update,
         acc_var,
         empty_list_check,
         enum_reverse_arg
       ) do
    with {condition, break_expr} <- chunk_exit_clause(exit_expr),
         ^acc_var <- enum_reverse_arg.(break_expr),
         {chunk_var, list_var, chunk_size} <- enum_split_step(split_step),
         {^acc_var, ^chunk_var} <- cons_update(chunk_update),
         mode when not is_nil(mode) <-
           chunk_exit_mode(condition, list_var, chunk_size, empty_list_check) do
      {list_var, chunk_size, chunk_size, mode}
    else
      _ -> nil
    end
  end

  defp chunk_every_quote(list_var, chunk_size, step_size, :normal) when chunk_size == step_size do
    quote do
      Enum.chunk_every(unquote(list_var), unquote(chunk_size))
    end
  end

  defp chunk_every_quote(list_var, chunk_size, step_size, :normal) do
    quote do
      Enum.chunk_every(unquote(list_var), unquote(chunk_size), unquote(step_size))
    end
  end

  defp chunk_every_quote(list_var, chunk_size, step_size, :discard) do
    quote do
      Enum.chunk_every(unquote(list_var), unquote(chunk_size), unquote(step_size), :discard)
    end
  end

  defp chunk_exit_mode(
         condition,
         list_var,
         chunk_size,
         empty_list_check
       ) do
    cond do
      match?({^list_var, _}, empty_list_check.(condition)) ->
        :normal

      chunk_discard_condition?(condition, list_var, chunk_size, empty_list_check) ->
        :discard

      true ->
        nil
    end
  end

  defp chunk_exit_clause({:if, _, [condition, [do: {:break, _, [break_expr]}]]}),
    do: {condition, break_expr}

  defp chunk_exit_clause(_), do: nil

  defp chunk_discard_condition?(condition, list_var, chunk_size, empty_list_check) do
    if list_shorter_than?(condition, list_var, chunk_size) do
      true
    else
      case condition do
        {op, _, [left, right]} when op in [:or, :||] ->
          (match?({^list_var, _}, empty_list_check.(left)) and
             list_shorter_than?(right, list_var, chunk_size)) or
            (match?({^list_var, _}, empty_list_check.(right)) and
               list_shorter_than?(left, list_var, chunk_size))

        _ ->
          false
      end
    end
  end

  defp list_shorter_than?({:<, _, [left, right]}, list_var, chunk_size) do
    list_length_expr?(left, list_var) and right == chunk_size
  end

  defp list_shorter_than?({:>, _, [left, right]}, list_var, chunk_size) do
    left == chunk_size and list_length_expr?(right, list_var)
  end

  defp list_shorter_than?(_, _, _), do: false

  defp list_length_expr?({:length, _, [list]}, list_var), do: list == list_var

  defp list_length_expr?(
         {{:., _, [{:__aliases__, _, [:Enum]}, :count]}, _, [list]},
         list_var
       ),
       do: list == list_var

  defp list_length_expr?(_, _), do: false

  defp cons_update({:=, _, [acc, {:|, _, [value, acc]}]}), do: {acc, value}
  defp cons_update(_), do: nil

  defp enum_take_call({{:., _, [{:__aliases__, _, [:Enum]}, :take]}, _, [list, size]}),
    do: {list, size}

  defp enum_take_call(_), do: nil

  defp enum_drop_call({:=, _, [list_target, drop_expr]}) do
    with {list_source, size} <- enum_drop_expr(drop_expr),
         true <- list_target == list_source do
      {list_source, size}
    else
      _ -> nil
    end
  end

  defp enum_drop_call(_), do: nil

  defp enum_drop_expr({{:., _, [{:__aliases__, _, [:Enum]}, :drop]}, _, [list, n]}),
    do: {list, n}

  defp enum_drop_expr(_), do: nil

  defp enum_split_step({:=, _, [{:{}, _, [chunk_var, list_target]}, split_expr]}) do
    with {list_source, size} <- enum_split_expr(split_expr),
         true <- list_target == list_source do
      {chunk_var, list_source, size}
    else
      _ -> nil
    end
  end

  defp enum_split_step(_), do: nil

  defp enum_split_expr({{:., _, [{:__aliases__, _, [:Enum]}, :split]}, _, [list, n]}),
    do: {list, n}

  defp enum_split_expr(_), do: nil

  defp map_update_call(
         {{:., _, [{:__aliases__, _, [:Map]}, :update]}, _, [acc, key, [value], updater]}
       ) do
    case append_or_prepend_updater(updater, value) do
      mode when mode in [:append, :prepend] -> {acc, key, value, mode}
      _ -> nil
    end
  end

  defp map_update_call(_), do: nil

  defp append_or_prepend_updater(updater, value_expr) do
    updater
    |> capture_body()
    |> case do
      {:++, _, [{:&, _, [1]}, [value]]} when value == value_expr ->
        :append

      {:++, _, [[value], {:&, _, [1]}]} when value == value_expr ->
        :prepend

      {{:., _, [{:__aliases__, _, [:Kernel]}, :++]}, _, [{:&, _, [1]}, [value]]}
      when value == value_expr ->
        :append

      {{:., _, [{:__aliases__, _, [:Kernel]}, :++]}, _, [[value], {:&, _, [1]}]}
      when value == value_expr ->
        :prepend

      _ ->
        nil
    end
  end

  defp capture_body({:&, _, [{:/, _, [body, 2]}]}), do: body
  defp capture_body({:&, _, [body]}), do: body
  defp capture_body(body), do: body

  defp mapset_member_call({{:., _, [{:__aliases__, _, [:MapSet]}, :member?]}, _, [seen, key]}),
    do: {seen, key}

  defp mapset_member_call(_), do: nil

  defp mapset_put_call({{:., _, [{:__aliases__, _, [:MapSet]}, :put]}, _, [seen, key]}),
    do: {seen, key}

  defp mapset_put_call(_), do: nil

  defp var_ast?({name, _, ctx}) when is_atom(name) and is_atom(ctx), do: true
  defp var_ast?(_), do: false

  defp has_var_ast?(ast, var) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        ^var, _acc -> {var, true}
        node, acc -> {node, acc}
      end)

    found
  end

  defp assigned_non_alias_vars(steps, aliases, excluded_vars) do
    steps
    |> Enum.flat_map(fn
      {:=, _, [{name, _, ctx} = var, _rhs]} when is_atom(name) and is_atom(ctx) -> [var]
      _ -> []
    end)
    |> Enum.uniq()
    |> Enum.reject(&(&1 in aliases or &1 in excluded_vars))
  end

  defp assignments_before(steps, idx) do
    steps
    |> Enum.take(idx)
    |> Enum.reduce(%{}, fn
      {:=, _, [{name, _, ctx} = var, rhs]}, acc when is_atom(name) and is_atom(ctx) ->
        Map.put(acc, var, rhs)

      _, acc ->
        acc
    end)
  end

  defp resolve_expr(expr, assignments, depth \\ 0)

  defp resolve_expr(expr, _assignments, depth) when depth > 8, do: expr

  defp resolve_expr({name, _, ctx} = expr, assignments, depth)
       when is_atom(name) and is_atom(ctx) do
    case Map.get(assignments, expr) do
      nil -> expr
      rhs -> resolve_expr(rhs, assignments, depth + 1)
    end
  end

  defp resolve_expr(expr, _assignments, _depth), do: expr

  defp has_any_var?(ast, vars, has_var), do: Enum.any?(vars, &has_var.(ast, &1))

  defp elem_aliases(steps, elem_var) do
    steps
    |> Enum.reduce([elem_var], fn
      {:=, _, [{name, _, ctx} = var, rhs]}, aliases when is_atom(name) and is_atom(ctx) ->
        if Enum.any?(aliases, &(&1 == rhs)), do: [var | aliases], else: aliases

      _, aliases ->
        aliases
    end)
    |> Enum.uniq()
  end

  defp callback(callbacks, key), do: Keyword.fetch!(callbacks, key)
end
