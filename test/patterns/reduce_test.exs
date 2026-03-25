defmodule LoopPatternsReduceTest do
  use ExUnit.Case, async: true
  use Loop

  test "reduce pattern: List.first(list) normalized to hd(list)" do
    list = [2, 3, 4]

    result =
      loop acc: 1 do
        if list == [], do: break(acc)
        acc = acc * List.first(list)
        list = tl(list)
      end

    assert result == 24
  end

  test "reduce pattern failure: using tail(list) instead of tl(list)" do
    list = [2, 3, 4]

    result =
      loop acc: 1 do
        if list == [], do: break(acc)
        acc = acc * hd(list)
        list = List.delete_at(list, 0)
      end

    assert result == 24
  end

  test "reduce pattern failure: using list pattern match for advancement" do
    list = [2, 3, 4]

    result =
      loop acc: 1 do
        if list == [], do: break(acc)
        [h | list] = list
        acc = acc * h
      end

    assert result == 24
  end

  test "reduce pattern: multiply all elements" do
    list = [2, 3, 4]

    result =
      loop acc: 1 do
        if list == [], do: break(acc)
        acc = acc * hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 1 do
          if list == [], do: break(acc)
          acc = acc * hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 24
  end

  test "reduce pattern: subtract all elements" do
    list = [10, 3, 2]

    result =
      loop acc: 20 do
        if list == [], do: break(acc)
        acc = acc - hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 20 do
          if list == [], do: break(acc)
          acc = acc - hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 5
  end

  test "reduce pattern: string concatenation" do
    list = ["Hello", " ", "World"]

    result =
      loop acc: "" do
        if list == [], do: break(acc)
        acc = acc <> hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: "" do
          if list == [], do: break(acc)
          acc = acc <> hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == "Hello World"
  end

  test "reduce pattern: division" do
    list = [2.0, 4.0]

    result =
      loop acc: 100.0 do
        if list == [], do: break(acc)
        acc = acc / hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 100.0 do
          if list == [], do: break(acc)
          acc = acc / hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 12.5
  end

  test "reduce pattern: max operation" do
    list = [3, 7, 2, 9, 4]

    result =
      loop acc: 0 do
        if list == [], do: break(acc)
        acc = max(acc, hd(list))
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 0 do
          if list == [], do: break(acc)
          acc = max(acc, hd(list))
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 9
  end

  test "sum pattern: basic integer sum" do
    list = [10, 20, 30]

    result =
      loop sum: 0 do
        if list == [], do: break(sum)
        sum = sum + hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop sum: 0 do
          if list == [], do: break(sum)
          sum = sum + hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 60
  end

  test "sum pattern: float sum" do
    list = [1.5, 2.5, 3.5]

    result =
      loop sum: 0.0 do
        if list == [], do: break(sum)
        sum = sum + hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop sum: 0.0 do
          if list == [], do: break(sum)
          sum = sum + hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 7.5
  end

  test "reduce pattern: using subtraction with specific initial value" do
    list = [5, 3, 2]

    result =
      loop result: 15 do
        if list == [], do: break(result)
        result = result - hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: 15 do
          if list == [], do: break(result)
          result = result - hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 5
  end

  test "reduce pattern: using multiplication with init 2" do
    list = [3, 4, 5]

    result =
      loop product: 2 do
        if list == [], do: break(product)
        product = product * hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 2 do
          if list == [], do: break(product)
          product = product * hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 120
  end

  test "reduce pattern: using division with floats" do
    list = [2.0, 5.0]

    result =
      loop quotient: 100.0 do
        if list == [], do: break(quotient)
        quotient = quotient / hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop quotient: 100.0 do
          if list == [], do: break(quotient)
          quotient = quotient / hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 10.0
  end

  test "reduce pattern: string concatenation with init" do
    list = [" ", "beautiful", " ", "day"]

    result =
      loop text: "A" do
        if list == [], do: break(text)
        text = text <> hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop text: "A" do
          if list == [], do: break(text)
          text = text <> hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == "A beautiful day"
  end

  test "reduce pattern: single element list" do
    list = [42]

    result =
      loop acc: 0 do
        if list == [], do: break(acc)
        acc = acc + hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 0 do
          if list == [], do: break(acc)
          acc = acc + hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 42
  end

  test "reduce pattern: empty list with initial value" do
    list = []

    result =
      loop acc: 100 do
        if list == [], do: break(acc)
        acc = acc + hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 100 do
          if list == [], do: break(acc)
          acc = acc + hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 100
  end

  test "product pattern: multiply integers" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        if list == [], do: break(product)
        product = product * hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1 do
          if list == [], do: break(product)
          product = product * hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 24
  end

  test "product pattern: single element" do
    list = [42]

    result =
      loop product: 1 do
        if list == [], do: break(product)
        product = product * hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1 do
          if list == [], do: break(product)
          product = product * hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 42
  end

  test "product pattern: empty list" do
    list = []

    result =
      loop product: 1 do
        if list == [], do: break(product)
        product = product * hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1 do
          if list == [], do: break(product)
          product = product * hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 1
  end

  test "product pattern: with float init 1.0" do
    list = [2.0, 3.0]

    result =
      loop product: 1.0 do
        if list == [], do: break(product)
        product = product * hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1.0 do
          if list == [], do: break(product)
          product = product * hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 6.0
  end

  test "reduce_while pattern: sum until threshold" do
    list = [1, 2, 3, 4, 5]

    result =
      loop acc: 0 do
        if list == [], do: break(acc)
        [h | list] = list
        if acc + h > 6, do: break(acc)
        acc = acc + h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 0 do
          if list == [], do: break(acc)
          [h | list] = list
          if acc + h > 6, do: break(acc)
          acc = acc + h
        end
      end,
      __ENV__
    )

    assert result == 6
  end

  test "reduce_while pattern: no early exit" do
    list = [1, 2, 3]

    result =
      loop acc: 0 do
        if list == [], do: break(acc)
        [h | list] = list
        if acc > 100, do: break(acc)
        acc = acc + h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 0 do
          if list == [], do: break(acc)
          [h | list] = list
          if acc > 100, do: break(acc)
          acc = acc + h
        end
      end,
      __ENV__
    )

    assert result == 6
  end

  test "reduce_while pattern: immediate exit" do
    list = [1, 2, 3]

    result =
      loop acc: 100 do
        if list == [], do: break(acc)
        [h | list] = list
        if acc > 50, do: break(acc)
        acc = acc + h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 100 do
          if list == [], do: break(acc)
          [h | list] = list
          if acc > 50, do: break(acc)
          acc = acc + h
        end
      end,
      __ENV__
    )

    assert result == 100
  end

  test "reduce_while pattern: empty list" do
    list = []

    result =
      loop acc: 42 do
        if list == [], do: break(acc)
        [h | list] = list
        if h > 10, do: break(acc)
        acc = acc + h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 42 do
          if list == [], do: break(acc)
          [h | list] = list
          if h > 10, do: break(acc)
          acc = acc + h
        end
      end,
      __ENV__
    )

    assert result == 42
  end

  test "scan pattern: running sum" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [], running: 0 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        running = running + h
        acc = [running | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], running: 0 do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          running = running + h
          acc = [running | acc]
        end
      end,
      __ENV__
    )

    assert result == [1, 3, 6, 10]
  end

  test "scan pattern: running product" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [], running: 1 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        running = running * h
        acc = [running | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], running: 1 do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          running = running * h
          acc = [running | acc]
        end
      end,
      __ENV__
    )

    assert result == [1, 2, 6, 24]
  end

  test "scan pattern: empty list" do
    list = []

    result =
      loop acc: [], running: 0 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        running = running + h
        acc = [running | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], running: 0 do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          running = running + h
          acc = [running | acc]
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "P067 — Map.update with resolver: accumulate with multiplier" do
    list = [2, 3, 2, 4, 3]

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.update(acc, h, 1, fn existing -> existing + h end)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: %{} do
          if list == [], do: break(acc)
          [h | list] = list
          acc = Map.update(acc, h, 1, fn existing -> existing + h end)
        end
      end,
      __ENV__
    )

    assert result == %{2 => 3, 3 => 4, 4 => 1}
  end

  test "P067 — Map.update with resolver: count duplicates" do
    list = [:a, :b, :a, :c, :b, :a]

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.update(acc, h, 1, &(&1 + 1))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: %{} do
          if list == [], do: break(acc)
          [h | list] = list
          acc = Map.update(acc, h, 1, &(&1 + 1))
        end
      end,
      __ENV__
    )

    assert result == %{a: 3, b: 2, c: 1}
  end

  test "P067 — Map.update with resolver: empty list" do
    list = []

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.update(acc, h, 1, &(&1 + 2))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: %{} do
          if list == [], do: break(acc)
          [h | list] = list
          acc = Map.update(acc, h, 1, &(&1 + 2))
        end
      end,
      __ENV__
    )

    assert result == %{}
  end

  test "P068 — Map.merge: simple merge" do
    list = [%{a: 1, b: 2}, %{c: 3}, %{a: 10}]

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.merge(acc, h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: %{} do
          if list == [], do: break(acc)
          [h | list] = list
          acc = Map.merge(acc, h)
        end
      end,
      __ENV__
    )

    assert result == %{a: 10, b: 2, c: 3}
  end

  test "P068 — Map.merge with resolver: custom merge function" do
    list = [%{a: 1, b: 2}, %{c: 3}, %{a: 10, b: 5}]

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.merge(acc, h, fn _k, v1, v2 -> v1 + v2 end)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: %{} do
          if list == [], do: break(acc)
          [h | list] = list
          acc = Map.merge(acc, h, fn _k, v1, v2 -> v1 + v2 end)
        end
      end,
      __ENV__
    )

    assert result == %{a: 11, b: 7, c: 3}
  end

  test "P068 — Map.merge: empty list" do
    list = []

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.merge(acc, h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: %{} do
          if list == [], do: break(acc)
          [h | list] = list
          acc = Map.merge(acc, h)
        end
      end,
      __ENV__
    )

    assert result == %{}
  end

  # P078 — Filter + count (dual return)
  test "P078 filter_count pattern: basic filter with count" do
    list = [1, 2, 3, 4, 5]

    result =
      loop acc: [], count: 0 do
        if list == [], do: break({Enum.reverse(acc), count})
        [h | list] = list

        if h > 2 do
          acc = [h | acc]
          count = count + 1
        end
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], count: 0 do
          if list == [], do: break({Enum.reverse(acc), count})
          [h | list] = list

          if h > 2 do
            acc = [h | acc]
            count = count + 1
          end
        end
      end,
      __ENV__
    )

    filtered = Enum.filter(list, fn h -> h > 2 end)
    assert result == {filtered, length(filtered)}
  end

  test "P078 filter_count pattern: empty list" do
    list = []

    result =
      loop acc: [], count: 0 do
        if list == [], do: break({Enum.reverse(acc), count})
        [h | list] = list

        if h > 2 do
          acc = [h | acc]
          count = count + 1
        end
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], count: 0 do
          if list == [], do: break({Enum.reverse(acc), count})
          [h | list] = list

          if h > 2 do
            acc = [h | acc]
            count = count + 1
          end
        end
      end,
      __ENV__
    )

    assert result == {[], 0}
  end

  test "P078 filter_count pattern: no elements match" do
    list = [1, 2, 3]

    result =
      loop acc: [], count: 0 do
        if list == [], do: break({Enum.reverse(acc), count})
        [h | list] = list

        if h > 10 do
          acc = [h | acc]
          count = count + 1
        end
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], count: 0 do
          if list == [], do: break({Enum.reverse(acc), count})
          [h | list] = list

          if h > 10 do
            acc = [h | acc]
            count = count + 1
          end
        end
      end,
      __ENV__
    )

    assert result == {[], 0}
  end

  # P079 — Map + sum (dual return): already handled by map_reduce_pattern
  test "P079 map_sum pattern: map and sum (covered by map_reduce)" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [], sum: 0 do
        if list == [], do: break({Enum.reverse(acc), sum})
        [h | list] = list
        acc = [h * 2 | acc]
        sum = sum + h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], sum: 0 do
          if list == [], do: break({Enum.reverse(acc), sum})
          [h | list] = list
          acc = [h * 2 | acc]
          sum = sum + h
        end
      end,
      __ENV__
    )

    assert result == Enum.map_reduce(list, 0, fn h, sum -> {h * 2, sum + h} end)
  end

  # P080 — Any-with-index (dual return)
  test "P080 any_with_index pattern: found at index 3" do
    list = [1, 2, 3, 4, 5]

    result =
      loop i: 0 do
        if list == [], do: break({false, nil})
        [h | list] = list
        if h > 3, do: break({true, i})
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: 0 do
          if list == [], do: break({false, nil})
          [h | list] = list
          if h > 3, do: break({true, i})
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == {true, 3}
  end

  test "P080 any_with_index pattern: not found" do
    list = [1, 2, 3]

    result =
      loop i: 0 do
        if list == [], do: break({false, nil})
        [h | list] = list
        if h > 100, do: break({true, i})
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: 0 do
          if list == [], do: break({false, nil})
          [h | list] = list
          if h > 100, do: break({true, i})
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == {false, nil}
  end

  # P072 — Sliding window reduce
  test "P072 sliding window reduce: sum of consecutive differences" do
    list = [1, 4, 2, 8, 5]

    result =
      loop acc: 0, prev: hd(list), list: tl(list) do
        if list == [], do: break(acc)
        [h | list] = list
        acc = acc + abs(h - prev)
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 0, prev: hd(list), list: tl(list) do
          if list == [], do: break(acc)
          [h | list] = list
          acc = acc + abs(h - prev)
          prev = h
        end
      end,
      __ENV__
    )

    # |1-4| + |4-2| + |2-8| + |8-5| = 3 + 2 + 6 + 3 = 14
    assert result == 14
  end

  test "P072 sliding window reduce: count ascending pairs" do
    list = [1, 3, 2, 5, 4, 6]

    result =
      loop acc: 0, prev: hd(list), list: tl(list) do
        if list == [], do: break(acc)
        [h | list] = list
        acc = if prev < h, do: acc + 1, else: acc
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 0, prev: hd(list), list: tl(list) do
          if list == [], do: break(acc)
          [h | list] = list
          acc = if prev < h, do: acc + 1, else: acc
          prev = h
        end
      end,
      __ENV__
    )

    # 1<3 yes, 3<2 no, 2<5 yes, 5<4 no, 4<6 yes => 3
    assert result == 3
  end

  test "P072 sliding window reduce: max consecutive difference" do
    list = [1, 5, 2, 9, 3]

    result =
      loop acc: 0, prev: hd(list), list: tl(list) do
        if list == [], do: break(acc)
        [h | list] = list
        acc = max(acc, abs(h - prev))
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 0, prev: hd(list), list: tl(list) do
          if list == [], do: break(acc)
          [h | list] = list
          acc = max(acc, abs(h - prev))
          prev = h
        end
      end,
      __ENV__
    )

    # |5-1|=4, |2-5|=3, |9-2|=7, |3-9|=6 => max is 7
    assert result == 7
  end

  test "P072 sliding window reduce: single element list" do
    list = [42]

    result =
      loop acc: 0, prev: hd(list), list: tl(list) do
        if list == [], do: break(acc)
        [h | list] = list
        acc = acc + abs(h - prev)
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 0, prev: hd(list), list: tl(list) do
          if list == [], do: break(acc)
          [h | list] = list
          acc = acc + abs(h - prev)
          prev = h
        end
      end,
      __ENV__
    )

    # No pairs, acc stays 0
    assert result == 0
  end

  test "P072 sliding window reduce: two element list" do
    list = [3, 7]

    result =
      loop acc: 0, prev: hd(list), list: tl(list) do
        if list == [], do: break(acc)
        [h | list] = list
        acc = acc + h - prev
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 0, prev: hd(list), list: tl(list) do
          if list == [], do: break(acc)
          [h | list] = list
          acc = acc + h - prev
          prev = h
        end
      end,
      __ENV__
    )

    # One pair: 0 + 7 - 3 = 4
    assert result == 4
  end

  test "P072 sliding window reduce: product of ratios" do
    list = [2.0, 4.0, 8.0, 16.0]

    result =
      loop acc: 1.0, prev: hd(list), list: tl(list) do
        if list == [], do: break(acc)
        [h | list] = list
        acc = acc * h / prev
        prev = h
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 1.0, prev: hd(list), list: tl(list) do
          if list == [], do: break(acc)
          [h | list] = list
          acc = acc * h / prev
          prev = h
        end
      end,
      __ENV__
    )

    # 1.0 * 4/2 * 8/4 * 16/8 = 1.0 * 2 * 2 * 2 = 8.0
    assert result == 8.0
  end

  test "P080 any_with_index pattern: empty list" do
    list = []

    result =
      loop i: 0 do
        if list == [], do: break({false, nil})
        [h | list] = list
        if h > 3, do: break({true, i})
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: 0 do
          if list == [], do: break({false, nil})
          [h | list] = list
          if h > 3, do: break({true, i})
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == {false, nil}
  end

  # P082 — Range loop with downward iteration
  test "P082 range_down pattern: sum from n down to 1" do
    n = 5

    result =
      loop i: n, acc: 0 do
        if i == 0, do: break(acc)
        acc = acc + i
        i = i - 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: n, acc: 0 do
          if i == 0, do: break(acc)
          acc = acc + i
          i = i - 1
        end
      end,
      __ENV__
    )

    # 5 + 4 + 3 + 2 + 1 = 15
    assert result == 15
  end

  test "P082 range_down pattern: factorial" do
    n = 5

    result =
      loop i: n, acc: 1 do
        if i <= 0, do: break(acc)
        acc = acc * i
        i = i - 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: n, acc: 1 do
          if i <= 0, do: break(acc)
          acc = acc * i
          i = i - 1
        end
      end,
      __ENV__
    )

    # 5! = 120
    assert result == 120
  end

  test "P082 range_down pattern: n = 0 (empty range)" do
    n = 0

    result =
      loop i: n, acc: 42 do
        if i == 0, do: break(acc)
        acc = acc + i
        i = i - 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: n, acc: 42 do
          if i == 0, do: break(acc)
          acc = acc + i
          i = i - 1
        end
      end,
      __ENV__
    )

    assert result == 42
  end

  test "P082 range_down pattern: n = 1 (single iteration)" do
    n = 1

    result =
      loop i: n, acc: 0 do
        if i == 0, do: break(acc)
        acc = acc + i * i
        i = i - 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: n, acc: 0 do
          if i == 0, do: break(acc)
          acc = acc + i * i
          i = i - 1
        end
      end,
      __ENV__
    )

    assert result == 1
  end

  test "chunk_every pattern: separate take/drop steps" do
    list = [1, 2, 3, 4, 5, 6, 7]
    size = 3

    result =
      loop acc: [] do
        if list == [], do: break(Enum.reverse(acc))
        chunk = Enum.take(list, size)
        list = Enum.drop(list, size)
        acc = [chunk | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list == [], do: break(Enum.reverse(acc))
          chunk = Enum.take(list, size)
          list = Enum.drop(list, size)
          acc = [chunk | acc]
        end
      end,
      __ENV__
    )

    assert result == Enum.chunk_every(list, size)
  end
end