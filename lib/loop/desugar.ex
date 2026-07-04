defmodule Loop.Desugar do
  @moduledoc false

  import Loop.Patterns.Helpers

  # ============================================================================
  # Tuple-Assignment Desugaring
  # ============================================================================
  # Converts `{v1, v2} = if/case ...` into block forms existing patterns handle.

  def desugar_tuple_assign({:=, _, [{v1, v2}, rhs]}) when is_tuple(v1) and is_tuple(v2) do
    case extract_break_continue(rhs) do
      nil -> nil
      result -> desugar_extracted(v1, v2, result)
    end
  end

  def desugar_tuple_assign(_), do: nil

  # Continue is a block — try direct extraction, then collapse assignments into a tuple
  defp desugar_extracted(v1, v2, {list_var, break_expr, {:__block__, _, exprs}}) do
    desugar_block_continue(v1, v2, list_var, break_expr, exprs) ||
      with {_, _} = collapsed <- collapse_block(exprs) do
        build_desugared_forms(v1, v2, list_var, break_expr, collapsed)
      end
  end

  # Continue is a simple tuple
  defp desugar_extracted(v1, v2, {list_var, break_expr, continue_tuple}) do
    build_desugared_forms(v1, v2, list_var, break_expr, continue_tuple)
  end

  # Case with block continue and [h | rest] bindings
  defp desugar_extracted(
         v1,
         v2,
         {list_var, break_expr, {:__block__, _, exprs}, elem_var, rest_var}
       ) do
    desugar_block_continue_case(v1, v2, list_var, break_expr, exprs, elem_var, rest_var) ||
      with {_, _} = collapsed <- collapse_block(exprs) do
        build_desugared_forms_case(v1, v2, list_var, break_expr, collapsed, elem_var, rest_var)
      end
  end

  # Case with simple tuple continue and [h | rest] bindings
  defp desugar_extracted(v1, v2, {list_var, break_expr, continue_tuple, elem_var, rest_var}) do
    build_desugared_forms_case(v1, v2, list_var, break_expr, continue_tuple, elem_var, rest_var)
  end

  # When the continue branch is a block ending with {v1, v2} matching the LHS,
  # the inner assignments ARE the desugared body — just prepend the exit check.
  # e.g. `product = product * hd(list); list = tl(list); {list, product}`
  #   => `if list == [], do: break(product); product = product * hd(list); list = tl(list)`
  defp desugar_block_continue(v1, v2, list_var, break_expr, exprs) do
    {body_exprs, [last]} = Enum.split(exprs, -1)

    if last == {v1, v2} and body_exprs != [] do
      exit_check =
        {:if, [], [{:==, [], [list_var, []]}, [do: {:break, [], [break_expr]}]]}

      [{:__block__, [], [exit_check | body_exprs]}]
    else
      nil
    end
  end

  # Same as above but for case with [h | rest] bindings
  defp desugar_block_continue_case(v1, v2, list_var, break_expr, exprs, _elem_var, _rest_var) do
    desugar_block_continue(v1, v2, list_var, break_expr, exprs)
  end

  # Collapse a block by inlining local variable assignments into the final expression.
  # e.g. [prod = x * y, {tl(list), prod}] => {tl(list), x * y}
  defp collapse_block(exprs) when length(exprs) >= 2 do
    {preceding, [last]} = Enum.split(exprs, -1)

    # Only collapse when ALL preceding expressions are simple variable assignments
    subs =
      Enum.reduce_while(preceding, [], fn
        {:=, _, [{name, _, ctx}, expr]}, acc when is_atom(name) and is_atom(ctx) ->
          {:cont, [{name, ctx, expr} | acc]}

        _, _acc ->
          {:halt, :error}
      end)

    case subs do
      :error ->
        nil

      sub_list ->
        # sub_list is reversed (last assignment first) — correct substitution order
        Enum.reduce(sub_list, last, fn {name, ctx, expr}, ast ->
          replace_var(ast, {name, [], ctx}, expr)
        end)
    end
  end

  defp collapse_block(_), do: nil

  # Extract break/continue from if/case RHS
  defp extract_break_continue({:if, _, [condition, [do: do_branch, else: else_branch]]}) do
    cond do
      # if list == [], do: break(x), else: {a, b}
      match = empty_list_check?(condition) ->
        {list_var, _} = match

        case do_branch do
          {:break, _, [break_expr]} -> {list_var, break_expr, else_branch}
          _ -> nil
        end

      # if list != [], do: {a, b}, else: break(x)
      match = non_empty_list_check?(condition) ->
        {list_var, _} = match

        case else_branch do
          {:break, _, [break_expr]} -> {list_var, break_expr, do_branch}
          _ -> nil
        end

      true ->
        nil
    end
  end

  defp extract_break_continue({:case, _, [scrutinee, [do: clauses]]}) do
    extract_break_continue_case(scrutinee, clauses)
  end

  defp extract_break_continue(_), do: nil

  defp extract_break_continue_case(scrutinee, clauses) when is_list(clauses) do
    # Find the break clause (matches []) and the continue clause
    {break_clause, continue_clause} = find_break_continue_clauses(clauses)

    case {break_clause, continue_clause} do
      {nil, _} ->
        nil

      {_, nil} ->
        nil

      {{_, break_expr}, {:wildcard, continue_expr}} ->
        # case list do [] -> break(x); _ -> {a, b} end
        {scrutinee, break_expr, continue_expr}

      {{_, break_expr}, {:cons, elem_var, rest_var, continue_expr}} ->
        # case list do [] -> break(x); [h | rest] -> {a, b} end
        {scrutinee, break_expr, continue_expr, elem_var, rest_var}
    end
  end

  # Build desugared forms for if-based tuple assign (no case bindings)
  defp build_desugared_forms(v1, v2, list_var, break_expr, {cont1, cont2}) do
    # Determine which variable is the list variable
    # by checking which continue element is tl(list_var)
    {list_pos, acc_var, acc_update} =
      cond do
        tl_of?(cont1, list_var) -> {:first, v2, cont2}
        tl_of?(cont2, list_var) -> {:second, v1, cont1}
        true -> {nil, nil, nil}
      end

    case list_pos do
      nil ->
        nil

      _ ->
        exit_check =
          {:if, [], [{:==, [], [list_var, []]}, [do: {:break, [], [break_expr]}]]}

        h_var = {:h, [], nil}

        # Form 1: destructure style — replace hd(list) with h
        destructure_form =
          {:__block__, [],
           [
             exit_check,
             {:=, [], [[{:|, [], [h_var, list_var]}], list_var]},
             {:=, [], [acc_var, replace_hd(acc_update, list_var, h_var)]}
           ]}

        # Form 2: hd/tl style — preserve hd(list)/tl(list)
        reduce_form =
          {:__block__, [],
           [
             exit_check,
             {:=, [], [acc_var, acc_update]},
             {:=, [], [list_var, {:tl, [], [list_var]}]}
           ]}

        [destructure_form, reduce_form]
    end
  end

  defp build_desugared_forms(_, _, _, _, _), do: nil

  # Build desugared forms for case with [h | rest] bindings
  defp build_desugared_forms_case(
         v1,
         v2,
         list_var,
         break_expr,
         continue_tuple,
         elem_var,
         rest_var
       ) do
    {cont1, cont2} =
      case continue_tuple do
        {c1, c2} -> {c1, c2}
        _ -> {nil, nil}
      end

    # Find which position holds the rest variable (maps to list_var)
    {list_pos, acc_var, acc_update} =
      cond do
        cont1 == rest_var -> {:first, v2, cont2}
        cont2 == rest_var -> {:second, v1, cont1}
        true -> {nil, nil, nil}
      end

    case list_pos do
      nil ->
        nil

      _ ->
        exit_check =
          {:if, [], [{:==, [], [list_var, []]}, [do: {:break, [], [break_expr]}]]}

        # Only destructure form makes sense for case with [h | rest]
        # Replace rest_var with list_var in acc_update
        acc_update = replace_var(acc_update, rest_var, list_var)

        destructure_form =
          {:__block__, [],
           [
             exit_check,
             {:=, [], [[{:|, [], [elem_var, list_var]}], list_var]},
             {:=, [], [acc_var, acc_update]}
           ]}

        [destructure_form]
    end
  end
end
