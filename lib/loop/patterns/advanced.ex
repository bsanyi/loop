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

      # P015 — cons-prepend form: acc = [mapper_list | acc], break(Enum.concat(Enum.reverse(acc)))
      {{:=, _, [acc, [{:|, _, [mapper_expr, acc]}]]}, idx} when acc == acc_var ->
        mapper = resolve_expr(mapper_expr, assignments_before(steps, idx))

        if concat_reverse_of?(break_expr, acc_var) and has_any_var?(mapper, aliases, has_var) do
          mapper
        else
          nil
        end

      _ ->
        nil
    end)
  end

  # P037 — Enum.concat/1: loop that appends each sublist element (identity flat_map)
  def concat_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with [{acc_name, []}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         acc_var = {acc_name, [], nil},
         mapper when not is_nil(mapper) <-
           flat_map_mapper(steps, elem_var, acc_var, break_expr, enum_reverse_arg, has_var),
         aliases = elem_aliases(steps, elem_var),
         true <- mapper in aliases do
      quote do
        Enum.concat(unquote(list_var))
      end
    else
      _ -> nil
    end
  end

  # P038 — Enum.concat/2: loop that copies one list onto another (break with acc ++ other)
  def concat_two_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{acc_name, []}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         acc_var = {acc_name, [], nil},
         {:++, _, [^acc_var, other_list]} <- break_expr,
         true <- concat_two_identity_step?(steps, elem_var, acc_var),
         false <- has_var.(other_list, elem_var) do
      quote do
        Enum.concat(unquote(list_var), unquote(other_list))
      end
    else
      _ -> nil
    end
  end

  defp concat_two_identity_step?(steps, elem_var, acc_var) do
    aliases = elem_aliases(steps, elem_var)

    Enum.any?(Enum.with_index(steps), fn
      {{:=, _, [acc, {:++, _, [acc, [mapper_expr]]}]}, idx} when acc == acc_var ->
        resolved = resolve_expr(mapper_expr, assignments_before(steps, idx))
        resolved in aliases

      _ ->
        false
    end)
  end

  def map_reduce_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)
    vars_equal = callback(callbacks, :vars_equal)

    with [{name1, init1}, {name2, init2}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         var1 = {name1, [], nil},
         var2 = {name2, [], nil},
         {mapped_acc_var, state_var, state_init} <-
           map_reduce_roles(
             {var1, init1},
             {var2, init2},
             break_expr,
             enum_reverse_arg,
             vars_equal
           ),
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
         enum_reverse_arg,
         vars_equal
       ) do
    left_var = enum_reverse_arg.(left_expr)

    cond do
      left_var != nil and vars_equal.(normalize_var(left_var), var1) and right_expr == var2 ->
        {var1, var2, init2}

      left_var != nil and vars_equal.(normalize_var(left_var), var2) and right_expr == var1 ->
        {var2, var1, init1}

      true ->
        nil
    end
  end

  # Handle 2-element tuple {left_expr, right_expr}
  defp map_reduce_roles(
         {var1, init1},
         {var2, init2},
         {left_expr, right_expr},
         enum_reverse_arg,
         vars_equal
       ) do
    left_var = enum_reverse_arg.(left_expr)

    cond do
      left_var != nil and vars_equal.(normalize_var(left_var), var1) and right_expr == var2 ->
        {var1, var2, init2}

      left_var != nil and vars_equal.(normalize_var(left_var), var2) and right_expr == var1 ->
        {var2, var1, init1}

      true ->
        nil
    end
  end

  defp map_reduce_roles(_, _, _, _, _), do: nil

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
    vars_equal = callback(callbacks, :vars_equal)

    with [{name1, init1}, {name2, init2}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         var1 = {name1, [], nil},
         var2 = {name2, [], nil},
         {mapped_acc_var, state_var, state_init} <-
           flat_map_reduce_roles({var1, init1}, {var2, init2}, break_expr, vars_equal),
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

  # 3-parameter version for backward compatibility
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

  # Handle 2-element tuple {left_expr, right_expr}
  defp flat_map_reduce_roles({var1, init1}, {var2, init2}, {left_expr, right_expr}) do
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

  # 4-parameter version with vars_equal support
  defp flat_map_reduce_roles(
         {var1, init1},
         {var2, init2},
         {:{}, _, [left_expr, right_expr]},
         vars_equal
       ) do
    left_normalized = normalize_var(left_expr)
    right_normalized = normalize_var(right_expr)

    cond do
      vars_equal.(left_normalized, var1) and vars_equal.(right_normalized, var2) ->
        {var1, var2, init2}

      vars_equal.(left_normalized, var2) and vars_equal.(right_normalized, var1) ->
        {var2, var1, init1}

      true ->
        nil
    end
  end

  # Handle 2-element tuple {left_expr, right_expr}
  defp flat_map_reduce_roles({var1, init1}, {var2, init2}, {left_expr, right_expr}, vars_equal) do
    left_normalized = normalize_var(left_expr)
    right_normalized = normalize_var(right_expr)

    cond do
      vars_equal.(left_normalized, var1) and vars_equal.(right_normalized, var2) ->
        {var1, var2, init2}

      vars_equal.(left_normalized, var2) and vars_equal.(right_normalized, var1) ->
        {var2, var1, init1}

      true ->
        nil
    end
  end

  defp flat_map_reduce_roles(_, _, _, _), do: nil

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

  # P016 — Enum.map_reduce/3: append single-element mapped acc + carry state
  def map_reduce_append_pattern(initials, body, callbacks) do
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
           map_reduce_append_callback_tuple(steps, elem_var, mapped_acc_var, state_var, has_var) do
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

  defp map_reduce_append_callback_tuple(steps, elem_var, mapped_acc_var, state_var, has_var) do
    aliases = elem_aliases(steps, elem_var)

    Enum.find_value(Enum.with_index(steps), fn
      {{:=, _, [acc, {:++, _, [acc, [single_expr]]}]}, idx} when acc == mapped_acc_var ->
        with {state_idx, state_rhs} <- latest_state_assignment(steps, state_var),
             true <- state_idx >= idx,
             resolved_mapped <- resolve_expr(single_expr, assignments_before(steps, idx)),
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

      _ ->
        nil
    end)
  end

  # P017 — Enum.flat_map_reduce/3: cons-prepend mapped lists + concat-reverse finish + carry state
  def flat_map_reduce_prepend_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{name1, init1}, {name2, init2}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         var1 = {name1, [], nil},
         var2 = {name2, [], nil},
         {mapped_acc_var, state_var, state_init} <-
           flat_map_reduce_prepend_roles({var1, init1}, {var2, init2}, break_expr),
         callback_tuple when not is_nil(callback_tuple) <-
           flat_map_reduce_prepend_callback_tuple(
             steps,
             elem_var,
             mapped_acc_var,
             state_var,
             has_var
           ) do
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

  defp flat_map_reduce_prepend_roles(
         {var1, init1},
         {var2, init2},
         {:{}, _, [left_expr, right_expr]}
       ) do
    cond do
      concat_reverse_of?(left_expr, var1) and right_expr == var2 ->
        {var1, var2, init2}

      concat_reverse_of?(left_expr, var2) and right_expr == var1 ->
        {var2, var1, init1}

      true ->
        nil
    end
  end

  # Handle 2-element tuple {left_expr, right_expr}
  defp flat_map_reduce_prepend_roles({var1, init1}, {var2, init2}, {left_expr, right_expr}) do
    cond do
      concat_reverse_of?(left_expr, var1) and right_expr == var2 ->
        {var1, var2, init2}

      concat_reverse_of?(left_expr, var2) and right_expr == var1 ->
        {var2, var1, init1}

      true ->
        nil
    end
  end

  defp flat_map_reduce_prepend_roles(_, _, _), do: nil

  defp flat_map_reduce_prepend_callback_tuple(
         steps,
         elem_var,
         mapped_acc_var,
         state_var,
         has_var
       ) do
    aliases = elem_aliases(steps, elem_var)

    Enum.find_value(Enum.with_index(steps), fn
      {{:=, _, [acc, [{:|, _, [mapper_expr, acc]}]]}, idx} when acc == mapped_acc_var ->
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

      _ ->
        nil
    end)
  end

  defp concat_reverse_of?(
         {{:., _, [{:__aliases__, _, [:Enum]}, :concat]}, _,
          [{{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [var]}]},
         target_var
       ) do
    var == target_var
  end

  defp concat_reverse_of?(_, _), do: false

  # P083 — Break expression `Enum.reverse(acc) ++ tail` canonicalizer
  # Returns {:ok, tail_expr} if break_expr is `Enum.reverse(acc_var) ++ tail_expr`, else :error
  defp reverse_acc_plus_tail?(
         {:++, _,
          [
            {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [var]},
            tail_expr
          ]},
         acc_var
       )
       when var == acc_var do
    {:ok, tail_expr}
  end

  defp reverse_acc_plus_tail?(_, _), do: :error

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

  def product_by_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{product_name, 1}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         product_var = {product_name, [], nil},
         true <- break_expr == product_var,
         {update_idx, term_expr} <- product_by_term_expr(steps, product_var),
         true <- update_idx == length(steps) - 1,
         aliases <- elem_aliases(steps, elem_var),
         resolved_term <- resolve_expr(term_expr, assignments_before(steps, update_idx)),
         assigned_non_alias <- assigned_non_alias_vars(steps, aliases, [product_var]),
         true <- has_any_var?(resolved_term, aliases, has_var),
         false <- has_var.(resolved_term, product_var),
         false <- has_var.(resolved_term, list_var),
         false <- has_any_var?(resolved_term, assigned_non_alias, has_var) do
      quote do
        Enum.product_by(unquote(list_var), fn unquote(elem_var) -> unquote(resolved_term) end)
      end
    else
      _ -> nil
    end
  end

  defp product_by_term_expr(steps, product_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, rhs]}, idx} when lhs == product_var ->
          case times_term(rhs, product_var) do
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

  defp times_term({:*, _, [left, right]}, product_var) do
    cond do
      left == product_var -> right
      right == product_var -> left
      true -> nil
    end
  end

  defp times_term({{:., _, [{:__aliases__, _, [:Kernel]}, :*]}, _, [left, right]}, product_var),
    do: times_term({:*, [], [left, right]}, product_var)

  defp times_term(_, _), do: nil

  # P056 — Count_until: count elements (or matching elements) up to a limit.
  # 2-arity: Enum.count_until(list, limit)
  # 3-arity: Enum.count_until(list, pred, limit)
  def count_until_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)

    with [{count_name, 0}] <- initials,
         count_var = {count_name, [], nil},
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- break_expr == count_var,
         [count_step, limit_step] <- steps,
         limit_expr when not is_nil(limit_expr) <- count_until_limit_step(limit_step, count_var),
         true <- limit_expr != count_var,
         true <- limit_expr != list_var do
      case count_until_count_step(count_step, count_var) do
        :all ->
          quote do
            Enum.count_until(unquote(list_var), unquote(limit_expr))
          end

        {:pred, pred_expr} ->
          quote do
            Enum.count_until(
              unquote(list_var),
              fn unquote(elem_var) -> unquote(pred_expr) end,
              unquote(limit_expr)
            )
          end

        nil ->
          nil
      end
    else
      _ -> nil
    end
  end

  # if count >= limit, do: break(count)  — after normalize: if limit <= count, do: break(count)
  defp count_until_limit_step(
         {:if, _, [{:<=, _, [limit, count1]}, [do: {:break, _, [count2]}]]},
         count_var
       )
       when count1 == count_var and count2 == count_var do
    limit
  end

  defp count_until_limit_step(_, _), do: nil

  # 2-arity: count = count + 1 (count all elements)
  defp count_until_count_step({:=, _, [count, {:+, _, [count, 1]}]}, count_var) do
    if count == count_var, do: :all
  end

  # 3-arity: count = if pred(h), do: count + 1, else: count (count matching elements)
  defp count_until_count_step(
         {:=, _, [count, {:if, _, [pred_expr, [do: {:+, _, [count, 1]}, else: count]]}]},
         count_var
       ) do
    if count == count_var, do: {:pred, pred_expr}
  end

  defp count_until_count_step(_, _), do: nil

  # P057 — Average: sum / count dual-accumulator pattern.
  # Emits: Enum.sum(list) / length(list)  or  Enum.sum_by(list, fn h -> f(h) end) / length(list)
  def average_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{name1, 0}, {name2, 0}] <- initials,
         var1 = {name1, [], nil},
         var2 = {name2, [], nil},
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         {sum_var, count_var} <- average_div_vars(break_expr, var1, var2),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         {sum_update_idx, sum_term} <- sum_by_term_expr(steps, sum_var),
         true <- count_has_increment?(steps, count_var),
         aliases <- elem_aliases(steps, elem_var),
         resolved_term <- resolve_expr(sum_term, assignments_before(steps, sum_update_idx)),
         true <- has_any_var?(resolved_term, aliases, has_var),
         false <- has_var.(resolved_term, sum_var),
         false <- has_var.(resolved_term, count_var),
         false <- has_var.(resolved_term, list_var) do
      if resolved_term == elem_var do
        quote do
          Enum.sum(unquote(list_var)) / length(unquote(list_var))
        end
      else
        quote do
          Enum.sum_by(unquote(list_var), fn unquote(elem_var) -> unquote(resolved_term) end) /
            length(unquote(list_var))
        end
      end
    else
      _ -> nil
    end
  end

  defp average_div_vars({:/, _, [left, right]}, var1, var2) do
    cond do
      left == var1 and right == var2 -> {var1, var2}
      left == var2 and right == var1 -> {var2, var1}
      true -> nil
    end
  end

  defp average_div_vars(_, _, _), do: nil

  defp count_has_increment?(steps, count_var) do
    Enum.any?(steps, fn
      {:=, _, [count, {:+, _, [count, 1]}]} -> count == count_var
      {:=, _, [count, {:+, _, [1, count]}]} -> count == count_var
      _ -> false
    end)
  end

  def delete_at_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, idx_var} <- delete_at_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         {update_idx, target_expr} <- delete_at_acc_update(steps, acc_var, idx_var, elem_var),
         true <- delete_at_index_updates_valid?(steps, idx_var),
         resolved_target <- resolve_expr(target_expr, assignments_before(steps, update_idx)),
         false <- has_var_ref(resolved_target, elem_var),
         false <- has_var_ref(resolved_target, list_var) do
      quote do
        list = unquote(list_var)
        target = unquote(resolved_target)

        list
        |> Enum.with_index()
        |> Enum.reduce([], fn
          {_elem, idx}, acc when idx == target -> acc
          {elem, _idx}, acc -> [elem | acc]
        end)
        |> Enum.reverse()
      end
    else
      _ -> nil
    end
  end

  defp delete_at_vars([{acc_name, []}, {idx_name, 0}]) do
    {{acc_name, [], nil}, {idx_name, [], nil}}
  end

  defp delete_at_vars([{idx_name, 0}, {acc_name, []}]) do
    {{acc_name, [], nil}, {idx_name, [], nil}}
  end

  defp delete_at_vars(_), do: nil

  defp delete_at_acc_update(steps, acc_var, idx_var, elem_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, rhs]}, idx} when lhs == acc_var ->
          case delete_at_update_rhs(rhs, acc_var, idx_var, elem_var) do
            nil -> []
            target_expr -> [{idx, target_expr}]
          end

        _ ->
          []
      end)

    case updates do
      [{idx, target_expr}] -> {idx, target_expr}
      _ -> nil
    end
  end

  defp delete_at_update_rhs(
         {:if, _, [condition, [do: acc_branch, else: cons_branch]]},
         acc_var,
         idx_var,
         elem_var
       )
       when acc_branch == acc_var do
    # Check if cons_branch is [elem | acc] (list-wrapped cons cell)
    case cons_branch do
      [{:|, _, [h, acc]}] when h == elem_var and acc == acc_var ->
        # Condition should be idx == target or target == idx
        case condition do
          {:==, _, [^idx_var, target]} -> target
          {:==, _, [target, ^idx_var]} -> target
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp delete_at_update_rhs(_, _, _, _), do: nil

  defp delete_at_index_updates_valid?(steps, idx_var) do
    Enum.any?(steps, fn step -> valid_index_increment?(step, idx_var) end)
  end

  defp valid_index_increment?({:=, _, [lhs, {:+, _, [rhs, 1]}]}, idx_var)
       when lhs == idx_var and rhs == idx_var, do: true

  defp valid_index_increment?({:=, _, [lhs, {:+, _, [1, rhs]}]}, idx_var)
       when lhs == idx_var and rhs == idx_var, do: true

  defp valid_index_increment?(
         {:=, _, [lhs, {{:., _, [{:__aliases__, _, [:Kernel]}, :+]}, _, [rhs, 1]}]},
         idx_var
       )
       when lhs == idx_var and rhs == idx_var, do: true

  defp valid_index_increment?(
         {:=, _, [lhs, {{:., _, [{:__aliases__, _, [:Kernel]}, :+]}, _, [1, rhs]}]},
         idx_var
       )
       when lhs == idx_var and rhs == idx_var, do: true

  defp valid_index_increment?(_, _), do: false

  defp has_var_ref(ast, var) do
    case ast do
      ^var -> true
      {_, _} -> false
      _ -> false
    end
  end

  # P058 — List mutation with index and tail append: delete-at-index but keep remaining list
  # loop acc: [], i: 0 do
  #   if list == [], do: break(Enum.reverse(acc) ++ other_list), else: [h | list] = list
  #   acc = if i != target, do: [h | acc], else: acc
  #   i = i + 1
  # end
  # =>
  # list
  # |> Enum.with_index()
  # |> Enum.reduce([], fn {h, i}, acc -> if i != target, do: [h | acc], else: acc end)
  # |> Enum.reverse()
  # |> Kernel.++(other_list)
  def list_delete_at_tail_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with {acc_var, idx_var} <- delete_at_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         {:ok, other_list} <- reverse_acc_plus_tail?(break_expr, acc_var),
         false <- has_var.(other_list, elem_var),
         false <- has_var.(other_list, idx_var),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         {update_idx, target_expr} <-
           list_delete_at_tail_acc_update(steps, acc_var, idx_var, elem_var),
         true <- delete_at_index_updates_valid?(steps, idx_var),
         resolved_target <- resolve_expr(target_expr, assignments_before(steps, update_idx)),
         false <- has_var.(resolved_target, elem_var),
         false <- has_var.(resolved_target, list_var) do
      quote do
        unquote(list_var)
        |> Enum.with_index()
        |> Enum.reduce([], fn {unquote(elem_var), unquote(idx_var)}, unquote(acc_var) ->
          if unquote(idx_var) != unquote(resolved_target),
            do: [unquote(elem_var) | unquote(acc_var)],
            else: unquote(acc_var)
        end)
        |> Enum.reverse()
        |> Kernel.++(unquote(other_list))
      end
    else
      _ -> nil
    end
  end

  # Find the acc update for P058 and extract the skip-index target.
  # Handles two forms:
  #   acc = if i != target, do: [h | acc], else: acc   (keep when !=)
  #   acc = if i == target, do: acc, else: [h | acc]   (skip when ==)
  defp list_delete_at_tail_acc_update(steps, acc_var, idx_var, elem_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        # Form 1: acc = if i != target, do: [h | acc], else: acc
        {{:=, _,
          [
            lhs,
            {:if, _,
             [{:!=, _, [idx, target_expr]}, [do: [{:|, _, [elem, acc_do]}], else: acc_else]]}
          ]}, step_idx}
        when lhs == acc_var and idx == idx_var and acc_do == acc_var and
               acc_else == acc_var and elem == elem_var ->
          [{step_idx, target_expr}]

        # Form 2: acc = if i == target, do: acc, else: [h | acc]
        {{:=, _,
          [
            lhs,
            {:if, _,
             [{:==, _, [idx, target_expr]}, [do: acc_do, else: [{:|, _, [elem, acc_else]}]]]}
          ]}, step_idx}
        when lhs == acc_var and idx == idx_var and acc_do == acc_var and
               acc_else == acc_var and elem == elem_var ->
          [{step_idx, target_expr}]

        _ ->
          []
      end)

    case updates do
      [{step_idx, target_expr}] -> {step_idx, target_expr}
      _ -> nil
    end
  end

  # P059 — List.update_at equivalent
  # loop acc: [], i: 0 do
  #   if list == [], do: break(Enum.reverse(acc))
  #   [h | list] = list
  #   acc = if i == target, do: [transform(h) | acc], else: [h | acc]
  #   i = i + 1
  # end
  # =>
  # list
  # |> Enum.with_index()
  # |> Enum.map(fn {h, i} -> if i == target, do: transform(h), else: h end)
  def list_update_at_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, idx_var} <- delete_at_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         {update_idx, condition, transform_expr} <-
           list_update_acc_update(steps, acc_var, idx_var, elem_var),
         true <- delete_at_index_updates_valid?(steps, idx_var),
         resolved_condition <- resolve_expr(condition, assignments_before(steps, update_idx)),
         {:==, _, [^idx_var, target_expr]} <- resolved_condition,
         resolved_transform <- resolve_expr(transform_expr, assignments_before(steps, update_idx)),
         false <- has_var.(target_expr, elem_var),
         false <- has_var.(target_expr, list_var) do
      quote do
        unquote(list_var)
        |> Enum.with_index()
        |> Enum.map(fn {unquote(elem_var), unquote(idx_var)} ->
          if unquote(idx_var) == unquote(target_expr),
            do: unquote(resolved_transform),
            else: unquote(elem_var)
        end)
      end
    else
      _ -> nil
    end
  end

  # P060 — List.insert_at equivalent
  # loop acc: [], i: 0 do
  #   if list == [], do: break(Enum.reverse(acc))
  #   [h | list] = list
  #   acc = if i == target, do: [h, value | acc], else: [h | acc]
  #   i = i + 1
  # end
  # =>
  # list
  # |> Enum.with_index()
  # |> Enum.reduce([], fn {h, i}, acc -> if i == target, do: [h, value | acc], else: [h | acc] end)
  # |> Enum.reverse()
  def list_insert_at_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, idx_var} <- delete_at_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         {update_idx, condition, insert_value_expr} <-
           list_insert_acc_update(steps, acc_var, idx_var, elem_var),
         true <- delete_at_index_updates_valid?(steps, idx_var),
         resolved_condition <- resolve_expr(condition, assignments_before(steps, update_idx)),
         {:==, _, [^idx_var, target_expr]} <- resolved_condition,
         resolved_value <- resolve_expr(insert_value_expr, assignments_before(steps, update_idx)),
         false <- has_var.(target_expr, elem_var),
         false <- has_var.(target_expr, list_var),
         false <- has_var.(resolved_value, elem_var),
         false <- has_var.(resolved_value, idx_var) do
      quote do
        unquote(list_var)
        |> Enum.with_index()
        |> Enum.reduce([], fn {unquote(elem_var), unquote(idx_var)}, unquote(acc_var) ->
          if unquote(idx_var) == unquote(target_expr),
            do: [unquote(elem_var), unquote(resolved_value) | unquote(acc_var)],
            else: [unquote(elem_var) | unquote(acc_var)]
        end)
        |> Enum.reverse()
      end
    else
      _ -> nil
    end
  end

  # Helper: extract acc update for list_update_at pattern
  # Returns {update_idx, condition, transform_expr} where
  #   acc = if condition, do: [transform(h) | acc], else: [h | acc]
  defp list_update_acc_update(steps, acc_var, _idx_var, elem_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _,
          [
            lhs,
            {:if, _,
             [
               condition,
               [do: [{:|, _, [transform_expr, acc_do]}], else: [{:|, _, [elem_else, acc_else]}]]
             ]}
          ]}, idx}
        when lhs == acc_var and acc_do == acc_var and acc_else == acc_var and
               elem_else == elem_var ->
          [{idx, condition, transform_expr}]

        _ ->
          []
      end)

    case updates do
      [{idx, condition, transform_expr}] -> {idx, condition, transform_expr}
      _ -> nil
    end
  end

  # Helper: extract acc update for list_insert_at pattern
  # Returns {update_idx, condition, value_expr} where
  #   acc = if condition, do: [h, value | acc], else: [h | acc]
  # AST of [h, value | acc] is [h_var, {:|, [], [value_var, acc_var]}]
  defp list_insert_acc_update(steps, acc_var, _idx_var, elem_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _,
          [
            lhs,
            {:if, _,
             [
               condition,
               [
                 do: [elem_do, {:|, _, [insert_val, acc_do]}],
                 else: [{:|, _, [elem_else, acc_else]}]
               ]
             ]}
          ]}, idx}
        when lhs == acc_var and acc_do == acc_var and acc_else == acc_var and
               elem_do == elem_var and elem_else == elem_var ->
          [{idx, condition, insert_val}]

        _ ->
          []
      end)

    case updates do
      [{idx, condition, insert_val}] -> {idx, condition, insert_val}
      _ -> nil
    end
  end

  def take_every_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)
    vars_equal = callback(callbacks, :vars_equal)

    with {acc_var, idx_var, offset} <- take_every_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         extracted_var when not is_nil(extracted_var) <- enum_reverse_arg.(break_expr),
         extracted_var_normalized <- normalize_var(extracted_var),
         true <- vars_equal.(extracted_var_normalized, acc_var),
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
      take_every_quote(list_var, elem_var, idx_var, stride_expr, offset)
    else
      _ -> nil
    end
  end

  defp take_every_vars([{acc_name, []}, {idx_name, k}]) when is_integer(k) and k >= 0,
    do: {{acc_name, [], nil}, {idx_name, [], nil}, k}

  defp take_every_vars([{idx_name, k}, {acc_name, []}]) when is_integer(k) and k >= 0,
    do: {{acc_name, [], nil}, {idx_name, [], nil}, k}

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
      do_expr == acc_var and match?([{:|, _, [_, ^acc_var]}], else_expr) ->
        [{:|, _, [selected_expr, ^acc_var]}] = else_expr
        {condition, false, selected_expr}

      else_expr == acc_var and match?([{:|, _, [_, ^acc_var]}], do_expr) ->
        [{:|, _, [selected_expr, ^acc_var]}] = do_expr
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

  defp take_every_quote(list_var, _elem_var, _idx_var, stride_expr, 0) do
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

  defp take_every_quote(list_var, _elem_var, _idx_var, stride_expr, k) do
    quote do
      list = unquote(list_var)
      stride = unquote(stride_expr)

      if is_integer(stride) and stride > 0 do
        drop_count = rem(stride - rem(unquote(k), stride), stride)
        list |> Enum.drop(drop_count) |> Enum.take_every(stride)
      else
        list
        |> Enum.with_index(unquote(k))
        |> Enum.reduce([], fn
          {elem, idx}, acc when rem(idx, stride) == 0 -> [elem | acc]
          _, acc -> acc
        end)
        |> Enum.reverse()
      end
    end
  end

  def drop_every_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, idx_var, offset} <- take_every_vars(initials),
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
         true <- condition_true_on_boundary != include_when_true do
      drop_every_quote(list_var, stride_expr, offset)
    else
      _ -> nil
    end
  end

  defp drop_every_quote(list_var, stride_expr, 0) do
    quote do
      list = unquote(list_var)
      stride = unquote(stride_expr)

      if is_integer(stride) and stride > 0 do
        Enum.drop_every(list, stride)
      else
        list
        |> Enum.with_index()
        |> Enum.reduce([], fn
          {_, idx}, acc when rem(idx, stride) == 0 -> acc
          {elem, _idx}, acc -> [elem | acc]
        end)
        |> Enum.reverse()
      end
    end
  end

  defp drop_every_quote(list_var, stride_expr, k) do
    quote do
      list = unquote(list_var)
      stride = unquote(stride_expr)

      if is_integer(stride) and stride > 0 do
        drop_count = rem(stride - rem(unquote(k), stride), stride)
        Enum.take(list, drop_count) ++ (list |> Enum.drop(drop_count) |> Enum.drop_every(stride))
      else
        list
        |> Enum.with_index(unquote(k))
        |> Enum.reduce([], fn
          {_, idx}, acc when rem(idx, stride) == 0 -> acc
          {elem, _idx}, acc -> [elem | acc]
        end)
        |> Enum.reverse()
      end
    end
  end

  def map_every_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, idx_var, offset} <- take_every_vars(initials),
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
      map_every_quote(list_var, elem_var, stride_expr, transform_expr, offset)
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
    with [{:|, _, [do_value, ^acc_var]}] <- do_expr,
         [{:|, _, [else_value, ^acc_var]}] <- else_expr do
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

  defp map_every_quote(list_var, elem_var, stride_expr, transform_expr, 0) do
    fallback = map_every_fallback_quote(elem_var, transform_expr, 0)

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

  defp map_every_quote(list_var, elem_var, stride_expr, transform_expr, k) do
    fallback = map_every_fallback_quote(elem_var, transform_expr, k)

    quote do
      list = unquote(list_var)
      stride = unquote(stride_expr)

      if is_integer(stride) and stride > 0 do
        drop_count = rem(stride - rem(unquote(k), stride), stride)

        Enum.take(list, drop_count) ++
          Enum.map_every(
            Enum.drop(list, drop_count),
            stride,
            fn unquote(elem_var) -> unquote(transform_expr) end
          )
      else
        unquote(fallback)
      end
    end
  end

  defp map_every_fallback_quote(elem_var, transform_expr, 0) do
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

  defp map_every_fallback_quote(elem_var, transform_expr, k) do
    quote do
      list
      |> Enum.with_index(unquote(k))
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
         extracted_acc <- enum_reverse_arg.(break_expr),
         true <- extracted_acc != nil and extracted_acc == acc_var,
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
      {[{:|, _, [mapped, ^acc_var]}], [mapped_else, {:|, _, [sep, ^acc_var]}]}
      when mapped == mapped_else ->
        {mapped, sep, true}

      {[mapped_do, {:|, _, [sep, ^acc_var]}], [{:|, _, [mapped, ^acc_var]}]}
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
      map_join_quote(list_var, elem_var, resolved_joiner, resolved_mapped, aliases)
    else
      _ -> nil
    end
  end

  defp map_join_quote(list_var, elem_var, resolved_joiner, resolved_mapped, aliases) do
    # P039: when mapper is identity (element itself), emit Enum.join instead of Enum.map_join
    if resolved_mapped in aliases do
      quote do
        Enum.join(unquote(list_var), unquote(resolved_joiner))
      end
    else
      quote do
        Enum.map_join(
          unquote(list_var),
          unquote(resolved_joiner),
          fn unquote(elem_var) -> unquote(resolved_mapped) end
        )
      end
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
         [{:=, _, [key_step_var, key_expr]}, tuple_update] <- steps,
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
             elem_var,
             key_step_var
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
            [
              {:|, [],
               [{{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [chunk_var]}, chunks_var]}
            ]

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
         elem_var,
         key_step_var
       ) do
    with true <- chunks_lhs == chunks_var,
         true <- chunk_lhs == chunk_var,
         true <- key_lhs == key_var,
         true <- started_lhs == started_var,
         true <- chunk_by_condition?(condition, started_var, key_var),
         true <- do_tuple == chunk_by_do_tuple(chunks_var, chunk_var, key_step_var, elem_var),
         true <- else_tuple == chunk_by_else_tuple(chunks_var, chunk_var, key_step_var, elem_var) do
      true
    else
      _ -> false
    end
  end

  defp chunk_by_tuple_update?(_, _, _, _, _, _, _), do: false

  defp chunk_by_condition?({:and, _, [left, right]}, started_var, key_var),
    do: left == started_var and key_not_equal?(right, key_var)

  defp chunk_by_condition?(_, _, _), do: false

  defp key_not_equal?({:!=, _, [left, right]}, key_var), do: left == key_var or right == key_var
  defp key_not_equal?({:!==, _, [left, right]}, key_var), do: left == key_var or right == key_var
  defp key_not_equal?(_, _), do: false

  defp chunk_by_do_tuple(chunks_var, chunk_var, key_step_var, elem_var) do
    {:{}, [],
     [
       [
         {:|, [],
          [{{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [chunk_var]}, chunks_var]}
       ],
       [elem_var],
       key_step_var,
       true
     ]}
  end

  defp chunk_by_else_tuple(chunks_var, chunk_var, key_step_var, elem_var) do
    {:{}, [], [chunks_var, [{:|, [], [elem_var, chunk_var]}], key_step_var, true]}
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

  # P021/P022 — Frequencies via Map.get + Map.put
  # Recognises:
  #   count = Map.get(freq, key_expr, 0)
  #   freq  = Map.put(freq, key_expr, count + 1)
  # Emits Enum.frequencies/1 when key_expr is the element itself (P021),
  # or Enum.frequencies_by/2 when key_expr is a function of the element (P022).
  def frequencies_get_put_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{freq_name, {:%{}, _, []}}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         freq_var = {freq_name, [], nil},
         true <- break_expr == freq_var,
         {put_idx, key_expr} <- frequencies_get_put_key(steps, freq_var),
         true <- put_idx == length(steps) - 1,
         aliases <- elem_aliases(steps, elem_var),
         resolved_key <- resolve_expr(key_expr, assignments_before(steps, put_idx)),
         assigned_non_alias <- assigned_non_alias_vars(steps, aliases, [freq_var]),
         true <- has_any_var?(resolved_key, aliases, has_var),
         false <- has_var.(resolved_key, freq_var),
         false <- has_var.(resolved_key, list_var),
         false <- has_any_var?(resolved_key, assigned_non_alias, has_var) do
      frequencies_quote(list_var, elem_var, resolved_key, aliases)
    else
      _ -> nil
    end
  end

  defp frequencies_quote(list_var, elem_var, resolved_key, aliases) do
    if resolved_key in aliases do
      quote do
        Enum.frequencies(unquote(list_var))
      end
    else
      quote do
        Enum.frequencies_by(unquote(list_var), fn unquote(elem_var) -> unquote(resolved_key) end)
      end
    end
  end

  defp frequencies_get_put_key(steps, freq_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, put_call]}, idx} when lhs == freq_var ->
          case map_put_increment(put_call, freq_var, steps, idx) do
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

  defp map_put_increment(
         {{:., _, [{:__aliases__, _, [:Map]}, :put]}, _, [freq, key_expr, increment]},
         freq_var,
         steps,
         put_idx
       )
       when freq == freq_var do
    case increment do
      {:+, _, [count, 1]} ->
        if count_for_freq_key?(count, freq_var, key_expr, steps, put_idx), do: key_expr

      {:+, _, [1, count]} ->
        if count_for_freq_key?(count, freq_var, key_expr, steps, put_idx), do: key_expr

      _ ->
        nil
    end
  end

  defp map_put_increment(_, _, _, _), do: nil

  # Accepts both:
  #   - a variable that is assigned via Map.get(freq_var, key_expr, 0) in an earlier step
  #   - the Map.get(freq_var, key_expr, 0) call itself (inline form after alias-inlining)
  defp count_for_freq_key?(count, freq_var, key_expr, steps, put_idx) do
    case count do
      {name, _, ctx} when is_atom(name) and is_atom(ctx) ->
        Enum.any?(Enum.take(steps, put_idx), fn
          {:=, _, [lhs, {{:., _, [{:__aliases__, _, [:Map]}, :get]}, _, [freq, key, 0]}]} ->
            lhs == count and freq == freq_var and key == key_expr

          _ ->
            false
        end)

      {{:., _, [{:__aliases__, _, [:Map]}, :get]}, _, [get_freq, get_key, 0]}
      when get_freq == freq_var and get_key == key_expr ->
        true

      _ ->
        false
    end
  end

  def unzip_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)
    vars_equal = callback(callbacks, :vars_equal)

    with {left_acc_var, right_acc_var} <- unzip_acc_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         {^left_acc_var, ^right_acc_var} <-
           unzip_break_payload(
             break_expr,
             left_acc_var,
             right_acc_var,
             enum_reverse_arg,
             vars_equal
           ),
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
         enum_reverse_arg,
         vars_equal
       ) do
    with extracted_left when not is_nil(extracted_left) <- enum_reverse_arg.(left_expr),
         true <- vars_equal.(normalize_var(extracted_left), left_acc_var),
         extracted_right when not is_nil(extracted_right) <- enum_reverse_arg.(right_expr),
         true <- vars_equal.(normalize_var(extracted_right), right_acc_var) do
      {left_acc_var, right_acc_var}
    else
      _ -> nil
    end
  end

  # Handle 2-element tuple break {left_expr, right_expr}
  defp unzip_break_payload(
         {left_expr, right_expr},
         left_acc_var,
         right_acc_var,
         enum_reverse_arg,
         vars_equal
       ) do
    with extracted_left when not is_nil(extracted_left) <- enum_reverse_arg.(left_expr),
         true <- vars_equal.(normalize_var(extracted_left), left_acc_var),
         extracted_right when not is_nil(extracted_right) <- enum_reverse_arg.(right_expr),
         true <- vars_equal.(normalize_var(extracted_right), right_acc_var) do
      {left_acc_var, right_acc_var}
    else
      _ -> nil
    end
  end

  defp unzip_break_payload(_, _, _, _, _), do: nil

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
         false <- mapped_expr == {elem1_var, elem2_var} do
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

  # P032 — Zip for 3+ lists → Enum.zip/1
  def zip_nary_pattern(initials, body, callbacks) do
    map_destructure = callback(callbacks, :map_destructure)
    empty_list_check = callback(callbacks, :empty_list_check)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with [{acc_name, []}] <- initials,
         {:__block__, _, [exit | rest]} <- body,
         {destructures, accumulate} when length(destructures) >= 3 <-
           split_stmts_last(rest),
         acc_var = {acc_name, [], nil},
         {list_vars, ^acc_var} <-
           zip_nary_exit_strategy(exit, empty_list_check, enum_reverse_arg),
         true <- length(list_vars) == length(destructures),
         elem_vars when not is_nil(elem_vars) <-
           zip_nary_destructures(destructures, list_vars, map_destructure),
         true <- zip_nary_accumulate(accumulate, acc_var, elem_vars) do
      quote do
        Enum.zip(unquote(list_vars))
      end
    else
      _ -> nil
    end
  end

  # P033 — Zip_with for 3+ lists → Enum.zip_with/2
  def zip_with_nary_pattern(initials, body, callbacks) do
    map_destructure = callback(callbacks, :map_destructure)
    has_var = callback(callbacks, :has_var)
    empty_list_check = callback(callbacks, :empty_list_check)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with [{acc_name, []}] <- initials,
         {:__block__, _, [exit | rest]} <- body,
         {destructures, accumulate} when length(destructures) >= 3 <-
           split_stmts_last(rest),
         acc_var = {acc_name, [], nil},
         {list_vars, ^acc_var} <-
           zip_nary_exit_strategy(exit, empty_list_check, enum_reverse_arg),
         true <- length(list_vars) == length(destructures),
         elem_vars when not is_nil(elem_vars) <-
           zip_nary_destructures(destructures, list_vars, map_destructure),
         {^acc_var, mapped_expr} <- cons_update(accumulate),
         true <- Enum.all?(elem_vars, &has_var.(mapped_expr, &1)),
         false <- mapped_expr == {:{}, [], elem_vars} do
      # Enum.zip_with/2 calls fun with a list of elements: fn [x, y, z] -> expr end
      fn_ast = {:fn, [], [{:->, [], [[elem_vars], mapped_expr]}]}

      quote do
        Enum.zip_with(unquote(list_vars), unquote(fn_ast))
      end
    else
      _ -> nil
    end
  end

  # P034 — Zip_reduce for 3+ lists → Enum.zip_reduce/3
  def zip_reduce_nary_pattern(initials, body, callbacks) do
    map_destructure = callback(callbacks, :map_destructure)
    has_var = callback(callbacks, :has_var)
    empty_list_check = callback(callbacks, :empty_list_check)

    with [{acc_name, init}] <- initials,
         {:__block__, _, [exit | rest]} <- body,
         {destructures, update} when length(destructures) >= 3 <-
           split_stmts_last(rest),
         acc_var = {acc_name, [], nil},
         {list_vars, ^acc_var} <-
           zip_reduce_nary_exit_strategy(exit, empty_list_check),
         true <- length(list_vars) == length(destructures),
         elem_vars when not is_nil(elem_vars) <-
           zip_nary_destructures(destructures, list_vars, map_destructure),
         {^acc_var, reduce_expr} <- zip_reduce_update(update, acc_var),
         true <- Enum.all?(elem_vars, &has_var.(reduce_expr, &1)),
         false <- Enum.any?(list_vars, &has_var.(reduce_expr, &1)) do
      # Enum.zip_reduce/3 calls reducer with (elements_list, acc): fn [x, y, z], acc -> expr end
      fn_ast = {:fn, [], [{:->, [], [[elem_vars, acc_var], reduce_expr]}]}

      quote do
        Enum.zip_reduce(unquote(list_vars), unquote(init), unquote(fn_ast))
      end
    else
      _ -> nil
    end
  end

  # Splits [s1, ..., sN] into {[s1, ..., sN-1], sN}. Returns nil if fewer than 2 elements.
  defp split_stmts_last([_ | _] = stmts) do
    n = length(stmts) - 1
    {front, [last]} = Enum.split(stmts, n)
    {front, last}
  end

  defp split_stmts_last(_), do: nil

  # Exit for N-ary zip/zip_with: if list1 == [] or ... or listN == [], do: break(Enum.reverse(acc))
  # Returns {list_vars, acc_var} where length(list_vars) >= 3, or nil.
  defp zip_nary_exit_strategy(
         {:if, _, [condition, [do: {:break, _, [break_expr]}]]},
         empty_list_check,
         enum_reverse_arg
       ) do
    with acc_var when not is_nil(acc_var) <- enum_reverse_arg.(break_expr),
         [_, _, _ | _] = list_vars <- zip_nary_or_lists(condition, empty_list_check) do
      {list_vars, acc_var}
    else
      _ -> nil
    end
  end

  defp zip_nary_exit_strategy(_, _, _), do: nil

  # Exit for N-ary zip_reduce: if list1 == [] or ... or listN == [], do: break(acc)
  # Returns {list_vars, acc_var} where length(list_vars) >= 3, or nil.
  defp zip_reduce_nary_exit_strategy(
         {:if, _, [condition, [do: {:break, _, [break_expr]}]]},
         empty_list_check
       ) do
    with true <- var_ast?(break_expr),
         [_, _, _ | _] = list_vars <- zip_nary_or_lists(condition, empty_list_check) do
      {list_vars, break_expr}
    else
      _ -> nil
    end
  end

  defp zip_reduce_nary_exit_strategy(_, _), do: nil

  # Extracts list vars from a left-nested OR-chain of empty-list checks.
  # list1 == [] or list2 == [] or list3 == [] parses as (check1 or check2) or check3.
  # Returns [list1_var, list2_var, list3_var, ...] in order, or nil.
  defp zip_nary_or_lists(expr, empty_list_check) do
    case expr do
      {op, _, [left, right]} when op in [:or, :||] ->
        with {list_var, _} <- empty_list_check.(right),
             [_ | _] = lists <- zip_nary_or_lists(left, empty_list_check) do
          lists ++ [list_var]
        else
          _ -> nil
        end

      _ ->
        case empty_list_check.(expr) do
          {list_var, _} -> [list_var]
          _ -> nil
        end
    end
  end

  # Matches N destructures [h_i | list_i] = list_i against expected list vars in order.
  # Returns [elem1_var, elem2_var, ...] in order, or nil if any destructure mismatches.
  defp zip_nary_destructures(destructures, list_vars, map_destructure) do
    Enum.zip(destructures, list_vars)
    |> Enum.reduce_while([], fn {d, list_var}, acc ->
      case map_destructure.(d) do
        {^list_var, elem_var} -> {:cont, [elem_var | acc]}
        _ -> {:halt, nil}
      end
    end)
    |> case do
      nil -> nil
      reversed -> Enum.reverse(reversed)
    end
  end

  # Checks acc = [{h1, h2, ..., hN} | acc] tuple accumulation.
  defp zip_nary_accumulate(
         {:=, _, [acc, [{:|, _, [{:{}, _, elems}, acc]}]]},
         acc_var,
         elem_vars
       ) do
    acc == acc_var and elems == elem_vars
  end

  defp zip_nary_accumulate(_, _, _), do: false

  def min_max_pattern(initials, body, callbacks) do
    next_step = callback(callbacks, :next_step)
    vars_equal = callback(callbacks, :vars_equal)
    empty_list_check = callback(callbacks, :empty_list_check)

    with [{name1, {:hd, _, [init_list1]}}, {name2, {:hd, _, [init_list2]}}] <- initials,
         init_list1_normalized <- normalize_var(init_list1),
         init_list2_normalized <- normalize_var(init_list2),
         true <- vars_equal.(init_list1_normalized, init_list2_normalized),
         {:__block__, _, [advance, exit, update1, update2]} <- body,
         list_var <- next_step.(advance),
         true <- vars_equal.(init_list1_normalized, list_var),
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
         {:if, _, [condition, [do: {:break, _, [{left, right}]}]]},
         empty_list_check
       ) do
    case empty_list_check.(condition) do
      {list_var, _} -> {list_var, left, right}
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
    normalize = callback(callbacks, :normalize)

    with {best_var, best_key_var, init_list, init_key_expr} <- max_by_state_vars(initials),
         init_list_normalized <- normalize_var(init_list),
         {:__block__, _, [advance, exit, candidate_assign, candidate_key_assign, update_if]} <-
           body,
         list_var <- next_step.(advance),
         true <- vars_equal.(init_list_normalized, list_var),
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
         expected_init <-
           replace_var.(candidate_key_expr, candidate_var, {:hd, [], [init_list_normalized]}),
         init_key_expr_normalized <- normalize.(init_key_expr),
         true <- expected_init == init_key_expr_normalized do
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
         true <- do_tuple == {:{}, [], [candidate_var, candidate_key_var]},
         true <- else_tuple == {:{}, [], [best_var, best_key_var]} do
      max_by_update_result(compare_op, left, right, best_var, best_key_var, candidate_key_var)
    else
      _ -> nil
    end
  end

  # Handle 2-element tuples (bare tuple form {a, b} instead of {:{}, _, [a, b]})
  defp max_by_update_tuple(
         {:=, _,
          [
            {best_lhs, best_key_lhs},
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
         true <- do_tuple == {candidate_var, candidate_key_var},
         true <- else_tuple == {best_var, best_key_var} do
      max_by_update_result(compare_op, left, right, best_var, best_key_var, candidate_key_var)
    else
      _ -> nil
    end
  end

  defp max_by_update_tuple(_, _, _, _, _), do: nil

  defp max_by_update_result(compare_op, left, right, best_var, best_key_var, candidate_key_var) do
    cond do
      left == candidate_key_var and right == best_key_var ->
        {compare_op, best_var, best_key_var}

      left == best_key_var and right == candidate_key_var ->
        flipped = if compare_op == :>, do: :<, else: :>
        {flipped, best_var, best_key_var}

      true ->
        nil
    end
  end

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

  # P070 — max_by/min_by with custom comparator (3-arity)
  # NOTE: P070 cannot be implemented with the current pattern matching approach because
  # non-strict operators (<=, >=) have different semantics in loops vs Enum functions.
  # The loop preserves "last element wins" semantics for ties, while Enum functions use
  # "first element wins". This is demonstrated by the test:
  # "max_by pattern failure: >= tie handling must preserve loop semantics"
  # which verifies that >= should NOT be recognized as an optimization.
  #
  # P070 remains unimplemented until we find a way to handle the semantic difference.

  def min_max_by_pattern(initials, body, callbacks) do
    next_step = callback(callbacks, :next_step)
    vars_equal = callback(callbacks, :vars_equal)
    empty_list_check = callback(callbacks, :empty_list_check)
    has_var = callback(callbacks, :has_var)
    replace_var = callback(callbacks, :replace_var)
    normalize = callback(callbacks, :normalize)

    with {min_var, min_key_var, max_var, max_key_var, init_list, init_key_expr} <-
           min_max_by_state_vars(initials),
         init_list_normalized <- normalize_var(init_list),
         {:__block__, _,
          [advance, exit, candidate_assign, candidate_key_assign, min_update, max_update]} <-
           body,
         list_var <- next_step.(advance),
         true <- vars_equal.(init_list_normalized, list_var),
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
         expected_init <-
           replace_var.(candidate_key_expr, candidate_var, {:hd, [], [init_list_normalized]}),
         init_key_expr_normalized <- normalize.(init_key_expr),
         true <- expected_init == init_key_expr_normalized,
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
         init_list1_normalized <- normalize_var(init_list1),
         init_list2_normalized <- normalize_var(init_list2),
         true <- init_list1_normalized == init_list2_normalized,
         key_entries <- Enum.reject(initials, &match?({_name, {:hd, _, [_]}}, &1)),
         [{min_key_name, init_key_expr1}, {max_key_name, init_key_expr2}] <- key_entries,
         true <- init_key_expr1 == init_key_expr2 do
      {
        {min_name, [], nil},
        {min_key_name, [], nil},
        {max_name, [], nil},
        {max_key_name, [], nil},
        init_list1_normalized,
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
    with compare_op when not is_nil(compare_op) <-
           min_max_by_compare(condition, candidate_key_var, best_key_var),
         true <- compare_op == expected_compare,
         true <- best_lhs == best_var,
         true <- best_key_lhs == best_key_var,
         true <- do_tuple == {:{}, [], [candidate_var, candidate_key_var]},
         true <- else_tuple == {:{}, [], [best_var, best_key_var]} do
      true
    else
      _ -> false
    end
  end

  # Handle 2-element tuples (bare tuple form {a, b} instead of {:{}, _, [a, b]})
  defp min_max_by_update_tuple(
         {:=, _,
          [
            {best_lhs, best_key_lhs},
            {:if, _, [condition, [do: do_tuple, else: else_tuple]]}
          ]},
         best_var,
         best_key_var,
         candidate_var,
         candidate_key_var,
         expected_compare
       ) do
    with compare_op when not is_nil(compare_op) <-
           min_max_by_compare(condition, candidate_key_var, best_key_var),
         true <- compare_op == expected_compare,
         true <- best_lhs == best_var,
         true <- best_key_lhs == best_key_var,
         true <- do_tuple == {candidate_var, candidate_key_var},
         true <- else_tuple == {best_var, best_key_var} do
      true
    else
      _ -> false
    end
  end

  defp min_max_by_update_tuple(_, _, _, _, _, _), do: false

  # Canonicalize the strict comparison to "candidate_key op best_key" orientation.
  # Normalize P047 rewrites `candidate_key > best_key` into `best_key < candidate_key`,
  # so the operand-swapped form must flip the operator back.
  defp min_max_by_compare(condition, candidate_key_var, best_key_var) do
    case strict_compare(condition) do
      {op, left, right} when left == candidate_key_var and right == best_key_var ->
        op

      {op, left, right} when left == best_key_var and right == candidate_key_var ->
        if op == :<, do: :>, else: :<

      _ ->
        nil
    end
  end

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

  # P023/P024 — Group_by via Map.get + Map.put
  # P023 (append mode):
  #   bucket = Map.get(acc, key_expr, [])
  #   acc    = Map.put(acc, key_expr, bucket ++ [value_expr])
  #   break with acc
  # P024 (prepend + reverse mode):
  #   bucket = Map.get(acc, key_expr, [])
  #   acc    = Map.put(acc, key_expr, [value_expr | bucket])
  #   break with Map.new(acc, fn {k, v} -> {k, Enum.reverse(v)} end)
  # Both emit Enum.group_by/2 or Enum.group_by/3.
  def group_by_get_put_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{acc_name, {:%{}, _, []}}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         acc_var = {acc_name, [], nil},
         {key_expr, value_expr} when not is_nil(key_expr) <-
           group_by_get_put_key_value(steps, elem_var, acc_var, break_expr, has_var) do
      group_by_quote(list_var, elem_var, key_expr, value_expr)
    else
      _ -> nil
    end
  end

  defp group_by_get_put_key_value(steps, elem_var, acc_var, break_expr, has_var) do
    aliases = elem_aliases(steps, elem_var)
    assigned_non_alias = assigned_non_alias_vars(steps, aliases, [acc_var])

    Enum.find_value(Enum.with_index(steps), fn
      {{:=, _, [acc, put_call]}, put_idx} when acc == acc_var ->
        # Try both: non-inlined (bucket_var as separate Map.get step) and
        # inlined (Map.get embedded directly in the Map.put call).
        pair = get_put_pair(put_call, acc_var, steps, put_idx)

        case pair do
          {_key_expr, _value_expr, _mode} = kvm ->
            group_by_get_put_resolve(
              kvm,
              put_idx,
              steps,
              acc_var,
              break_expr,
              aliases,
              assigned_non_alias,
              has_var
            )

          _ ->
            nil
        end

      _ ->
        nil
    end)
  end

  defp get_put_pair(put_call, acc_var, steps, put_idx) do
    map_put_inline_get_update(put_call, acc_var) ||
      case map_put_list_update(put_call, acc_var) do
        {key_expr, value_expr, bucket_var, mode} ->
          if find_get_step?(bucket_var, acc_var, key_expr, steps, put_idx) do
            {key_expr, value_expr, mode}
          end

        _ ->
          nil
      end
  end

  defp group_by_get_put_resolve(
         {key_expr, value_expr, mode},
         put_idx,
         steps,
         acc_var,
         break_expr,
         aliases,
         assigned_non_alias,
         has_var
       ) do
    if valid_group_by_break?(break_expr, acc_var, mode) do
      assignments = assignments_before(steps, put_idx)
      resolved_key = resolve_expr(key_expr, assignments)
      resolved_value = resolve_expr(value_expr, assignments)

      if has_any_var?(resolved_key, aliases, has_var) and
           has_any_var?(resolved_value, aliases, has_var) and
           not has_any_var?(resolved_key, assigned_non_alias, has_var) and
           not has_any_var?(resolved_value, assigned_non_alias, has_var) do
        {resolved_key, resolved_value}
      end
    end
  end

  # Recognises the inlined form:
  #   Map.put(acc, key, Map.get(acc, key, []) ++ [val]) → {key, val, :append}
  #   Map.put(acc, key, [val | Map.get(acc, key, [])]) → {key, val, :prepend}
  defp map_put_inline_get_update(
         {{:., _, [{:__aliases__, _, [:Map]}, :put]}, _, [acc, key_expr, list_update]},
         acc_var
       )
       when acc == acc_var do
    case list_update do
      {:++, _,
       [
         {{:., _, [{:__aliases__, _, [:Map]}, :get]}, _, [get_acc, get_key, []]},
         [value_expr]
       ]}
      when get_acc == acc_var and get_key == key_expr ->
        {key_expr, value_expr, :append}

      [
        {:|, _,
         [
           value_expr,
           {{:., _, [{:__aliases__, _, [:Map]}, :get]}, _, [get_acc, get_key, []]}
         ]}
      ]
      when get_acc == acc_var and get_key == key_expr ->
        {key_expr, value_expr, :prepend}

      _ ->
        nil
    end
  end

  defp map_put_inline_get_update(_, _), do: nil

  # Recognises acc = Map.put(acc, key, bucket ++ [val]) → {key, val, bucket, :append}
  # or         acc = Map.put(acc, key, [val | bucket])  → {key, val, bucket, :prepend}
  # (bucket is a variable, looked up via a preceding Map.get step)
  defp map_put_list_update(
         {{:., _, [{:__aliases__, _, [:Map]}, :put]}, _, [acc, key_expr, list_update]},
         acc_var
       )
       when acc == acc_var do
    case list_update do
      {:++, _, [{name, _, ctx} = bucket_var, [value_expr]]}
      when is_atom(name) and is_atom(ctx) ->
        {key_expr, value_expr, bucket_var, :append}

      [{:|, _, [value_expr, {name, _, ctx} = bucket_var]}]
      when is_atom(name) and is_atom(ctx) ->
        {key_expr, value_expr, bucket_var, :prepend}

      _ ->
        nil
    end
  end

  defp map_put_list_update(_, _), do: nil

  defp find_get_step?(bucket_var, acc_var, key_expr, steps, put_idx) do
    Enum.any?(Enum.take(steps, put_idx), fn
      {:=, _, [lhs, {{:., _, [{:__aliases__, _, [:Map]}, :get]}, _, [acc, key, []]}]} ->
        lhs == bucket_var and acc == acc_var and key == key_expr

      _ ->
        false
    end)
  end

  defp valid_group_by_break?(break_expr, acc_var, :append), do: break_expr == acc_var

  defp valid_group_by_break?(break_expr, acc_var, :prepend),
    do: map_reverse_all_buckets?(break_expr, acc_var)

  defp map_reverse_all_buckets?(
         {{:., _, [{:__aliases__, _, [:Map]}, :new]}, _,
          [acc, {:fn, _, [{:->, _, [[{k_var, v_var}], {same_k, reverse_call}]}]}]},
         acc_var
       )
       when acc == acc_var and same_k == k_var do
    case reverse_call do
      {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [same_v]} -> same_v == v_var
      _ -> false
    end
  end

  defp map_reverse_all_buckets?(_, _), do: false

  # P025 — Map.put_new first-write-wins
  # Recognises:
  #   acc = Map.put_new(acc, key_expr, val_expr)   (last step)
  #   break with acc
  # Emits Enum.reduce(list, %{}, fn elem, acc -> Map.put_new(acc, key, val) end).
  def map_put_new_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{acc_name, {:%{}, _, []}}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         acc_var = {acc_name, [], nil},
         true <- break_expr == acc_var,
         {put_idx, key_expr, val_expr} <- map_put_new_step(steps, acc_var),
         true <- put_idx == length(steps) - 1,
         aliases <- elem_aliases(steps, elem_var),
         resolved_key <- resolve_expr(key_expr, assignments_before(steps, put_idx)),
         resolved_val <- resolve_expr(val_expr, assignments_before(steps, put_idx)),
         assigned_non_alias <- assigned_non_alias_vars(steps, aliases, [acc_var]),
         true <- has_any_var?(resolved_key, aliases, has_var),
         false <- has_var.(resolved_key, acc_var),
         false <- has_var.(resolved_key, list_var),
         false <- has_any_var?(resolved_key, assigned_non_alias, has_var),
         false <- has_var.(resolved_val, acc_var),
         false <- has_var.(resolved_val, list_var),
         false <- has_any_var?(resolved_val, assigned_non_alias, has_var) do
      quote do
        Enum.reduce(unquote(list_var), %{}, fn unquote(elem_var), unquote(acc_var) ->
          Map.put_new(unquote(acc_var), unquote(resolved_key), unquote(resolved_val))
        end)
      end
    else
      _ -> nil
    end
  end

  defp map_put_new_step(steps, acc_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, {{:., _, [{:__aliases__, _, [:Map]}, :put_new]}, _, [acc, key, val]}]},
         idx}
        when lhs == acc_var and acc == acc_var ->
          [{idx, key, val}]

        _ ->
          []
      end)

    case updates do
      [{idx, key, val}] -> {idx, key, val}
      _ -> nil
    end
  end

  # P064 — Enum.into for Map via Map.put
  # Loop: acc: %{}, Map.put(acc, key_expr(h), val_expr(h)), break(acc)
  # Emits: Map.new(list, fn h -> {key_expr(h), val_expr(h)} end)
  def map_into_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{acc_name, {:%{}, _, []}}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         acc_var = {acc_name, [], nil},
         true <- break_expr == acc_var,
         {put_idx, key_expr, val_expr} <- map_put_step(steps, acc_var),
         true <- put_idx == length(steps) - 1,
         aliases <- elem_aliases(steps, elem_var),
         resolved_key <- resolve_expr(key_expr, assignments_before(steps, put_idx)),
         resolved_val <- resolve_expr(val_expr, assignments_before(steps, put_idx)),
         assigned_non_alias <- assigned_non_alias_vars(steps, aliases, [acc_var]),
         true <- has_any_var?(resolved_key, aliases, has_var),
         false <- has_var.(resolved_key, acc_var),
         false <- has_var.(resolved_key, list_var),
         false <- has_any_var?(resolved_key, assigned_non_alias, has_var),
         false <- has_var.(resolved_val, acc_var),
         false <- has_var.(resolved_val, list_var),
         false <- has_any_var?(resolved_val, assigned_non_alias, has_var) do
      quote do
        Map.new(unquote(list_var), fn unquote(elem_var) ->
          {unquote(resolved_key), unquote(resolved_val)}
        end)
      end
    else
      _ -> nil
    end
  end

  # P067 — Map.update/4 with arbitrary resolver
  # Recognises: acc = Map.update(acc, key_expr, default_expr, fn existing -> resolver_expr end)
  # Emits: Enum.reduce(list, %{}, fn h, acc -> Map.update(acc, key, default, fn existing -> resolver end) end)
  def map_update_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with [{acc_name, {:%{}, _, []}}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         acc_var = {acc_name, [], nil},
         true <- break_expr == acc_var,
         {update_idx, key_expr, default_expr, resolver_fn} <- map_update_step(steps, acc_var),
         true <- update_idx == length(steps) - 1,
         aliases <- elem_aliases(steps, elem_var),
         resolved_key <- resolve_expr(key_expr, assignments_before(steps, update_idx)),
         resolved_default <- resolve_expr(default_expr, assignments_before(steps, update_idx)),
         assigned_non_alias <- assigned_non_alias_vars(steps, aliases, [acc_var]),
         true <- has_any_var?(resolved_key, aliases, has_var),
         false <- has_var.(resolved_key, acc_var),
         false <- has_var.(resolved_key, list_var),
         false <- has_any_var?(resolved_key, assigned_non_alias, has_var),
         false <- has_var.(resolved_default, acc_var),
         false <- has_var.(resolved_default, list_var),
         false <- has_any_var?(resolved_default, assigned_non_alias, has_var),
         true <-
           map_update_resolver_ok?(
             resolver_fn,
             aliases,
             assigned_non_alias,
             acc_var,
             list_var,
             has_var
           ) do
      quote do
        Enum.reduce(unquote(list_var), %{}, fn unquote(elem_var), unquote(acc_var) ->
          Map.update(
            unquote(acc_var),
            unquote(resolved_key),
            unquote(resolved_default),
            unquote(resolver_fn)
          )
        end)
      end
    else
      _ -> nil
    end
  end

  # P068 — Map.merge accumulation
  # Recognises: acc = Map.merge(acc, h) or acc = Map.merge(acc, h, fn k, v1, v2 -> resolver end)
  # Emits: Enum.reduce(list, %{}, &Map.merge(&2, &1)) or with resolver
  def map_merge_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)

    with [{acc_name, {:%{}, _, []}}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         acc_var = {acc_name, [], nil},
         true <- break_expr == acc_var,
         {merge_idx, merge_info} <- map_merge_step(steps, acc_var),
         true <- merge_idx == length(steps) - 1 do
      case merge_info do
        # Simple two-argument merge: Map.merge(acc, elem)
        {:simple, elem_arg} when elem_arg == elem_var ->
          quote do
            Enum.reduce(unquote(list_var), %{}, &Map.merge(&2, &1))
          end

        # Three-argument merge with resolver
        {:with_resolver, elem_arg, resolver_fn} when elem_arg == elem_var ->
          quote do
            Enum.reduce(unquote(list_var), %{}, fn unquote(elem_var), unquote(acc_var) ->
              Map.merge(unquote(acc_var), unquote(elem_var), unquote(resolver_fn))
            end)
          end

        _ ->
          nil
      end
    else
      _ -> nil
    end
  end

  # P064 helper: extract Map.put step (not put_new, just put)
  defp map_put_step(steps, acc_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, {{:., _, [{:__aliases__, _, [:Map]}, :put]}, _, [acc, key, val]}]}, idx}
        when lhs == acc_var and acc == acc_var ->
          [{idx, key, val}]

        _ ->
          []
      end)

    case updates do
      [{idx, key, val}] -> {idx, key, val}
      _ -> nil
    end
  end

  # P067 helper: extract Map.update/4 step
  defp map_update_step(steps, acc_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _,
          [lhs, {{:., _, [{:__aliases__, _, [:Map]}, :update]}, _, [acc, key, default, resolver]}]},
         idx}
        when lhs == acc_var and acc == acc_var ->
          [{idx, key, default, resolver}]

        _ ->
          []
      end)

    case updates do
      [{idx, key, default, resolver}] -> {idx, key, default, resolver}
      _ -> nil
    end
  end

  # P067 helper: validate resolver function doesn't reference forbidden variables
  # Resolver can be:
  #   - fn existing -> resolver_expr end
  #   - &(&1 + 5) (capture form)
  # resolver_expr should only reference existing and variables in aliases (from destructuring)
  defp map_update_resolver_ok?(
         resolver_fn,
         _aliases,
         assigned_non_alias,
         acc_var,
         list_var,
         has_var
       ) do
    case resolver_fn do
      {:fn, _, [{:->, _, [[_existing_param], body]}]} ->
        # body should reference aliases and existing, but not acc, list, or assigned_non_alias vars
        not has_var.(body, acc_var) and
          not has_var.(body, list_var) and
          not has_any_var?(body, assigned_non_alias, has_var)

      {:&, _, [_capture_expr]} ->
        # For capture forms like &(&1 + 5), the validator always passes
        # The capture expr contains &1 which refers to the existing value
        true

      _ ->
        false
    end
  end

  # P068 helper: extract Map.merge step (2-arg or 3-arg with resolver)
  defp map_merge_step(steps, acc_var) do
    merges =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, {{:., _, [{:__aliases__, _, [:Map]}, :merge]}, _, [acc, elem]}]}, idx}
        when lhs == acc_var and acc == acc_var ->
          [{idx, {:simple, elem}}]

        {{:=, _, [lhs, {{:., _, [{:__aliases__, _, [:Map]}, :merge]}, _, [acc, elem, resolver]}]},
         idx}
        when lhs == acc_var and acc == acc_var ->
          [{idx, {:with_resolver, elem, resolver}}]

        _ ->
          []
      end)

    case merges do
      [{idx, info}] -> {idx, info}
      _ -> nil
    end
  end

  def uniq_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)
    vars_equal = callback(callbacks, :vars_equal)

    with {acc_var, seen_var} <- uniq_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         extracted_var when not is_nil(extracted_var) <- enum_reverse_arg.(break_expr),
         extracted_var_normalized <- normalize_var(extracted_var),
         true <- vars_equal.(extracted_var_normalized, acc_var),
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
    vars_equal = callback(callbacks, :vars_equal)

    with {acc_var, seen_var} <- uniq_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         extracted_var when not is_nil(extracted_var) <- enum_reverse_arg.(break_expr),
         extracted_var_normalized <- normalize_var(extracted_var),
         true <- vars_equal.(extracted_var_normalized, acc_var),
         key_expr when not is_nil(key_expr) <-
           uniq_by_key_expr(steps, elem_var, acc_var, seen_var, has_var) do
      quote do
        Enum.uniq_by(unquote(list_var), fn unquote(elem_var) -> unquote(key_expr) end)
      end
    else
      _ -> nil
    end
  end

  # P018 — Enum.dedup_by/2: remove consecutive elements sharing the same key
  def dedup_by_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, prev_key_var} <- uniq_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         key_expr when not is_nil(key_expr) <-
           dedup_by_key_expr(steps, elem_var, acc_var, prev_key_var, has_var) do
      quote do
        Enum.dedup_by(unquote(list_var), fn unquote(elem_var) -> unquote(key_expr) end)
      end
    else
      _ -> nil
    end
  end

  defp dedup_by_key_expr(steps, elem_var, acc_var, prev_key_var, has_var) do
    aliases = elem_aliases(steps, elem_var)

    Enum.find_value(Enum.with_index(steps), fn
      {{:=, _, [acc, if_expr]}, idx} when acc == acc_var ->
        with {:ok, raw_key_expr, kept} <- dedup_by_acc_if(if_expr, acc_var, prev_key_var),
             true <- kept in aliases do
          dedup_key_if_valid(raw_key_expr, aliases, has_var, steps, idx, prev_key_var)
        else
          _ -> nil
        end

      _ ->
        nil
    end)
  end

  defp dedup_key_if_valid(raw_key_expr, aliases, has_var, steps, idx, prev_key_var) do
    resolved_key = resolve_expr(raw_key_expr, assignments_before(steps, idx))

    if has_any_var?(resolved_key, aliases, has_var) and
         dedup_prev_key_updated?(steps, idx, prev_key_var, raw_key_expr) do
      resolved_key
    end
  end

  defp dedup_by_acc_if(
         {:if, _, [condition, [do: acc, else: [{:|, _, [kept, acc]}]]]},
         acc_var,
         prev_key_var
       )
       when acc == acc_var do
    case dedup_equality_key(condition, prev_key_var) do
      {:ok, key_expr} -> {:ok, key_expr, kept}
      _ -> nil
    end
  end

  defp dedup_by_acc_if(_, _, _), do: nil

  defp dedup_equality_key({:==, _, [key_expr, prev]}, prev_key_var) when prev == prev_key_var,
    do: {:ok, key_expr}

  defp dedup_equality_key({:==, _, [prev, key_expr]}, prev_key_var) when prev == prev_key_var,
    do: {:ok, key_expr}

  defp dedup_equality_key(_, _), do: nil

  defp dedup_prev_key_updated?(steps, idx, prev_key_var, raw_key_expr) do
    Enum.any?(Enum.drop(steps, idx + 1), fn
      {:=, _, [prev_key, expr]} when prev_key == prev_key_var -> expr == raw_key_expr
      _ -> false
    end)
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
    do: match?({^seen_var, _}, seen_put_call(put_expr))

  defp seen_set_put_step?(_, _), do: false

  defp uniq_acc_if(
         {:if, _, [condition, [do: acc, else: [{:|, _, [value_expr, acc]}]]]},
         acc_var,
         seen_var
       ) do
    with ^acc_var <- acc,
         {^seen_var, key_expr} <- seen_member_call(condition) do
      {key_expr, value_expr}
    else
      _ -> nil
    end
  end

  defp uniq_acc_if(
         {:if, _, [condition, [do: [{:|, _, [value_expr, acc]}], else: acc]]},
         acc_var,
         seen_var
       ) do
    with ^acc_var <- acc,
         {member_condition, _, [inner]} <- condition,
         true <- member_condition in [:not, :!],
         {^seen_var, key_expr} <- seen_member_call(inner) do
      {key_expr, value_expr}
    else
      _ -> nil
    end
  end

  defp uniq_acc_if(_, _, _), do: nil

  def chunk_every_pattern(initials, body, callbacks) do
    empty_list_check = callback(callbacks, :empty_list_check)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)
    has_var = callback(callbacks, :has_var)

    with [{acc_name, []}] <- initials,
         {:__block__, _, exprs} <- body,
         acc_var = {acc_name, [], nil},
         {list_var, chunk_size, step_size, mode} <-
           chunk_every_shape(exprs, acc_var, empty_list_check, enum_reverse_arg),
         true <- leftover_loop_invariant?(mode, list_var, acc_var, has_var) do
      chunk_every_quote(list_var, chunk_size, step_size, mode)
    else
      _ -> nil
    end
  end

  defp leftover_loop_invariant?({:leftover, leftover}, list_var, acc_var, has_var) do
    not has_var.(leftover, list_var) and not has_var.(leftover, acc_var)
  end

  defp leftover_loop_invariant?(_, _, _, _), do: true

  defp chunk_every_shape([exit_expr, step2, step3], acc_var, empty_list_check, enum_reverse_arg) do
    chunk_every_take_drop_shape(
      exit_expr,
      step2,
      step3,
      acc_var,
      empty_list_check,
      enum_reverse_arg
    ) ||
      chunk_every_take_drop_separate_shape(
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

  defp chunk_every_shape(
         [exit_expr, step2, step3, step4],
         acc_var,
         empty_list_check,
         enum_reverse_arg
       ) do
    chunk_every_split_drop_shape(
      exit_expr,
      step2,
      step3,
      step4,
      acc_var,
      empty_list_check,
      enum_reverse_arg
    ) ||
      chunk_every_split_pad_shape(
        exit_expr,
        step2,
        step3,
        step4,
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

  # Handle the case where take/drop are separate steps (before alias inlining)
  # Step 1: list = Enum.drop(list, step_size)
  # Step 2: acc = [Enum.take(list, size) | acc] OR acc = [chunk_var | acc]
  defp chunk_every_take_drop_separate_shape(
         exit_expr,
         advance,
         chunk_update,
         acc_var,
         empty_list_check,
         enum_reverse_arg
       ) do
    with {condition, break_expr} <- chunk_exit_clause(exit_expr),
         ^acc_var <- enum_reverse_arg.(break_expr),
         {^acc_var, chunk_expr} <- cons_update(chunk_update),
         {list_var, chunk_size, step_size} <-
           chunk_every_separate_take_drop(advance, chunk_expr),
         mode when not is_nil(mode) <-
           chunk_exit_mode(condition, list_var, chunk_size, empty_list_check) do
      {list_var, chunk_size, step_size, mode}
    else
      _ -> nil
    end
  end

  # Extract take/drop info from separate steps
  # advance: list = Enum.drop(list, step_size)
  # chunk_expr: Enum.take(list, size) OR a variable
  defp chunk_every_separate_take_drop(advance, chunk_expr) do
    with {list_var, step_size} <- enum_drop_call(advance),
         {^list_var, chunk_size} <- enum_take_call(chunk_expr) do
      {list_var, chunk_size, step_size}
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

  # P035: {chunk, _} = Enum.split(list, size) + [chunk | acc] + list = Enum.drop(list, step)
  defp chunk_every_split_drop_shape(
         exit_expr,
         split_step,
         chunk_update,
         advance,
         acc_var,
         empty_list_check,
         enum_reverse_arg
       ) do
    with {condition, break_expr} <- chunk_exit_clause(exit_expr),
         ^acc_var <- enum_reverse_arg.(break_expr),
         {chunk_var, list_var, chunk_size} <- enum_split_wildcard_step(split_step),
         {^acc_var, ^chunk_var} <- cons_update(chunk_update),
         {^list_var, step_size} <- enum_drop_call(advance),
         mode when not is_nil(mode) <-
           chunk_exit_mode(condition, list_var, chunk_size, empty_list_check) do
      {list_var, chunk_size, step_size, mode}
    else
      _ -> nil
    end
  end

  # P036: {chunk, rest} = Enum.split(list, size) + [Enum.take(chunk ++ pad, size) | acc] + list = rest
  defp chunk_every_split_pad_shape(
         exit_expr,
         split_step,
         pad_update,
         rest_advance,
         acc_var,
         empty_list_check,
         enum_reverse_arg
       ) do
    with {condition, break_expr} <- chunk_exit_clause(exit_expr),
         ^acc_var <- enum_reverse_arg.(break_expr),
         {chunk_var, rest_var, list_var, chunk_size} <- enum_split_full_step(split_step),
         {^acc_var, leftover} <- cons_pad_update(pad_update, chunk_var, chunk_size),
         {:=, _, [^list_var, ^rest_var]} <- rest_advance,
         :normal <- chunk_exit_mode(condition, list_var, chunk_size, empty_list_check) do
      {list_var, chunk_size, chunk_size, {:leftover, leftover}}
    else
      _ -> nil
    end
  end

  defp cons_pad_update({:=, _, [acc, [{:|, _, [pad_expr, acc]}]]}, chunk_var, chunk_size) do
    case pad_expr do
      {{:., _, [{:__aliases__, _, [:Enum]}, :take]}, _,
       [{:++, _, [^chunk_var, leftover]}, ^chunk_size]} ->
        {acc, leftover}

      _ ->
        nil
    end
  end

  defp cons_pad_update(_, _, _), do: nil

  defp chunk_every_quote(list_var, chunk_size, step_size, {:leftover, leftover}) do
    quote do
      Enum.chunk_every(
        unquote(list_var),
        unquote(chunk_size),
        unquote(step_size),
        unquote(leftover)
      )
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

  defp cons_update({:=, _, [acc, [{:|, _, [value, acc]}]]}), do: {acc, value}
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

  defp enum_split_step({:=, _, [{chunk_var, list_target}, split_expr]}) do
    with {list_source, size} <- enum_split_expr(split_expr),
         true <- list_target == list_source do
      {chunk_var, list_source, size}
    else
      _ -> nil
    end
  end

  defp enum_split_step({:=, _, [{:{}, _, [chunk_var, list_target]}, split_expr]}) do
    with {list_source, size} <- enum_split_expr(split_expr),
         true <- list_target == list_source do
      {chunk_var, list_source, size}
    else
      _ -> nil
    end
  end

  defp enum_split_step(_), do: nil

  defp enum_split_wildcard_step({:=, _, [{chunk_var, {:_, _, _}}, split_expr]}) do
    case enum_split_expr(split_expr) do
      {list_source, size} -> {chunk_var, list_source, size}
      _ -> nil
    end
  end

  defp enum_split_wildcard_step(_), do: nil

  defp enum_split_full_step({:=, _, [{chunk_var, rest_var}, split_expr]}) do
    case enum_split_expr(split_expr) do
      {list_source, size} when rest_var != list_source -> {chunk_var, rest_var, list_source, size}
      _ -> nil
    end
  end

  defp enum_split_full_step(_), do: nil

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

  # P020 — Map.has_key?/Map.put variants for seen-set membership
  defp map_has_key_call({{:., _, [{:__aliases__, _, [:Map]}, :has_key?]}, _, [seen, key]}),
    do: {seen, key}

  defp map_has_key_call(_), do: nil

  defp map_put_call({{:., _, [{:__aliases__, _, [:Map]}, :put]}, _, [seen, key, _value]}),
    do: {seen, key}

  defp map_put_call(_), do: nil

  defp seen_member_call(expr), do: mapset_member_call(expr) || map_has_key_call(expr)

  defp seen_put_call(expr), do: mapset_put_call(expr) || map_put_call(expr)

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

  defp normalize_var({name, _meta, _ctx}) when is_atom(name), do: {name, [], nil}
  defp normalize_var(other), do: other

  # P075 — Index-aware map: loop with index counter, emit Enum.with_index() |> Enum.map()
  def index_aware_map_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, idx_var} <- index_aware_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         {update_idx, transform_expr} <-
           index_aware_map_update(steps, acc_var),
         true <- index_aware_index_updates_valid?(steps, idx_var),
         resolved_transform <- resolve_expr(transform_expr, assignments_before(steps, update_idx)),
         true <- has_var.(resolved_transform, elem_var),
         true <- has_var.(resolved_transform, idx_var),
         false <- has_var.(resolved_transform, acc_var),
         false <- has_var.(resolved_transform, list_var) do
      quote do
        unquote(list_var)
        |> Enum.with_index()
        |> Enum.map(fn {unquote(elem_var), unquote(idx_var)} -> unquote(resolved_transform) end)
      end
    else
      _ -> nil
    end
  end

  defp index_aware_map_update(steps, acc_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, rhs]}, idx} when lhs == acc_var ->
          case index_aware_cons_transform(rhs, acc_var) do
            nil -> []
            transform_expr -> [{idx, transform_expr}]
          end

        _ ->
          []
      end)

    case updates do
      [{idx, transform_expr}] -> {idx, transform_expr}
      _ -> nil
    end
  end

  defp index_aware_cons_transform([{:|, _, [transform_expr, acc]}], acc) do
    transform_expr
  end

  defp index_aware_cons_transform(_, _), do: nil

  # P076 — Index-aware filter: loop with index counter, emit Enum.with_index() |> Enum.filter()
  def index_aware_filter_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, idx_var} <- index_aware_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         {update_idx, condition} <-
           index_aware_filter_update(steps, acc_var),
         true <- index_aware_index_updates_valid?(steps, idx_var),
         resolved_condition <- resolve_expr(condition, assignments_before(steps, update_idx)),
         true <- has_var.(resolved_condition, elem_var),
         true <- has_var.(resolved_condition, idx_var),
         false <- has_var.(resolved_condition, acc_var),
         false <- has_var.(resolved_condition, list_var) do
      quote do
        unquote(list_var)
        |> Enum.with_index()
        |> Enum.filter(fn {unquote(elem_var), unquote(idx_var)} ->
          unquote(resolved_condition)
        end)
        |> Enum.map(fn {unquote(elem_var), _} -> unquote(elem_var) end)
      end
    else
      _ -> nil
    end
  end

  defp index_aware_filter_update(steps, acc_var) do
    updates =
      Enum.flat_map(Enum.with_index(steps), fn
        {{:=, _, [lhs, {:if, _, [condition, [do: [{:|, _, [_elem, acc]}], else: acc]]}]}, idx}
        when lhs == acc_var and acc == acc_var ->
          [{idx, condition}]

        _ ->
          []
      end)

    case updates do
      [{idx, condition}] -> {idx, condition}
      _ -> nil
    end
  end

  # P077 — Index-aware each: loop with index counter, emit Enum.with_index() |> Enum.each()
  def index_aware_each_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with {[], idx_var} <- index_aware_each_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: :ok, steps: steps} <-
           list_loop_ir.(body),
         true <- index_aware_index_updates_valid?(steps, idx_var),
         true <- steps != [],
         {side_effects, _remaining} =
           Enum.split(steps, length(steps) - 1),
         [_ | _] <- side_effects,
         true <- Enum.all?(side_effects, &uses_elem_and_index?(&1, elem_var, idx_var, has_var)) do
      side_effect_body =
        case side_effects do
          [single] -> single
          multiple -> {:__block__, [], multiple}
        end

      quote do
        unquote(list_var)
        |> Enum.with_index()
        |> Enum.each(fn {unquote(elem_var), unquote(idx_var)} -> unquote(side_effect_body) end)
      end
    else
      _ -> nil
    end
  end

  defp uses_elem_and_index?(step, elem_var, idx_var, has_var) do
    has_var.(step, elem_var) and has_var.(step, idx_var)
  end

  defp index_aware_vars([{acc_name, []}, {idx_name, 0}]) do
    {{acc_name, [], nil}, {idx_name, [], nil}}
  end

  defp index_aware_vars([{idx_name, 0}, {acc_name, []}]) do
    {{acc_name, [], nil}, {idx_name, [], nil}}
  end

  defp index_aware_vars(_), do: nil

  defp index_aware_each_vars([{idx_name, 0}]) do
    {[], {idx_name, [], nil}}
  end

  defp index_aware_each_vars(_), do: nil

  defp index_aware_index_updates_valid?(steps, idx_var) do
    Enum.any?(steps, fn step -> valid_index_increment?(step, idx_var) end)
  end

  # P071 — Enum.zip/2: adjacent pairs from sliding window
  def adjacent_pairs_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, prev_var, loop_list_var, original_list_var} <-
           adjacent_pairs_initials(initials),
         %{list_var: ^loop_list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         true <- adjacent_pairs_accumulate?(steps, elem_var, acc_var, prev_var),
         true <- adjacent_pairs_update_prev?(steps, elem_var, prev_var) do
      quote do
        Enum.zip(unquote(original_list_var), Enum.drop(unquote(original_list_var), 1))
      end
    else
      _ -> nil
    end
  end

  defp adjacent_pairs_initials([
         {acc_name, []},
         {prev_name, {:hd, _, [list_expr]}},
         {list_name, {:tl, _, [tl_arg]}}
       ]) do
    # Verify that hd and tl operate on the same list
    list_normalized = normalize_adjacent_var(list_expr)
    tl_arg_normalized = normalize_adjacent_var(tl_arg)

    if list_normalized == tl_arg_normalized do
      {
        {acc_name, [], nil},
        {prev_name, [], nil},
        {list_name, [], nil},
        list_normalized
      }
    end
  end

  defp adjacent_pairs_initials([
         {acc_name, []},
         {list_name, {:tl, _, [tl_arg]}},
         {prev_name, {:hd, _, [list_expr]}}
       ]) do
    # Same but with reordered initials
    list_normalized = normalize_adjacent_var(list_expr)
    tl_arg_normalized = normalize_adjacent_var(tl_arg)

    if list_normalized == tl_arg_normalized do
      {
        {acc_name, [], nil},
        {prev_name, [], nil},
        {list_name, [], nil},
        list_normalized
      }
    end
  end

  defp adjacent_pairs_initials([
         {prev_name, {:hd, _, [list_expr]}},
         {acc_name, []},
         {list_name, {:tl, _, [tl_arg]}}
       ]) do
    # Another permutation
    list_normalized = normalize_adjacent_var(list_expr)
    tl_arg_normalized = normalize_adjacent_var(tl_arg)

    if list_normalized == tl_arg_normalized do
      {
        {acc_name, [], nil},
        {prev_name, [], nil},
        {list_name, [], nil},
        list_normalized
      }
    end
  end

  defp adjacent_pairs_initials([
         {prev_name, {:hd, _, [list_expr]}},
         {list_name, {:tl, _, [tl_arg]}},
         {acc_name, []}
       ]) do
    # Another permutation
    list_normalized = normalize_adjacent_var(list_expr)
    tl_arg_normalized = normalize_adjacent_var(tl_arg)

    if list_normalized == tl_arg_normalized do
      {
        {acc_name, [], nil},
        {prev_name, [], nil},
        {list_name, [], nil},
        list_normalized
      }
    end
  end

  defp adjacent_pairs_initials([
         {list_name, {:tl, _, [tl_arg]}},
         {acc_name, []},
         {prev_name, {:hd, _, [list_expr]}}
       ]) do
    # Another permutation
    list_normalized = normalize_adjacent_var(list_expr)
    tl_arg_normalized = normalize_adjacent_var(tl_arg)

    if list_normalized == tl_arg_normalized do
      {
        {acc_name, [], nil},
        {prev_name, [], nil},
        {list_name, [], nil},
        list_normalized
      }
    end
  end

  defp adjacent_pairs_initials([
         {list_name, {:tl, _, [tl_arg]}},
         {prev_name, {:hd, _, [list_expr]}},
         {acc_name, []}
       ]) do
    # Another permutation
    list_normalized = normalize_adjacent_var(list_expr)
    tl_arg_normalized = normalize_adjacent_var(tl_arg)

    if list_normalized == tl_arg_normalized do
      {
        {acc_name, [], nil},
        {prev_name, [], nil},
        {list_name, [], nil},
        list_normalized
      }
    end
  end

  defp adjacent_pairs_initials(_), do: nil

  # Check if acc = [{prev, h} | acc]
  defp adjacent_pairs_accumulate?(steps, elem_var, acc_var, prev_var) do
    Enum.any?(steps, fn
      {:=, _, [acc, [{:|, _, [{prev, elem}, acc_check]}]]} ->
        acc == acc_var and elem == elem_var and prev == prev_var and acc_check == acc_var

      _ ->
        false
    end)
  end

  # Check if prev = h
  defp adjacent_pairs_update_prev?(steps, elem_var, prev_var) do
    Enum.any?(steps, fn
      {:=, _, [prev, elem]} -> prev == prev_var and elem == elem_var
      _ -> false
    end)
  end

  # P073 — Enum.zip_with/3: adjacent pairs with transform
  def adjacent_pairs_map_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, prev_var, loop_list_var, original_list_var} <-
           adjacent_pairs_initials(initials),
         %{list_var: ^loop_list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         ^acc_var <- enum_reverse_arg.(break_expr),
         transform when not is_nil(transform) <-
           adjacent_pairs_map_transform(steps, elem_var, acc_var, prev_var, has_var) do
      quote do
        Enum.zip_with(
          unquote(original_list_var),
          Enum.drop(unquote(original_list_var), 1),
          fn unquote(prev_var), unquote(elem_var) ->
            unquote(transform)
          end
        )
      end
    else
      _ -> nil
    end
  end

  defp adjacent_pairs_map_transform(steps, elem_var, acc_var, prev_var, has_var) do
    Enum.find_value(steps, fn
      {:=, _, [acc, [{:|, _, [transform_expr, acc_check]}]]}
      when acc == acc_var and acc_check == acc_var ->
        # Check that transform uses both prev and elem
        if has_var.(transform_expr, prev_var) and has_var.(transform_expr, elem_var) do
          transform_expr
        else
          nil
        end

      _ ->
        nil
    end)
  end

  defp normalize_adjacent_var({name, _meta, _ctx}) when is_atom(name), do: {name, [], nil}
  defp normalize_adjacent_var(other), do: other

  # P063 — Enum.slice (range extraction)
  # Recognizes a loop that:
  #   - iterates with index i starting at 0
  #   - exits when list is empty OR i >= stop (exclusive stop)
  #   - conditionally accumulates when i >= start (inclusive start)
  #   - breaks with Enum.reverse(acc)
  # Emits: Enum.slice(list, start..(stop-1)//1)
  def slice_pattern(initials, body, callbacks) do
    map_destructure = callback(callbacks, :map_destructure)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {acc_var, idx_var} <- slice_vars(initials),
         {:__block__, _, [exit_expr, destructure, acc_update, idx_update]} <- body,
         {list_var, stop_expr} <-
           slice_exit_condition(exit_expr, acc_var, idx_var, enum_reverse_arg),
         {^list_var, elem_var} <- map_destructure.(destructure),
         start_expr when not is_nil(start_expr) <-
           slice_start_condition(acc_update, acc_var, elem_var, idx_var),
         true <- valid_index_increment?(idx_update, idx_var) do
      # stop_expr is exclusive (loop exits when i >= stop_expr)
      # inclusive end = stop_expr - 1
      # Emit Enum.slice(list, start..(stop-1)//1) with explicit step to avoid
      # descending-range warnings when stop <= start at runtime
      inclusive_stop = {:-, [], [stop_expr, 1]}
      range_ast = {:..//, [], [start_expr, inclusive_stop, 1]}

      quote do
        Enum.slice(unquote(list_var), unquote(range_ast))
      end
    else
      _ -> nil
    end
  end

  # Initials must be [acc: [], i: 0] or [i: 0, acc: []] (either order)
  defp slice_vars([{acc_name, []}, {idx_name, 0}]),
    do: {{acc_name, [], nil}, {idx_name, [], nil}}

  defp slice_vars([{idx_name, 0}, {acc_name, []}]),
    do: {{acc_name, [], nil}, {idx_name, [], nil}}

  defp slice_vars(_), do: nil

  # Exit: if (list == []) or (i >= stop), do: break(Enum.reverse(acc))
  # After P047 normalize: i >= stop becomes stop <= i (i.e. {:<=, [], [stop, i]})
  # The OR can have either operand order
  defp slice_exit_condition(
         {:if, _, [{op, _, [c1, c2]}, [do: {:break, _, [break_expr]}]]},
         acc_var,
         idx_var,
         enum_reverse_arg
       )
       when op in [:or, :||] do
    case enum_reverse_arg.(break_expr) do
      ^acc_var ->
        cond do
          # empty_list_check on c1, count-limit check on c2
          match?({:==, _, [_, []]}, c1) or match?({:==, _, [[], _]}, c1) ->
            list_var = slice_empty_list_var(c1)
            stop_expr = slice_limit_var(c2, idx_var)
            if list_var != nil and stop_expr != nil, do: {list_var, stop_expr}

          match?({:==, _, [_, []]}, c2) or match?({:==, _, [[], _]}, c2) ->
            list_var = slice_empty_list_var(c2)
            stop_expr = slice_limit_var(c1, idx_var)
            if list_var != nil and stop_expr != nil, do: {list_var, stop_expr}

          true ->
            nil
        end

      _ ->
        nil
    end
  end

  defp slice_exit_condition(_, _, _, _), do: nil

  # Extract list var from `list == []` or `[] == list`
  defp slice_empty_list_var({:==, _, [list, []]}), do: list
  defp slice_empty_list_var({:==, _, [[], list]}), do: list
  defp slice_empty_list_var(_), do: nil

  # Extract stop_expr from `stop <= i` (after normalize: i >= stop → stop <= i)
  # Also handle `stop < i` (i.e. i > stop → strictly greater) meaning stop is inclusive
  defp slice_limit_var({:<=, _, [stop, idx]}, idx_var) when idx == idx_var, do: stop
  defp slice_limit_var(_, _), do: nil

  # Detect the acc update step:
  #   - `acc = if start <= i, do: [h | acc], else: acc`  → returns start_expr
  #   - `acc = [h | acc]` (unconditional, i.e. start = 0) → returns 0
  defp slice_start_condition(
         {:=, _,
          [
            acc,
            {:if, _, [{:<=, _, [start, idx]}, [do: [{:|, _, [elem, acc_inner]}], else: acc_else]]}
          ]},
         acc_var,
         elem_var,
         idx_var
       )
       when acc == acc_var and acc_inner == acc_var and acc_else == acc_var and elem == elem_var and
              idx == idx_var do
    start
  end

  defp slice_start_condition(
         {:=, _, [acc, [{:|, _, [elem, acc_inner]}]]},
         acc_var,
         elem_var,
         _idx_var
       )
       when acc == acc_var and acc_inner == acc_var and elem == elem_var do
    0
  end

  defp slice_start_condition(_, _, _, _), do: nil

  # P062 — Dual-list split pattern (count-up variant)
  # Recognizes: prefix: [], suffix: list, count: 0 with count >= n exit
  # Emits: Enum.split(list, n), Enum.take(list, n), or Enum.drop(list, n)
  def split_count_up_pattern(initials, body, callbacks) do
    map_destructure = callback(callbacks, :map_destructure)
    list_prepend = callback(callbacks, :list_prepend)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {prefix_name, suffix_name, count_name, list_expr} <-
           split_count_up_initials(initials),
         {:__block__, _, [exit, destructure, accumulate, increment]} <- body,
         prefix_var = {prefix_name, [], nil},
         suffix_var = {suffix_name, [], nil},
         count_var = {count_name, [], nil},
         {limit_expr, break_kind} <-
           split_count_up_exit(exit, prefix_var, suffix_var, count_var, enum_reverse_arg),
         {^suffix_var, elem_var} <- map_destructure.(destructure),
         true <- list_prepend.(accumulate, prefix_var, elem_var),
         true <- split_count_up_increment(increment, count_var) do
      case break_kind do
        :split ->
          quote do
            Enum.split(unquote(list_expr), unquote(limit_expr))
          end

        :take ->
          quote do
            Enum.take(unquote(list_expr), unquote(limit_expr))
          end

        :drop ->
          quote do
            Enum.drop(unquote(list_expr), unquote(limit_expr))
          end
      end
    else
      _ -> nil
    end
  end

  # Match 3 initials: one with [] (prefix), one with list expr (suffix), one with 0 (count)
  defp split_count_up_initials(initials) when is_list(initials) and length(initials) == 3 do
    prefix = Enum.find(initials, fn {_name, val} -> val == [] end)
    count = Enum.find(initials, fn {_name, val} -> val == 0 end)

    suffix =
      Enum.find(initials, fn {name, val} ->
        val != [] and val != 0 and
          (prefix == nil or name != elem(prefix, 0)) and
          (count == nil or name != elem(count, 0))
      end)

    case {prefix, suffix, count} do
      {{prefix_name, []}, {suffix_name, list_expr}, {count_name, 0}} ->
        {prefix_name, suffix_name, count_name, list_expr}

      _ ->
        nil
    end
  end

  defp split_count_up_initials(_), do: nil

  # Exit: if n <= count, do: break({Enum.reverse(prefix), suffix})  — split form
  # Exit: if n <= count, do: break(Enum.reverse(prefix))            — take form
  # Exit: if n <= count, do: break(suffix)                          — drop form
  defp split_count_up_exit(
         {:if, _, [{:<=, _, [limit_expr, count]}, [do: {:break, _, [break_expr]}]]},
         prefix_var,
         suffix_var,
         count_var,
         enum_reverse_arg
       )
       when count == count_var do
    cond do
      # Split: break({Enum.reverse(prefix), suffix}) — 2-element tuple
      match?({_, _}, break_expr) ->
        {left, right} = break_expr

        with ^prefix_var <- enum_reverse_arg.(left),
             true <- right == suffix_var do
          {limit_expr, :split}
        else
          _ -> nil
        end

      # Split: break({Enum.reverse(prefix), suffix}) — 3+ element tuple
      match?({:{}, _, _}, break_expr) ->
        {:{}, _, elements} = break_expr

        case elements do
          [left, right] ->
            with ^prefix_var <- enum_reverse_arg.(left),
                 true <- right == suffix_var do
              {limit_expr, :split}
            else
              _ -> nil
            end

          _ ->
            nil
        end

      # Take: break(Enum.reverse(prefix))
      not is_nil(enum_reverse_arg.(break_expr)) ->
        if enum_reverse_arg.(break_expr) == prefix_var do
          {limit_expr, :take}
        else
          nil
        end

      # Drop: break(suffix)
      break_expr == suffix_var ->
        {limit_expr, :drop}

      true ->
        nil
    end
  end

  defp split_count_up_exit(_, _, _, _, _), do: nil

  # count = count + 1
  defp split_count_up_increment({:=, _, [count, {:+, _, [count_inner, 1]}]}, count_var)
       when count == count_var and count_inner == count_var do
    true
  end

  defp split_count_up_increment(_, _), do: false

  # P072 — Sliding window reduce: consecutive pairs with accumulation
  # Emits: list |> Enum.chunk_every(2, 1, :discard) |> Enum.reduce(init, fn [a, b], acc -> f(a, b, acc) end)
  def sliding_window_reduce_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)

    with {acc_var, acc_init, prev_var, loop_list_var, original_list_var} <-
           sliding_window_reduce_initials(initials),
         %{list_var: ^loop_list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- break_expr == acc_var,
         {reduce_expr} <-
           sliding_window_reduce_accumulate(steps, elem_var, acc_var, prev_var, has_var),
         true <- sliding_window_reduce_update_prev?(steps, elem_var, prev_var) do
      quote do
        unquote(original_list_var)
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.reduce(unquote(acc_init), fn [unquote(prev_var), unquote(elem_var)],
                                             unquote(acc_var) ->
          unquote(reduce_expr)
        end)
      end
    else
      _ -> nil
    end
  end

  # Parse initials for P072: need acc with any init, prev with hd(list), and list with tl(list)
  # All 6 permutations of {acc, prev, list}
  defp sliding_window_reduce_initials(initials) when length(initials) == 3 do
    # Find the prev (hd), list (tl), and acc (other) initials
    prev_entry =
      Enum.find(initials, fn
        {_name, {:hd, _, [_]}} -> true
        _ -> false
      end)

    list_entry =
      Enum.find(initials, fn
        {_name, {:tl, _, [_]}} -> true
        _ -> false
      end)

    with {prev_name, {:hd, _, [hd_arg]}} <- prev_entry,
         {list_name, {:tl, _, [tl_arg]}} <- list_entry,
         true <- normalize_adjacent_var(hd_arg) == normalize_adjacent_var(tl_arg) do
      acc_entry =
        Enum.find(initials, fn {name, _} ->
          name != prev_name and name != list_name
        end)

      case acc_entry do
        {acc_name, acc_init} ->
          {
            {acc_name, [], nil},
            acc_init,
            {prev_name, [], nil},
            {list_name, [], nil},
            normalize_adjacent_var(hd_arg)
          }

        _ ->
          nil
      end
    else
      _ -> nil
    end
  end

  # Also support 2-initial form: acc and prev only (list is external)
  defp sliding_window_reduce_initials(initials) when length(initials) == 2 do
    _prev_entry =
      Enum.find(initials, fn
        {_name, {:hd, _, [_]}} -> true
        _ -> false
      end)

    # 2-initial form not supported yet (list_loop_ir expects a list initial)
    nil
  end

  defp sliding_window_reduce_initials(_), do: nil

  # Find the accumulate step: acc = f(prev, h, acc) where f uses both prev and h
  defp sliding_window_reduce_accumulate(steps, elem_var, acc_var, prev_var, has_var) do
    Enum.find_value(steps, fn
      {:=, _, [acc, expr]} when acc == acc_var ->
        # The expression must reference prev_var and elem_var (and implicitly acc_var)
        if has_var.(expr, prev_var) and has_var.(expr, elem_var) do
          {expr}
        end

      _ ->
        nil
    end)
  end

  # Check if prev = h (window shift)
  defp sliding_window_reduce_update_prev?(steps, elem_var, prev_var) do
    Enum.any?(steps, fn
      {:=, _, [prev, elem]} -> prev == prev_var and elem == elem_var
      _ -> false
    end)
  end

  # P074 — Enum.chunk_while/4: chunk-and-yield pattern
  # Recognizes dual-accumulator loops that group consecutive elements into chunks
  # based on a condition, yielding completed chunks when the condition changes.
  #
  # Form:
  #   loop chunks: [], chunk: [] do
  #     if list == [], do: break(Enum.reverse([Enum.reverse(chunk) | chunks]))
  #     [h | list] = list
  #     if pred(h) do
  #       chunk = [h | chunk]
  #     else
  #       chunks = [Enum.reverse(chunk) | chunks]
  #       chunk = [h]
  #     end
  #   end
  #
  # Emits: Enum.chunk_while(list, [], chunk_fn, after_fn)
  def chunk_while_pattern(initials, body, callbacks) do
    list_loop_ir = callback(callbacks, :list_loop_ir)
    has_var = callback(callbacks, :has_var)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {chunks_var, chunk_var} <- chunk_while_vars(initials),
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps} <-
           list_loop_ir.(body),
         true <- chunk_while_break_expr?(break_expr, chunks_var, chunk_var, enum_reverse_arg),
         {condition, continue_expr, yield_new_chunk_expr} <-
           chunk_while_step(steps, chunks_var, chunk_var, elem_var, has_var, enum_reverse_arg) do
      chunk_while_emit(
        list_var,
        elem_var,
        chunk_var,
        condition,
        continue_expr,
        yield_new_chunk_expr
      )
    else
      _ -> nil
    end
  end

  # Extract the two accumulator variables: chunks (outer) and chunk (inner)
  # Both must be initialized to []
  defp chunk_while_vars(initials) do
    case initials do
      [{name1, []}, {name2, []}] ->
        {{name1, [], nil}, {name2, [], nil}}

      _ ->
        nil
    end
  end

  # Check that break_expr is Enum.reverse([Enum.reverse(chunk) | chunks])
  # This means: finalize current chunk and reverse the accumulated list of chunks
  defp chunk_while_break_expr?(break_expr, chunks_var, chunk_var, enum_reverse_arg) do
    with outer_arg when not is_nil(outer_arg) <- enum_reverse_arg.(break_expr),
         [{:|, _, [inner_reverse, ^chunks_var]}] <- outer_arg,
         ^chunk_var <- enum_reverse_arg.(inner_reverse) do
      true
    else
      _ -> false
    end
  end

  # Extract the conditional step that decides continue vs yield.
  # Returns {condition, continue_expr, yield_new_chunk_expr} where:
  #   - condition: the predicate (when true, continue building chunk)
  #   - continue_expr: e.g. [h | chunk] (the new chunk value when continuing)
  #   - yield_new_chunk_expr: e.g. [h] (the new chunk value after yielding)
  #
  # Handles both orientations:
  #   if pred, do: continue, else: yield  (condition = pred)
  #   if pred, do: yield, else: continue  (condition = negated pred)
  defp chunk_while_step(steps, chunks_var, chunk_var, elem_var, has_var, enum_reverse_arg) do
    case steps do
      [{:if, _, [condition, [do: do_branch, else: else_branch]]}] ->
        # Try: do = continue, else = yield
        case chunk_while_try_branches(
               do_branch,
               else_branch,
               chunks_var,
               chunk_var,
               elem_var,
               has_var,
               enum_reverse_arg
             ) do
          {:continue_first, continue_expr, yield_new_chunk} ->
            {condition, continue_expr, yield_new_chunk}

          :not_matched ->
            # Try: do = yield, else = continue (condition is inverted)
            case chunk_while_try_branches(
                   else_branch,
                   do_branch,
                   chunks_var,
                   chunk_var,
                   elem_var,
                   has_var,
                   enum_reverse_arg
                 ) do
              {:continue_first, continue_expr, yield_new_chunk} ->
                negated = chunk_while_negate(condition)
                {negated, continue_expr, yield_new_chunk}

              :not_matched ->
                nil
            end
        end

      _ ->
        nil
    end
  end

  # Try interpreting continue_candidate as "continue building chunk" and
  # yield_candidate as "yield current chunk + start new one".
  # Returns {:continue_first, continue_expr, yield_new_chunk} or :not_matched
  defp chunk_while_try_branches(
         continue_candidate,
         yield_candidate,
         chunks_var,
         chunk_var,
         elem_var,
         has_var,
         enum_reverse_arg
       ) do
    with {:ok, continue_expr} <-
           chunk_while_continue_branch(continue_candidate, chunk_var, elem_var, has_var),
         {:ok, yield_new_chunk} <-
           chunk_while_yield_branch(
             yield_candidate,
             chunks_var,
             chunk_var,
             elem_var,
             has_var,
             enum_reverse_arg
           ) do
      {:continue_first, continue_expr, yield_new_chunk}
    else
      _ -> :not_matched
    end
  end

  # Continue branch: chunk = [h | chunk] or chunk = [expr | chunk]
  # Returns {:ok, continue_expr} where continue_expr is the full new chunk value
  defp chunk_while_continue_branch(branch, chunk_var, elem_var, has_var) do
    expr = unwrap_block(branch)

    case expr do
      {:=, _, [^chunk_var, [{:|, _, [prepend_expr, ^chunk_var]}]]} ->
        if has_var.(prepend_expr, elem_var) do
          {:ok, [{:|, [], [prepend_expr, chunk_var]}]}
        else
          :error
        end

      _ ->
        :error
    end
  end

  # Yield branch: chunks = [Enum.reverse(chunk) | chunks]; chunk = new_chunk_expr
  # Returns {:ok, yield_new_chunk_expr}
  defp chunk_while_yield_branch(
         branch,
         chunks_var,
         chunk_var,
         elem_var,
         has_var,
         enum_reverse_arg
       ) do
    stmts =
      case branch do
        {:__block__, _, exprs} -> exprs
        single -> [single]
      end

    case stmts do
      [
        {:=, _, [^chunks_var, [{:|, _, [reversed_chunk, ^chunks_var]}]]},
        {:=, _, [^chunk_var, new_chunk_expr]}
      ] ->
        with ^chunk_var <- enum_reverse_arg.(reversed_chunk),
             true <- has_var.(new_chunk_expr, elem_var) or new_chunk_expr == [] do
          {:ok, new_chunk_expr}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp chunk_while_negate({:not, _, [expr]}), do: expr
  defp chunk_while_negate({:!, _, [expr]}), do: expr

  defp chunk_while_negate(expr) do
    {:not, [], [expr]}
  end

  # Emit the Enum.chunk_while/4 call
  defp chunk_while_emit(
         list_var,
         elem_var,
         chunk_var,
         condition,
         continue_expr,
         yield_new_chunk_expr
       ) do
    # chunk_fn: fn elem, chunk ->
    #   if condition do
    #     {:cont, [elem | chunk]}        # continue building
    #   else
    #     {:cont, Enum.reverse(chunk), new_chunk}  # yield + reset
    #   end
    # end
    chunk_fn =
      quote do
        fn unquote(elem_var), unquote(chunk_var) ->
          if unquote(condition) do
            {:cont, unquote(continue_expr)}
          else
            {:cont, Enum.reverse(unquote(chunk_var)), unquote(yield_new_chunk_expr)}
          end
        end
      end

    # after_fn: fn chunk -> {:cont, Enum.reverse(chunk), []} end
    # The loop's break expression always includes the final chunk (even if empty),
    # so the after_fn must always emit it.
    after_fn =
      quote do
        fn unquote(chunk_var) -> {:cont, Enum.reverse(unquote(chunk_var)), []} end
      end

    quote do
      Enum.chunk_while(unquote(list_var), [], unquote(chunk_fn), unquote(after_fn))
    end
  end

  defp unwrap_block({:__block__, _, [single]}), do: single
  defp unwrap_block(other), do: other

  # ==========================================================================
  # P082 — Range loop with downward iteration
  # Recognizes: loop i: n, acc: init do; if i <= 0 or i == 0, do: break(acc); acc = f(i, acc); i = i - 1; end
  # Emits: Enum.reduce(n..1//-1, init, fn i, acc -> f(i, acc) end)
  # ==========================================================================
  def range_down_pattern(initials, body, callbacks) do
    has_var = callback(callbacks, :has_var)

    with {:__block__, _, [exit_check | rest]} <- body,
         {counter_var, break_expr} <- range_down_exit?(exit_check),
         {counter_name, _, _} <- counter_var,
         counter_init when not is_nil(counter_init) <- Keyword.get(initials, counter_name),
         {steps, last} <- split_stmts_last(rest),
         true <- decrement_by_one?(last, counter_var),
         acc_initials = Keyword.delete(initials, counter_name),
         true <- acc_initials != [],
         acc_vars = Enum.map(acc_initials, fn {name, _} -> {name, [], nil} end),
         true <- break_matches_acc?(break_expr, acc_vars),
         true <- Enum.all?(steps, &match?({:=, _, _}, &1)),
         true <- all_acc_updated?(steps, acc_vars),
         true <- not has_var.(break_expr, counter_var) or break_expr == counter_var do
      case acc_initials do
        [{acc_name, acc_init}] ->
          acc_var = {acc_name, [], nil}
          # Extract the update expression for the single accumulator
          update_expr = find_acc_update_expr(steps, acc_var)

          if update_expr do
            range_ast = quote do: unquote(counter_init)..1//-1

            reducer_fn =
              {:fn, [], [{:->, [], [[counter_var, acc_var], update_expr]}]}

            quote do
              Enum.reduce(unquote(range_ast), unquote(acc_init), unquote(reducer_fn))
            end
          end

        multi_acc when length(multi_acc) >= 2 ->
          acc_inits = Enum.map(multi_acc, fn {_, init} -> init end)
          init_tuple = build_tuple_ast(acc_inits)
          acc_pattern = build_tuple_ast(acc_vars)

          update_exprs =
            Enum.map(acc_vars, fn acc_var ->
              find_acc_update_expr(steps, acc_var) || acc_var
            end)

          update_tuple = build_tuple_ast(update_exprs)
          range_ast = quote do: unquote(counter_init)..1//-1

          reducer_fn =
            {:fn, [], [{:->, [], [[counter_var, acc_pattern], update_tuple]}]}

          quote do
            Enum.reduce(unquote(range_ast), unquote(init_tuple), unquote(reducer_fn))
          end
      end
    else
      _ -> nil
    end
  end

  # Exit condition: if i <= 0, do: break(expr) OR if i == 0, do: break(expr)
  defp range_down_exit?({:if, _, [{:<=, _, [counter_var, 0]}, [do: {:break, _, [break_expr]}]]}) do
    if maybe_var_ast?(counter_var), do: {counter_var, break_expr}
  end

  defp range_down_exit?({:if, _, [{:==, _, [counter_var, 0]}, [do: {:break, _, [break_expr]}]]}) do
    if maybe_var_ast?(counter_var), do: {counter_var, break_expr}
  end

  defp range_down_exit?({:if, _, [{:==, _, [0, counter_var]}, [do: {:break, _, [break_expr]}]]}) do
    if maybe_var_ast?(counter_var), do: {counter_var, break_expr}
  end

  defp range_down_exit?(_), do: nil

  defp maybe_var_ast?({name, _, ctx}) when is_atom(name) and is_atom(ctx), do: true
  defp maybe_var_ast?(_), do: false

  defp decrement_by_one?({:=, _, [n, {:-, _, [n, 1]}]}, n_var), do: n == n_var
  defp decrement_by_one?(_, _), do: false

  defp break_matches_acc?(break_expr, [single_var]) do
    break_expr == single_var
  end

  defp break_matches_acc?(break_expr, acc_vars) do
    case break_expr do
      {:{}, _, elems} -> elems == acc_vars
      {a, b} when length(acc_vars) == 2 -> [a, b] == acc_vars
      _ -> false
    end
  end

  defp all_acc_updated?(steps, acc_vars) do
    Enum.all?(acc_vars, fn acc_var ->
      Enum.any?(steps, fn
        {:=, _, [^acc_var, _]} -> true
        _ -> false
      end)
    end)
  end

  defp find_acc_update_expr(steps, acc_var) do
    Enum.find_value(steps, fn
      {:=, _, [^acc_var, expr]} -> expr
      _ -> nil
    end)
  end

  defp build_tuple_ast([a, b]), do: {a, b}
  defp build_tuple_ast(elems), do: {:{}, [], elems}

  # ==========================================================================
  # P084 — Complex break expression canonicalizer
  # Handles complex break expressions combining multiple transformations
  # ==========================================================================

  @doc false
  def normalize_break_expr(break_expr, acc_var, _list_var) do
    cond do
      # Form 1: Enum.reverse(acc) ++ tail
      match?({:++, _, [{{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [_]}, _]}, break_expr) ->
        {:++, _, [{{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [rev_arg]}, tail]} =
          break_expr

        if rev_arg == acc_var do
          {:reverse_acc_append, acc_var, tail}
        else
          # Form 2: Enum.reverse([value | acc]) ++ tail
          case rev_arg do
            [{:|, _, [value, ^acc_var]}] ->
              {:cons_reverse_acc_append, value, acc_var, tail}

            _ ->
              nil
          end
        end

      # Form 3: [value | Enum.reverse(acc)]
      match?(
        [{:|, _, [_, {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [_]}]}],
        break_expr
      ) ->
        [{:|, _, [value, {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [rev_arg]}]}] =
          break_expr

        if rev_arg == acc_var do
          {:cons_reverse_acc, value, acc_var}
        end

      # Form 5: Enum.reverse([value | acc]) — must come before Form 4 (more specific)
      match?(
        {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [[{:|, _, _}]]},
        break_expr
      ) ->
        {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [[{:|, _, [value, rev_inner]}]]} =
          break_expr

        if rev_inner == acc_var do
          {:reverse_cons_acc, value, acc_var}
        end

      # Form 4 + Plain: Enum.reverse(...) — handles double reverse, nested, or plain
      match?(
        {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [_]},
        break_expr
      ) ->
        {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [inner]} = break_expr

        case inner do
          {:++, _, [{{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [^acc_var]}, tail]} ->
            {:reverse_reverse_acc_append, acc_var, tail}

          ^acc_var ->
            {:reverse_acc, acc_var}

          _ ->
            nil
        end

      # Plain acc
      break_expr == acc_var ->
        {:plain_acc, acc_var}

      true ->
        nil
    end
  end

  defp callback(callbacks, key), do: Keyword.fetch!(callbacks, key)
end
