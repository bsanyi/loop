defmodule LoopPatternsAggregateTest do
  use ExUnit.Case, async: true
  use Loop

  test "reject pattern: reject even numbers" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: acc, else: [h | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if rem(h, 2) == 0, do: acc, else: [h | acc]
        end
      end,
      __ENV__
    )

    assert result == [1, 3, 5]
  end

  test "reject pattern: reject short strings" do
    list = ["a", "bb", "ccc", "d"]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if String.length(h) <= 1, do: acc, else: [h | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if String.length(h) <= 1, do: acc, else: [h | acc]
        end
      end,
      __ENV__
    )

    assert result == ["bb", "ccc"]
  end

  test "reject pattern: empty list" do
    list = []

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 0, do: acc, else: [h | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h > 0, do: acc, else: [h | acc]
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "reject pattern: reject none" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 10, do: acc, else: [h | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h > 10, do: acc, else: [h | acc]
        end
      end,
      __ENV__
    )

    assert result == [1, 2, 3]
  end

  test "reject pattern: reject all" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 0, do: acc, else: [h | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h > 0, do: acc, else: [h | acc]
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "reverse pattern: reverse a list" do
    list = [1, 2, 3, 4, 5]

    result =
      loop acc: [] do
        if list == [], do: break(acc)
        [h | list] = list
        acc = [h | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list == [], do: break(acc)
          [h | list] = list
          acc = [h | acc]
        end
      end,
      __ENV__
    )

    assert result == [5, 4, 3, 2, 1]
  end

  test "reverse pattern: reverse single element" do
    list = [42]

    result =
      loop acc: [] do
        if list == [], do: break(acc)
        [h | list] = list
        acc = [h | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list == [], do: break(acc)
          [h | list] = list
          acc = [h | acc]
        end
      end,
      __ENV__
    )

    assert result == [42]
  end

  test "reverse pattern: reverse empty list" do
    list = []

    result =
      loop acc: [] do
        if list == [], do: break(acc)
        [h | list] = list
        acc = [h | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list == [], do: break(acc)
          [h | list] = list
          acc = [h | acc]
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "reverse pattern: with Enum.empty? exit" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(acc)
        [h | list] = list
        acc = [h | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(acc)
          [h | list] = list
          acc = [h | acc]
        end
      end,
      __ENV__
    )

    assert result == [3, 2, 1]
  end

  test "length pattern: count elements" do
    list = [1, 2, 3, 4, 5]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [_ | list] = list
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [_ | list] = list
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == 5
  end

  test "length pattern: empty list" do
    list = []

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [_ | list] = list
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [_ | list] = list
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == 0
  end

  test "length pattern: single element" do
    list = [42]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [_ | list] = list
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [_ | list] = list
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == 1
  end

  test "length pattern: different variable name" do
    list = [1, 2, 3]

    result =
      loop n: 0 do
        if list == [], do: break(n)
        [_ | list] = list
        n = n + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop n: 0 do
          if list == [], do: break(n)
          [_ | list] = list
          n = n + 1
        end
      end,
      __ENV__
    )

    assert result == 3
  end

  test "max pattern: find maximum" do
    list = [3, 7, 2, 9, 4]

    result =
      loop best: hd(list) do
        list = tl(list)
        if list == [], do: break(best)
        best = max(best, hd(list))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop best: hd(list) do
          list = tl(list)
          if list == [], do: break(best)
          best = max(best, hd(list))
        end
      end,
      __ENV__
    )

    assert result == 9
  end

  test "min pattern: find minimum" do
    list = [3, 7, 2, 9, 4]

    result =
      loop best: hd(list) do
        list = tl(list)
        if list == [], do: break(best)
        best = min(best, hd(list))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop best: hd(list) do
          list = tl(list)
          if list == [], do: break(best)
          best = min(best, hd(list))
        end
      end,
      __ENV__
    )

    assert result == 2
  end

  test "max pattern: single element (after tl)" do
    list = [42, 99]

    result =
      loop best: hd(list) do
        list = tl(list)
        if list == [], do: break(best)
        best = max(best, hd(list))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop best: hd(list) do
          list = tl(list)
          if list == [], do: break(best)
          best = max(best, hd(list))
        end
      end,
      __ENV__
    )

    assert result == 99
  end

  test "min pattern: already sorted ascending" do
    list = [1, 2, 3, 4, 5]

    result =
      loop best: hd(list) do
        list = tl(list)
        if list == [], do: break(best)
        best = min(best, hd(list))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop best: hd(list) do
          list = tl(list)
          if list == [], do: break(best)
          best = min(best, hd(list))
        end
      end,
      __ENV__
    )

    assert result == 1
  end

  test "frequencies pattern: count occurrences" do
    list = [:a, :b, :a, :c, :b, :a]

    result =
      loop freq: %{} do
        if list == [], do: break(freq)
        [h | list] = list
        freq = Map.update(freq, h, 1, &(&1 + 1))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop freq: %{} do
          if list == [], do: break(freq)
          [h | list] = list
          freq = Map.update(freq, h, 1, &(&1 + 1))
        end
      end,
      __ENV__
    )

    assert result == %{a: 3, b: 2, c: 1}
  end

  test "frequencies pattern: empty list" do
    list = []

    result =
      loop freq: %{} do
        if list == [], do: break(freq)
        [h | list] = list
        freq = Map.update(freq, h, 1, &(&1 + 1))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop freq: %{} do
          if list == [], do: break(freq)
          [h | list] = list
          freq = Map.update(freq, h, 1, &(&1 + 1))
        end
      end,
      __ENV__
    )

    assert result == %{}
  end

  test "frequencies pattern: all unique" do
    list = [1, 2, 3]

    result =
      loop freq: %{} do
        if list == [], do: break(freq)
        [h | list] = list
        freq = Map.update(freq, h, 1, &(&1 + 1))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop freq: %{} do
          if list == [], do: break(freq)
          [h | list] = list
          freq = Map.update(freq, h, 1, &(&1 + 1))
        end
      end,
      __ENV__
    )

    assert result == %{1 => 1, 2 => 1, 3 => 1}
  end

  test "map_new pattern: create map from list" do
    list = [{:a, 1}, {:b, 2}, {:c, 3}]

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.put(acc, elem(h, 0), elem(h, 1))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: %{} do
          if list == [], do: break(acc)
          [h | list] = list
          acc = Map.put(acc, elem(h, 0), elem(h, 1))
        end
      end,
      __ENV__
    )

    assert result == %{a: 1, b: 2, c: 3}
  end

  test "map_new pattern: empty list" do
    list = []

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.put(acc, elem(h, 0), elem(h, 1))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: %{} do
          if list == [], do: break(acc)
          [h | list] = list
          acc = Map.put(acc, elem(h, 0), elem(h, 1))
        end
      end,
      __ENV__
    )

    assert result == %{}
  end

  test "into_mapset pattern: identity" do
    list = [1, 2, 2, 3]

    result =
      loop set: MapSet.new() do
        if list == [], do: break(set)
        [h | list] = list
        set = MapSet.put(set, h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop set: MapSet.new() do
          if list == [], do: break(set)
          [h | list] = list
          set = MapSet.put(set, h)
        end
      end,
      __ENV__
    )

    assert result == MapSet.new([1, 2, 3])
  end

  test "into_mapset pattern: transformed values" do
    list = [1, 2, 2, 3]

    result =
      loop set: MapSet.new() do
        if list == [], do: break(set)
        [h | list] = list
        set = MapSet.put(set, h * 10)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop set: MapSet.new() do
          if list == [], do: break(set)
          [h | list] = list
          set = MapSet.put(set, h * 10)
        end
      end,
      __ENV__
    )

    assert result == MapSet.new([10, 20, 30])
  end

  test "reject pattern failure: wrong exit (list == [] instead of Enum.empty?)" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [] do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: acc, else: [h | acc]
      end

    # Falls back to generic loop - should still produce correct result
    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if rem(h, 2) == 0, do: acc, else: [h | acc]
        end
      end,
      __ENV__
    )

    assert result == [1, 3]
  end

  test "length pattern failure: increment by 2" do
    list = [1, 2, 3]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [_ | list] = list
        count = count + 2
      end

    assert result == 6
  end
end
