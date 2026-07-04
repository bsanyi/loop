defmodule Loop.Patterns.Collection do
  @moduledoc false

  def partition_pattern(initials, body, callbacks) do
    empty_list_check = callback(callbacks, :empty_list_check)
    map_destructure = callback(callbacks, :map_destructure)
    list_prepend = callback(callbacks, :list_prepend)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with [{left_name, []}, {right_name, []}] <- initials,
         {:__block__, _, [exit, destructure, update]} <- body,
         left_var = {left_name, [], nil},
         right_var = {right_name, [], nil},
         {list_var, ^left_var, ^right_var} <-
           partition_exit_strategy(exit, empty_list_check, enum_reverse_arg),
         {^list_var, elem_var} <- map_destructure.(destructure),
         condition <- partition_update(update, left_var, right_var, elem_var, list_prepend) do
      quote do
        Enum.split_with(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp partition_exit_strategy(
         {:if, _, [condition, [do: {:break, _, [{left_expr, right_expr}]}]]},
         empty_list_check,
         enum_reverse_arg
       ) do
    with {left_var, right_var} <- partition_break_payload(left_expr, right_expr, enum_reverse_arg),
         {list_var, _} <- empty_list_check.(condition) do
      {list_var, left_var, right_var}
    else
      _ -> nil
    end
  end

  defp partition_exit_strategy(
         {:if, _, [condition, [do: {:break, _, [{:{}, _, [left_expr, right_expr]}]}]]},
         empty_list_check,
         enum_reverse_arg
       ) do
    with {left_var, right_var} <- partition_break_payload(left_expr, right_expr, enum_reverse_arg),
         {list_var, _} <- empty_list_check.(condition) do
      {list_var, left_var, right_var}
    else
      _ -> nil
    end
  end

  defp partition_exit_strategy(_, _, _), do: nil

  defp partition_break_payload(left_expr, right_expr, enum_reverse_arg) do
    with left_var when not is_nil(left_var) <- enum_reverse_arg.(left_expr),
         right_var when not is_nil(right_var) <- enum_reverse_arg.(right_expr) do
      {left_var, right_var}
    else
      _ -> nil
    end
  end

  defp partition_update(
         {:=, _,
          [
            {left, right},
            {:if, _,
             [
               condition,
               [
                 do: {do_left, do_right},
                 else: {else_left, else_right}
               ]
             ]}
          ]},
         left_var,
         right_var,
         elem_var,
         _list_prepend
       ) do
    if left == left_var and right == right_var and
         list_cons?(do_left, left_var, elem_var) and do_right == right_var and
         else_left == left_var and list_cons?(else_right, right_var, elem_var) do
      condition
    else
      nil
    end
  end

  defp partition_update(
         {:=, _,
          [
            {left, right},
            {:if, _,
             [
               condition,
               [
                 do: {:{}, _, [do_left, do_right]},
                 else: {:{}, _, [else_left, else_right]}
               ]
             ]}
          ]},
         left_var,
         right_var,
         elem_var,
         _list_prepend
       ) do
    if left == left_var and right == right_var and
         list_cons?(do_left, left_var, elem_var) and do_right == right_var and
         else_left == left_var and list_cons?(else_right, right_var, elem_var) do
      condition
    else
      nil
    end
  end

  defp partition_update(_, _, _, _, _), do: nil

  # Check if an expression is a list cons like [elem | acc]
  defp list_cons?([{:|, _, [elem, acc]}], acc_var, elem_var) do
    acc == acc_var and elem == elem_var
  end

  defp list_cons?(_, _, _), do: false

  def take_pattern(initials, body, callbacks) do
    list_or_zero_check = callback(callbacks, :list_or_zero_check)
    map_destructure = callback(callbacks, :map_destructure)
    list_prepend = callback(callbacks, :list_prepend)
    decrement_by_one = callback(callbacks, :decrement_by_one)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with [{acc_name, []}, {count_name, count_init}] <- initials,
         {:__block__, _, [exit, destructure, accumulate, decrement]} <- body,
         acc_var = {acc_name, [], nil},
         count_var = {count_name, [], nil},
         {list_var, ^acc_var, ^count_var} <-
           take_exit_strategy(exit, list_or_zero_check, enum_reverse_arg),
         {^list_var, elem_var} <- map_destructure.(destructure),
         true <- list_prepend.(accumulate, acc_var, elem_var),
         true <- decrement_by_one.(decrement, count_var) do
      quote do
        n = unquote(count_init)

        if n < 0 do
          unquote(list_var)
        else
          Enum.take(unquote(list_var), n)
        end
      end
    else
      _ -> nil
    end
  end

  defp take_exit_strategy(
         {:if, _, [condition, [do: {:break, _, [break_expr]}]]},
         list_or_zero_check,
         enum_reverse_arg
       ) do
    with acc_var when not is_nil(acc_var) <- enum_reverse_arg.(break_expr),
         {list_var, count_var} <- list_or_zero_check.(condition) do
      {list_var, acc_var, count_var}
    else
      _ -> nil
    end
  end

  defp take_exit_strategy(_, _, _), do: nil

  def drop_pattern(initials, body, callbacks) do
    list_or_zero_check = callback(callbacks, :list_or_zero_check)
    decrement_by_one = callback(callbacks, :decrement_by_one)

    with [{count_name, count_init}] <- initials,
         {:__block__, _, [exit, destructure, decrement]} <- body,
         count_var = {count_name, [], nil},
         {list_var, ^count_var} <- drop_exit_strategy(exit, list_or_zero_check),
         {^list_var, _} <- drop_destructure(destructure),
         true <- decrement_by_one.(decrement, count_var) do
      quote do
        n = unquote(count_init)

        if n < 0 do
          []
        else
          Enum.drop(unquote(list_var), n)
        end
      end
    else
      _ -> nil
    end
  end

  defp drop_exit_strategy(
         {:if, _, [condition, [do: {:break, _, [break_list]}]]},
         list_or_zero_check
       ) do
    with {list_var, count_var} <- list_or_zero_check.(condition),
         true <- break_list == list_var do
      {list_var, count_var}
    else
      _ -> nil
    end
  end

  defp drop_exit_strategy(_, _), do: nil

  defp drop_destructure({:=, _, [[{:|, _, [_elem, list]}], list]}), do: {list, :ok}
  defp drop_destructure(_), do: nil

  def split_pattern(initials, body, callbacks) do
    list_or_zero_check = callback(callbacks, :list_or_zero_check)
    map_destructure = callback(callbacks, :map_destructure)
    list_prepend = callback(callbacks, :list_prepend)
    decrement_by_one = callback(callbacks, :decrement_by_one)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)

    with {left_name, count_name, count_init} <- split_initials(initials),
         {:__block__, _, [exit, destructure, accumulate, decrement]} <- body,
         left_var = {left_name, [], nil},
         count_var = {count_name, [], nil},
         {list_var, ^left_var, ^count_var} <-
           split_exit_strategy(exit, list_or_zero_check, enum_reverse_arg),
         {^list_var, elem_var} <- map_destructure.(destructure),
         true <- list_prepend.(accumulate, left_var, elem_var),
         true <- decrement_by_one.(decrement, count_var) do
      quote do
        n = unquote(count_init)

        if n < 0 do
          {unquote(list_var), []}
        else
          Enum.split(unquote(list_var), n)
        end
      end
    else
      _ -> nil
    end
  end

  defp split_initials([{left_name, []}, {count_name, count_init}]),
    do: {left_name, count_name, count_init}

  defp split_initials([{count_name, count_init}, {left_name, []}]),
    do: {left_name, count_name, count_init}

  defp split_initials(_), do: nil

  defp split_exit_strategy(
         {:if, _, [condition, [do: {:break, _, [{:{}, _, [left_expr, right_expr]}]}]]},
         list_or_zero_check,
         enum_reverse_arg
       ) do
    with left_var when not is_nil(left_var) <- enum_reverse_arg.(left_expr),
         {list_var, count_var} <- list_or_zero_check.(condition),
         true <- right_expr == list_var do
      {list_var, left_var, count_var}
    else
      _ -> nil
    end
  end

  # Handle 2-element tuple {left_expr, right_expr}
  defp split_exit_strategy(
         {:if, _, [condition, [do: {:break, _, [{left_expr, right_expr}]}]]},
         list_or_zero_check,
         enum_reverse_arg
       ) do
    with left_var when not is_nil(left_var) <- enum_reverse_arg.(left_expr),
         {list_var, count_var} <- list_or_zero_check.(condition),
         true <- right_expr == list_var do
      {list_var, left_var, count_var}
    else
      _ -> nil
    end
  end

  defp split_exit_strategy(_, _, _), do: nil

  def split_while_pattern(initials, body, callbacks) do
    empty_list_check = callback(callbacks, :empty_list_check)
    map_destructure = callback(callbacks, :map_destructure)
    enum_reverse_arg = callback(callbacks, :enum_reverse_arg)
    has_var = callback(callbacks, :has_var)

    with [{left_name, []}] <- initials,
         {:__block__, _, [exit_empty, destructure, accumulate]} <- body,
         left_var = {left_name, [], nil},
         {list_var, ^left_var} <-
           split_while_exit_empty(exit_empty, left_var, empty_list_check, enum_reverse_arg),
         {^list_var, elem_var} <- map_destructure.(destructure),
         condition when not is_nil(condition) <-
           split_while_accumulate_condition(
             accumulate,
             left_var,
             list_var,
             elem_var,
             enum_reverse_arg,
             has_var
           ) do
      quote do
        Enum.split_while(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp split_while_exit_empty(
         {:if, _, [condition, [do: {:break, _, [{:{}, _, [left_expr, []]}]}]]},
         left_var,
         empty_list_check,
         enum_reverse_arg
       ) do
    with ^left_var <- enum_reverse_arg.(left_expr),
         {list_var, _} <- empty_list_check.(condition) do
      {list_var, left_var}
    else
      _ -> nil
    end
  end

  # Handle 2-element tuple {left_expr, []}
  defp split_while_exit_empty(
         {:if, _, [condition, [do: {:break, _, [{left_expr, []}]}]]},
         left_var,
         empty_list_check,
         enum_reverse_arg
       ) do
    with ^left_var <- enum_reverse_arg.(left_expr),
         {list_var, _} <- empty_list_check.(condition) do
      {list_var, left_var}
    else
      _ -> nil
    end
  end

  defp split_while_exit_empty(_, _, _, _), do: nil

  defp split_while_accumulate_condition(
         {:=, _, [left, {:if, _, [condition, [do: do_expr, else: else_expr]]}]},
         left_var,
         list_var,
         elem_var,
         enum_reverse_arg,
         has_var
       ) do
    if left == left_var do
      split_while_condition_from_branches(
        condition,
        do_expr,
        else_expr,
        left_var,
        list_var,
        elem_var,
        enum_reverse_arg,
        has_var
      )
    end
  end

  defp split_while_accumulate_condition(
         {:=, _, [left, {:unless, _, [condition, [do: do_expr, else: else_expr]]}]},
         left_var,
         list_var,
         elem_var,
         enum_reverse_arg,
         has_var
       ) do
    if left == left_var do
      split_while_condition_from_branches(
        condition,
        else_expr,
        do_expr,
        left_var,
        list_var,
        elem_var,
        enum_reverse_arg,
        has_var
      )
    end
  end

  defp split_while_accumulate_condition(_, _, _, _, _, _), do: nil

  defp split_while_condition_from_branches(
         condition,
         do_expr,
         else_expr,
         left_var,
         list_var,
         elem_var,
         enum_reverse_arg,
         has_var
       ) do
    cond do
      split_while_cons?(do_expr, left_var, elem_var) and
        split_while_break_payload?(else_expr, left_var, list_var, elem_var, enum_reverse_arg) and
          has_var.(condition, elem_var) ->
        condition

      split_while_cons?(else_expr, left_var, elem_var) and
        split_while_break_payload?(do_expr, left_var, list_var, elem_var, enum_reverse_arg) and
          has_var.(condition, elem_var) ->
        {:not, [], [condition]}

      true ->
        nil
    end
  end

  defp split_while_cons?([{:|, _, [elem, left]}], left_var, elem_var),
    do: left == left_var and elem == elem_var

  defp split_while_cons?(_, _, _), do: false

  defp split_while_break_payload?(
         {:break, _, [{:{}, _, [left_expr, [{:|, _, [elem, list]}]]}]},
         left_var,
         list_var,
         elem_var,
         enum_reverse_arg
       ) do
    enum_reverse_arg.(left_expr) == left_var and elem == elem_var and list == list_var
  end

  # Handle 2-element tuple {left_expr, [elem | list]}
  defp split_while_break_payload?(
         {:break, _, [{left_expr, [{:|, _, [elem, list]}]}]},
         left_var,
         list_var,
         elem_var,
         enum_reverse_arg
       ) do
    enum_reverse_arg.(left_expr) == left_var and elem == elem_var and list == list_var
  end

  defp split_while_break_payload?(_, _, _, _, _), do: false

  defp callback(callbacks, key), do: Keyword.fetch!(callbacks, key)

  # Split While Append Pattern: left built via acc ++ [elem], break with {left, [h | rest]}
  def split_while_append_pattern(initials, body, callbacks) do
    empty_list_check = callback(callbacks, :empty_list_check)
    map_destructure = callback(callbacks, :map_destructure)
    has_var = callback(callbacks, :has_var)

    with [{left_name, []}] <- initials,
         {:__block__, _, [exit_empty, destructure, accumulate]} <- body,
         left_var = {left_name, [], nil},
         {list_var, ^left_var} <-
           split_while_append_exit_empty(exit_empty, left_var, empty_list_check),
         {^list_var, elem_var} <- map_destructure.(destructure),
         condition when not is_nil(condition) <-
           split_while_append_accumulate_condition(
             accumulate,
             left_var,
             list_var,
             elem_var,
             has_var
           ) do
      quote do
        Enum.split_while(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  # Handle 2-element tuple break({left, []}) — raw {a, b} in quoted form
  defp split_while_append_exit_empty(
         {:if, _, [condition, [do: {:break, _, [{left_var, []}]}]]},
         left_var,
         empty_list_check
       ) do
    case empty_list_check.(condition) do
      {list_var, _} -> {list_var, left_var}
      nil -> nil
    end
  end

  defp split_while_append_exit_empty(_, _, _), do: nil

  defp split_while_append_accumulate_condition(
         {:=, _, [left, {:if, _, [condition, [do: do_expr, else: else_expr]]}]},
         left_var,
         list_var,
         elem_var,
         has_var
       ) do
    if left == left_var do
      split_while_append_condition_from_branches(
        condition,
        do_expr,
        else_expr,
        left_var,
        list_var,
        elem_var,
        has_var
      )
    end
  end

  defp split_while_append_accumulate_condition(
         {:=, _, [left, {:unless, _, [condition, [do: do_expr, else: else_expr]]}]},
         left_var,
         list_var,
         elem_var,
         has_var
       ) do
    if left == left_var do
      split_while_append_condition_from_branches(
        condition,
        else_expr,
        do_expr,
        left_var,
        list_var,
        elem_var,
        has_var
      )
    end
  end

  defp split_while_append_accumulate_condition(_, _, _, _, _), do: nil

  defp split_while_append_condition_from_branches(
         condition,
         do_expr,
         else_expr,
         left_var,
         list_var,
         elem_var,
         has_var
       ) do
    cond do
      split_while_append_acc?(do_expr, left_var, elem_var) and
        split_while_append_break_payload?(else_expr, left_var, list_var, elem_var) and
          has_var.(condition, elem_var) ->
        condition

      split_while_append_acc?(else_expr, left_var, elem_var) and
        split_while_append_break_payload?(do_expr, left_var, list_var, elem_var) and
          has_var.(condition, elem_var) ->
        {:not, [], [condition]}

      true ->
        nil
    end
  end

  defp split_while_append_acc?({:++, _, [left, [elem]]}, left_var, elem_var),
    do: left == left_var and elem == elem_var

  defp split_while_append_acc?(_, _, _), do: false

  # Handle 2-element tuple break({left, [elem | list]}) — raw {a, b} in quoted form
  defp split_while_append_break_payload?(
         {:break, _, [{left_expr, [{:|, _, [elem, list]}]}]},
         left_var,
         list_var,
         elem_var
       ) do
    left_expr == left_var and elem == elem_var and list == list_var
  end

  defp split_while_append_break_payload?(_, _, _, _), do: false
end
