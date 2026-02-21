defmodule Loop do
  @moduledoc """
  An imperative style loop macro implementation.

  ## Usage:

      use Loop

      loop do
        ...
      end

  For further information and examples look at the help page of `Loop.loop`:

      iex> use Loop
      iex> h loop

  This is a demo that macros are actually powerful enough to simulate something
  alien in functional programming like a loop with seamingliy mutable state.

  Yes, we can do it. But I'm not at all saying we shoud do it.

  This thing is instead a proof of concept for myself.  We can use imperative
  style loop code, and have macros that recognize certain patterns of the loop
  and translate it inder the hood into a functional pattern, like an
  `Enum.reduce` or even an `Enum.sum`.

  ## Recognized Optimization Patterns

  The Loop module automatically recognizes and optimizes the following 26 patterns:

  ### 1. Map
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [transform(h) | acc]
      end
      # => Enum.map(list, fn h -> transform(h) end)

  ### 2. Filter
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if condition(h), do: [h | acc], else: acc
      end
      # => Enum.filter(list, fn h -> condition(h) end)

  ### 3. Reject
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if condition(h), do: acc, else: [h | acc]
      end
      # => Enum.reject(list, fn h -> condition(h) end)

  ### 4. Reverse
      loop acc: [] do
        if list == [], do: break(acc)
        [h | list] = list
        acc = [h | acc]
      end
      # => Enum.reverse(list)

  ### 5. Filter+Map
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if condition(h), do: [transform(h) | acc], else: acc
      end
      # => for h <- list, condition(h), do: transform(h)

  ### 6. Find
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if condition(h), do: break(h)
      end
      # => Enum.find(list, fn h -> condition(h) end)

  ### 7. Member?
      loop do
        if list == [], do: break(false)
        [h | list] = list
        if h == target, do: break(true)
      end
      # => Enum.member?(list, target)

  ### 8. Find Index
      loop index: 0 do
        if list == [], do: break(nil)
        [h | list] = list
        if condition(h), do: break(index)
        index = index + 1
      end
      # => Enum.find_index(list, fn h -> condition(h) end)

  ### 9. Count
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if condition(h), do: count + 1, else: count
      end
      # => Enum.count(list, fn h -> condition(h) end)

  ### 10. Length
      loop count: 0 do
        if list == [], do: break(count)
        [_ | list] = list
        count = count + 1
      end
      # => length(list)

  ### 11. Any
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result or condition(h)
      end
      # => Enum.any?(list, fn h -> condition(h) end)

  ### 12. All
      loop result: true do
        if list == [], do: break(result)
        [h | list] = list
        result = result and condition(h)
      end
      # => Enum.all?(list, fn h -> condition(h) end)

  ### 13. Each
      loop do
        if list == [], do: break()
        [h | list] = list
        side_effect(h)
      end
      # => Enum.each(list, fn h -> side_effect(h) end)

  ### 14. Take While
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if condition(h), do: [h | acc], else: break(Enum.reverse(acc))
      end
      # => Enum.take_while(list, fn h -> condition(h) end)

  ### 15. Drop While
      loop do
        if list == [], do: break([])
        [h | list] = list
        unless condition(h), do: break([h | list])
      end
      # => Enum.drop_while(list, fn h -> condition(h) end)

  ### 16. With Index
      loop acc: [], i: 0 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{h, i} | acc]
        i = i + 1
      end
      # => Enum.with_index(list)

  ### 17. Zip
      loop acc: [] do
        if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
        [h1 | list1] = list1
        [h2 | list2] = list2
        acc = [{h1, h2} | acc]
      end
      # => Enum.zip(list1, list2)

  ### 18. Reduce While
      loop acc: init do
        if list == [], do: break(acc)
        [h | list] = list
        if stop_condition(h, acc), do: break(acc)
        acc = transform(h, acc)
      end
      # => Enum.reduce_while(list, init, fn h, acc -> ... end)

  ### 19. Dedup
      loop acc: [], prev: nil do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h == prev, do: acc, else: [h | acc]
        prev = h
      end
      # => Enum.dedup(list)

  ### 20. Max
      loop best: hd(list) do
        list = tl(list)
        if list == [], do: break(best)
        best = max(best, hd(list))
      end
      # => Enum.max(list)

  ### 21. Min
      loop best: hd(list) do
        list = tl(list)
        if list == [], do: break(best)
        best = min(best, hd(list))
      end
      # => Enum.min(list)

  ### 22. Frequencies
      loop freq: %{} do
        if list == [], do: break(freq)
        [h | list] = list
        freq = Map.update(freq, h, 1, &(&1 + 1))
      end
      # => Enum.frequencies(list)

  ### 23. Map.new
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.put(acc, key_fn(h), val_fn(h))
      end
      # => Map.new(list, fn h -> {key_fn(h), val_fn(h)} end)

  ### 24. Scan
      loop acc: [], running: init do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        running = running + h
        acc = [running | acc]
      end
      # => Enum.scan(list, init, &+/2)

  ### 25. Sum
      loop sum: 0 do
        if list == [], do: break(sum)
        sum = sum + hd(list)
        list = tl(list)
      end
      # => Enum.sum(list)

  ### 26. Product / Reduce
      loop acc: init do
        if list == [], do: break(acc)
        acc = acc op hd(list)
        list = tl(list)
      end
      # => Enum.product(list) when init=1 and op=*
      # => Enum.reduce(list, init, fn x, acc -> acc op x end)

  """

  defmacro __using__(_) do
    quote do
      require Loop
      import Loop, only: [loop: 1, loop: 2]
    end
  end

  @doc """
  Simulates an imperative style infinite loop that can be exited with
  `break(value)`.

      loop do
        IO.write("and again ")
        Process.sleep(500)
      end

  Add `use Loop` to your module in order to use Loop. It will import a `loop`
  macro that can be used as explained below. If you want to go without the
  import, simply `require Loop` and use `Loop.loop` instead of `loop` in the
  coming examples.

  This will print a random pattern to the terminal:

      loop do: IO.write(Enum.random(["░", "▒", "▓", "█"]))

  Just like this, but this time with some colors:

      items = ["▙", "▚", "▛", "▜", "▞", "▟"]

      loop do
        IO.write(Enum.random([IO.ANSI.red(), IO.ANSI.green(), IO.ANSI.blue()]))
        IO.write(Enum.random(items))
        Process.sleep(100)
        IO.write(IO.ANSI.cursor_left())
      end

  ## `break()` out of the loop

  `loop` runs infinitely unless you escape from the loop with `break(value)`.
  The return value if the `loop do ... end` will be `value`. If used as
  `break()`, `nil` is returned. This just returns `123`:

      loop do
        break(123)
      end

  ## Simulation of mutable state

  The bindings from the end of the `do ... end` block are carreid over to the
  next execution of the block. The following example prints 0, 1, 2, and so on
  without ever stopping:

      i = 0

      loop do
        IO.puts(i)
        i = i + 1
      end

  This is how you can stop at, let's say 100:

      i = 0

      loop do
        IO.puts(i)

        if i == 100 do
          break()
        end

        i = i + 1
      end

  A shorter form of the above looks like this:

      loop i: 0 do
        IO.puts(i)
        i = if i == 100, do: break(), else: i + 1
      end

  You can use more than one initiali values, like a `step`ing value here:

      loop i: 0, step: 2 do
        IO.puts(i)
        i = i + step
      end

  ## `loop` just returns values, but does not change variables

  This prints the numbers from 10 down to 1 and at the end return the value
  `{:final, 1}`.  It also demonstrated that the loop cannot change the
  surrounding environments variables. The value of `a` won't be affected:

      a = 10

      loop do
        IO.puts(a)
        if a < 2, do: break({:final, a})
        a = a - 1
      end # => {:final, 1}

      a #=> 10

  ## Quick and dirty service example

  Let's spawn a counter process that listens for `:inc`, `:dec`, `:get` and
  `:stop` messages:

      pid = spawn_link(fn ->
        loop counter: 0 do
          counter =
            receive do
              :inc -> counter + 1
              :dec -> counter - 1
              {:get, from} -> send(from, counter) ; counter
              :stop -> break()
            end
        end
      end)

  Send it some commands:

      send(pid, :inc)
      send(pid, :inc)
      send(pid, :inc)
      send(pid, :dec)
      send(pid, {:get, self()})
      flush() #=> 2
      send(pid, :stop)

  ## Map a function over a list - but in imperative style

  This will return a list with the items doubled in the original `list`:

      list = [1, 2, 3]

      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [2 * h | acc]
      end

  ## Reduce on a list:

  Let's sum the elements of a `list`:

      list = [1, 2, 3]

      loop [sum: 0] do
        if Enum.empty?(list), do: break(sum)
        sum = sum + hd(list)
        list = tl(list)
      end

  """
  defmacro loop(initial_binding \\ [], do: body) do
    case analyze(initial_binding, body) do
      nil ->
        body =
          body
          |> add_break()
          |> Macro.escape()

        quote bind_quoted: [body: body, initial_binding: initial_binding] do
          b = Kernel.binding()

          loop_fun = fn loop_fun, b ->
            {_result, new_binding} = Code.eval_quoted(body, b, __ENV__)
            loop_fun.(loop_fun, new_binding)
          end

          try do
            {result, _binding} = loop_fun.(loop_fun, Keyword.merge(b, initial_binding))
          catch
            :throw, {:break, value} -> value
          end
        end

      quoted ->
        quoted
        # |> tap(fn ast -> IO.puts("RECOG: #{Macro.to_string(ast)}") end)
    end
  end

  defp add_break(ast) do
    ast
    |> Macro.traverse([], fn etc, acc -> {etc, acc} end, fn
      {:break, meta, [val]}, acc -> {{:throw, meta, [{:break, val}]}, acc}
      {:break, meta, []}, acc -> {{:throw, meta, [{:break, nil}]}, acc}
      etc, acc -> {etc, acc}
    end)
    |> elem(0)
  end

  defp analyze(initials, body) do
    Loop.Analyzer.analyze(initials, body,
      normalize: &normalize/1,
      try_patterns: &try_all_patterns/2,
      desugar_tuple_assign: &desugar_tuple_assign/1
    )
  end

  defp try_all_patterns(initials, body) do
    [
      &map_pattern/2,
      &filter_pattern/2,
      &reject_pattern/2,
      &reverse_pattern/2,
      &filter_map_pattern/2,
      &flat_map_pattern/2,
      &map_reduce_pattern/2,
      &flat_map_reduce_pattern/2,
      &none_pattern/2,
      &find_pattern/2,
      &find_default_pattern/2,
      &find_value_pattern/2,
      &find_value_default_pattern/2,
      &member_pattern/2,
      &find_at_pattern/2,
      &find_index_pattern/2,
      &count_pattern/2,
      &sum_by_pattern/2,
      &length_pattern/2,
      &any_pattern/2,
      &all_pattern/2,
      &each_pattern/2,
      &take_while_pattern/2,
      &drop_while_pattern/2,
      &partition_pattern/2,
      &chunk_every_pattern/2,
      &chunk_by_pattern/2,
      &take_pattern/2,
      &map_intersperse_pattern/2,
      &map_join_pattern/2,
      &map_every_pattern/2,
      &take_every_pattern/2,
      &drop_pattern/2,
      &split_while_pattern/2,
      &split_pattern/2,
      &with_index_pattern/2,
      &zip_with_pattern/2,
      &zip_reduce_pattern/2,
      &zip_pattern/2,
      &unzip_pattern/2,
      &reduce_while_pattern/2,
      &dedup_pattern/2,
      &uniq_pattern/2,
      &uniq_by_pattern/2,
      &min_max_by_pattern/2,
      &max_by_min_by_pattern/2,
      &min_max_pattern/2,
      &max_min_pattern/2,
      &frequencies_pattern/2,
      &frequencies_by_pattern/2,
      &group_by_pattern/2,
      &map_new_pattern/2,
      &into_mapset_pattern/2,
      &scan_pattern/2,
      &reduce_pattern/2
    ]
    |> Enum.find_value(fn matcher -> matcher.(initials, body) end)
  end

  # Strip metadata from AST so that variable nodes at different source
  # positions compare as equal. {:list, [line: 5, col: 12], nil} becomes
  # {:list, [], nil}, making pattern matching metadata-agnostic.
  defp normalize(ast) do
    Macro.prewalk(ast, fn
      {name, _meta, ctx} when is_atom(name) and is_atom(ctx) -> {name, [], ctx}
      {name, _meta, ctx} when is_atom(name) and is_list(ctx) -> {name, [], ctx}
      other -> other
    end)
  end

  # ============================================================================
  # Tuple-Assignment Desugaring
  # ============================================================================
  # Converts `{v1, v2} = if/case ...` into block forms existing patterns handle.

  defp desugar_tuple_assign({:=, _, [{v1, v2}, rhs]}) when is_tuple(v1) and is_tuple(v2) do
    case extract_break_continue(rhs) do
      nil -> nil
      result -> desugar_extracted(v1, v2, result)
    end
  end

  defp desugar_tuple_assign(_), do: nil

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

  defp find_break_continue_clauses(clauses) do
    break_clause =
      Enum.find_value(clauses, fn
        {:->, _, [[[]], {:break, _, [break_expr]}]} -> {:empty, break_expr}
        _ -> nil
      end)

    continue_clause =
      Enum.find_value(clauses, fn
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

  # Check if expr is tl(var)
  defp tl_of?({:tl, _, [arg]}, var), do: arg == var
  defp tl_of?(_, _), do: false

  # Replace hd(list_var) with replacement in AST
  defp replace_hd(ast, list_var, replacement) do
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
  defp non_empty_list_check?(condition) do
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
  defp list_loop_ir(body) do
    case body do
      {:__block__, _, exprs} ->
        list_loop_ir_from_block(exprs)

      {:case, _, [scrutinee, [do: clauses]]} ->
        list_loop_ir_from_case(scrutinee, clauses)

      {:cond, _, [[do: clauses]]} ->
        list_loop_ir_from_cond(clauses)

      _ ->
        nil
    end
  end

  defp list_loop_ir_from_block([exit_expr | tail]) do
    with {list_var, break_expr} <- empty_break_clause(exit_expr),
         {elem_var, steps} <- parse_continue_expr(list_var, tail) do
      %{list_var: list_var, elem_var: elem_var, break_expr: break_expr, steps: steps}
    else
      _ -> nil
    end
  end

  defp list_loop_ir_from_block(_), do: nil

  defp list_loop_ir_from_case(scrutinee, clauses) when is_list(clauses) do
    with {{:empty, break_expr}, continue_clause} <- find_break_continue_clauses(clauses),
         {elem_var, steps} <- case_continue_to_steps(scrutinee, continue_clause) do
      %{list_var: scrutinee, elem_var: elem_var, break_expr: break_expr, steps: steps}
    else
      _ -> nil
    end
  end

  defp list_loop_ir_from_case(_, _), do: nil

  defp list_loop_ir_from_cond(clauses) when is_list(clauses) do
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

  defp list_loop_ir_from_cond(_), do: nil

  defp case_continue_to_steps(list_var, {:cons, elem_var, rest_var, continue_expr}) do
    steps =
      continue_expr
      |> block_exprs()
      |> Enum.map(&replace_var(&1, rest_var, list_var))

    {elem_var, steps}
  end

  defp case_continue_to_steps(list_var, {:wildcard, continue_expr}) do
    parse_continue_expr(list_var, continue_expr)
  end

  defp case_continue_to_steps(_, _), do: nil

  # if empty?(list), do: break(x)
  # unless non_empty?(list), do: break(x)
  defp empty_break_clause({:if, _, [condition, [do: {:break, _, [break_expr]}]]}) do
    case empty_list_check?(condition) do
      {list_var, _} -> {list_var, break_expr}
      _ -> nil
    end
  end

  defp empty_break_clause({:unless, _, [condition, [do: {:break, _, [break_expr]}]]}) do
    case non_empty_list_check?(condition) do
      {list_var, _} -> {list_var, break_expr}
      _ -> nil
    end
  end

  defp empty_break_clause(_), do: nil

  defp cond_break_clause(clauses) do
    Enum.find_value(clauses, fn
      {:->, _, [[condition], {:break, _, [break_expr]}]} -> {condition, break_expr}
      _ -> nil
    end)
  end

  defp cond_continue_clause(clauses, break_condition) do
    Enum.find_value(clauses, fn
      {:->, _, [[condition], expr]} when condition != break_condition -> expr
      _ -> nil
    end)
  end

  defp parse_continue_expr(list_var, exprs) when is_list(exprs) do
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

  defp parse_continue_expr(list_var, continue_expr) do
    parse_continue_expr(list_var, block_exprs(continue_expr))
  end

  defp parse_continue_hd_tl(list_var, [_ | _] = exprs) when is_list(exprs) do
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

  defp parse_continue_hd_tl(_, _), do: nil

  defp block_exprs({:__block__, _, exprs}), do: exprs
  defp block_exprs(expr), do: [expr]

  # Returns {condition, payload} for if/unless conditional breaks.
  defp conditional_break({:if, _, [condition, [do: {:break, _, [payload]}]]}) do
    {condition, payload}
  end

  defp conditional_break({:unless, _, [condition, [do: {:break, _, [payload]}]]}) do
    {{:not, [], [condition]}, payload}
  end

  defp conditional_break(_), do: nil

  defp has_any_var?(ast, vars) when is_list(vars), do: Enum.any?(vars, &has_var?(ast, &1))

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

  # Map Pattern: loop acc: [] with [expr | acc] accumulation
  defp map_pattern([acc: []], body) do
    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, transform} <- map_accumulate(accumulate, elem_var) do
      quote do
        unquote(list_var) |> Enum.map(fn unquote(elem_var) -> unquote(transform) end)
      end
    else
      _ -> nil
    end
  end

  defp map_pattern(_, _), do: nil

  defp map_exit_strategy({:if, _, [condition, [do: {:break, _, [reverse_expr]}]]}) do
    with {{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [acc]} <- reverse_expr,
         {list, ^acc} <- empty_list_check?(condition) do
      {list, acc}
    else
      _ -> nil
    end
  end

  defp map_exit_strategy(_), do: nil

  defp map_destructure({:=, _, [[{:|, _, [h, list]}], list]}) do
    {list, h}
  end

  defp map_destructure(_), do: nil

  defp map_accumulate({:=, _, [acc, {:|, _, [transform, acc]}]}, elem_var) do
    # Verify that transform uses elem_var
    if has_var?(transform, elem_var) do
      {acc, transform}
    else
      nil
    end
  end

  defp map_accumulate(_, _), do: nil

  # Filter Pattern: loop acc: [] with conditional accumulation
  defp filter_pattern([acc: []], body) do
    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, ^elem_var, condition} <- filter_accumulate(accumulate, elem_var) do
      quote do
        unquote(list_var) |> Enum.filter(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp filter_pattern(_, _), do: nil

  defp filter_accumulate(
         {:=, _, [acc, {:if, _, [condition, [do: {:|, _, [elem, acc]}, else: acc]]}]},
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
  defp none_pattern([], body) do
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

  defp none_pattern(_, _), do: nil

  defp none_break_condition(step, aliases) do
    case conditional_break(step) do
      {condition, false} ->
        if has_any_var?(condition, aliases), do: condition

      _ ->
        nil
    end
  end

  # Find Pattern: no accumulator, returns first matching element or nil
  defp find_pattern([], body) do
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

  defp find_pattern(_, _), do: nil

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

  defp find_default_pattern([], body) do
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

  defp find_default_pattern(_, _), do: nil

  # Find Value Pattern: break on first truthy mapped value
  defp find_value_pattern([], body) do
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

  defp find_value_pattern(_, _), do: nil

  defp find_value_default_pattern([], body) do
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

  defp find_value_default_pattern(_, _), do: nil

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

  # Count Pattern: loop count: 0 with conditional increment
  defp count_pattern([count: 0], body) do
    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, count_var} <- count_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^count_var, condition} <- count_accumulate(accumulate, elem_var, count_var) do
      quote do
        unquote(list_var) |> Enum.count(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp count_pattern(_, _), do: nil

  defp sum_by_pattern(initials, body) do
    Loop.Patterns.Advanced.sum_by_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2
    )
  end

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
  defp any_pattern([result: false], body) do
    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, result_var} <- any_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^result_var, condition} <- any_accumulate(accumulate, elem_var, result_var) do
      quote do
        unquote(list_var) |> Enum.any?(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> any_pattern_ir([result: false], body)
    end
  end

  defp any_pattern(_, _), do: nil

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
    # Verify result variable matches
    if result == result_var do
      {result_var, condition}
    else
      nil
    end
  end

  defp any_accumulate(_, _, _), do: nil

  # All Pattern: loop result: true with 'and' operation
  defp all_pattern([result: true], body) do
    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, result_var} <- all_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^result_var, condition} <- all_accumulate(accumulate, elem_var, result_var) do
      quote do
        unquote(list_var) |> Enum.all?(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> all_pattern_ir([result: true], body)
    end
  end

  defp all_pattern(_, _), do: nil

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
    # Verify result variable matches
    if result == result_var do
      {result_var, condition}
    else
      nil
    end
  end

  defp all_accumulate(_, _, _), do: nil

  # Reject Pattern: inverse of filter - keep elements where condition is false
  defp reject_pattern([acc: []], body) do
    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, ^elem_var, condition} <- reject_accumulate(accumulate, elem_var) do
      quote do
        unquote(list_var) |> Enum.reject(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp reject_pattern(_, _), do: nil

  defp reject_accumulate(
         {:=, _, [acc, {:if, _, [condition, [do: acc, else: {:|, _, [elem, acc]}]]}]},
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
  defp reverse_pattern([acc: []], body) do
    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, acc_var} <- reverse_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, ^elem_var} <- reverse_accumulate(accumulate, elem_var) do
      quote do
        Enum.reverse(unquote(list_var))
      end
    else
      _ -> nil
    end
  end

  defp reverse_pattern(_, _), do: nil

  # break(acc) without Enum.reverse
  defp reverse_exit_strategy({:if, _, [condition, [do: {:break, _, [acc]}]]}) do
    case empty_list_check?(condition) do
      {list, _} -> {list, acc}
      nil -> nil
    end
  end

  defp reverse_exit_strategy(_), do: nil

  # acc = [elem | acc] where elem is raw (identity transform)
  defp reverse_accumulate({:=, _, [acc, {:|, _, [elem, acc]}]}, elem_var) do
    if elem == elem_var do
      {acc, elem_var}
    else
      nil
    end
  end

  defp reverse_accumulate(_, _), do: nil

  # Filter+Map Pattern: like filter but with transform in do branch
  defp filter_map_pattern([acc: []], body) do
    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, acc_var} <- map_exit_strategy(exit),
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

  defp filter_map_pattern(_, _), do: nil

  defp filter_map_accumulate(
         {:=, _, [acc, {:if, _, [condition, [do: {:|, _, [transform, acc]}, else: acc]]}]},
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

  defp flat_map_pattern(initials, body) do
    Loop.Patterns.Advanced.flat_map_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp map_reduce_pattern(initials, body) do
    Loop.Patterns.Advanced.map_reduce_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp flat_map_reduce_pattern(initials, body) do
    Loop.Patterns.Advanced.flat_map_reduce_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2
    )
  end

  # Member? Pattern: break(false) on empty, break(true) on equality match
  defp member_pattern([], body) do
    with {:__block__, _, [exit_empty, destructure, check]} <- body,
         list_var <- member_exit_empty(exit_empty),
         {^list_var, elem_var} <- map_destructure(destructure),
         target <- member_check(check, elem_var) do
      quote do
        Enum.member?(unquote(list_var), unquote(target))
      end
    else
      _ -> member_pattern_ir(body)
    end
  end

  defp member_pattern(_, _), do: nil

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
  defp find_index_pattern(initials, body) do
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

  defp find_index_check({:if, _, [condition, [do: {:break, _, [index]}]]}, index_var, elem_var) do
    if index == index_var and has_var?(condition, elem_var) do
      condition
    else
      nil
    end
  end

  defp find_index_check(_, _, _), do: nil

  defp find_index_increment({:=, _, [index, {:+, _, [index, 1]}]}, index_var) do
    if index == index_var, do: index_var
  end

  defp find_index_increment(_, _), do: nil

  # Find At Pattern: explicit index target lookup
  defp find_at_pattern(initials, body) do
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

  # Length Pattern: init count: 0, discard element, unconditional increment
  defp length_pattern(initials, body) do
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
      _ -> nil
    end
  end

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
  defp each_pattern([], body) do
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

  defp each_pattern(_, _), do: nil

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
  defp take_while_pattern([acc: []], body) do
    with {:__block__, _, [exit, destructure, accumulate]} <- body,
         {list_var, acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^acc_var, ^elem_var, condition} <- take_while_accumulate(accumulate, acc_var, elem_var) do
      quote do
        unquote(list_var) |> Enum.take_while(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp take_while_pattern(_, _), do: nil

  defp take_while_accumulate(
         {:=, _,
          [
            acc,
            {:if, _,
             [
               condition,
               [
                 do: {:|, _, [elem, acc]},
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
  defp drop_while_pattern([], body) do
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

  defp drop_while_pattern(_, _), do: nil

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

  defp partition_pattern(initials, body) do
    Loop.Patterns.Collection.partition_pattern(initials, body,
      empty_list_check: &empty_list_check?/1,
      map_destructure: &map_destructure/1,
      list_prepend: &list_prepend?/3,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp chunk_every_pattern(initials, body) do
    Loop.Patterns.Advanced.chunk_every_pattern(initials, body,
      empty_list_check: &empty_list_check?/1,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp chunk_by_pattern(initials, body) do
    Loop.Patterns.Advanced.chunk_by_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp take_pattern(initials, body) do
    Loop.Patterns.Collection.take_pattern(initials, body,
      list_or_zero_check: &list_or_zero_check?/1,
      map_destructure: &map_destructure/1,
      list_prepend: &list_prepend?/3,
      decrement_by_one: &decrement_by_one?/2,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp map_intersperse_pattern(initials, body) do
    Loop.Patterns.Advanced.map_intersperse_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp map_join_pattern(initials, body) do
    Loop.Patterns.Advanced.map_join_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2
    )
  end

  defp map_every_pattern(initials, body) do
    Loop.Patterns.Advanced.map_every_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp take_every_pattern(initials, body) do
    Loop.Patterns.Advanced.take_every_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp drop_pattern(initials, body) do
    Loop.Patterns.Collection.drop_pattern(initials, body,
      list_or_zero_check: &list_or_zero_check?/1,
      decrement_by_one: &decrement_by_one?/2
    )
  end

  defp split_while_pattern(initials, body) do
    Loop.Patterns.Collection.split_while_pattern(initials, body,
      empty_list_check: &empty_list_check?/1,
      map_destructure: &map_destructure/1,
      enum_reverse_arg: &enum_reverse_arg/1,
      has_var: &has_var?/2
    )
  end

  defp split_pattern(initials, body) do
    Loop.Patterns.Collection.split_pattern(initials, body,
      list_or_zero_check: &list_or_zero_check?/1,
      map_destructure: &map_destructure/1,
      list_prepend: &list_prepend?/3,
      decrement_by_one: &decrement_by_one?/2,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp zip_with_pattern(initials, body) do
    Loop.Patterns.Advanced.zip_with_pattern(initials, body,
      map_destructure: &map_destructure/1,
      has_var: &has_var?/2,
      empty_list_check: &empty_list_check?/1,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp zip_reduce_pattern(initials, body) do
    Loop.Patterns.Advanced.zip_reduce_pattern(initials, body,
      map_destructure: &map_destructure/1,
      has_var: &has_var?/2,
      empty_list_check: &empty_list_check?/1
    )
  end

  defp unzip_pattern(initials, body) do
    Loop.Patterns.Advanced.unzip_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  # With Index Pattern: two initial bindings [acc: [], i: 0], accumulate {elem, i} tuples
  defp with_index_pattern(initials, body) do
    with {acc_name, index_name, index_offset} <- with_index_initials(initials),
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

  defp with_index_initials([{acc_name, []}, {index_name, offset}]) when is_integer(offset),
    do: {acc_name, index_name, offset}

  defp with_index_initials([{index_name, offset}, {acc_name, []}]) when is_integer(offset),
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
         {:=, _, [acc, {:|, _, [{:{}, _, [elem, index]}, acc]}]},
         acc_var,
         elem_var,
         index_var
       ) do
    acc == acc_var and elem == elem_var and index == index_var
  end

  defp with_index_accumulate(_, _, _, _), do: false

  # Zip Pattern: two lists, or exit, two destructures, accumulate tuples
  defp zip_pattern([acc: []], body) do
    with {:__block__, _, [exit, destructure1, destructure2, accumulate]} <- body,
         {list1_var, list2_var, acc_var} <- zip_exit_strategy(exit),
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

  defp zip_pattern(_, _), do: nil

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

  # acc = [{elem1, elem2} | acc]
  defp zip_accumulate(
         {:=, _, [acc, {:|, _, [{:{}, _, [elem1, elem2]}, acc]}]},
         acc_var,
         elem1_var,
         elem2_var
       ) do
    acc == acc_var and elem1 == elem1_var and elem2 == elem2_var
  end

  defp zip_accumulate(_, _, _, _), do: false

  # Reduce While Pattern: early exit reduce
  defp reduce_while_pattern(initials, body) do
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
    if acc == acc_var do
      {condition, acc_var}
    else
      nil
    end
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

  # Dedup Pattern: two initial bindings [acc: [], prev: nil], compare to prev
  defp dedup_pattern(initials, body) do
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
          [acc, {:if, _, [{:==, _, [elem, prev]}, [do: acc, else: {:|, _, [elem, acc]}]]}]},
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

  defp uniq_pattern(initials, body) do
    Loop.Patterns.Advanced.uniq_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp uniq_by_pattern(initials, body) do
    Loop.Patterns.Advanced.uniq_by_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2,
      enum_reverse_arg: &enum_reverse_arg/1
    )
  end

  defp min_max_by_pattern(initials, body) do
    Loop.Patterns.Advanced.min_max_by_pattern(initials, body,
      next_step: &next_step/1,
      vars_equal: &vars_equal?/2,
      empty_list_check: &empty_list_check?/1,
      has_var: &has_var?/2,
      replace_var: &replace_var/3
    )
  end

  defp max_by_min_by_pattern(initials, body) do
    Loop.Patterns.Advanced.max_by_min_by_pattern(initials, body,
      next_step: &next_step/1,
      vars_equal: &vars_equal?/2,
      empty_list_check: &empty_list_check?/1,
      has_var: &has_var?/2,
      replace_var: &replace_var/3
    )
  end

  defp min_max_pattern(initials, body) do
    Loop.Patterns.Advanced.min_max_pattern(initials, body,
      next_step: &next_step/1,
      vars_equal: &vars_equal?/2,
      empty_list_check: &empty_list_check?/1
    )
  end

  # Max/Min Pattern: init with hd(list), advance, exit, update with max/min
  defp max_min_pattern(initials, body) do
    with [{best_name, {:hd, _, [init_list]}}] <- initials,
         {:__block__, _, [advance, exit, update]} <- body,
         best_var = {best_name, [], nil},
         list_var <- next_step(advance),
         # verify it's the same list
         true <- vars_equal?(init_list, list_var),
         {^list_var, ^best_var} <- max_min_exit(exit),
         {^best_var, func} <- max_min_update(update, best_var, list_var) do
      case func do
        :max ->
          quote do
            Enum.max(unquote(list_var))
          end

        :min ->
          quote do
            Enum.min(unquote(list_var))
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

  defp max_min_update(_, _, _), do: nil

  # Frequencies Pattern: Map.update(freq, elem, 1, &(&1 + 1))
  defp frequencies_pattern(initials, body) do
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

  defp frequencies_by_pattern(initials, body) do
    Loop.Patterns.Advanced.frequencies_by_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2
    )
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
               {:&, _, [{:/, _, [{:+, _, [{:&, _, [1]}, 1]}, 2]}]}
             ]}
          ]},
         freq_var,
         elem_var
       ) do
    freq == freq_var and elem == elem_var
  end

  defp frequencies_update(_, _, _), do: false

  defp group_by_pattern(initials, body) do
    Loop.Patterns.Advanced.group_by_pattern(initials, body,
      list_loop_ir: &list_loop_ir/1,
      has_var: &has_var?/2
    )
  end

  # Map.new Pattern: Map.put(acc, key_fn(h), val_fn(h))
  defp map_new_pattern(initials, body) do
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
  defp into_mapset_pattern(initials, body) do
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

  # Scan Pattern: two accumulators [acc: [], running: init], running = running op h, acc = [running | acc]
  defp scan_pattern(initials, body) do
    with [{acc_name, []}, {running_name, init}] <- initials,
         {:__block__, _, [exit, destructure, update_running, accumulate]} <- body,
         acc_var = {acc_name, [], nil},
         running_var = {running_name, [], nil},
         {list_var, ^acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         {^running_var, op} <- scan_update_running(update_running, running_var, elem_var),
         true <- scan_accumulate(accumulate, acc_var, running_var) do
      operation =
        {:fn, [],
         [
           {:->, [],
            [
              [{:x, [], Elixir}, {:running, [], Elixir}],
              {op, [], [{:running, [], Elixir}, {:x, [], Elixir}]}
            ]}
         ]}

      quote do
        Enum.scan(unquote(list_var), unquote(init), unquote(operation))
      end
    else
      _ -> nil
    end
  end

  # running = running op elem
  defp scan_update_running({:=, _, [running, {op, _, [running, elem]}]}, running_var, elem_var) do
    if running == running_var and elem == elem_var do
      {running_var, op}
    else
      nil
    end
  end

  defp scan_update_running(_, _, _), do: nil

  # acc = [running | acc]
  defp scan_accumulate({:=, _, [acc, {:|, _, [running, acc]}]}, acc_var, running_var) do
    acc == acc_var and running == running_var
  end

  defp scan_accumulate(_, _, _), do: false

  # acc = [elem | acc]
  defp list_prepend?({:=, _, [acc, {:|, _, [elem, acc]}]}, acc_var, elem_var) do
    acc == acc_var and elem == elem_var
  end

  defp list_prepend?(_, _, _), do: false

  # Enum.reverse(acc)
  defp enum_reverse_arg({{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [arg]}), do: arg

  defp enum_reverse_arg(_), do: nil

  # n = n - 1
  defp decrement_by_one?({:=, _, [n, {:-, _, [n, 1]}]}, n_var), do: n == n_var

  defp decrement_by_one?(_, _), do: false

  # if list empty OR n == 0
  defp list_or_zero_check?({op, _, [c1, c2]}) when op in [:or, :||] do
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

  defp list_or_zero_check?(_), do: nil

  # n == 0 variants
  defp zero_check?({:==, _, [n, 0]}), do: maybe_var_ast(n)
  defp zero_check?({:==, _, [0, n]}), do: maybe_var_ast(n)
  defp zero_check?({:===, _, [n, 0]}), do: maybe_var_ast(n)
  defp zero_check?({:===, _, [0, n]}), do: maybe_var_ast(n)

  defp zero_check?({{:., _, [{:__aliases__, _, [:Kernel]}, :==]}, _, [n, 0]}),
    do: maybe_var_ast(n)

  defp zero_check?({{:., _, [{:__aliases__, _, [:Kernel]}, :==]}, _, [0, n]}),
    do: maybe_var_ast(n)

  defp zero_check?({{:., _, [{:__aliases__, _, [:Kernel]}, :===]}, _, [n, 0]}),
    do: maybe_var_ast(n)

  defp zero_check?({{:., _, [{:__aliases__, _, [:Kernel]}, :===]}, _, [0, n]}),
    do: maybe_var_ast(n)

  defp zero_check?(_), do: nil

  defp maybe_var_ast({name, _, ctx} = ast) when is_atom(name) and is_atom(ctx), do: ast

  defp maybe_var_ast(_), do: nil

  # Helper to check if AST contains a break call
  defp has_break?(ast) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        {:break, _, _}, _acc -> {{:break, [], []}, true}
        node, acc -> {node, acc}
      end)

    found
  end

  # Helper to check if AST contains a variable
  defp has_var?(ast, var) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        ^var, _acc -> {var, true}
        node, acc -> {node, acc}
      end)

    found
  end

  defp has_var_name?(ast, {name, _, _}) when is_atom(name) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        {^name, _, ctx} = node, _acc when ctx in [nil, Elixir] -> {node, true}
        node, acc -> {node, acc}
      end)

    found
  end

  defp has_var_name?(_ast, _var), do: false

  # Helper to replace a variable/expression in AST
  defp replace_var(ast, old_var, new_var) do
    Macro.prewalk(ast, fn
      node when node == old_var -> new_var
      node -> node
    end)
  end

  # Helper to check if two variable AST nodes refer to the same variable
  defp vars_equal?({name, _, ctx1}, {name, _, ctx2})
       when ctx1 in [nil, Elixir] and ctx2 in [nil, Elixir] do
    true
  end

  defp vars_equal?(_, _), do: false

  defp same_var_ast?(left, right) do
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
  defp empty_list_check?(condition) do
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

  # Reduce Pattern: existing implementation
  defp reduce_pattern(initials, body) do
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

  defp reduce(initials, {:__block__, _, [exit_strategy, reducer, next_step]}) do
    with {object, target} <- exit_strategy(exit_strategy),
         {^object, ^target, op} <- reducer(reducer),
         ^object <- next_step(next_step),
         {name, _, x} when x in [nil, Elixir] <- target do
      {object, Keyword.get(initials, name), op}
    else
      _ ->
        nil
    end
  end

  defp reduce(_initials, _body), do: nil

  defp exit_strategy({:if, _, [condition, [do: {:break, _, [target]}]]}) do
    case empty_list_check?(condition) do
      {object, _} -> {object, target}
      nil -> nil
    end
  end

  defp exit_strategy(_), do: nil

  defp reducer({:=, _, [target, {op, _, [target, {:hd, _, [object]}]}]}), do: {object, target, op}

  defp reducer(_), do: nil

  defp next_step({:=, _, [object, {:tl, _, [object]}]}), do: object

  defp next_step(_), do: nil
end
