defmodule LoopPatternsTransformTest do
  use ExUnit.Case, async: true
  use Loop

  test "zip pattern: equal length lists" do
    list1 = [1, 2, 3]
    list2 = [:a, :b, :c]

    result =
      loop acc: [] do
        if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
        [h1 | list1] = list1
        [h2 | list2] = list2
        acc = [{h1, h2} | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
          [h1 | list1] = list1
          [h2 | list2] = list2
          acc = [{h1, h2} | acc]
        end
      end,
      __ENV__
    )

    assert result == [{1, :a}, {2, :b}, {3, :c}]
  end

  test "zip pattern: first list shorter" do
    list1 = [1, 2]
    list2 = [:a, :b, :c]

    result =
      loop acc: [] do
        if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
        [h1 | list1] = list1
        [h2 | list2] = list2
        acc = [{h1, h2} | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
          [h1 | list1] = list1
          [h2 | list2] = list2
          acc = [{h1, h2} | acc]
        end
      end,
      __ENV__
    )

    assert result == [{1, :a}, {2, :b}]
  end

  test "zip pattern: second list shorter" do
    list1 = [1, 2, 3]
    list2 = [:a]

    result =
      loop acc: [] do
        if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
        [h1 | list1] = list1
        [h2 | list2] = list2
        acc = [{h1, h2} | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
          [h1 | list1] = list1
          [h2 | list2] = list2
          acc = [{h1, h2} | acc]
        end
      end,
      __ENV__
    )

    assert result == [{1, :a}]
  end

  test "zip pattern: empty lists" do
    list1 = []
    list2 = []

    result =
      loop acc: [] do
        if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
        [h1 | list1] = list1
        [h2 | list2] = list2
        acc = [{h1, h2} | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
          [h1 | list1] = list1
          [h2 | list2] = list2
          acc = [{h1, h2} | acc]
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "dedup pattern: remove consecutive duplicates" do
    list = [1, 1, 2, 2, 2, 3, 1, 1]

    result =
      loop acc: [], prev: nil do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h == prev, do: acc, else: [h | acc]
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], prev: nil do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h == prev, do: acc, else: [h | acc]
          prev = h
        end
      end,
      __ENV__
    )

    assert result == [1, 2, 3, 1]
  end

  test "dedup pattern: no duplicates" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [], prev: nil do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h == prev, do: acc, else: [h | acc]
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], prev: nil do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h == prev, do: acc, else: [h | acc]
          prev = h
        end
      end,
      __ENV__
    )

    assert result == [1, 2, 3, 4]
  end

  test "dedup pattern: all same" do
    list = [1, 1, 1, 1]

    result =
      loop acc: [], prev: nil do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h == prev, do: acc, else: [h | acc]
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], prev: nil do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h == prev, do: acc, else: [h | acc]
          prev = h
        end
      end,
      __ENV__
    )

    assert result == [1]
  end

  test "dedup pattern: empty list" do
    list = []

    result =
      loop acc: [], prev: nil do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h == prev, do: acc, else: [h | acc]
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], prev: nil do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h == prev, do: acc, else: [h | acc]
          prev = h
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "filter_map pattern: filter and transform" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: [h * 10 | acc], else: acc
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if rem(h, 2) == 0, do: [h * 10 | acc], else: acc
        end
      end,
      __ENV__
    )

    assert result == [20, 40, 60]
  end

  test "filter_map pattern: filter and transform strings" do
    list = ["hello", "hi", "world", "yo"]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if String.length(h) > 2, do: [String.upcase(h) | acc], else: acc
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if String.length(h) > 2, do: [String.upcase(h) | acc], else: acc
        end
      end,
      __ENV__
    )

    assert result == ["HELLO", "WORLD"]
  end

  test "filter_map pattern: empty list" do
    list = []

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 0, do: [h * 2 | acc], else: acc
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h > 0, do: [h * 2 | acc], else: acc
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "partition pattern: split by predicate" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop left: [], right: [] do
        if Enum.empty?(list), do: break({Enum.reverse(left), Enum.reverse(right)})
        [h | list] = list
        {left, right} = if rem(h, 2) == 0, do: {[h | left], right}, else: {left, [h | right]}
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop left: [], right: [] do
          if Enum.empty?(list), do: break({Enum.reverse(left), Enum.reverse(right)})
          [h | list] = list
          {left, right} = if rem(h, 2) == 0, do: {[h | left], right}, else: {left, [h | right]}
        end
      end,
      __ENV__
    )

    assert result == {[2, 4, 6], [1, 3, 5]}
  end

  test "partition pattern: empty list" do
    list = []

    result =
      loop left: [], right: [] do
        if Enum.empty?(list), do: break({Enum.reverse(left), Enum.reverse(right)})
        [h | list] = list
        {left, right} = if h > 0, do: {[h | left], right}, else: {left, [h | right]}
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop left: [], right: [] do
          if Enum.empty?(list), do: break({Enum.reverse(left), Enum.reverse(right)})
          [h | list] = list
          {left, right} = if h > 0, do: {[h | left], right}, else: {left, [h | right]}
        end
      end,
      __ENV__
    )

    assert result == {[], []}
  end

  test "flat_map pattern: append mapped lists" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if list == [], do: break(acc)
        [h | list] = list
        acc = acc ++ [h, -h]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list == [], do: break(acc)
          [h | list] = list
          acc = acc ++ [h, -h]
        end
      end,
      __ENV__
    )

    assert result == Enum.flat_map(list, fn h -> [h, -h] end)
  end

  test "flat_map pattern: tuple desugar with hd/tl" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        {list, acc} =
          if list == [] do
            break(acc)
          else
            mapped = [hd(list), hd(list) * 10]
            {tl(list), acc ++ mapped}
          end
      end

    assert result == [1, 10, 2, 20, 3, 30]
  end

  test "group_by pattern: classify by parity" do
    list = [1, 2, 3, 4, 5]

    result =
      loop groups: %{} do
        if list == [], do: break(groups)
        [h | list] = list
        key = rem(h, 2)
        groups = Map.update(groups, key, [h], &(&1 ++ [h]))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop groups: %{} do
          if list == [], do: break(groups)
          [h | list] = list
          key = rem(h, 2)
          groups = Map.update(groups, key, [h], &(&1 ++ [h]))
        end
      end,
      __ENV__
    )

    assert result == Enum.group_by(list, &rem(&1, 2))
  end

  test "group_by pattern: tuple desugar with transformed values" do
    list = ["apple", "apricot", "banana", "blueberry"]

    result =
      loop groups: %{} do
        {list, groups} =
          if list == [] do
            break(groups)
          else
            key = String.first(hd(list))
            val = String.upcase(hd(list))
            updated = Map.update(groups, key, [val], &(&1 ++ [val]))
            {tl(list), updated}
          end
      end

    assert result == Enum.group_by(list, &String.first/1, &String.upcase/1)
  end

  test "uniq_by pattern: deduplicate by key" do
    list = [1, 4, 2, 5, 3, 6]

    result =
      loop acc: [], seen: MapSet.new() do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        key = rem(h, 3)
        acc = if MapSet.member?(seen, key), do: acc, else: [h | acc]
        seen = MapSet.put(seen, key)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], seen: MapSet.new() do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          key = rem(h, 3)
          acc = if MapSet.member?(seen, key), do: acc, else: [h | acc]
          seen = MapSet.put(seen, key)
        end
      end,
      __ENV__
    )

    assert result == Enum.uniq_by(list, &rem(&1, 3))
  end

  test "uniq_by pattern: hd/tl style" do
    list = ["a", "bb", "cc", "ddd", "ee"]

    result =
      loop acc: [], seen: MapSet.new() do
        if list == [], do: break(Enum.reverse(acc))
        key = String.length(hd(list))
        acc = if MapSet.member?(seen, key), do: acc, else: [hd(list) | acc]
        seen = MapSet.put(seen, key)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], seen: MapSet.new() do
          if list == [], do: break(Enum.reverse(acc))
          key = String.length(hd(list))
          acc = if MapSet.member?(seen, key), do: acc, else: [hd(list) | acc]
          seen = MapSet.put(seen, key)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == Enum.uniq_by(list, &String.length/1)
  end

  test "chunk_every pattern: take/drop style" do
    list = [1, 2, 3, 4, 5]
    size = 2

    result =
      loop chunks: [] do
        if list == [], do: break(Enum.reverse(chunks))
        chunks = [Enum.take(list, size) | chunks]
        list = Enum.drop(list, size)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop chunks: [] do
          if list == [], do: break(Enum.reverse(chunks))
          chunks = [Enum.take(list, size) | chunks]
          list = Enum.drop(list, size)
        end
      end,
      __ENV__
    )

    assert result == Enum.chunk_every(list, size)
  end

  test "chunk_every pattern: take/drop with custom step" do
    list = [1, 2, 3, 4, 5]
    size = 2
    step = 3

    result =
      loop chunks: [] do
        if list == [], do: break(Enum.reverse(chunks))
        chunks = [Enum.take(list, size) | chunks]
        list = Enum.drop(list, step)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop chunks: [] do
          if list == [], do: break(Enum.reverse(chunks))
          chunks = [Enum.take(list, size) | chunks]
          list = Enum.drop(list, step)
        end
      end,
      __ENV__
    )

    assert result == Enum.chunk_every(list, size, step)
  end

  test "chunk_every pattern: discard tail with strict short-list check" do
    list = [1, 2, 3, 4, 5]
    size = 3
    step = 2

    result =
      loop chunks: [] do
        if list == [] or length(list) < size, do: break(Enum.reverse(chunks))
        chunks = [Enum.take(list, size) | chunks]
        list = Enum.drop(list, step)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop chunks: [] do
          if list == [] or length(list) < size, do: break(Enum.reverse(chunks))
          chunks = [Enum.take(list, size) | chunks]
          list = Enum.drop(list, step)
        end
      end,
      __ENV__
    )

    assert result == Enum.chunk_every(list, size, step, :discard)
  end

  test "chunk_every pattern: discard tail with Enum.empty?/Enum.count guard" do
    list = [1, 2, 3, 4, 5]
    size = 3
    step = 2

    result =
      loop chunks: [] do
        if Enum.empty?(list) or Enum.count(list) < size, do: break(Enum.reverse(chunks))
        chunks = [Enum.take(list, size) | chunks]
        list = Enum.drop(list, step)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop chunks: [] do
          if Enum.empty?(list) or Enum.count(list) < size, do: break(Enum.reverse(chunks))
          chunks = [Enum.take(list, size) | chunks]
          list = Enum.drop(list, step)
        end
      end,
      __ENV__
    )

    assert result == Enum.chunk_every(list, size, step, :discard)
  end

  test "chunk_every pattern failure: non-strict cutoff must not optimize to :discard" do
    list = [1, 2, 3, 4, 5]
    size = 3
    step = 2

    result =
      loop chunks: [] do
        if list == [] or length(list) <= size, do: break(Enum.reverse(chunks))
        chunks = [Enum.take(list, size) | chunks]
        list = Enum.drop(list, step)
      end

    assert result == [[1, 2, 3]]
  end

  test "chunk_every pattern: split tuple style" do
    list = [1, 2, 3, 4, 5]
    size = 3

    result =
      loop chunks: [] do
        if Enum.empty?(list), do: break(Enum.reverse(chunks))
        {chunk, list} = Enum.split(list, size)
        chunks = [chunk | chunks]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop chunks: [] do
          if Enum.empty?(list), do: break(Enum.reverse(chunks))
          {chunk, list} = Enum.split(list, size)
          chunks = [chunk | chunks]
        end
      end,
      __ENV__
    )

    assert result == Enum.chunk_every(list, size)
  end

  test "map_reduce pattern: mapped output with running state" do
    list = [1, 2, 3, 4]

    result =
      loop mapped: [], state: 0 do
        if list == [], do: break({Enum.reverse(mapped), state})
        [h | list] = list
        mapped = [h + state | mapped]
        state = state + h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop mapped: [], state: 0 do
          if list == [], do: break({Enum.reverse(mapped), state})
          [h | list] = list
          mapped = [h + state | mapped]
          state = state + h
        end
      end,
      __ENV__
    )

    assert result == Enum.map_reduce(list, 0, fn h, state -> {h + state, state + h} end)
  end

  test "map_reduce pattern: tuple assignment with hd/tl style" do
    list = [2, 3, 4]

    result =
      loop mapped: [], state: 1 do
        if Enum.empty?(list), do: break({Enum.reverse(mapped), state})
        {mapped_value, state} = {hd(list) * state, state + 1}
        mapped = [mapped_value | mapped]
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop mapped: [], state: 1 do
          if Enum.empty?(list), do: break({Enum.reverse(mapped), state})
          {mapped_value, state} = {hd(list) * state, state + 1}
          mapped = [mapped_value | mapped]
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == Enum.map_reduce(list, 1, fn h, state -> {h * state, state + 1} end)
  end

  test "map_reduce pattern failure: preserve side effects in loop body" do
    parent = self()
    list = [1, 2, 3]

    result =
      loop mapped: [], state: 0 do
        if list == [], do: break({Enum.reverse(mapped), state})
        [h | list] = list
        send(parent, {:seen, h})
        mapped = [h * 2 | mapped]
        state = state + h
      end

    seen =
      Enum.map(list, fn _ ->
        receive do
          {:seen, h} -> h
        after
          200 -> :missing
        end
      end)

    assert result == {[2, 4, 6], 6}
    assert seen == list
  end

  test "map_every pattern: rem(i, n) == 0 transforms boundary elements" do
    list = [1, 2, 3, 4, 5, 6]
    n = 2

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(i, n) == 0, do: [h * 10 | acc], else: [h | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if rem(i, n) == 0, do: [h * 10 | acc], else: [h | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == Enum.map_every(list, n, &(&1 * 10))
  end

  test "map_every pattern failure: transform depends on index" do
    list = [1, 2, 3, 4]
    n = 2

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(i, n) == 0, do: [h + i | acc], else: [h | acc]
        i = i + 1
      end

    assert result == [1, 2, 5, 4]
  end

  test "frequencies_by pattern: transformed key" do
    list = ["apple", "apricot", "banana", "blueberry", "cherry"]

    result =
      loop freq: %{} do
        if list == [], do: break(freq)
        [h | list] = list
        key = String.first(h)
        freq = Map.update(freq, key, 1, &(&1 + 1))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop freq: %{} do
          if list == [], do: break(freq)
          [h | list] = list
          key = String.first(h)
          freq = Map.update(freq, key, 1, &(&1 + 1))
        end
      end,
      __ENV__
    )

    assert result == Enum.frequencies_by(list, &String.first/1)
  end

  test "frequencies_by pattern failure: key depends on loop-carried state" do
    list = [1, 1, 1]

    result =
      loop freq: %{}, offset: 0 do
        if list == [], do: break(freq)
        [h | list] = list
        key = h + offset
        freq = Map.update(freq, key, 1, &(&1 + 1))
        offset = offset + 1
      end

    assert result == %{1 => 1, 2 => 1, 3 => 1}
  end

  test "split_while pattern: break with {taken, rest}" do
    list = [1, 2, 3, 0, 4, 5]

    result =
      loop left: [] do
        if list == [], do: break({Enum.reverse(left), []})
        [h | list] = list
        left = if h > 0, do: [h | left], else: break({Enum.reverse(left), [h | list]})
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop left: [] do
          if list == [], do: break({Enum.reverse(left), []})
          [h | list] = list
          left = if h > 0, do: [h | left], else: break({Enum.reverse(left), [h | list]})
        end
      end,
      __ENV__
    )

    assert result == Enum.split_while(list, &(&1 > 0))
  end

  test "split_while pattern failure: wrong rest payload" do
    list = [1, 2, 0, 3]

    result =
      loop left: [] do
        if list == [], do: break({Enum.reverse(left), []})
        [h | list] = list
        left = if h > 0, do: [h | left], else: break({Enum.reverse(left), [h]})
      end

    assert result == {[1, 2], [0]}
  end

  test "zip_with pattern: combine two lists with expression" do
    list1 = [1, 2, 3]
    list2 = [10, 20, 30]

    result =
      loop acc: [] do
        if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
        [x | list1] = list1
        [y | list2] = list2
        acc = [x + y * 2 | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
          [x | list1] = list1
          [y | list2] = list2
          acc = [x + y * 2 | acc]
        end
      end,
      __ENV__
    )

    assert result == Enum.zip_with(list1, list2, fn x, y -> x + y * 2 end)
  end

  test "zip_with pattern failure: preserve side effects" do
    parent = self()
    list1 = [1, 2, 3]
    list2 = [10, 20, 30]

    result =
      loop acc: [] do
        if list1 == [] or list2 == [], do: break(Enum.reverse(acc))
        [x | list1] = list1
        [y | list2] = list2
        send(parent, {:pair, x, y})
        acc = [x + y | acc]
      end

    seen =
      Enum.map(1..3, fn _ ->
        receive do
          {:pair, x, y} -> {x, y}
        after
          200 -> :missing
        end
      end)

    assert result == [11, 22, 33]
    assert seen == [{1, 10}, {2, 20}, {3, 30}]
  end

  test "unzip pattern: collect tuple elements" do
    list = [{1, "a"}, {2, "b"}, {3, "c"}]

    result =
      loop left: [], right: [] do
        if list == [], do: break({Enum.reverse(left), Enum.reverse(right)})
        [pair | list] = list
        left = [elem(pair, 0) | left]
        right = [elem(pair, 1) | right]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop left: [], right: [] do
          if list == [], do: break({Enum.reverse(left), Enum.reverse(right)})
          [pair | list] = list
          left = [elem(pair, 0) | left]
          right = [elem(pair, 1) | right]
        end
      end,
      __ENV__
    )

    assert result == Enum.unzip(list)
  end

  test "unzip pattern failure: preserve side effects" do
    parent = self()
    list = [{1, "a"}, {2, "b"}, {3, "c"}]

    result =
      loop left: [], right: [] do
        if list == [], do: break({Enum.reverse(left), Enum.reverse(right)})
        [pair | list] = list
        send(parent, {:seen, pair})
        left = [elem(pair, 0) | left]
        right = [elem(pair, 1) | right]
      end

    seen =
      Enum.map(1..3, fn _ ->
        receive do
          {:seen, pair} -> pair
        after
          200 -> :missing
        end
      end)

    assert result == {[1, 2, 3], ["a", "b", "c"]}
    assert seen == list
  end

  test "min_max pattern: track both extrema" do
    list = [4, 1, 7, 3, 9, 2]

    result =
      loop min_v: hd(list), max_v: hd(list) do
        list = tl(list)
        if list == [], do: break({min_v, max_v})
        min_v = min(min_v, hd(list))
        max_v = max(max_v, hd(list))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop min_v: hd(list), max_v: hd(list) do
          list = tl(list)
          if list == [], do: break({min_v, max_v})
          min_v = min(min_v, hd(list))
          max_v = max(max_v, hd(list))
        end
      end,
      __ENV__
    )

    assert result == Enum.min_max(list)
  end

  test "min_max pattern failure: reversed break tuple" do
    list = [4, 1, 7, 3]

    result =
      loop min_v: hd(list), max_v: hd(list) do
        list = tl(list)
        if list == [], do: break({max_v, min_v})
        min_v = min(min_v, hd(list))
        max_v = max(max_v, hd(list))
      end

    assert result == {7, 1}
  end

  test "max_by pattern: keep best element and key" do
    list = ["pear", "kiwi", "banana", "fig"]

    result =
      loop best: hd(list), best_key: String.length(hd(list)) do
        list = tl(list)
        if list == [], do: break(best)
        candidate = hd(list)
        candidate_key = String.length(candidate)

        {best, best_key} =
          if candidate_key > best_key,
            do: {candidate, candidate_key},
            else: {best, best_key}
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop best: hd(list), best_key: String.length(hd(list)) do
          list = tl(list)
          if list == [], do: break(best)
          candidate = hd(list)
          candidate_key = String.length(candidate)

          {best, best_key} =
            if candidate_key > best_key,
              do: {candidate, candidate_key},
              else: {best, best_key}
        end
      end,
      __ENV__
    )

    assert result == Enum.max_by(list, &String.length/1)
  end

  test "min_by pattern: keep smallest key element" do
    list = ["pear", "kiwi", "banana", "fig"]

    result =
      loop best: hd(list), best_key: String.length(hd(list)) do
        list = tl(list)
        if list == [], do: break(best)
        candidate = hd(list)
        candidate_key = String.length(candidate)

        {best, best_key} =
          if candidate_key < best_key,
            do: {candidate, candidate_key},
            else: {best, best_key}
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop best: hd(list), best_key: String.length(hd(list)) do
          list = tl(list)
          if list == [], do: break(best)
          candidate = hd(list)
          candidate_key = String.length(candidate)

          {best, best_key} =
            if candidate_key < best_key,
              do: {candidate, candidate_key},
              else: {best, best_key}
        end
      end,
      __ENV__
    )

    assert result == Enum.min_by(list, &String.length/1)
  end

  test "max_by pattern failure: >= tie handling must preserve loop semantics" do
    list = [5, 3, 1]

    result =
      loop best: hd(list), best_key: rem(hd(list), 2) do
        list = tl(list)
        if list == [], do: break(best)
        candidate = hd(list)
        candidate_key = rem(candidate, 2)

        {best, best_key} =
          if candidate_key >= best_key,
            do: {candidate, candidate_key},
            else: {best, best_key}
      end

    assert result == 1
  end

  test "sum_by pattern: accumulate transformed numeric key" do
    list = [1, 2, 3, 4]

    result =
      loop sum: 0 do
        if list == [], do: break(sum)
        [h | list] = list
        key = h * 2
        sum = sum + key
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop sum: 0 do
          if list == [], do: break(sum)
          [h | list] = list
          key = h * 2
          sum = sum + key
        end
      end,
      __ENV__
    )

    assert result == Enum.sum_by(list, &(&1 * 2))
  end

  test "sum_by pattern failure: preserve side effects" do
    parent = self()
    list = [1, 2, 3]

    result =
      loop sum: 0 do
        if list == [], do: break(sum)
        [h | list] = list
        send(parent, {:seen, h})
        sum = sum + h
      end

    seen =
      Enum.map(1..3, fn _ ->
        receive do
          {:seen, h} -> h
        after
          200 -> :missing
        end
      end)

    assert result == 6
    assert seen == [1, 2, 3]
  end

  test "uniq pattern: keep first occurrence per element" do
    list = [1, 2, 1, 3, 2, 4, 4]

    result =
      loop acc: [], seen: MapSet.new() do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if MapSet.member?(seen, h), do: acc, else: [h | acc]
        seen = MapSet.put(seen, h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], seen: MapSet.new() do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if MapSet.member?(seen, h), do: acc, else: [h | acc]
          seen = MapSet.put(seen, h)
        end
      end,
      __ENV__
    )

    assert result == Enum.uniq(list)
  end

  test "uniq pattern failure: preserve side effects" do
    parent = self()
    list = [1, 2, 1]

    result =
      loop acc: [], seen: MapSet.new() do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        send(parent, {:seen, h})
        acc = if MapSet.member?(seen, h), do: acc, else: [h | acc]
        seen = MapSet.put(seen, h)
      end

    seen =
      Enum.map(1..3, fn _ ->
        receive do
          {:seen, h} -> h
        after
          200 -> :missing
        end
      end)

    assert result == [1, 2]
    assert seen == [1, 2, 1]
  end

  test "min_max_by pattern: track both extrema by key" do
    list = ["pear", "kiwi", "banana", "fig"]

    result =
      loop min_v: hd(list),
           min_k: String.length(hd(list)),
           max_v: hd(list),
           max_k: String.length(hd(list)) do
        list = tl(list)
        if list == [], do: break({min_v, max_v})
        candidate = hd(list)
        candidate_key = String.length(candidate)

        {min_v, min_k} =
          if candidate_key < min_k,
            do: {candidate, candidate_key},
            else: {min_v, min_k}

        {max_v, max_k} =
          if candidate_key > max_k,
            do: {candidate, candidate_key},
            else: {max_v, max_k}
      end

    assert result == Enum.min_max_by(list, &String.length/1)
  end

  test "min_max_by pattern failure: non-strict compare preserves tie semantics" do
    list = ["ab", "cd", "ef"]

    result =
      loop min_v: hd(list),
           min_k: String.length(hd(list)),
           max_v: hd(list),
           max_k: String.length(hd(list)) do
        list = tl(list)
        if list == [], do: break({min_v, max_v})
        candidate = hd(list)
        candidate_key = String.length(candidate)

        {min_v, min_k} =
          if candidate_key <= min_k,
            do: {candidate, candidate_key},
            else: {min_v, min_k}

        {max_v, max_k} =
          if candidate_key > max_k,
            do: {candidate, candidate_key},
            else: {max_v, max_k}
      end

    assert result == {"ef", "ab"}
  end

  test "zip_reduce pattern: reduce two lists into scalar" do
    list1 = [1, 2, 3]
    list2 = [10, 20, 30]

    result =
      loop acc: 0 do
        if list1 == [] or list2 == [], do: break(acc)
        [x | list1] = list1
        [y | list2] = list2
        acc = acc + x * y
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 0 do
          if list1 == [] or list2 == [], do: break(acc)
          [x | list1] = list1
          [y | list2] = list2
          acc = acc + x * y
        end
      end,
      __ENV__
    )

    assert result == Enum.zip_reduce(list1, list2, 0, fn x, y, acc -> acc + x * y end)
  end

  test "zip_reduce pattern failure: preserve side effects" do
    parent = self()
    list1 = [1, 2]
    list2 = [10, 20]

    result =
      loop acc: 0 do
        if list1 == [] or list2 == [], do: break(acc)
        [x | list1] = list1
        [y | list2] = list2
        send(parent, {:pair, x, y})
        acc = acc + x + y
      end

    seen =
      Enum.map(1..2, fn _ ->
        receive do
          {:pair, x, y} -> {x, y}
        after
          200 -> :missing
        end
      end)

    assert result == 33
    assert seen == [{1, 10}, {2, 20}]
  end

  test "flat_map_reduce pattern: map to lists and carry state" do
    list = [1, 2, 3]

    result =
      loop acc: [], state: 0 do
        if list == [], do: break({acc, state})
        [h | list] = list
        acc = acc ++ [h + state, h - state]
        state = state + h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], state: 0 do
          if list == [], do: break({acc, state})
          [h | list] = list
          acc = acc ++ [h + state, h - state]
          state = state + h
        end
      end,
      __ENV__
    )

    assert result ==
             Enum.flat_map_reduce(list, 0, fn h, state ->
               {[h + state, h - state], state + h}
             end)
  end

  test "flat_map_reduce pattern failure: preserve side effects" do
    parent = self()
    list = [1, 2]

    result =
      loop acc: [], state: 0 do
        if list == [], do: break({acc, state})
        [h | list] = list
        send(parent, {:seen, h})
        acc = acc ++ [h]
        state = state + h
      end

    seen =
      Enum.map(1..2, fn _ ->
        receive do
          {:seen, h} -> h
        after
          200 -> :missing
        end
      end)

    assert result == {[1, 2], 3}
    assert seen == [1, 2]
  end

  test "chunk_by pattern: flush chunk when key changes" do
    list = [1, 3, 5, 2, 4, 7, 9]

    result =
      loop chunks: [], chunk: [], current_key: nil, started: false do
        if list == [],
          do:
            break(Enum.reverse(if chunk == [], do: chunks, else: [Enum.reverse(chunk) | chunks]))

        [h | list] = list
        key = rem(h, 2)

        {chunks, chunk, current_key, started} =
          if started and key != current_key,
            do: {[Enum.reverse(chunk) | chunks], [h], key, true},
            else: {chunks, [h | chunk], key, true}
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop chunks: [], chunk: [], current_key: nil, started: false do
          if list == [],
            do:
              break(
                Enum.reverse(if chunk == [], do: chunks, else: [Enum.reverse(chunk) | chunks])
              )

          [h | list] = list
          key = rem(h, 2)

          {chunks, chunk, current_key, started} =
            if started and key != current_key,
              do: {[Enum.reverse(chunk) | chunks], [h], key, true},
              else: {chunks, [h | chunk], key, true}
        end
      end,
      __ENV__
    )

    assert result == Enum.chunk_by(list, &rem(&1, 2))
  end

  test "chunk_by pattern failure: preserve side effects" do
    parent = self()
    list = [1, 3, 2]

    result =
      loop chunks: [], chunk: [], current_key: nil, started: false do
        if list == [],
          do:
            break(Enum.reverse(if chunk == [], do: chunks, else: [Enum.reverse(chunk) | chunks]))

        [h | list] = list
        send(parent, {:seen, h})
        key = rem(h, 2)

        {chunks, chunk, current_key, started} =
          if started and key != current_key,
            do: {[Enum.reverse(chunk) | chunks], [h], key, true},
            else: {chunks, [h | chunk], key, true}
      end

    seen =
      Enum.map(1..3, fn _ ->
        receive do
          {:seen, h} -> h
        after
          200 -> :missing
        end
      end)

    assert result == [[1, 3], [2]]
    assert seen == [1, 3, 2]
  end

  test "map_intersperse pattern: map and insert separator" do
    list = [1, 2, 3]

    result =
      loop acc: [], first: true do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        mapped = h * 10
        acc = if first, do: [mapped | acc], else: [mapped, :sep | acc]
        first = false
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], first: true do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          mapped = h * 10
          acc = if first, do: [mapped | acc], else: [mapped, :sep | acc]
          first = false
        end
      end,
      __ENV__
    )

    assert result == Enum.map_intersperse(list, :sep, &(&1 * 10))
  end

  test "map_intersperse pattern failure: preserve side effects" do
    parent = self()
    list = [1, 2, 3]

    result =
      loop acc: [], first: true do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        send(parent, {:seen, h})
        mapped = h * 10
        acc = if first, do: [mapped | acc], else: [mapped, :sep | acc]
        first = false
      end

    seen =
      Enum.map(1..3, fn _ ->
        receive do
          {:seen, h} -> h
        after
          200 -> :missing
        end
      end)

    assert result == [10, :sep, 20, :sep, 30]
    assert seen == [1, 2, 3]
  end

  test "map_join pattern: map and join with separator" do
    list = [1, 2, 3]

    result =
      loop acc: "", first: true do
        if list == [], do: break(acc)
        [h | list] = list
        part = Integer.to_string(h)
        acc = if first, do: part, else: acc <> "," <> part
        first = false
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: "", first: true do
          if list == [], do: break(acc)
          [h | list] = list
          part = Integer.to_string(h)
          acc = if first, do: part, else: acc <> "," <> part
          first = false
        end
      end,
      __ENV__
    )

    assert result == Enum.map_join(list, ",", &Integer.to_string/1)
  end

  test "map_join pattern failure: preserve side effects" do
    parent = self()
    list = [1, 2]

    result =
      loop acc: "", first: true do
        if list == [], do: break(acc)
        [h | list] = list
        send(parent, {:seen, h})
        part = Integer.to_string(h)
        acc = if first, do: part, else: acc <> "," <> part
        first = false
      end

    seen =
      Enum.map(1..2, fn _ ->
        receive do
          {:seen, h} -> h
        after
          200 -> :missing
        end
      end)

    assert result == "1,2"
    assert seen == [1, 2]
  end

  test "count_until pattern (2-arity): stop when limit reached" do
    list = [1, 2, 3, 4, 5, 6, 7]
    limit = 3

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [_h | list] = list
        count = count + 1
        if count >= limit, do: break(count)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [_h | list] = list
          count = count + 1
          if count >= limit, do: break(count)
        end
      end,
      __ENV__
    )

    assert result == Enum.count_until(list, limit)
    assert result == 3
  end

  test "count_until pattern (2-arity): list shorter than limit" do
    list = [1, 2]
    limit = 10

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [_h | list] = list
        count = count + 1
        if count >= limit, do: break(count)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [_h | list] = list
          count = count + 1
          if count >= limit, do: break(count)
        end
      end,
      __ENV__
    )

    assert result == Enum.count_until(list, limit)
    assert result == 2
  end

  test "count_until pattern (2-arity): empty list" do
    list = []
    limit = 5

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [_h | list] = list
        count = count + 1
        if count >= limit, do: break(count)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [_h | list] = list
          count = count + 1
          if count >= limit, do: break(count)
        end
      end,
      __ENV__
    )

    assert result == Enum.count_until(list, limit)
    assert result == 0
  end

  test "count_until pattern (3-arity): count matching elements up to limit" do
    list = [1, 2, 3, 4, 5, 6, 7, 8]
    limit = 3

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if rem(h, 2) == 0, do: count + 1, else: count
        if count >= limit, do: break(count)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [h | list] = list
          count = if rem(h, 2) == 0, do: count + 1, else: count
          if count >= limit, do: break(count)
        end
      end,
      __ENV__
    )

    assert result == Enum.count_until(list, &(rem(&1, 2) == 0), limit)
    assert result == 3
  end

  test "count_until pattern (3-arity): fewer matches than limit" do
    list = [1, 2, 3]
    limit = 10

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if h > 1, do: count + 1, else: count
        if count >= limit, do: break(count)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [h | list] = list
          count = if h > 1, do: count + 1, else: count
          if count >= limit, do: break(count)
        end
      end,
      __ENV__
    )

    assert result == Enum.count_until(list, &(&1 > 1), limit)
    assert result == 2
  end

  test "average pattern: sum / count" do
    list = [1, 2, 3, 4, 5]

    result =
      loop sum: 0, count: 0 do
        if list == [], do: break(sum / count)
        [h | list] = list
        sum = sum + h
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop sum: 0, count: 0 do
          if list == [], do: break(sum / count)
          [h | list] = list
          sum = sum + h
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == Enum.sum(list) / length(list)
    assert result == 3.0
  end

  test "average pattern: count before sum in initials" do
    list = [10, 20, 30]

    result =
      loop count: 0, sum: 0 do
        if list == [], do: break(sum / count)
        [h | list] = list
        sum = sum + h
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0, sum: 0 do
          if list == [], do: break(sum / count)
          [h | list] = list
          sum = sum + h
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == Enum.sum(list) / length(list)
    assert result == 20.0
  end

  test "average pattern: single element" do
    list = [42]

    result =
      loop sum: 0, count: 0 do
        if list == [], do: break(sum / count)
        [h | list] = list
        sum = sum + h
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop sum: 0, count: 0 do
          if list == [], do: break(sum / count)
          [h | list] = list
          sum = sum + h
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == 42.0
  end

  test "average pattern (sum_by variant): average of transformed values" do
    list = [1, 2, 3, 4]

    result =
      loop sum: 0, count: 0 do
        if list == [], do: break(sum / count)
        [h | list] = list
        sum = sum + h * 2
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop sum: 0, count: 0 do
          if list == [], do: break(sum / count)
          [h | list] = list
          sum = sum + h * 2
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == Enum.sum_by(list, &(&1 * 2)) / length(list)
    assert result == 5.0
  end

  test "average pattern failure: break not sum/count" do
    list = [1, 2, 3]

    result =
      loop sum: 0, count: 0 do
        if list == [], do: break({sum, count})
        [h | list] = list
        sum = sum + h
        count = count + 1
      end

    # Should fall back (break is a tuple, not division)
    assert result == {6, 3}
  end

  # P055 — product_by: multiply transformed elements
  test "product_by pattern: multiply by element" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        if list == [], do: break(product)
        [h | list] = list
        product = product * h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1 do
          if list == [], do: break(product)
          [h | list] = list
          product = product * h
        end
      end,
      __ENV__
    )

    assert result == Enum.product_by(list, fn x -> x end)
    assert result == 24
  end

  test "product_by pattern: multiply by transformed element" do
    list = [1, 2, 3]

    result =
      loop product: 1 do
        if list == [], do: break(product)
        [h | list] = list
        product = product * (h + 1)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1 do
          if list == [], do: break(product)
          [h | list] = list
          product = product * (h + 1)
        end
      end,
      __ENV__
    )

    assert result == Enum.product_by(list, &(&1 + 1))
    assert result == 24
  end

  test "product_by pattern: single element" do
    list = [5]

    result =
      loop product: 1 do
        if list == [], do: break(product)
        [h | list] = list
        product = product * h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1 do
          if list == [], do: break(product)
          [h | list] = list
          product = product * h
        end
      end,
      __ENV__
    )

    assert result == Enum.product_by(list, fn x -> x end)
    assert result == 5
  end

  test "product_by pattern: empty list" do
    list = []

    result =
      loop product: 1 do
        if list == [], do: break(product)
        [h | list] = list
        product = product * h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1 do
          if list == [], do: break(product)
          [h | list] = list
          product = product * h
        end
      end,
      __ENV__
    )

    assert result == Enum.product_by(list, fn x -> x end)
    assert result == 1
  end

  # P061 — delete_at: remove element at index
  test "delete_at pattern: delete at index 0" do
    list = [1, 2, 3]
    target = 0

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i == target, do: acc, else: [h | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i == target, do: acc, else: [h | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [2, 3]
  end

  test "delete_at pattern: delete at index 1" do
    list = [10, 20, 30, 40]
    target = 1

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i == target, do: acc, else: [h | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i == target, do: acc, else: [h | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [10, 30, 40]
  end

  test "delete_at pattern: delete at last index" do
    list = [1, 2, 3]
    target = 2

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i == target, do: acc, else: [h | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i == target, do: acc, else: [h | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [1, 2]
  end

  test "delete_at pattern: index and acc in reverse order" do
    list = [:a, :b, :c, :d]
    target = 1

    result =
      loop i: 0, acc: [] do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i == target, do: acc, else: [h | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: 0, acc: [] do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i == target, do: acc, else: [h | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [:a, :c, :d]
  end

  test "index_aware_map pattern: basic example" do
    list = [10, 20, 30]

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h + i | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [h + i | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [10, 21, 32]
  end

  test "index_aware_map pattern: index and element in different order" do
    list = [:a, :b, :c]

    result =
      loop i: 0, acc: [] do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{i, h} | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: 0, acc: [] do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [{i, h} | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [{0, :a}, {1, :b}, {2, :c}]
  end

  test "index_aware_map pattern failure: transform doesn't use index" do
    list = [1, 2, 3]

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
        i = i + 1
      end

    # Should be recognized by regular map pattern (not index-aware), since transform doesn't use i
    assert result == [2, 4, 6]
  end

  test "index_aware_filter pattern: basic example" do
    list = [10, 20, 30, 40, 50]

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 15 and i > 0, do: [h | acc], else: acc
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h > 15 and i > 0, do: [h | acc], else: acc
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [20, 30, 40, 50]
  end

  test "index_aware_filter pattern: index variable order" do
    list = [1, 2, 3, 4, 5]

    result =
      loop i: 0, acc: [] do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(i, 2) == 0, do: [h | acc], else: acc
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: 0, acc: [] do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if rem(i, 2) == 0, do: [h | acc], else: acc
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [1, 3, 5]
  end

  test "index_aware_filter pattern failure: predicate doesn't use index" do
    list = [1, 2, 3, 4, 5]

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 2, do: [h | acc], else: acc
        i = i + 1
      end

    # Should be recognized by regular filter pattern (not index-aware), since predicate doesn't use i
    assert result == [3, 4, 5]
  end

  test "index_aware_each pattern: basic example" do
    list = [:a, :b, :c]
    _results = []

    result =
      loop i: 0 do
        if list == [], do: break(:ok)
        [h | list] = list
        _ = {i, h}
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: 0 do
          if list == [], do: break(:ok)
          [h | list] = list
          _ = {i, h}
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == :ok
  end

  test "index_aware_each pattern: multiple side effects" do
    list = [10, 20, 30]

    result =
      loop i: 0 do
        if list == [], do: break(:ok)
        [h | list] = list
        _a = h + i
        _b = h * i
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: 0 do
          if list == [], do: break(:ok)
          [h | list] = list
          a = h + i
          b = h * i
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == :ok
  end

  test "index_aware_each pattern failure: side effect doesn't use index" do
    list = [1, 2, 3]

    result =
      loop i: 0 do
        if list == [], do: break(:ok)
        [h | list] = list
        _ = h
        i = i + 1
      end

    # Should not be recognized (side effect doesn't use i)
    assert result == :ok
  end

  test "map_into pattern: Map.put with simple key/value" do
    list = [1, 2, 3]

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.put(acc, h, h * 2)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: %{} do
          if list == [], do: break(acc)
          [h | list] = list
          acc = Map.put(acc, h, h * 2)
        end
      end,
      __ENV__
    )

    assert result == %{1 => 2, 2 => 4, 3 => 6}
  end

  test "map_into pattern: Map.put with computed key/value from element" do
    list = ["a", "b", "c"]

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.put(acc, String.upcase(h), String.length(h))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: %{} do
          if list == [], do: break(acc)
          [h | list] = list
          acc = Map.put(acc, String.upcase(h), String.length(h))
        end
      end,
      __ENV__
    )

    assert result == %{"A" => 1, "B" => 1, "C" => 1}
  end

  test "map_into pattern failure: Map.put_new instead of Map.put" do
    list = [1, 2, 3]

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.put_new(acc, h, h * 2)
      end

    # Should be recognized by map_put_new_pattern instead
    assert result == %{1 => 2, 2 => 4, 3 => 6}
  end

  test "map_into pattern failure: break not acc" do
    list = [1, 2, 3]

    result =
      loop acc: %{} do
        if list == [], do: break(%{extra: 99})
        [h | list] = list
        acc = Map.put(acc, h, h * 2)
      end

    # Should not be recognized (break expr is not acc)
    assert result == %{extra: 99}
  end

  # P065 — Enum.into for keyword list (verification)
  # This should already be recognized by the existing map_pattern
  test "keyword list pattern: cons-prepend tuple building" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{h, h * 2} | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [{h, h * 2} | acc]
        end
      end,
      __ENV__
    )

    assert result == [{1, 2}, {2, 4}, {3, 6}]
  end

  test "keyword list pattern: multiple tuple elements from element" do
    list = ["a", "b", "c"]

    result =
      loop acc: [] do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{String.upcase(h), String.length(h)} | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [{String.upcase(h), String.length(h)} | acc]
        end
      end,
      __ENV__
    )

    assert result == [{"A", 1}, {"B", 1}, {"C", 1}]
  end

  # P071 — Adjacent pairs: Enum.zip/2
  test "adjacent pairs with basic list" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [], prev: hd(list), list: tl(list) do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{prev, h} | acc]
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], prev: hd(list), list: tl(list) do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [{prev, h} | acc]
          prev = h
        end
      end,
      __ENV__
    )

    assert result == [{1, 2}, {2, 3}, {3, 4}]
  end

  test "adjacent pairs with single element" do
    list = [1]

    result =
      loop acc: [], prev: hd(list), list: tl(list) do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{prev, h} | acc]
        prev = h
      end

    assert result == []
  end

  test "adjacent pairs with two elements" do
    list = [10, 20]

    result =
      loop acc: [], prev: hd(list), list: tl(list) do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{prev, h} | acc]
        prev = h
      end

    assert result == [{10, 20}]
  end

  # P073 — Pairwise map: Enum.zip_with/3
  test "pairwise map with simple addition" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [], prev: hd(list), list: tl(list) do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [prev + h | acc]
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], prev: hd(list), list: tl(list) do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [prev + h | acc]
          prev = h
        end
      end,
      __ENV__
    )

    assert result == [3, 5, 7]
  end

  test "pairwise map with function application" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [], prev: hd(list), list: tl(list) do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{prev, h, prev * h} | acc]
        prev = h
      end

    assert result == [{1, 2, 2}, {2, 3, 6}, {3, 4, 12}]
  end

  test "pairwise map with string operations" do
    list = ["a", "b", "c"]

    result =
      loop acc: [], prev: hd(list), list: tl(list) do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [prev <> h | acc]
        prev = h
      end

    assert result == ["ab", "bc"]
  end

  # P058 — list_delete_at_tail: delete element at index, append remaining tail
  test "P058: delete at index 0, append other list" do
    list = [1, 2, 3]
    other_list = [10, 11]
    target = 0

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc) ++ other_list)
        [h | list] = list
        acc = if i != target, do: [h | acc], else: acc
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if list == [], do: break(Enum.reverse(acc) ++ other_list)
          [h | list] = list
          acc = if i != target, do: [h | acc], else: acc
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [2, 3, 10, 11]
  end

  test "P058: delete at index 1, append other list" do
    list = [1, 2, 3]
    other_list = [99]
    target = 1

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc) ++ other_list)
        [h | list] = list
        acc = if i != target, do: [h | acc], else: acc
        i = i + 1
      end

    assert result == [1, 3, 99]
  end

  test "P058: delete at index on empty list" do
    list = []
    other_list = [5, 6]
    target = 0

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc) ++ other_list)
        [h | list] = list
        acc = if i != target, do: [h | acc], else: acc
        i = i + 1
      end

    assert result == [5, 6]
  end

  # P059 — list_update_at: update element at index with transform
  test "P059: update element at index 1 with transform" do
    list = [1, 2, 3]
    target = 1

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i == target, do: [h * 10 | acc], else: [h | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i == target, do: [h * 10 | acc], else: [h | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [1, 20, 3]
  end

  test "P059: update element at index 0" do
    list = [1, 2, 3]
    target = 0

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i == target, do: [h + 100 | acc], else: [h | acc]
        i = i + 1
      end

    assert result == [101, 2, 3]
  end

  test "P059: update element on empty list" do
    list = []
    target = 0

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i == target, do: [h * 2 | acc], else: [h | acc]
        i = i + 1
      end

    assert result == []
  end

  # P060 — list_insert_at: insert value at index
  # Loop form: acc = if i == target, do: [h, value | acc], else: [h | acc]; break(Enum.reverse(acc))
  test "P060: insert value at index 1" do
    list = [1, 2, 3]
    target = 1
    value = 99

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i == target, do: [h, value | acc], else: [h | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i == target, do: [h, value | acc], else: [h | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [1, 99, 2, 3]
  end

  test "P060: insert value at index 0" do
    list = [1, 2, 3]
    target = 0
    value = 0

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i == target, do: [h, value | acc], else: [h | acc]
        i = i + 1
      end

    assert result == [0, 1, 2, 3]
  end

  test "P060: insert value at last index" do
    list = [1, 2, 3]
    target = 2
    value = 42

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i == target, do: [h, value | acc], else: [h | acc]
        i = i + 1
      end

    assert result == [1, 2, 42, 3]
  end

  test "P063 slice: extract middle range from list" do
    list = [1, 2, 3, 4, 5, 6, 7, 8]
    stop = 5
    start = 2

    result =
      loop acc: [], i: 0 do
        if list == [] or i >= stop, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i >= start, do: [h | acc], else: acc
        i = i + 1
      end

    Loop.TestHelpers.assert_recognized(
      quote do
        loop acc: [], i: 0 do
          if list == [] or i >= stop, do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i >= start, do: [h | acc], else: acc
          i = i + 1
        end
      end,
      __ENV__,
      Loop.TestHelpers.enum_call?(:slice)
    )

    assert result == [3, 4, 5]
  end

  test "P063 slice: extract from start (start = 0)" do
    list = [10, 20, 30, 40, 50]
    stop = 3
    start = 0

    result =
      loop acc: [], i: 0 do
        if list == [] or i >= stop, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i >= start, do: [h | acc], else: acc
        i = i + 1
      end

    Loop.TestHelpers.assert_recognized(
      quote do
        loop acc: [], i: 0 do
          if list == [] or i >= stop, do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i >= start, do: [h | acc], else: acc
          i = i + 1
        end
      end,
      __ENV__,
      Loop.TestHelpers.enum_call?(:slice)
    )

    assert result == [10, 20, 30]
  end

  test "P063 slice: extract tail end of list" do
    list = [1, 2, 3, 4, 5]
    stop = 5
    start = 3

    result =
      loop acc: [], i: 0 do
        if list == [] or i >= stop, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i >= start, do: [h | acc], else: acc
        i = i + 1
      end

    Loop.TestHelpers.assert_recognized(
      quote do
        loop acc: [], i: 0 do
          if list == [] or i >= stop, do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i >= start, do: [h | acc], else: acc
          i = i + 1
        end
      end,
      __ENV__,
      Loop.TestHelpers.enum_call?(:slice)
    )

    assert result == [4, 5]
  end

  test "P063 slice: stop exceeds list length" do
    list = [1, 2, 3]
    stop = 100
    start = 1

    result =
      loop acc: [], i: 0 do
        if list == [] or i >= stop, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i >= start, do: [h | acc], else: acc
        i = i + 1
      end

    Loop.TestHelpers.assert_recognized(
      quote do
        loop acc: [], i: 0 do
          if list == [] or i >= stop, do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i >= start, do: [h | acc], else: acc
          i = i + 1
        end
      end,
      __ENV__,
      Loop.TestHelpers.enum_call?(:slice)
    )

    assert result == [2, 3]
  end

  test "P063 slice: empty result when start equals stop" do
    list = [1, 2, 3, 4, 5]
    stop = 3
    start = 3

    result =
      loop acc: [], i: 0 do
        if list == [] or i >= stop, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i >= start, do: [h | acc], else: acc
        i = i + 1
      end

    Loop.TestHelpers.assert_recognized(
      quote do
        loop acc: [], i: 0 do
          if list == [] or i >= stop, do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i >= start, do: [h | acc], else: acc
          i = i + 1
        end
      end,
      __ENV__,
      Loop.TestHelpers.enum_call?(:slice)
    )

    assert result == []
  end

  test "P063 slice: empty list input" do
    list = []
    stop = 5
    start = 1

    result =
      loop acc: [], i: 0 do
        if list == [] or i >= stop, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if i >= start, do: [h | acc], else: acc
        i = i + 1
      end

    Loop.TestHelpers.assert_recognized(
      quote do
        loop acc: [], i: 0 do
          if list == [] or i >= stop, do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if i >= start, do: [h | acc], else: acc
          i = i + 1
        end
      end,
      __ENV__,
      Loop.TestHelpers.enum_call?(:slice)
    )

    assert result == []
  end

  test "chunk_while pattern: split on negative elements" do
    list = [1, 2, -1, 3, 4, -2, 5]

    result =
      loop chunks: [], chunk: [] do
        if list == [], do: break(Enum.reverse([Enum.reverse(chunk) | chunks]))
        [h | list] = list

        if h >= 0 do
          chunk = [h | chunk]
        else
          chunks = [Enum.reverse(chunk) | chunks]
          chunk = [h]
        end
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop chunks: [], chunk: [] do
          if list == [], do: break(Enum.reverse([Enum.reverse(chunk) | chunks]))
          [h | list] = list

          if h >= 0 do
            chunk = [h | chunk]
          else
            chunks = [Enum.reverse(chunk) | chunks]
            chunk = [h]
          end
        end
      end,
      __ENV__
    )

    assert result ==
             Enum.chunk_while(
               list,
               [],
               fn h, chunk ->
                 if h >= 0 do
                   {:cont, [h | chunk]}
                 else
                   {:cont, Enum.reverse(chunk), [h]}
                 end
               end,
               fn chunk -> {:cont, Enum.reverse(chunk), []} end
             )
  end

  test "chunk_while pattern: split when element changes parity" do
    list = [2, 4, 3, 5, 6, 8, 1]

    result =
      loop chunks: [], chunk: [] do
        if list == [], do: break(Enum.reverse([Enum.reverse(chunk) | chunks]))
        [h | list] = list

        if chunk == [] or rem(h, 2) == rem(hd(chunk), 2) do
          chunk = [h | chunk]
        else
          chunks = [Enum.reverse(chunk) | chunks]
          chunk = [h]
        end
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop chunks: [], chunk: [] do
          if list == [], do: break(Enum.reverse([Enum.reverse(chunk) | chunks]))
          [h | list] = list

          if chunk == [] or rem(h, 2) == rem(hd(chunk), 2) do
            chunk = [h | chunk]
          else
            chunks = [Enum.reverse(chunk) | chunks]
            chunk = [h]
          end
        end
      end,
      __ENV__
    )

    assert result == [[2, 4], [3, 5], [6, 8], [1]]
  end

  test "chunk_while pattern: inverted condition (yield in do branch)" do
    list = [1, 2, -1, 3, 4]

    result =
      loop chunks: [], chunk: [] do
        if list == [], do: break(Enum.reverse([Enum.reverse(chunk) | chunks]))
        [h | list] = list

        if h < 0 do
          chunks = [Enum.reverse(chunk) | chunks]
          chunk = [h]
        else
          chunk = [h | chunk]
        end
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop chunks: [], chunk: [] do
          if list == [], do: break(Enum.reverse([Enum.reverse(chunk) | chunks]))
          [h | list] = list

          if h < 0 do
            chunks = [Enum.reverse(chunk) | chunks]
            chunk = [h]
          else
            chunk = [h | chunk]
          end
        end
      end,
      __ENV__
    )

    assert result ==
             Enum.chunk_while(
               list,
               [],
               fn h, chunk ->
                 if h >= 0 do
                   {:cont, [h | chunk]}
                 else
                   {:cont, Enum.reverse(chunk), [h]}
                 end
               end,
               fn chunk -> {:cont, Enum.reverse(chunk), []} end
             )
  end

  test "chunk_while pattern: single element list" do
    list = [42]

    result =
      loop chunks: [], chunk: [] do
        if list == [], do: break(Enum.reverse([Enum.reverse(chunk) | chunks]))
        [h | list] = list

        if h > 0 do
          chunk = [h | chunk]
        else
          chunks = [Enum.reverse(chunk) | chunks]
          chunk = [h]
        end
      end

    assert result == [[42]]
  end

  test "chunk_while pattern: empty list produces empty-chunk artifact" do
    list = []

    result =
      loop chunks: [], chunk: [] do
        if list == [], do: break(Enum.reverse([Enum.reverse(chunk) | chunks]))
        [h | list] = list

        if h > 0 do
          chunk = [h | chunk]
        else
          chunks = [Enum.reverse(chunk) | chunks]
          chunk = [h]
        end
      end

    # The break expression always wraps the final chunk, so empty list produces [[]]
    assert result == [[]]
  end
end
