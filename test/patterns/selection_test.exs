defmodule LoopPatternsSelectionTest do
  use ExUnit.Case, async: true
  use Loop

  test "take_while pattern: take while positive" do
    list = [1, 2, 3, -1, 4, 5]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 0, do: [h | acc], else: break(Enum.reverse(acc))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h > 0, do: [h | acc], else: break(Enum.reverse(acc))
        end
      end,
      __ENV__
    )

    assert result == [1, 2, 3]
  end

  test "take_while pattern: take none" do
    list = [-1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 0, do: [h | acc], else: break(Enum.reverse(acc))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h > 0, do: [h | acc], else: break(Enum.reverse(acc))
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "take_while pattern: take all" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 0, do: [h | acc], else: break(Enum.reverse(acc))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h > 0, do: [h | acc], else: break(Enum.reverse(acc))
        end
      end,
      __ENV__
    )

    assert result == [1, 2, 3]
  end

  test "take_while pattern: empty list" do
    list = []

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 0, do: [h | acc], else: break(Enum.reverse(acc))
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h > 0, do: [h | acc], else: break(Enum.reverse(acc))
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "drop_while pattern: drop while less than 3" do
    list = [1, 2, 3, 4, 5]

    result =
      loop do
        if list == [], do: break([])
        [h | list] = list
        unless h < 3, do: break([h | list])
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break([])
          [h | list] = list
          unless h < 3, do: break([h | list])
        end
      end,
      __ENV__
    )

    assert result == [3, 4, 5]
  end

  test "drop_while pattern: drop none" do
    list = [5, 4, 3, 2, 1]

    result =
      loop do
        if list == [], do: break([])
        [h | list] = list
        unless h < 3, do: break([h | list])
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break([])
          [h | list] = list
          unless h < 3, do: break([h | list])
        end
      end,
      __ENV__
    )

    assert result == [5, 4, 3, 2, 1]
  end

  test "drop_while pattern: drop all" do
    list = [1, 2]

    result =
      loop do
        if list == [], do: break([])
        [h | list] = list
        unless h < 10, do: break([h | list])
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break([])
          [h | list] = list
          unless h < 10, do: break([h | list])
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "drop_while pattern: empty list" do
    list = []

    result =
      loop do
        if list == [], do: break([])
        [h | list] = list
        unless h < 3, do: break([h | list])
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break([])
          [h | list] = list
          unless h < 3, do: break([h | list])
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "with_index pattern: basic" do
    list = [:a, :b, :c]

    result =
      loop acc: [], i: 0 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{h, i} | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [{h, i} | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [a: 0, b: 1, c: 2]
  end

  test "with_index pattern: empty list" do
    list = []

    result =
      loop acc: [], i: 0 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{h, i} | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [{h, i} | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "with_index pattern: single element" do
    list = [42]

    result =
      loop acc: [], i: 0 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{h, i} | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [{h, i} | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == [{42, 0}]
  end

  test "with_index pattern: custom offset" do
    list = [:a, :b, :c]
    offset = 5

    result =
      loop acc: [], i: offset do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{h, i} | acc]
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: offset do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [{h, i} | acc]
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == Enum.with_index(list, offset)
  end

  test "with_index pattern failure: non-integer offset preserves loop semantics" do
    list = [:a, :b]

    result =
      loop acc: [], i: 1.5 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{h, i} | acc]
        i = i + 1
      end

    assert result == [{:a, 1.5}, {:b, 2.5}]
  end

  test "take pattern: take first n" do
    list = [1, 2, 3, 4, 5]

    result =
      loop acc: [], count: 3 do
        if count == 0 or list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h | acc]
        count = count - 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], count: 3 do
          if count == 0 or list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [h | acc]
          count = count - 1
        end
      end,
      __ENV__
    )

    assert result == [1, 2, 3]
  end

  test "take pattern: negative n returns whole list (loop semantics)" do
    list = [1, 2, 3]

    result =
      loop acc: [], count: -2 do
        if list == [] or count == 0, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h | acc]
        count = count - 1
      end

    assert result == [1, 2, 3]
  end

  test "drop pattern: drop first n" do
    list = [1, 2, 3, 4, 5]

    result =
      loop count: 2 do
        if list == [] or count == 0, do: break(list)
        [_ | list] = list
        count = count - 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 2 do
          if list == [] or count == 0, do: break(list)
          [_ | list] = list
          count = count - 1
        end
      end,
      __ENV__
    )

    assert result == [3, 4, 5]
  end

  test "drop pattern: negative n drops all (loop semantics)" do
    list = [1, 2, 3]

    result =
      loop count: -1 do
        if count == 0 or list == [], do: break(list)
        [_ | list] = list
        count = count - 1
      end

    assert result == []
  end

  test "split pattern: split at n" do
    list = [1, 2, 3, 4, 5]

    result =
      loop left: [], count: 3 do
        if list == [] or count == 0, do: break({Enum.reverse(left), list})
        [h | list] = list
        left = [h | left]
        count = count - 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop left: [], count: 3 do
          if list == [] or count == 0, do: break({Enum.reverse(left), list})
          [h | list] = list
          left = [h | left]
          count = count - 1
        end
      end,
      __ENV__
    )

    assert result == {[1, 2, 3], [4, 5]}
  end

  test "split pattern: negative n returns {list, []} (loop semantics)" do
    list = [1, 2, 3]

    result =
      loop left: [], count: -3 do
        if count == 0 or list == [], do: break({Enum.reverse(left), list})
        [h | list] = list
        left = [h | left]
        count = count - 1
      end

    assert result == {[1, 2, 3], []}
  end

  test "split count-up pattern: split at n" do
    list = [1, 2, 3, 4, 5]
    n = 3

    result =
      loop prefix: [], suffix: list, count: 0 do
        if count >= n, do: break({Enum.reverse(prefix), suffix})
        [h | suffix] = suffix
        prefix = [h | prefix]
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop prefix: [], suffix: list, count: 0 do
          if count >= n, do: break({Enum.reverse(prefix), suffix})
          [h | suffix] = suffix
          prefix = [h | prefix]
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == {[1, 2, 3], [4, 5]}
  end

  test "split count-up pattern: take only" do
    list = [1, 2, 3, 4, 5]
    n = 2

    result =
      loop prefix: [], suffix: list, count: 0 do
        if count >= n, do: break(Enum.reverse(prefix))
        [h | suffix] = suffix
        prefix = [h | prefix]
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop prefix: [], suffix: list, count: 0 do
          if count >= n, do: break(Enum.reverse(prefix))
          [h | suffix] = suffix
          prefix = [h | prefix]
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == [1, 2]
  end

  test "split count-up pattern: drop only" do
    list = [1, 2, 3, 4, 5]
    n = 2

    result =
      loop prefix: [], suffix: list, count: 0 do
        if count >= n, do: break(suffix)
        [h | suffix] = suffix
        prefix = [h | prefix]
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop prefix: [], suffix: list, count: 0 do
          if count >= n, do: break(suffix)
          [h | suffix] = suffix
          prefix = [h | prefix]
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == [3, 4, 5]
  end

  test "split count-up pattern: initials in any order" do
    list = [1, 2, 3, 4, 5]
    n = 3

    result =
      loop count: 0, prefix: [], suffix: list do
        if count >= n, do: break({Enum.reverse(prefix), suffix})
        [h | suffix] = suffix
        prefix = [h | prefix]
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0, prefix: [], suffix: list do
          if count >= n, do: break({Enum.reverse(prefix), suffix})
          [h | suffix] = suffix
          prefix = [h | prefix]
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == {[1, 2, 3], [4, 5]}
  end

  test "take_every pattern: rem(i, n) == 0 with increment" do
    list = Enum.to_list(1..10)
    n = 3

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(i, n) == 0, do: [h | acc], else: acc
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if rem(i, n) == 0, do: [h | acc], else: acc
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == Enum.take_every(list, n)
  end

  test "take_every pattern: Kernel.rem with swapped branches" do
    list = Enum.to_list(1..12)
    n = 4

    result =
      loop acc: [], i: 0 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if Kernel.rem(i, n) !== 0, do: acc, else: [h | acc]
        i = Kernel.+(i, 1)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [], i: 0 do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if Kernel.rem(i, n) !== 0, do: acc, else: [h | acc]
          i = Kernel.+(i, 1)
        end
      end,
      __ENV__
    )

    assert result == Enum.take_every(list, n)
  end

  test "take_every pattern failure: condition depends on element" do
    list = [1, -2, -3, 4, 5]
    n = 2

    result =
      loop acc: [], i: 0 do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(i, n) == 0 and h > 0, do: [h | acc], else: acc
        i = i + 1
      end

    assert result == [1, 5]
  end
end
