# Loop

An Elixir macro that provides imperative-style loop syntax with automatic
compile-time optimization to functional patterns. Write loops like you would in
imperative languages, and let the compiler intelligently transform them to
functional patterns.

During [an interview with Prime](https://youtu.be/-mFJ5rPbY_w?t=2388), José
Valim discussed a common challenge faced by new programmers: understanding
complex functional patterns such as map-reduce. In addition to these patterns,
others like simple reducers and recursion can be equally daunting for
beginners. My proof-of-concept application addresses this issue by enabling
inexperienced developers to write imperative-style loops that are familiar to
them, while still allowing them to learn the underlying idiomatic functional
constructs.

If you want to play around with `loop`, I recommend checking out the
[loop_trial](https://github.com/bsanyi/loop_trial) repo.

## Features

- **Imperative Loop Syntax** - Write familiar `loop`/`break` constructs
- **Automatic Optimization** - Recognizes common patterns and optimizes to `Enum` functions
- **Mutable-like State** - Bindings carry over between iterations, simulating mutable state
- **Pattern Recognition** - Supports dozens of optimization patterns, including advanced collection transforms

## Quick Start

```elixir
use Loop

# Basic infinite loop (broken with `break/0` or `break/1`)
loop do
  IO.puts("repeating...")
  Process.sleep(500)
end

# Loop with state
i = 0
loop do
  IO.puts(i)
  i = i + 1
  if i == 10, do: break()
end

# Using initial binding
loop count: 0 do
  IO.puts(count)
  if count >= 5, do: break(count)
  count = count + 1
end
```

### Loop recognizes common patterns and rewrites them internally

```elixir
quote do
  loop product: 1 do
    if list == [], do: break(product)
    product = product * hd(list)
    list = tl(list)
  end
end
|> Macro.expand(__ENV__)
|> Macro.to_string()        #=> "Enum.product(list)"
```

## Core Concepts

### Breaking Out of Loops

Use `break()` to exit a loop with `nil`, or `break(value)` to exit with a
specific value:

```elixir
loop do
  break(123)  # Returns 123
end
```

### State Across Iterations

Bindings at the end of each iteration are carried to the next, creating the
illusion of mutable state:

```elixir
i = 0
loop do
  IO.puts(i)
  i = i + 1 # This binding carries to the next iteration
end
```

### Initial Bindings

Declare initial values using keyword arguments:

```elixir
loop i: 0, step: 2 do
  IO.puts(i)
  i = i + step
end
```

## Automatic Pattern Optimization

Loop recognizes many common patterns and automatically optimizes them to
equivalent `Enum` operations at compile-time, with zero runtime overhead.

The 26 classic patterns are below, and there are additional advanced patterns too.

### 1. Map

```elixir
loop acc: [] do
  if Enum.empty?(list), do: break(Enum.reverse(acc))
  [h | list] = list
  acc = [h * h | acc]
end
# => Enum.map(list, fn h -> h * h end)
```

### 2. Filter

```elixir
loop acc: [] do
  if Enum.empty?(list), do: break(Enum.reverse(acc))
  [h | list] = list
  acc = if rem(h, 2) == 0, do: [h | acc], else: acc
end
# => Enum.filter(list, fn h -> rem(h, 2) == 0 end)
```

### 3. Reject

```elixir
loop acc: [] do
  if Enum.empty?(list), do: break(Enum.reverse(acc))
  [h | list] = list
  acc = if rem(h, 2) == 0, do: acc, else: [h | acc]
end
# => Enum.reject(list, fn h -> rem(h, 2) == 0 end)
```

### 4. Reverse

```elixir
loop acc: [] do
  if list == [], do: break(acc)
  [h | list] = list
  acc = [h | acc]
end
# => Enum.reverse(list)
```

### 5. Filter+Map

```elixir
loop acc: [] do
  if Enum.empty?(list), do: break(Enum.reverse(acc))
  [h | list] = list
  acc = if rem(h, 2) == 0, do: [h * 10 | acc], else: acc
end
# => for h <- list, rem(h, 2) == 0, do: h * 10
```

### 6. Find

```elixir
loop do
  if list == [], do: break(nil)
  [h | list] = list
  if String.starts_with?(h, "c"), do: break(h)
end
# => Enum.find(list, fn h -> String.starts_with?(h, "c") end)
```

### 7. Member?

```elixir
loop do
  if list == [], do: break(false)
  [h | list] = list
  if h == target, do: break(true)
end
# => Enum.member?(list, target)
```

### 8. Find Index

```elixir
loop index: 0 do
  if list == [], do: break(nil)
  [h | list] = list
  if rem(h, 2) == 0, do: break(index)
  index = index + 1
end
# => Enum.find_index(list, fn h -> rem(h, 2) == 0 end)
```

### 9. Count

```elixir
loop count: 0 do
  if list == [], do: break(count)
  [h | list] = list
  count = if h > 5, do: count + 1, else: count
end
# => Enum.count(list, fn h -> h > 5 end)
```

### 10. Length

```elixir
loop count: 0 do
  if list == [], do: break(count)
  [_ | list] = list
  count = count + 1
end
# => length(list)
```

### 11. Any

```elixir
loop result: false do
  if list == [], do: break(result)
  [h | list] = list
  result = result or rem(h, 2) == 0
end
# => Enum.any?(list, fn h -> rem(h, 2) == 0 end)
```

### 12. All

```elixir
loop result: true do
  if list == [], do: break(result)
  [h | list] = list
  result = result and rem(h, 2) == 0
end
# => Enum.all?(list, fn h -> rem(h, 2) == 0 end)
```

### 13. Each

```elixir
loop do
  if list == [], do: break()
  [h | list] = list
  IO.puts(h)
end
# => Enum.each(list, fn h -> IO.puts(h) end)
```

### 14. Take While

```elixir
loop acc: [] do
  if Enum.empty?(list), do: break(Enum.reverse(acc))
  [h | list] = list
  acc = if h > 0, do: [h | acc], else: break(Enum.reverse(acc))
end
# => Enum.take_while(list, fn h -> h > 0 end)
```

### 15. Drop While

```elixir
loop do
  if list == [], do: break([])
  [h | list] = list
  unless h < 3, do: break([h | list])
end
# => Enum.drop_while(list, fn h -> h < 3 end)
```

### 16. With Index

```elixir
loop acc: [], i: 0 do
  if Enum.empty?(list), do: break(Enum.reverse(acc))
  [h | list] = list
  acc = [{h, i} | acc]
  i = i + 1
end
# => Enum.with_index(list)

loop acc: [], i: 5 do
  if Enum.empty?(list), do: break(Enum.reverse(acc))
  [h | list] = list
  acc = [{h, i} | acc]
  i = i + 1
end
# => Enum.with_index(list, 5)
```

### 17. Zip

```elixir
loop acc: [] do
  if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
  [h1 | list1] = list1
  [h2 | list2] = list2
  acc = [{h1, h2} | acc]
end
# => Enum.zip(list1, list2)
```

### 18. Reduce While

```elixir
loop acc: 0 do
  if list == [], do: break(acc)
  [h | list] = list
  if acc + h > 6, do: break(acc)
  acc = acc + h
end
# => Enum.reduce_while(list, 0, fn h, acc -> ... end)
```

### 19. Dedup

```elixir
loop acc: [], prev: nil do
  if Enum.empty?(list), do: break(Enum.reverse(acc))
  [h | list] = list
  acc = if h == prev, do: acc, else: [h | acc]
  prev = h
end
# => Enum.dedup(list)
```

### 20. Max

```elixir
loop best: hd(list) do
  list = tl(list)
  if list == [], do: break(best)
  best = max(best, hd(list))
end
# => Enum.max(list)
```

### 21. Min

```elixir
loop best: hd(list) do
  list = tl(list)
  if list == [], do: break(best)
  best = min(best, hd(list))
end
# => Enum.min(list)
```

### 22. Frequencies

```elixir
loop freq: %{} do
  if list == [], do: break(freq)
  [h | list] = list
  freq = Map.update(freq, h, 1, &(&1 + 1))
end
# => Enum.frequencies(list)
```

### 23. Map.new

```elixir
loop acc: %{} do
  if list == [], do: break(acc)
  [h | list] = list
  acc = Map.put(acc, elem(h, 0), elem(h, 1))
end
# => Map.new(list, fn h -> {elem(h, 0), elem(h, 1)} end)
```

### 24. Scan

```elixir
loop acc: [], running: 0 do
  if Enum.empty?(list), do: break(Enum.reverse(acc))
  [h | list] = list
  running = running + h
  acc = [running | acc]
end
# => Enum.scan(list, 0, fn x, running -> running + x end)
```

### 25. Sum

```elixir
loop sum: 0 do
  if list == [], do: break(sum)
  sum = sum + hd(list)
  list = tl(list)
end
# => Enum.sum(list)
```

### 26. Product / Reduce

```elixir
loop product: 1 do
  if list == [], do: break(product)
  product = product * hd(list)
  list = tl(list)
end
# => Enum.product(list)
# (Other init/op combos become Enum.reduce)
```

## Additional Advanced Patterns (Showcase)

### Flat Map

```elixir
loop acc: [] do
  if list == [], do: break(acc)
  [h | list] = list
  acc = acc ++ [h, -h]
end
# => Enum.flat_map(list, fn h -> [h, -h] end)
```

### Map Reduce

```elixir
loop mapped: [], state: 0 do
  if list == [], do: break({Enum.reverse(mapped), state})
  [h | list] = list
  mapped = [h + state | mapped]
  state = state + h
end
# => Enum.map_reduce(list, 0, fn h, state -> {h + state, state + h} end)
```

### Group By

```elixir
loop groups: %{} do
  if list == [], do: break(groups)
  [h | list] = list
  key = rem(h, 2)
  groups = Map.update(groups, key, [h], &(&1 ++ [h]))
end
# => Enum.group_by(list, &rem(&1, 2))
```

### Uniq By

```elixir
loop acc: [], seen: MapSet.new() do
  if list == [], do: break(Enum.reverse(acc))
  [h | list] = list
  key = rem(h, 3)
  acc = if MapSet.member?(seen, key), do: acc, else: [h | acc]
  seen = MapSet.put(seen, key)
end
# => Enum.uniq_by(list, &rem(&1, 3))
```

### Chunk Every

```elixir
loop chunks: [] do
  if list == [], do: break(Enum.reverse(chunks))
  chunks = [Enum.take(list, size) | chunks]
  list = Enum.drop(list, size)
end
# => Enum.chunk_every(list, size)

loop chunks: [] do
  if list == [], do: break(Enum.reverse(chunks))
  chunks = [Enum.take(list, size) | chunks]
  list = Enum.drop(list, step)
end
# => Enum.chunk_every(list, size, step)

loop chunks: [] do
  if list == [] or length(list) < size, do: break(Enum.reverse(chunks))
  chunks = [Enum.take(list, size) | chunks]
  list = Enum.drop(list, step)
end
# => Enum.chunk_every(list, size, step, :discard)
```

### Split While

```elixir
loop left: [] do
  if list == [], do: break({Enum.reverse(left), []})
  [h | list] = list
  left = if h > 0, do: [h | left], else: break({Enum.reverse(left), [h | list]})
end
# => Enum.split_while(list, &(&1 > 0))
```

### Zip With / Unzip

```elixir
loop acc: [] do
  if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
  [x | list1] = list1
  [y | list2] = list2
  acc = [x + y * 2 | acc]
end
# => Enum.zip_with(list1, list2, fn x, y -> x + y * 2 end)

loop left: [], right: [] do
  if list == [], do: break({Enum.reverse(left), Enum.reverse(right)})
  [pair | list] = list
  left = [elem(pair, 0) | left]
  right = [elem(pair, 1) | right]
end
# => Enum.unzip(list)
```

### Max By / Min By / Frequencies By

```elixir
loop best: hd(list), best_key: String.length(hd(list)) do
  list = tl(list)
  if list == [], do: break(best)
  candidate = hd(list)
  candidate_key = String.length(candidate)
  {best, best_key} = if candidate_key > best_key, do: {candidate, candidate_key}, else: {best, best_key}
end
# => Enum.max_by(list, &String.length/1)
# (same shape with < => Enum.min_by/2)

loop freq: %{} do
  if list == [], do: break(freq)
  [h | list] = list
  freq = Map.update(freq, String.first(h), 1, &(&1 + 1))
end
# => Enum.frequencies_by(list, &String.first/1)
```

## Practical Examples

### Counter Service

Spawn a counter process with a message loop:

```elixir
pid = spawn_link(fn ->
  loop counter: 0 do
    counter =
      receive do
        :inc -> counter + 1
        :dec -> counter - 1
        {:get, from} -> send(from, counter); counter
        :stop -> break()
      end
  end
end)

send(pid, :inc)
send(pid, :inc)
send(pid, {:get, self()})
flush()  # => 2
send(pid, :stop)
```

### Random Pattern Animation

```elixir
loop do
  IO.write(Enum.random(["░", "▒", "▓", "█"]))
  Process.sleep(100)
end
```

## Important Notes

- **Scoping**: Loops don't modify surrounding scope. Capture the return value:

  ```elixir
  a = 10
  result =
    loop do
      a = a - 1 # doesn't affect outer a
      if a < 2, do: break({:final, a})
    end
  # a is still 10 here
  ```

- **Proof of Concept**: This library demonstrates that Elixir macros are
  powerful enough to bridge imperative and functional paradigms. However,
  idiomatic Elixir code typically uses `Enum` functions directly. I'm not
  suggesting you should code with `loop`s in Elixir.

## Design Philosophy

Loop is a thought experiment and proof of concept showing that:

1. Elixir's meta-programming capabilities enable unconventional syntax
2. Macros can recognize algorithmic patterns
3. Imperative-looking code can be compiled to efficient functional operations
