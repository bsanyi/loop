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

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp analyze(initials, body) do
    # Normalize AST to strip metadata so variable comparison works
    # regardless of source positions (e.g. in compiled test modules)
    body = normalize(body)

    cond do
      match = map_pattern(initials, body) -> match
      match = filter_pattern(initials, body) -> match
      match = reject_pattern(initials, body) -> match
      match = reverse_pattern(initials, body) -> match
      match = filter_map_pattern(initials, body) -> match
      match = find_pattern(initials, body) -> match
      match = member_pattern(initials, body) -> match
      match = find_index_pattern(initials, body) -> match
      match = count_pattern(initials, body) -> match
      match = length_pattern(initials, body) -> match
      match = any_pattern(initials, body) -> match
      match = all_pattern(initials, body) -> match
      match = each_pattern(initials, body) -> match
      match = take_while_pattern(initials, body) -> match
      match = drop_while_pattern(initials, body) -> match
      match = with_index_pattern(initials, body) -> match
      match = zip_pattern(initials, body) -> match
      match = reduce_while_pattern(initials, body) -> match
      match = dedup_pattern(initials, body) -> match
      match = max_min_pattern(initials, body) -> match
      match = frequencies_pattern(initials, body) -> match
      match = map_new_pattern(initials, body) -> match
      match = scan_pattern(initials, body) -> match
      match = reduce_pattern(initials, body) -> match
      true -> nil
    end
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

  defp map_exit_strategy(
         {:if, _,
          [
            {{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]},
            [do: {:break, _, [{{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [acc]}]}]
          ]}
       ) do
    {list, acc}
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
      _ -> nil
    end
  end

  defp find_pattern(_, _), do: nil

  defp find_exit_empty({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [nil]}]]}) do
    list
  end

  defp find_exit_empty(_), do: nil

  defp find_check({:if, _, [condition, [do: {:break, _, [elem]}]]}, elem_var)
       when elem == elem_var do
    {elem_var, condition}
  end

  defp find_check(_, _), do: nil

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

  defp count_exit_strategy({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [count]}]]}) do
    {list, count}
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
      _ -> nil
    end
  end

  defp any_pattern(_, _), do: nil

  defp any_exit_strategy({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [result]}]]}) do
    {list, result}
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
      _ -> nil
    end
  end

  defp all_pattern(_, _), do: nil

  defp all_exit_strategy({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [result]}]]}) do
    {list, result}
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
  defp reverse_exit_strategy({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [acc]}]]}) do
    {list, acc}
  end

  defp reverse_exit_strategy(
         {:if, _,
          [
            {{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]},
            [do: {:break, _, [acc]}]
          ]}
       ) do
    {list, acc}
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
      _ -> nil
    end
  end

  defp member_pattern(_, _), do: nil

  defp member_exit_empty({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [false]}]]}) do
    list
  end

  defp member_exit_empty(
         {:if, _,
          [
            {{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]},
            [do: {:break, _, [false]}]
          ]}
       ) do
    list
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
      _ -> nil
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

  defp find_index_increment({:=, _, [index, {:+, _, [index, 1]}]}, index_var) do
    if index == index_var, do: index_var
  end

  defp find_index_increment(_, _), do: nil

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

  defp each_exit_empty({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [nil]}]]}) do
    list
  end

  defp each_exit_empty({:if, _, [{:==, _, [list, []]}, [do: {:break, _, []}]]}) do
    list
  end

  defp each_exit_empty(
         {:if, _,
          [
            {{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]},
            [do: {:break, _, [nil]}]
          ]}
       ) do
    list
  end

  defp each_exit_empty(
         {:if, _,
          [
            {{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]},
            [do: {:break, _, []}]
          ]}
       ) do
    list
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
         condition <- drop_while_check(check, list_var, elem_var) do
      quote do
        unquote(list_var) |> Enum.drop_while(fn unquote(elem_var) -> unquote(condition) end)
      end
    else
      _ -> nil
    end
  end

  defp drop_while_pattern(_, _), do: nil

  defp drop_while_exit_empty({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [[]]}]]}) do
    list
  end

  defp drop_while_exit_empty(
         {:if, _,
          [
            {{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]},
            [do: {:break, _, [[]]}]
          ]}
       ) do
    list
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

  # With Index Pattern: two initial bindings [acc: [], i: 0], accumulate {elem, i} tuples
  defp with_index_pattern(initials, body) do
    with [{acc_name, []}, {index_name, 0}] <- initials,
         {:__block__, _, [exit, destructure, accumulate, increment]} <- body,
         acc_var = {acc_name, [], nil},
         index_var = {index_name, [], nil},
         {list_var, ^acc_var} <- map_exit_strategy(exit),
         {^list_var, elem_var} <- map_destructure(destructure),
         true <- with_index_accumulate(accumulate, acc_var, elem_var, index_var),
         ^index_var <- find_index_increment(increment, index_var) do
      quote do
        Enum.with_index(unquote(list_var))
      end
    else
      _ -> nil
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

  defp reduce_while_exit({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [acc]}]]}) do
    {list, acc}
  end

  defp reduce_while_exit(
         {:if, _,
          [
            {{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]},
            [do: {:break, _, [acc]}]
          ]}
       ) do
    {list, acc}
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

  defp max_min_exit({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [best]}]]}) do
    {list, best}
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

  defp frequencies_exit({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [freq]}]]}) do
    {list, freq}
  end

  defp frequencies_exit(
         {:if, _,
          [
            {{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]},
            [do: {:break, _, [freq]}]
          ]}
       ) do
    {list, freq}
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

  defp map_new_exit({:if, _, [{:==, _, [list, []]}, [do: {:break, _, [acc]}]]}) do
    {list, acc}
  end

  defp map_new_exit(
         {:if, _,
          [
            {{:., _, [{:__aliases__, _, [:Enum]}, :empty?]}, _, [list]},
            [do: {:break, _, [acc]}]
          ]}
       ) do
    {list, acc}
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

  defp exit_strategy({:if, _, [{:==, _, [object, []]}, [do: {:break, _, [target]}]]}) do
    {object, target}
  end

  defp exit_strategy(_), do: nil

  defp reducer({:=, _, [target, {op, _, [target, {:hd, _, [object]}]}]}), do: {object, target, op}

  defp reducer(_), do: nil

  defp next_step({:=, _, [object, {:tl, _, [object]}]}), do: object

  defp next_step(_), do: nil
end
