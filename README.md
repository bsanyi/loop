# Loop

An Elixir macro that provides imperative-style loop syntax with automatic
compile-time optimization to functional patterns. Write loops like you would in
imperative languages, and let the compiler intelligently transform them to
efficient `Enum` operations.

## Features

- **Imperative Loop Syntax**: Write familiar `loop`/`break` constructs
- **Automatic Optimization**: Recognizes common patterns and optimizes to `Enum` functions
- **Mutable-like State**: Bindings carry over between iterations, simulating mutable state
- **Pattern Recognition**: Supports 26 optimization patterns out of the box

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
|> Macro.to_string()
     #=> "Enum.product(list)"
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

Loop recognizes 26 common patterns and automatically optimizes them to
equivalent `Enum` operations at compile-time, with zero runtime overhead.

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

