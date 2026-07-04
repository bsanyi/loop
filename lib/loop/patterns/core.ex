defmodule Loop.Patterns.Core do
  @moduledoc false

  import Loop.Patterns.Helpers

  # Map Pattern: loop acc: [] with [expr | acc] accumulation
  def map_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, transform} <- map_accumulate(accumulate, elem_var) do
      quote do
        unquote(list_var) |> Enum.map(fn unquote(elem_var) -> unquote(transform) end)
      end
    else
      _ -> nil
    end
  end

  def map_pattern(_, _), do: nil

  defp map_accumulate({:=, _, [acc, [{:|, _, [transform, acc]}]]}, elem_var) do
    # Verify that transform uses elem_var
    if has_var?(transform, elem_var) do
      {acc, transform}
    else
      nil
    end
  end

  defp map_accumulate(_, _), do: nil

  # Filter Pattern: loop acc: [] with conditional accumulation
  def filter_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, ^elem_var, condition} <- filter_accumulate(accumulate, elem_var) do
      quote do
        unquote(list_var) |> Enum.filter(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  def filter_pattern(_, _), do: nil

  defp filter_accumulate(
         {:=, _, [acc, {:if, _, [condition, [do: [{:|, _, [elem, acc]}], else: acc]]}]},
         elem_var
       ) do
    # Verify element is not transformed (just elem_var itself)
    if elem == elem_var do
      {acc, elem_var, condition}
    else
      nil
    end
  end

  defp filter_accumulate(_, _), do: nil

  # None? Pattern: break(true) on empty, break(false) on first match
  def none_pattern([], body) do
    with %{list_var: list_var, elem_var: elem_var, break_expr: true, steps: steps} <-
           list_loop_ir(body),
         aliases <- elem_aliases(steps, elem_var),
         condition when not is_nil(condition) <-
           Enum.find_value(steps, &none_break_condition(&1, aliases)) do
      quote do
        not Enum.any?(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  def none_pattern(_, _), do: nil

  defp none_break_condition(step, aliases) do
    case conditional_break(step) do
      {condition, false} ->
        if has_any_var?(condition, aliases), do: condition

      _ ->
        nil
    end
  end

  # All? Early Break Pattern: break(true) on empty, break(false) on negated condition
  # Shape: `unless pred(h), do: break(false)` or `if not pred(h), do: break(false)`
  def all_early_break_pattern([], body) do
    with %{list_var: list_var, elem_var: elem_var, break_expr: true, steps: steps} <-
           list_loop_ir(body),
         aliases <- elem_aliases(steps, elem_var),
         condition when not is_nil(condition) <-
           Enum.find_value(steps, &all_early_break_condition(&1, aliases)) do
      quote do
        Enum.all?(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  def all_early_break_pattern(_, _), do: nil

  defp all_early_break_condition(step, aliases) do
    case conditional_break(step) do
      {{:not, _, [inner_condition]}, false} ->
        if has_any_var?(inner_condition, aliases), do: inner_condition

      _ ->
        nil
    end
  end

  # Any? Early Break Pattern: break(false) on empty, break(true) on condition match
  # Shape: `if pred(h), do: break(true)`
  def any_early_break_pattern([], body) do
    with %{list_var: list_var, elem_var: elem_var, break_expr: false, steps: steps} <-
           list_loop_ir(body),
         aliases <- elem_aliases(steps, elem_var),
         condition when not is_nil(condition) <-
           Enum.find_value(steps, &any_early_break_condition(&1, aliases)) do
      quote do
        Enum.any?(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  def any_early_break_pattern(_, _), do: nil

  defp any_early_break_condition(step, aliases) do
    case conditional_break(step) do
      {condition, true} ->
        if has_any_var?(condition, aliases), do: condition

      _ ->
        nil
    end
  end

  # Count Pattern: loop count: 0 with conditional increment
  def count_pattern([{count_name, 0}], body) when is_atom(count_name) do
    count_var = {count_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^count_var} <- count_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^count_var, condition} <- count_accumulate(accumulate, elem_var, count_var) do
      quote do
        unquote(list_var) |> Enum.count(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ ->
        count_pattern_stmt([{count_name, 0}], body) || count_pattern_ir([{count_name, 0}], body)
    end
  end

  def count_pattern(_, _), do: nil

  # P008: Statement-style count — `if pred(h), do: count = count + 1` (no else clause)
  defp count_pattern_stmt([{count_name, 0}], body) do
    count_var = {count_name, [], nil}

    with {:__block__, _, [exit, destructure, stmt]} <- body,
         {list_var, ^count_var} <- count_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^count_var, condition} <- count_accumulate_stmt(stmt, elem_var, count_var) do
      quote do
        unquote(list_var) |> Enum.count(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp count_pattern_stmt(_, _), do: nil

  # P008: `if condition, do: count = count + 1`
  defp count_accumulate_stmt(
         {:if, _, [condition, [do: {:=, _, [count, {:+, _, [count, 1]}]}]]},
         _elem_var,
         count_var
       ) do
    if count == count_var, do: {count_var, condition}
  end

  # P008: `unless condition, do: count = count + 1`
  defp count_accumulate_stmt(
         {:unless, _, [condition, [do: {:=, _, [count, {:+, _, [count, 1]}]}]]},
         _elem_var,
         count_var
       ) do
    if count == count_var, do: {count_var, {:not, [], [condition]}}
  end

  defp count_accumulate_stmt(_, _, _), do: nil

  # P009: Count via hd/tl style — uses list_loop_ir to normalise the body
  defp count_pattern_ir([{count_name, 0}], body) do
    count_var = {count_name, [], nil}

    with %{list_var: list_var, elem_var: elem_var, break_expr: ^count_var, steps: [accumulate]} <-
           list_loop_ir(body),
         {^count_var, condition} <- count_accumulate(accumulate, elem_var, count_var) do
      quote do
        Enum.count(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp count_pattern_ir(_, _), do: nil

  defp count_exit_strategy({:if, _, [condition, [do: {:break, _, [count]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> {list, count}
      nil -> nil
    end
  end

  defp count_exit_strategy(_), do: nil

  defp count_accumulate(
         {:=, _, [count, {:if, _, [condition, [do: {:+, _, [count, 1]}, else: count]]}]},
         _elem_var,
         count_var
       ) do
    # Verify count variable matches
    if count == count_var do
      {count_var, condition}
    else
      nil
    end
  end

  defp count_accumulate(_, _, _), do: nil

  # Any Pattern: loop result: false with 'or' operation
  def any_pattern([{result_name, false}], body) when is_atom(result_name) do
    result_var = {result_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^result_var} <- any_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^result_var, condition} <- any_accumulate(accumulate, elem_var, result_var) do
      quote do
        unquote(list_var) |> Enum.any?(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> any_pattern_ir([{result_name, false}], body)
    end
  end

  def any_pattern(_, _), do: nil

  defp any_pattern_ir([{result_name, false}], body) do
    result_var = {result_name, [], nil}

    with %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: [accumulate]} <-
           list_loop_ir(body),
         true <- break_expr == result_var,
         {^result_var, condition} <- any_accumulate(accumulate, elem_var, result_var) do
      quote do
        Enum.any?(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp any_pattern_ir(_, _), do: nil

  defp any_exit_strategy({:if, _, [condition, [do: {:break, _, [result]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> {list, result}
      nil -> nil
    end
  end

  defp any_exit_strategy(_), do: nil

  defp any_accumulate(
         {:=, _, [result, {:or, _, [result, condition]}]},
         _elem_var,
         result_var
       ) do
    if result == result_var, do: {result_var, condition}
  end

  # P054: commuted form — result = condition or result
  defp any_accumulate(
         {:=, _, [result, {:or, _, [condition, result]}]},
         _elem_var,
         result_var
       ) do
    if result == result_var, do: {result_var, condition}
  end

  defp any_accumulate(_, _, _), do: nil

  # All Pattern: loop result: true with 'and' operation
  def all_pattern([{result_name, true}], body) when is_atom(result_name) do
    result_var = {result_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^result_var} <- all_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^result_var, condition} <- all_accumulate(accumulate, elem_var, result_var) do
      quote do
        unquote(list_var) |> Enum.all?(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> all_pattern_ir([{result_name, true}], body)
    end
  end

  def all_pattern(_, _), do: nil

  defp all_pattern_ir([{result_name, true}], body) do
    result_var = {result_name, [], nil}

    with %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: [accumulate]} <-
           list_loop_ir(body),
         true <- break_expr == result_var,
         {^result_var, condition} <- all_accumulate(accumulate, elem_var, result_var) do
      quote do
        Enum.all?(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp all_pattern_ir(_, _), do: nil

  defp all_exit_strategy({:if, _, [condition, [do: {:break, _, [result]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> {list, result}
      nil -> nil
    end
  end

  defp all_exit_strategy(_), do: nil

  defp all_accumulate(
         {:=, _, [result, {:and, _, [result, condition]}]},
         _elem_var,
         result_var
       ) do
    if result == result_var, do: {result_var, condition}
  end

  # P054: commuted form — result = condition and result
  defp all_accumulate(
         {:=, _, [result, {:and, _, [condition, result]}]},
         _elem_var,
         result_var
       ) do
    if result == result_var, do: {result_var, condition}
  end

  defp all_accumulate(_, _, _), do: nil

  # Reject Pattern: inverse of filter - keep elements where condition is false
  def reject_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, ^elem_var, condition} <- reject_accumulate(accumulate, elem_var) do
      quote do
        unquote(list_var) |> Enum.reject(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  def reject_pattern(_, _), do: nil

  defp reject_accumulate(
         {:=, _, [acc, {:if, _, [condition, [do: acc, else: [{:|, _, [elem, acc]}]]]}]},
         elem_var
       ) do
    if elem == elem_var do
      {acc, elem_var, condition}
    else
      nil
    end
  end

  defp reject_accumulate(_, _), do: nil

  # Reverse Pattern: accumulate raw elements, break with acc (not reversed)
  def reverse_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^acc_var} <- reverse_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, ^elem_var} <- reverse_accumulate(accumulate, elem_var) do
      quote do
        Enum.reverse(unquote(list_var))
      end
    else
      _ -> nil
    end
  end

  def reverse_pattern(_, _), do: nil

  # break(acc) without Enum.reverse
  defp reverse_exit_strategy({:if, _, [condition, [do: {:break, _, [acc]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> {list, acc}
      nil -> nil
    end
  end

  defp reverse_exit_strategy(_), do: nil

  # acc = [elem | acc] where elem is raw (identity transform)
  defp reverse_accumulate({:=, _, [acc, [{:|, _, [elem, acc]}]]}, elem_var) do
    if elem == elem_var do
      {acc, elem_var}
    else
      nil
    end
  end

  defp reverse_accumulate(_, _), do: nil

  # Filter+Map Pattern: like filter but with transform in do branch
  def filter_map_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, condition, transform} <- filter_map_accumulate(accumulate, elem_var) do
      quote do
        for unquote(elem_var) <- unquote(list_var),
            unquote(condition),
            do: unquote(transform)
      end
    else
      _ -> nil
    end
  end

  def filter_map_pattern(_, _), do: nil

  defp filter_map_accumulate(
         {:=, _, [acc, {:if, _, [condition, [do: [{:|, _, [transform, acc]}], else: acc]]}]},
         elem_var
       ) do
    # Must have a transform that uses elem_var AND differs from elem_var
    if has_var?(transform, elem_var) and transform != elem_var and has_var?(condition, elem_var) do
      {acc, condition, transform}
    else
      nil
    end
  end

  defp filter_map_accumulate(_, _), do: nil
  # Length Pattern: init count: 0, discard element, unconditional increment
  def length_pattern(initials, body) do
    with [{count_name, 0}] <- initials,
         {:__block__, _, [exit, destructure, increment]} <- body,
         count_var = {count_name, [], nil},
         {list_var, ^count_var} <- count_exit_strategy(exit),
         {^list_var, _elem_var} <- length_destructure(destructure),
         ^count_var <- length_increment(increment, count_var) do
      quote do
        length(unquote(list_var))
      end
    else
      _ -> length_pattern_ir(initials, body)
    end
  end

  # P010: Length via hd/tl style — `count = count + 1; list = tl(list)`
  defp length_pattern_ir([{count_name, 0}], body) do
    count_var = {count_name, [], nil}

    with %{list_var: list_var, break_expr: ^count_var, steps: [increment]} <-
           list_loop_ir(body),
         ^count_var <- length_increment(increment, count_var) do
      quote do
        length(unquote(list_var))
      end
    else
      _ -> nil
    end
  end

  defp length_pattern_ir(_, _), do: nil

  # Destructure that discards element: [_ | list] = list
  defp length_destructure({:=, _, [[{:|, _, [{:_, _, _}, list]}], list]}) do
    {list, :_}
  end

  defp length_destructure(_), do: nil

  # Unconditional increment: count = count + 1
  defp length_increment({:=, _, [count, {:+, _, [count, 1]}]}, count_var) do
    if count == count_var, do: count_var
  end

  defp length_increment(_, _), do: nil

  # Each Pattern: no accumulator, side-effect iteration
  # Variant 1: [h | list] = list destructure
  def each_pattern([], body) do
    with {:__block__, _, [exit_empty, destructure | side_effects]} <- body,
         list_var when list_var != nil <- each_exit_empty(exit_empty),
         {^list_var, elem_var} <- map_destructure(destructure),
         [_ | _] <- side_effects,
         false <- Enum.any?(side_effects, &has_break?/1),
         true <- Enum.all?(side_effects, &has_var?(&1, elem_var)) do
      side_effect_body =
        case side_effects do
          [single] -> single
          multiple -> {:__block__, [], multiple}
        end

      quote do
        unquote(list_var)
        |> Enum.each(fn unquote(elem_var) -> unquote(side_effect_body) end)
      end
    else
      _ -> each_pattern_hd_tl(body)
    end
  end

  def each_pattern(_, _), do: nil

  # Variant 2: hd/tl variant
  defp each_pattern_hd_tl(body) do
    with {:__block__, _, [exit_empty | rest]} <- body,
         list_var <- each_exit_empty(exit_empty),
         true <- length(rest) >= 2,
         {side_effects, [advance]} = Enum.split(rest, -1),
         ^list_var <- next_step(advance),
         elem_expr = {:hd, [], [list_var]},
         true <- Enum.all?(side_effects, &has_var?(&1, elem_expr)) do
      elem_var = {:elem, [], Elixir}

      side_effect_body =
        case side_effects do
          [single] -> replace_var(single, elem_expr, elem_var)
          multiple -> {:__block__, [], Enum.map(multiple, &replace_var(&1, elem_expr, elem_var))}
        end

      quote do
        unquote(list_var) |> Enum.each(fn unquote(elem_var) -> unquote(side_effect_body) end)
      end
    else
      _ -> nil
    end
  end

  defp each_exit_empty({:if, _, [condition, [do: {:break, _, break_val}]]})
       when break_val == [nil] or break_val == [] do
    case empty_list_check?(condition) do
      {list, _} -> list
      nil -> nil
    end
  end

  defp each_exit_empty(_), do: nil

  # Take While Pattern: like filter but break on first failure
  def take_while_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, ^elem_var, condition} <- take_while_accumulate(accumulate, acc_var, elem_var) do
      quote do
        unquote(list_var) |> Enum.take_while(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  def take_while_pattern(_, _), do: nil

  defp take_while_accumulate(
         {:=, _,
          [
            acc,
            {:if, _,
             [
               condition,
               [
                 do: [{:|, _, [elem, acc]}],
                 else: {:break, _, [{{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [acc]}]}
               ]
             ]}
          ]},
         acc_var,
         elem_var
       ) do
    if acc == acc_var and elem == elem_var and has_var?(condition, elem_var) do
      {acc_var, elem_var, condition}
    else
      nil
    end
  end

  defp take_while_accumulate(_, _, _), do: nil

  # Drop While Pattern: no acc, break with reconstituted list when condition fails
  def drop_while_pattern([], body) do
    with {:__block__, _, [exit_empty, destructure, check]} <- body,
         list_var <- drop_while_exit_empty(exit_empty),
         {^list_var, elem_var} <- map_destructure(destructure),
         condition when not is_nil(condition) <- drop_while_check(check, list_var, elem_var) do
      quote do
        unquote(list_var) |> Enum.drop_while(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  def drop_while_pattern(_, _), do: nil

  defp drop_while_exit_empty({:if, _, [condition, [do: {:break, _, [[]]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> list
      nil -> nil
    end
  end

  defp drop_while_exit_empty(_), do: nil

  # unless condition(h), do: break([h | list])
  defp drop_while_check(
         {:unless, _, [condition, [do: {:break, _, [[{:|, _, [elem, list]}]]}]]},
         list_var,
         elem_var
       ) do
    if elem == elem_var and list == list_var and has_var?(condition, elem_var) do
      condition
    else
      nil
    end
  end

  defp drop_while_check(_, _, _), do: nil

  # Map Append Pattern: loop acc: [] with acc ++ [mapped] accumulation
  def map_append_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^acc_var} <- reverse_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, transform} <- map_append_accumulate(accumulate, elem_var) do
      quote do
        unquote(list_var) |> Enum.map(fn unquote(elem_var) -> unquote(transform) end)
      end
    else
      _ -> nil
    end
  end

  def map_append_pattern(_, _), do: nil

  defp map_append_accumulate({:=, _, [acc, {:++, _, [acc, [transform]]}]}, elem_var) do
    # Verify that transform uses elem_var
    if has_var?(transform, elem_var) do
      {acc, transform}
    else
      nil
    end
  end

  defp map_append_accumulate(_, _), do: nil

  # Filter Append Pattern: loop acc: [] with conditional append accumulation
  def filter_append_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^acc_var} <- reverse_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, ^elem_var, condition} <- filter_append_accumulate(accumulate, elem_var) do
      quote do
        unquote(list_var) |> Enum.filter(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  def filter_append_pattern(_, _), do: nil

  defp filter_append_accumulate(
         {:=, _, [acc, {:if, _, [condition, [do: {:++, _, [acc, [elem]]}, else: acc]]}]},
         elem_var
       ) do
    # Verify element is not transformed (just elem_var itself)
    if elem == elem_var do
      {acc, elem_var, condition}
    else
      nil
    end
  end

  defp filter_append_accumulate(_, _), do: nil

  # Reject Append Pattern: loop acc: [] with inverted conditional append accumulation
  def reject_append_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^acc_var} <- reverse_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, ^elem_var, condition} <- reject_append_accumulate(accumulate, elem_var) do
      quote do
        unquote(list_var) |> Enum.reject(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  def reject_append_pattern(_, _), do: nil

  defp reject_append_accumulate(
         {:=, _, [acc, {:if, _, [condition, [do: acc, else: {:++, _, [acc, [elem]]}]]}]},
         elem_var
       ) do
    if elem == elem_var do
      {acc, elem_var, condition}
    else
      nil
    end
  end

  defp reject_append_accumulate(_, _), do: nil

  # Take While Append Pattern: loop acc: [] with conditional append or break
  def take_while_append_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, ^acc_var} <- reverse_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, ^elem_var, condition} <-
           take_while_append_accumulate(accumulate, acc_var, elem_var) do
      quote do
        unquote(list_var) |> Enum.take_while(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  def take_while_append_pattern(_, _), do: nil

  defp take_while_append_accumulate(
         {:=, _,
          [
            acc,
            {:if, _,
             [
               condition,
               [
                 do: {:++, _, [acc, [elem]]},
                 else: {:break, _, [acc]}
               ]
             ]}
          ]},
         acc_var,
         elem_var
       ) do
    if acc == acc_var and elem == elem_var and has_var?(condition, elem_var) do
      {acc_var, elem_var, condition}
    else
      nil
    end
  end

  defp take_while_append_accumulate(_, _, _), do: nil

  # P042: Map_while — map elements until a halt condition, return the mapped prefix.
  # Shape: exit_empty + destructure + halt_check + accumulate (4 steps)
  # Emitted as Enum.reduce_while since Enum.map_while is not in the stdlib.
  def map_while_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit_empty, destructure, halt_check, accumulate]} <- body,
         {list_var, ^acc_var} <- map_exit_strategy(exit_empty),
         {^list_var, elem_var} <- map_destructure(destructure),
         condition when not is_nil(condition) <- map_while_halt(halt_check, acc_var),
         true <- has_var?(condition, elem_var),
         false <- has_var?(condition, acc_var),
         {^acc_var, transform} <- map_accumulate(accumulate, elem_var) do
      build_map_while(list_var, elem_var, acc_var, condition, transform)
    else
      _ -> nil
    end
  end

  def map_while_pattern(_, _), do: nil

  defp build_map_while(list_var, elem_var, acc_var, condition, transform) do
    quote do
      unquote(list_var)
      |> Enum.reduce_while([], fn unquote(elem_var), unquote(acc_var) ->
        if unquote(condition),
          do: {:halt, unquote(acc_var)},
          else: {:cont, [unquote(transform) | unquote(acc_var)]}
      end)
      |> Enum.reverse()
    end
  end

  # Matches `if stop_condition, do: break(Enum.reverse(acc))` (and the
  # 2-branch else-literal form produced by P040 cond/case normalization).
  defp map_while_halt(step, acc_var) do
    case conditional_break(step) do
      {condition, {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [^acc_var]}} ->
        condition

      _ ->
        nil
    end
  end
end
