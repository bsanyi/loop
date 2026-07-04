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
  alien in functional programming like a loop with seemingly mutable state.

  Yes, we can do it. But I'm not at all saying we should do it.

  This thing is instead a proof of concept for myself.  We can use imperative
  style loop code, and have macros that recognize certain patterns of the loop
  and translate it under the hood into a functional pattern, like an
  `Enum.reduce` or even an `Enum.sum`.

  ## Recognized Optimization Patterns

  The Loop module automatically recognizes and optimizes the 26 classic
  patterns below, plus dozens of additional advanced variants (see the README
  for a showcase):

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
  The return value of the `loop do ... end` will be `value`. If used as
  `break()`, `nil` is returned. This just returns `123`:

      loop do
        break(123)
      end

  ## Simulation of mutable state

  The bindings from the end of the `do ... end` block are carried over to the
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

  You can use more than one initial value, like a `step`ing value here:

      loop i: 0, step: 2 do
        IO.puts(i)
        i = i + step
      end

  ## `loop` just returns values, but does not change variables

  This prints the numbers from 10 down to 1 and at the end returns the value
  `{:final, 1}`.  It also demonstrates that the loop cannot change the
  surrounding environment's variables. The value of `a` won't be affected:

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
    case Loop.Analyzer.analyze(initial_binding, body) do
      nil ->
        body =
          body
          |> add_break()
          |> Macro.escape()

        quote bind_quoted: [body: body, initial_binding: initial_binding] do
          b = Kernel.binding()
          ref = make_ref()

          loop_fun = fn loop_fun, b ->
            {_result, new_binding} = Code.eval_quoted(body, b, __ENV__)
            loop_fun.(loop_fun, new_binding)
          end

          try do
            initial = [{{:loop_ref, Loop}, ref} | Keyword.merge(b, initial_binding)]
            {result, _binding} = loop_fun.(loop_fun, initial)
          catch
            :throw, {:break, ^ref, value} -> value
          end
        end

      quoted ->
        quoted
        # |> tap(fn ast -> IO.puts("RECOG: #{Macro.to_string(ast)}") end)
    end
  end

  # Rewrites break/0 and break/1 into throws tagged with a loop-unique
  # reference. The `loop_ref` variable lives in the `Loop` context, so user
  # code inside the body can neither read nor shadow it, and a user-thrown
  # `{:break, value}` no longer gets mistaken for a loop break.
  defp add_break(ast) do
    loop_ref = {:loop_ref, [], Loop}

    ast
    |> Macro.traverse([], fn etc, acc -> {etc, acc} end, fn
      {:break, meta, [val]}, acc -> {{:throw, meta, [{:{}, [], [:break, loop_ref, val]}]}, acc}
      {:break, meta, []}, acc -> {{:throw, meta, [{:{}, [], [:break, loop_ref, nil]}]}, acc}
      etc, acc -> {etc, acc}
    end)
    |> elem(0)
  end
end
