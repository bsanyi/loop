defmodule Loop.Patterns.Search do
  @moduledoc false

  import Loop.Patterns.Helpers

  defp index_target_from_condition({op, _, [left, right]}, index_var) when op in [:==, :===] do
    cond do
      left == index_var -> right
      right == index_var -> left
      true -> nil
    end
  end

  defp index_target_from_condition(
         {{:., _, [{:__aliases__, _, [:Kernel]}, op]}, _, [left, right]},
         index_var
       )
       when op in [:==, :===] do
    index_target_from_condition({op, [], [left, right]}, index_var)
  end

  defp index_target_from_condition(_, _), do: nil

  # Find Pattern: no accumulator, returns first matching element or nil
  def find_pattern([], body) do
    with {:__block__, _, [exit_empty, destructure, check]} <- body,
         list_var <- find_exit_empty(exit_empty),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^elem_var, condition} <- find_check(check, elem_var) do
      quote do
        unquote(list_var) |> Enum.find(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> find_pattern_ir(body)
    end
  end

  def find_pattern(_, _), do: nil

  defp find_pattern_ir(body) do
    with %{list_var: list_var, elem_var: elem_var, break_expr: nil, steps: steps} <-
           list_loop_ir(body),
         condition when not is_nil(condition) <- find_condition_from_steps(steps, elem_var) do
      quote do
        Enum.find(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp find_condition_from_steps(steps, elem_var) do
    Enum.find_value(steps, &find_condition_break(&1, elem_var))
  end

  defp find_condition_break(step, elem_var) do
    case conditional_break(step) do
      {condition, payload} ->
        if same_var_ast?(payload, elem_var) and has_var?(condition, elem_var), do: condition

      _ ->
        nil
    end
  end

  defp find_exit_empty({:if, _, [condition, [do: {:break, _, [nil]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> list
      nil -> nil
    end
  end

  defp find_exit_empty(_), do: nil

  defp find_check({:if, _, [condition, [do: {:break, _, [elem]}]]}, elem_var)
       when elem == elem_var do
    {elem_var, condition}
  end

  defp find_check(_, _), do: nil

  def find_default_pattern([], body) do
    with %{list_var: list_var, elem_var: elem_var, break_expr: default_expr, steps: steps} <-
           list_loop_ir(body),
         true <- default_expr != nil,
         true <- Macro.quoted_literal?(default_expr),
         condition when not is_nil(condition) <- find_condition_from_steps(steps, elem_var),
         false <- has_var_name?(condition, list_var) do
      quote do
        Enum.find(unquote(list_var), unquote(default_expr), fn unquote(elem_var) ->
          unquote(condition)
        end)
      end
    else
      _ -> nil
    end
  end

  def find_default_pattern(_, _), do: nil

  # Find Value Pattern: break on first truthy mapped value
  def find_value_pattern([], body) do
    with %{list_var: list_var, elem_var: elem_var, break_expr: nil, steps: steps} <-
           list_loop_ir(body),
         mapper when not is_nil(mapper) <- find_value_mapper(steps, elem_var),
         false <- has_var_name?(mapper, list_var) do
      quote do
        Enum.find_value(unquote(list_var), fn unquote(elem_var) -> unquote(mapper) end)
      end
    else
      _ -> find_value_pattern_hd_tl(body)
    end
  end

  def find_value_pattern(_, _), do: nil

  def find_value_default_pattern([], body) do
    with %{list_var: list_var, elem_var: elem_var, break_expr: default_expr, steps: steps} <-
           list_loop_ir(body),
         true <- default_expr != nil,
         true <- Macro.quoted_literal?(default_expr),
         mapper when not is_nil(mapper) <- find_value_mapper(steps, elem_var),
         false <- has_var_name?(mapper, list_var) do
      quote do
        Enum.find_value(unquote(list_var), unquote(default_expr), fn unquote(elem_var) ->
          unquote(mapper)
        end)
      end
    else
      _ -> nil
    end
  end

  def find_value_default_pattern(_, _), do: nil

  defp find_value_mapper(steps, elem_var) do
    aliases = elem_aliases(steps, elem_var)

    find_assignment_mapper(steps, aliases) || find_conditional_mapper(steps, aliases)
  end

  defp find_assignment_mapper(steps, aliases) do
    Enum.find_value(Enum.with_index(steps), fn
      {{:=, _, [value_var, value_expr]}, idx} ->
        if has_any_var?(value_expr, aliases) and
             assignment_breaks_with_value?(steps, idx, value_var) do
          value_expr
        end

      _ ->
        nil
    end)
  end

  defp assignment_breaks_with_value?(steps, idx, value_var) do
    Enum.any?(Enum.drop(steps, idx + 1), &break_matches_value?(&1, value_var))
  end

  defp break_matches_value?(step, value_var) do
    case conditional_break(step) do
      {condition, payload} -> condition == value_var and payload == value_var
      _ -> false
    end
  end

  defp find_conditional_mapper(steps, aliases) do
    Enum.find_value(steps, &conditional_mapper_from_step(&1, aliases))
  end

  defp conditional_mapper_from_step(step, aliases) do
    case conditional_break(step) do
      {condition, payload} ->
        if has_any_var?(condition, aliases) and has_any_var?(payload, aliases) and
             payload not in aliases do
          {:if, [], [condition, [do: payload, else: nil]]}
        end

      _ ->
        nil
    end
  end

  defp find_value_pattern_hd_tl({:__block__, _, [exit_empty, assign, check, advance]}) do
    with list_var when not is_nil(list_var) <- find_exit_empty(exit_empty),
         {value_var, value_expr} <- value_assignment(assign),
         {^value_var, ^value_var} <- conditional_break(check),
         ^list_var <- next_step(advance),
         elem_var = {:elem, [], Elixir},
         hd_expr = {:hd, [], [list_var]},
         mapper = replace_var(value_expr, hd_expr, elem_var),
         true <- has_var?(mapper, elem_var) do
      quote do
        Enum.find_value(unquote(list_var), fn unquote(elem_var) -> unquote(mapper) end)
      end
    else
      _ -> nil
    end
  end

  defp find_value_pattern_hd_tl(_), do: nil

  defp value_assignment({:=, _, [{name, _, ctx} = var, value_expr]})
       when is_atom(name) and is_atom(ctx),
       do: {var, value_expr}

  defp value_assignment(_), do: nil
  # Member? Pattern: break(false) on empty, break(true) on equality match
  def member_pattern([], body) do
    with {:__block__, _, [exit_empty, destructure, check]} <- body,
         list_var <- member_exit_empty(exit_empty),
         {^list_var, elem_var} <- map_destructure(destructure),
         target when not is_nil(target) <- member_check(check, elem_var) do
      quote do
        Enum.member?(unquote(list_var), unquote(target))
      end
    else
      _ -> member_pattern_ir(body)
    end
  end

  def member_pattern(_, _), do: nil

  defp member_pattern_ir(body) do
    with %{list_var: list_var, elem_var: elem_var, break_expr: false, steps: steps} <-
           list_loop_ir(body),
         target when not is_nil(target) <- member_target_from_steps(steps, elem_var) do
      quote do
        Enum.member?(unquote(list_var), unquote(target))
      end
    else
      _ -> nil
    end
  end

  defp member_target_from_steps(steps, elem_var) do
    aliases = elem_aliases(steps, elem_var)

    Enum.find_value(steps, fn step ->
      case conditional_break(step) do
        {condition, true} -> equality_target_with_aliases(condition, aliases)
        _ -> nil
      end
    end)
  end

  defp member_exit_empty({:if, _, [condition, [do: {:break, _, [false]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> list
      nil -> nil
    end
  end

  defp member_exit_empty(_), do: nil

  defp member_check({:if, _, [{:==, _, [elem, target]}, [do: {:break, _, [true]}]]}, elem_var) do
    cond do
      elem == elem_var -> target
      target == elem_var -> elem
      true -> nil
    end
  end

  defp member_check(_, _), do: nil

  defp equality_target_with_aliases({op, _, [left, right]}, aliases) when op in [:==, :===] do
    cond do
      left in aliases -> right
      right in aliases -> left
      true -> nil
    end
  end

  defp equality_target_with_aliases(
         {{:., _, [{:__aliases__, _, [:Kernel]}, op]}, _, [left, right]},
         aliases
       )
       when op in [:==, :===] do
    equality_target_with_aliases({op, [], [left, right]}, aliases)
  end

  defp equality_target_with_aliases(_, _), do: nil

  # Find Index Pattern: init index: 0, break nil on empty, conditional break with index, increment
  def find_index_pattern(initials, body) do
    with [{index_name, 0}] <- initials,
         {:__block__, _, [exit_empty, destructure, check, increment]} <- body,
         list_var <- find_exit_empty(exit_empty),
         {^list_var, elem_var} <- map_destructure(destructure),
         index_var = {index_name, [], nil},
         condition <- find_index_check(check, index_var, elem_var),
         ^index_var <- find_index_increment(increment, index_var) do
      quote do
        unquote(list_var) |> Enum.find_index(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> find_index_pattern_ir(initials, body)
    end
  end

  defp find_index_pattern_ir([{index_name, 0}], body) do
    index_var = {index_name, [], nil}

    with %{list_var: list_var, elem_var: elem_var, break_expr: nil, steps: steps} <-
           list_loop_ir(body),
         condition when not is_nil(condition) <-
           Enum.find_value(steps, fn step -> find_index_check(step, index_var, elem_var) end),
         true <- Enum.any?(steps, &(find_index_increment(&1, index_var) == index_var)) do
      quote do
        Enum.find_index(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp find_index_pattern_ir(_, _), do: nil

  # P026: Find Index with non-zero integer offset
  # loop index: k do ... if cond(h), do: break(index); index = index + 1 end
  # => case Enum.find_index(list, fn h -> cond end) do nil -> nil; idx -> k + idx end
  def find_index_offset_pattern(initials, body) do
    with [{index_name, offset}] when is_integer(offset) <- initials,
         index_var = {index_name, [], nil},
         %{list_var: list_var, elem_var: elem_var, break_expr: nil, steps: steps} <-
           list_loop_ir(body),
         condition when not is_nil(condition) <-
           Enum.find_value(steps, fn step -> find_index_check(step, index_var, elem_var) end),
         true <- Enum.any?(steps, &(find_index_increment(&1, index_var) == index_var)) do
      find_index_offset_ast(list_var, elem_var, condition, offset)
    else
      _ -> nil
    end
  end

  defp find_index_offset_ast(list_var, elem_var, condition, offset) do
    quote do
      case Enum.find_index(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end) do
        nil -> nil
        idx -> unquote(offset) + idx
      end
    end
  end

  # P028: Fetch pattern — break {:ok, h} on match, :error on empty
  # loop index: 0 do ... if index == wanted, do: break({:ok, h}); index = index + 1 end
  # => if is_integer(n) and n >= 0, do: Enum.fetch(list, n), else: :error
  def fetch_pattern(initials, body) do
    with [{index_name, 0}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: :error, steps: steps} <-
           list_loop_ir(body),
         index_var = {index_name, [], nil},
         target when not is_nil(target) <- fetch_target(steps, index_var, elem_var),
         true <- Enum.any?(steps, &(find_index_increment(&1, index_var) == index_var)) do
      quote do
        n = unquote(target)

        if is_integer(n) and n >= 0 do
          Enum.fetch(unquote(list_var), n)
        else
          :error
        end
      end
    else
      _ -> nil
    end
  end

  defp fetch_target(steps, index_var, elem_var) do
    aliases = elem_aliases(steps, elem_var)
    Enum.find_value(steps, &fetch_target_from_step(&1, aliases, index_var))
  end

  defp fetch_target_from_step(step, aliases, index_var) do
    case conditional_break(step) do
      {condition, {:ok, payload}} ->
        if payload in aliases, do: index_target_from_condition(condition, index_var)

      _ ->
        nil
    end
  end

  defp find_index_check({:if, _, [condition, [do: {:break, _, [index]}]]}, index_var, elem_var) do
    if index == index_var and has_var?(condition, elem_var) do
      condition
    else
      nil
    end
  end

  defp find_index_check(_, _, _), do: nil

  # Find At Pattern with default: explicit index target lookup with empty-list fallback
  def find_at_default_pattern(initials, body) do
    with [{index_name, 0}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: default_expr, steps: steps} <-
           list_loop_ir(body),
         true <- default_expr != nil,
         index_var = {index_name, [], nil},
         target when not is_nil(target) <- find_at_target(steps, index_var, elem_var),
         true <- Enum.any?(steps, &(find_index_increment(&1, index_var) == index_var)),
         false <- has_var_name?(default_expr, list_var),
         false <- has_var_name?(default_expr, index_var),
         aliases <- elem_aliases(steps, elem_var),
         false <- has_any_var?(default_expr, aliases) do
      find_at_default_quote(list_var, target, default_expr)
    else
      _ -> nil
    end
  end

  defp find_at_default_quote(list_var, target, default_expr) do
    quote do
      n = unquote(target)
      default = unquote(default_expr)

      if is_integer(n) and n >= 0 do
        Enum.at(unquote(list_var), n, default)
      else
        default
      end
    end
  end

  # P027: Find At with non-zero integer offset
  # loop index: k do ... if index == wanted, do: break(h); index = index + 1 end
  # => if is_integer(n) and n >= k, do: Enum.at(list, n - k), else: nil
  def find_at_offset_pattern(initials, body) do
    with [{index_name, offset}] when is_integer(offset) and offset != 0 <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: nil, steps: steps} <-
           list_loop_ir(body),
         index_var = {index_name, [], nil},
         target when not is_nil(target) <- find_at_target(steps, index_var, elem_var),
         true <- Enum.any?(steps, &(find_index_increment(&1, index_var) == index_var)) do
      quote do
        n = unquote(target)

        if is_integer(n) and n >= unquote(offset) do
          Enum.at(unquote(list_var), n - unquote(offset))
        else
          nil
        end
      end
    else
      _ -> nil
    end
  end

  # P027 with default: loop index: k, break(default) on empty
  def find_at_default_offset_pattern(initials, body) do
    with [{index_name, offset}] when is_integer(offset) and offset != 0 <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: default_expr, steps: steps} <-
           list_loop_ir(body),
         true <- default_expr != nil,
         index_var = {index_name, [], nil},
         target when not is_nil(target) <- find_at_target(steps, index_var, elem_var),
         true <- Enum.any?(steps, &(find_index_increment(&1, index_var) == index_var)),
         false <- has_var_name?(default_expr, list_var),
         false <- has_var_name?(default_expr, index_var),
         aliases <- elem_aliases(steps, elem_var),
         false <- has_any_var?(default_expr, aliases) do
      quote do
        n = unquote(target)
        default = unquote(default_expr)

        if is_integer(n) and n >= unquote(offset) do
          Enum.at(unquote(list_var), n - unquote(offset), default)
        else
          default
        end
      end
    else
      _ -> nil
    end
  end

  # Find At Pattern: explicit index target lookup
  def find_at_pattern(initials, body) do
    with [{index_name, 0}] <- initials,
         %{list_var: list_var, elem_var: elem_var, break_expr: nil, steps: steps} <-
           list_loop_ir(body),
         index_var = {index_name, [], nil},
         target when not is_nil(target) <- find_at_target(steps, index_var, elem_var),
         true <- Enum.any?(steps, &(find_index_increment(&1, index_var) == index_var)) do
      find_at_quote(list_var, target)
    else
      _ -> nil
    end
  end

  defp find_at_quote(list_var, target) do
    quote do
      n = unquote(target)

      if is_integer(n) and n >= 0 do
        Enum.at(unquote(list_var), n)
      else
        Enum.find_value(Enum.with_index(unquote(list_var)), fn
          {elem, idx} when idx == n -> elem
          _ -> nil
        end)
      end
    end
  end

  defp find_at_target(steps, index_var, elem_var) do
    aliases = elem_aliases(steps, elem_var)

    Enum.find_value(steps, &find_at_target_from_step(&1, aliases, index_var))
  end

  defp find_at_target_from_step(step, aliases, index_var) do
    case conditional_break(step) do
      {condition, payload} ->
        if payload in aliases, do: index_target_from_condition(condition, index_var)

      _ ->
        nil
    end
  end

  # end
  # => case Enum.find_index(list, fn h -> pred(h) end) do nil -> {false, nil}; i -> {true, i} end
  def any_with_index_pattern(initials, body) do
    with [{index_name, 0}] <- initials,
         index_var = {index_name, [], nil},
         %{list_var: list_var, elem_var: elem_var, break_expr: {false, nil}, steps: steps} <-
           list_loop_ir(body),
         condition when not is_nil(condition) <-
           Enum.find_value(steps, fn step -> any_with_index_check(step, index_var, elem_var) end),
         true <- Enum.any?(steps, &(find_index_increment(&1, index_var) == index_var)) do
      quote do
        case Enum.find_index(unquote(list_var), fn unquote(elem_var) -> unquote(condition) end) do
          nil -> {false, nil}
          unquote(index_var) -> {true, unquote(index_var)}
        end
      end
    else
      _ -> nil
    end
  end

  # Matches `if pred(h), do: break({true, i})`
  defp any_with_index_check(
         {:if, _, [condition, [do: {:break, _, [break_payload]}]]},
         index_var,
         elem_var
       ) do
    case break_payload do
      {true, ^index_var} ->
        if has_var?(condition, elem_var), do: condition

      _ ->
        nil
    end
  end

  defp any_with_index_check(_, _, _), do: nil
end
