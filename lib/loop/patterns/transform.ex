defmodule Loop.Patterns.Transform do
  @moduledoc false

  import Loop.Patterns.Helpers

  # With Index Pattern: two initial bindings [acc: [], i: 0], accumulate {elem, i} tuples
  def with_index_pattern(initials, body) do
    with {acc_name, index_name, index_offset} <- with_index_initials(initials),
         false <- is_float(index_offset),
         {:__block__, _, [exit, destructure, accumulate, increment]} <- body,
         acc_var = {acc_name, [], nil},
         index_var = {index_name, [], nil},
         {list_var, ^acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         true <- with_index_accumulate(accumulate, acc_var, elem_var, index_var),
         ^index_var <- find_index_increment(increment, index_var) do
      with_index_quote(list_var, index_offset)
    else
      _ -> nil
    end
  end

  defp with_index_initials([{acc_name, []}, {index_name, offset}]),
    do: {acc_name, index_name, offset}

  defp with_index_initials([{index_name, offset}, {acc_name, []}]),
    do: {acc_name, index_name, offset}

  defp with_index_initials(_), do: nil

  defp with_index_quote(list_var, 0) do
    quote do
      Enum.with_index(unquote(list_var))
    end
  end

  defp with_index_quote(list_var, offset) do
    quote do
      Enum.with_index(unquote(list_var), unquote(offset))
    end
  end

  # acc = [{elem, index} | acc]
  defp with_index_accumulate(
         {:=, _, [acc, [{:|, _, [{elem, index}, acc]}]]},
         acc_var,
         elem_var,
         index_var
       ) do
    acc == acc_var and elem == elem_var and index == index_var
  end

  defp with_index_accumulate(_, _, _, _), do: false

  # Zip Pattern: two lists, or exit, two destructures, accumulate tuples
  def zip_pattern([{acc_name, []}], body) when is_atom(acc_name) do
    acc_var = {acc_name, [], nil}

    with {:__block__, _, [exit, destructure1, destructure2, accumulate]} <- body,
         {list1_var, list2_var, ^acc_var} <- zip_exit_strategy(exit),
         {^list1_var, elem1_var} <- map_destructure(destructure1),
         {^list2_var, elem2_var} <- map_destructure(destructure2),
         true <- zip_accumulate(accumulate, acc_var, elem1_var, elem2_var) do
      quote do
        Enum.zip(unquote(list1_var), unquote(list2_var))
      end
    else
      _ -> nil
    end
  end

  def zip_pattern(_, _), do: nil

  # if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
  defp zip_exit_strategy(
         {:if, _,
          [
            {:or, _, [{:==, _, [list1, []]}, {:==, _, [list2, []]}]},
            [do: {:break, _, [{{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [acc]}]}]
          ]}
       ) do
    {list1, list2, acc}
  end

  defp zip_exit_strategy(_), do: nil

  # acc = [{elem1, elem2} | acc] — a 2-element tuple is a raw {a, b} in quoted form
  defp zip_accumulate(
         {:=, _, [acc, [{:|, _, [{elem1, elem2}, acc]}]]},
         acc_var,
         elem1_var,
         elem2_var
       ) do
    acc == acc_var and elem1 == elem1_var and elem2 == elem2_var
  end

  defp zip_accumulate(_, _, _, _), do: false

  # Dedup Pattern: two initial bindings [acc: [], prev: nil], compare to prev
  def dedup_pattern(initials, body) do
    with [{acc_name, []}, {prev_name, nil}] <- initials,
         {:__block__, _, [exit, destructure, accumulate, update_prev]} <- body,
         acc_var = {acc_name, [], nil},
         prev_var = {prev_name, [], nil},
         {list_var, ^acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         true <- dedup_accumulate(accumulate, acc_var, elem_var, prev_var),
         true <- dedup_update_prev(update_prev, elem_var, prev_var) do
      quote do
        Enum.dedup(unquote(list_var))
      end
    else
      _ -> nil
    end
  end

  # acc = if h == prev, do: acc, else: [h | acc]
  defp dedup_accumulate(
         {:=, _,
          [acc, {:if, _, [{:==, _, [elem, prev]}, [do: acc, else: [{:|, _, [elem, acc]}]]]}]},
         acc_var,
         elem_var,
         prev_var
       ) do
    acc == acc_var and elem == elem_var and prev == prev_var
  end

  defp dedup_accumulate(_, _, _, _), do: false

  # prev = h
  defp dedup_update_prev({:=, _, [prev, elem]}, elem_var, prev_var) do
    prev == prev_var and elem == elem_var
  end

  defp dedup_update_prev(_, _, _), do: false

  def dedup_first_flag_pattern(initials, body) do
    with {acc_var, prev_var, started_var} <- dedup_first_flag_vars(initials),
         {:__block__, _, [exit_expr, destructure, accumulate, update_prev, update_started]} <-
           body,
         {list_var, ^acc_var} <- map_exit_strategy(exit_expr),
         {^list_var, elem_var} <- map_destructure(destructure),
         true <- dedup_first_flag_accumulate(accumulate, acc_var, elem_var, prev_var, started_var),
         true <- dedup_update_prev(update_prev, elem_var, prev_var),
         true <- dedup_update_started(update_started, started_var) do
      quote do
        Enum.dedup(unquote(list_var))
      end
    else
      _ -> nil
    end
  end

  defp dedup_first_flag_vars([_, _, _] = initials) do
    acc_name =
      Enum.find_value(initials, fn
        {n, []} -> n
        _ -> nil
      end)

    started_name =
      Enum.find_value(initials, fn
        {n, false} -> n
        _ -> nil
      end)

    prev_name =
      Enum.find_value(initials, fn
        {n, _} -> if n != acc_name and n != started_name, do: n
      end)

    if acc_name && started_name && prev_name do
      {{acc_name, [], nil}, {prev_name, [], nil}, {started_name, [], nil}}
    end
  end

  defp dedup_first_flag_vars(_), do: nil

  defp dedup_first_flag_accumulate(stmt, acc_var, elem_var, prev_var, started_var) do
    dedup_flag_form_a(stmt, acc_var, elem_var, prev_var, started_var) or
      dedup_flag_form_b(stmt, acc_var, elem_var, prev_var, started_var)
  end

  # Form A (canonical after P043): acc = if started and h == prev, do: acc, else: [h | acc]
  defp dedup_flag_form_a(
         {:=, _, [acc, {:if, _, [condition, [do: acc, else: [{:|, _, [elem, acc]}]]]}]},
         acc_var,
         elem_var,
         prev_var,
         started_var
       )
       when acc == acc_var and elem == elem_var do
    case condition do
      {:and, _, [started, {:==, _, [e, prev]}]}
      when started == started_var and e == elem_var and prev == prev_var ->
        true

      {:and, _, [started, {:==, _, [prev, e]}]}
      when started == started_var and e == elem_var and prev == prev_var ->
        true

      _ ->
        false
    end
  end

  defp dedup_flag_form_a(_, _, _, _, _), do: false

  # Form B: acc = if not started or h != prev, do: [h | acc], else: acc
  defp dedup_flag_form_b(
         {:=, _, [acc, {:if, _, [condition, [do: [{:|, _, [elem, acc]}], else: acc]]}]},
         acc_var,
         elem_var,
         prev_var,
         started_var
       )
       when acc == acc_var and elem == elem_var do
    case condition do
      {:or, _, [{:not, _, [started]}, {:!=, _, [e, prev]}]}
      when started == started_var and e == elem_var and prev == prev_var ->
        true

      {:or, _, [{:not, _, [started]}, {:!=, _, [prev, e]}]}
      when started == started_var and e == elem_var and prev == prev_var ->
        true

      _ ->
        false
    end
  end

  defp dedup_flag_form_b(_, _, _, _, _), do: false

  defp dedup_update_started({:=, _, [started, true]}, started_var)
       when started == started_var,
       do: true

  defp dedup_update_started(_, _), do: false
  # Frequencies Pattern: Map.update(freq, elem, 1, &(&1 + 1))
  def frequencies_pattern(initials, body) do
    with [{freq_name, {:%{}, _, []}}] <- initials,
         {:__block__, _, [exit, destructure, update]} <- body,
         freq_var = {freq_name, [], nil},
         {list_var, ^freq_var} <- frequencies_exit(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         true <- frequencies_update(update, freq_var, elem_var) do
      quote do
        Enum.frequencies(unquote(list_var))
      end
    else
      _ -> nil
    end
  end

  defp frequencies_exit({:if, _, [condition, [do: {:break, _, [freq]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> {list, freq}
      nil -> nil
    end
  end

  defp frequencies_exit(_), do: nil

  # freq = Map.update(freq, elem, 1, &(&1 + 1))
  defp frequencies_update(
         {:=, _,
          [
            freq,
            {{:., _, [{:__aliases__, _, [:Map]}, :update]}, _,
             [
               freq,
               elem,
               1,
               {:&, _, [{:+, _, [{:&, _, [1]}, 1]}]}
             ]}
          ]},
         freq_var,
         elem_var
       ) do
    freq == freq_var and elem == elem_var
  end

  defp frequencies_update(_, _, _), do: false

  def map_new_pattern(initials, body) do
    with [{acc_name, {:%{}, _, []}}] <- initials,
         {:__block__, _, [exit, destructure, update]} <- body,
         acc_var = {acc_name, [], nil},
         {list_var, ^acc_var} <- map_new_exit(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, key_expr, val_expr} <- map_new_update(update, acc_var, elem_var) do
      quote do
        Map.new(unquote(list_var), fn unquote(elem_var) ->
          {unquote(key_expr), unquote(val_expr)}
        end)
      end
    else
      _ -> nil
    end
  end

  defp map_new_exit({:if, _, [condition, [do: {:break, _, [acc]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> {list, acc}
      nil -> nil
    end
  end

  defp map_new_exit(_), do: nil

  # acc = Map.put(acc, key_expr, val_expr)
  defp map_new_update(
         {:=, _,
          [
            acc,
            {{:., _, [{:__aliases__, _, [:Map]}, :put]}, _, [acc, key_expr, val_expr]}
          ]},
         acc_var,
         elem_var
       ) do
    if acc == acc_var and has_var?(key_expr, elem_var) do
      {acc_var, key_expr, val_expr}
    else
      nil
    end
  end

  defp map_new_update(_, _, _), do: nil

  # Into MapSet Pattern: set = MapSet.put(set, value)
  def into_mapset_pattern(initials, body) do
    with [{set_name, _init}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: [update]} <-
           list_loop_ir(body),
         set_var = {set_name, [], nil},
         true <- break_expr == set_var,
         {^set_var, value_expr} <- into_mapset_update(update, set_var, elem_var),
         true <- has_var?(value_expr, elem_var) do
      into_mapset_quote(list_var, elem_var, value_expr)
    else
      _ -> nil
    end
  end

  defp into_mapset_quote(list_var, elem_var, value_expr) when value_expr == elem_var do
    quote do
      MapSet.new(unquote(list_var))
    end
  end

  defp into_mapset_quote(list_var, elem_var, value_expr) do
    quote do
      MapSet.new(unquote(list_var), fn unquote(elem_var) -> unquote(value_expr) end)
    end
  end

  defp into_mapset_update(
         {:=, _, [set, {{:., _, [{:__aliases__, _, [:MapSet]}, :put]}, _, [set, value_expr]}]},
         set_var,
         _elem_var
       ) do
    if set == set_var do
      {set_var, value_expr}
    else
      nil
    end
  end

  defp into_mapset_update(_, _, _), do: nil
end
