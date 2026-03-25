defmodule LoopPatternsCoreTest do
  use ExUnit.Case, async: true
  use Loop

  test "map pattern: double each element" do
    list = [1, 2, 3, 4, 5]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [2 * h | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [2 * h | acc]
        end
      end,
      __ENV__
    )

    assert result == [2, 4, 6, 8, 10]
  end

  test "map pattern: transform strings" do
    list = ["hello", "world"]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [String.upcase(h) | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [String.upcase(h) | acc]
        end
      end,
      __ENV__
    )

    assert result == ["HELLO", "WORLD"]
  end

  test "map pattern: complex transformation" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * h + 1 | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [h * h + 1 | acc]
        end
      end,
      __ENV__
    )

    assert result == [2, 5, 10]
  end

  test "map pattern: empty list" do
    list = []

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [h * 2 | acc]
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "filter pattern: filter even numbers" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: [h | acc], else: acc
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if rem(h, 2) == 0, do: [h | acc], else: acc
        end
      end,
      __ENV__
    )

    assert result == [2, 4, 6]
  end

  test "filter pattern: filter strings by length" do
    list = ["a", "bb", "ccc", "d"]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if String.length(h) > 1, do: [h | acc], else: acc
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if String.length(h) > 1, do: [h | acc], else: acc
        end
      end,
      __ENV__
    )

    assert result == ["bb", "ccc"]
  end

  test "filter pattern: filter positive numbers" do
    list = [-2, -1, 0, 1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 0, do: [h | acc], else: acc
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h > 0, do: [h | acc], else: acc
        end
      end,
      __ENV__
    )

    assert result == [1, 2, 3]
  end

  test "filter pattern: empty list" do
    list = []

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 0, do: [h | acc], else: acc
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h > 0, do: [h | acc], else: acc
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "find pattern: find first even number" do
    list = [1, 3, 5, 6, 8, 10]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          [h | list] = list
          if rem(h, 2) == 0, do: break(h)
        end
      end,
      __ENV__
    )

    assert result == 6
  end

  test "find pattern: find first string starting with 'b'" do
    list = ["apple", "banana", "cherry", "blueberry"]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if String.starts_with?(h, "b"), do: break(h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          [h | list] = list
          if String.starts_with?(h, "b"), do: break(h)
        end
      end,
      __ENV__
    )

    assert result == "banana"
  end

  test "find pattern: no match returns nil" do
    list = [1, 3, 5, 7]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          [h | list] = list
          if rem(h, 2) == 0, do: break(h)
        end
      end,
      __ENV__
    )

    assert result == nil
  end

  test "find pattern: empty list returns nil" do
    list = []

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if h > 10, do: break(h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          [h | list] = list
          if h > 10, do: break(h)
        end
      end,
      __ENV__
    )

    assert result == nil
  end

  test "count pattern: count even numbers" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if rem(h, 2) == 0, do: count + 1, else: count
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [h | list] = list
          count = if rem(h, 2) == 0, do: count + 1, else: count
        end
      end,
      __ENV__
    )

    assert result == 3
  end

  test "count pattern: count positive numbers" do
    list = [-2, -1, 0, 1, 2, 3]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if h > 0, do: count + 1, else: count
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [h | list] = list
          count = if h > 0, do: count + 1, else: count
        end
      end,
      __ENV__
    )

    assert result == 3
  end

  test "count pattern: count strings longer than 3 chars" do
    list = ["a", "bb", "ccc", "dddd", "eeeee"]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if String.length(h) > 3, do: count + 1, else: count
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [h | list] = list
          count = if String.length(h) > 3, do: count + 1, else: count
        end
      end,
      __ENV__
    )

    assert result == 2
  end

  test "count pattern: empty list" do
    list = []

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if h > 0, do: count + 1, else: count
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [h | list] = list
          count = if h > 0, do: count + 1, else: count
        end
      end,
      __ENV__
    )

    assert result == 0
  end

  test "count pattern: no matches" do
    list = [1, 3, 5, 7]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if rem(h, 2) == 0, do: count + 1, else: count
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [h | list] = list
          count = if rem(h, 2) == 0, do: count + 1, else: count
        end
      end,
      __ENV__
    )

    assert result == 0
  end

  test "any pattern: check if any even numbers exist" do
    list = [1, 3, 5, 6, 7]

    result =
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result or rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: false do
          if list == [], do: break(result)
          [h | list] = list
          result = result or rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "any pattern: no matches returns false" do
    list = [1, 3, 5, 7]

    result =
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result or rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: false do
          if list == [], do: break(result)
          [h | list] = list
          result = result or rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == false
  end

  test "any pattern: check if any positive numbers" do
    list = [-2, -1, 0, 1]

    result =
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result or h > 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: false do
          if list == [], do: break(result)
          [h | list] = list
          result = result or h > 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "any pattern: empty list returns false" do
    list = []

    result =
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result or h > 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: false do
          if list == [], do: break(result)
          [h | list] = list
          result = result or h > 0
        end
      end,
      __ENV__
    )

    assert result == false
  end

  test "all pattern: check if all numbers are positive" do
    list = [1, 2, 3, 4, 5]

    result =
      loop result: true do
        if list == [], do: break(result)
        [h | list] = list
        result = result and h > 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: true do
          if list == [], do: break(result)
          [h | list] = list
          result = result and h > 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "all pattern: not all match returns false" do
    list = [1, 2, -3, 4, 5]

    result =
      loop result: true do
        if list == [], do: break(result)
        [h | list] = list
        result = result and h > 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: true do
          if list == [], do: break(result)
          [h | list] = list
          result = result and h > 0
        end
      end,
      __ENV__
    )

    assert result == false
  end

  test "all pattern: check if all even" do
    list = [2, 4, 6, 8]

    result =
      loop result: true do
        if list == [], do: break(result)
        [h | list] = list
        result = result and rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: true do
          if list == [], do: break(result)
          [h | list] = list
          result = result and rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "all pattern: empty list returns true" do
    list = []

    result =
      loop result: true do
        if list == [], do: break(result)
        [h | list] = list
        result = result and h > 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: true do
          if list == [], do: break(result)
          [h | list] = list
          result = result and h > 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "map pattern: single element" do
    list = [5]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 3 | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [h * 3 | acc]
        end
      end,
      __ENV__
    )

    assert result == [15]
  end

  test "map pattern: with division transformation" do
    list = [10, 20, 30]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [div(h, 2) | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [div(h, 2) | acc]
        end
      end,
      __ENV__
    )

    assert result == [5, 10, 15]
  end

  test "filter pattern: all elements match" do
    list = [2, 4, 6, 8]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: [h | acc], else: acc
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if rem(h, 2) == 0, do: [h | acc], else: acc
        end
      end,
      __ENV__
    )

    assert result == [2, 4, 6, 8]
  end

  test "filter pattern: no elements match" do
    list = [1, 3, 5, 7]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: [h | acc], else: acc
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if rem(h, 2) == 0, do: [h | acc], else: acc
        end
      end,
      __ENV__
    )

    assert result == []
  end

  test "filter pattern: single element match" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h == 2, do: [h | acc], else: acc
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if h == 2, do: [h | acc], else: acc
        end
      end,
      __ENV__
    )

    assert result == [2]
  end

  test "find pattern: first element matches" do
    list = [2, 4, 6, 8]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          [h | list] = list
          if rem(h, 2) == 0, do: break(h)
        end
      end,
      __ENV__
    )

    assert result == 2
  end

  test "find pattern: last element matches" do
    list = [1, 3, 5, 7, 8]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          [h | list] = list
          if rem(h, 2) == 0, do: break(h)
        end
      end,
      __ENV__
    )

    assert result == 8
  end

  test "find pattern: single element matches" do
    list = [42]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if h == 42, do: break(h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          [h | list] = list
          if h == 42, do: break(h)
        end
      end,
      __ENV__
    )

    assert result == 42
  end

  test "find pattern: single element doesn't match" do
    list = [41]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if h == 42, do: break(h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          [h | list] = list
          if h == 42, do: break(h)
        end
      end,
      __ENV__
    )

    assert result == nil
  end

  test "count pattern: all elements match" do
    list = [2, 4, 6]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if rem(h, 2) == 0, do: count + 1, else: count
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [h | list] = list
          count = if rem(h, 2) == 0, do: count + 1, else: count
        end
      end,
      __ENV__
    )

    assert result == 3
  end

  test "count pattern: single element matches" do
    list = [1, 2, 3]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if h == 2, do: count + 1, else: count
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [h | list] = list
          count = if h == 2, do: count + 1, else: count
        end
      end,
      __ENV__
    )

    assert result == 1
  end

  test "any pattern: first element matches" do
    list = [2, 3, 5, 7]

    result =
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result or rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: false do
          if list == [], do: break(result)
          [h | list] = list
          result = result or rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "any pattern: all elements match" do
    list = [2, 4, 6, 8]

    result =
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result or rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: false do
          if list == [], do: break(result)
          [h | list] = list
          result = result or rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "any pattern: single element matches" do
    list = [2]

    result =
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result or rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: false do
          if list == [], do: break(result)
          [h | list] = list
          result = result or rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "any pattern: single element doesn't match" do
    list = [3]

    result =
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result or rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: false do
          if list == [], do: break(result)
          [h | list] = list
          result = result or rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == false
  end

  test "all pattern: single element matches" do
    list = [2]

    result =
      loop result: true do
        if list == [], do: break(result)
        [h | list] = list
        result = result and rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: true do
          if list == [], do: break(result)
          [h | list] = list
          result = result and rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "all pattern: single element doesn't match" do
    list = [3]

    result =
      loop result: true do
        if list == [], do: break(result)
        [h | list] = list
        result = result and rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: true do
          if list == [], do: break(result)
          [h | list] = list
          result = result and rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == false
  end

  test "all pattern: first element doesn't match" do
    list = [1, 2, 4, 6]

    result =
      loop result: true do
        if list == [], do: break(result)
        [h | list] = list
        result = result and rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: true do
          if list == [], do: break(result)
          [h | list] = list
          result = result and rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == false
  end

  test "find pattern: hd/tl parity" do
    list = [1, 3, 5, 8]

    result =
      loop do
        if list == [], do: break(nil)
        if rem(hd(list), 2) == 0, do: break(hd(list))
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          if rem(hd(list), 2) == 0, do: break(hd(list))
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 8
  end

  test "find pattern: default value via break on empty" do
    list = [1, 2, 3]

    result =
      loop do
        if list == [], do: break(:none)
        [h | list] = list
        if h > 10, do: break(h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(:none)
          [h | list] = list
          if h > 10, do: break(h)
        end
      end,
      __ENV__
    )

    assert result == Enum.find(list, :none, &(&1 > 10))
  end
end
