defmodule LoopPatternsSearchTest do
  use ExUnit.Case, async: true
  use Loop

  test "member? pattern: element found" do
    list = [1, 2, 3, 4, 5]

    result =
      loop do
        if list == [], do: break(false)
        [h | list] = list
        if h == 3, do: break(true)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(false)
          [h | list] = list
          if h == 3, do: break(true)
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "member? pattern: element not found" do
    list = [1, 2, 3, 4, 5]

    result =
      loop do
        if list == [], do: break(false)
        [h | list] = list
        if h == 99, do: break(true)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(false)
          [h | list] = list
          if h == 99, do: break(true)
        end
      end,
      __ENV__
    )

    assert result == false
  end

  test "member? pattern: empty list" do
    list = []

    result =
      loop do
        if list == [], do: break(false)
        [h | list] = list
        if h == 1, do: break(true)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(false)
          [h | list] = list
          if h == 1, do: break(true)
        end
      end,
      __ENV__
    )

    assert result == false
  end

  test "member? pattern: first element matches" do
    list = [42, 1, 2, 3]

    result =
      loop do
        if list == [], do: break(false)
        [h | list] = list
        if h == 42, do: break(true)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(false)
          [h | list] = list
          if h == 42, do: break(true)
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "member? pattern: target on left side of ==" do
    list = [1, 2, 3]
    target = 2

    result =
      loop do
        if list == [], do: break(false)
        [h | list] = list
        if target == h, do: break(true)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(false)
          [h | list] = list
          if target == h, do: break(true)
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "find_index pattern: find first even" do
    list = [1, 3, 4, 5, 6]

    result =
      loop index: 0 do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(index)
        index = index + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop index: 0 do
          if list == [], do: break(nil)
          [h | list] = list
          if rem(h, 2) == 0, do: break(index)
          index = index + 1
        end
      end,
      __ENV__
    )

    assert result == 2
  end

  test "find_index pattern: not found" do
    list = [1, 3, 5, 7]

    result =
      loop index: 0 do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(index)
        index = index + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop index: 0 do
          if list == [], do: break(nil)
          [h | list] = list
          if rem(h, 2) == 0, do: break(index)
          index = index + 1
        end
      end,
      __ENV__
    )

    assert result == nil
  end

  test "find_index pattern: first element" do
    list = [2, 3, 4]

    result =
      loop index: 0 do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(index)
        index = index + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop index: 0 do
          if list == [], do: break(nil)
          [h | list] = list
          if rem(h, 2) == 0, do: break(index)
          index = index + 1
        end
      end,
      __ENV__
    )

    assert result == 0
  end

  test "find_index pattern: last element" do
    list = [1, 3, 5, 6]

    result =
      loop index: 0 do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(index)
        index = index + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop index: 0 do
          if list == [], do: break(nil)
          [h | list] = list
          if rem(h, 2) == 0, do: break(index)
          index = index + 1
        end
      end,
      __ENV__
    )

    assert result == 3
  end

  test "find_index pattern: empty list" do
    list = []

    result =
      loop index: 0 do
        if list == [], do: break(nil)
        [h | list] = list
        if h > 10, do: break(index)
        index = index + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop index: 0 do
          if list == [], do: break(nil)
          [h | list] = list
          if h > 10, do: break(index)
          index = index + 1
        end
      end,
      __ENV__
    )

    assert result == nil
  end

  test "find_index pattern: different variable name" do
    list = [10, 20, 30]

    result =
      loop i: 0 do
        if list == [], do: break(nil)
        [h | list] = list
        if h == 20, do: break(i)
        i = i + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop i: 0 do
          if list == [], do: break(nil)
          [h | list] = list
          if h == 20, do: break(i)
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == 1
  end

  test "none? pattern: returns true when no element matches" do
    list = [1, 3, 5, 7]

    result =
      loop do
        if list == [], do: break(true)
        [h | list] = list
        if rem(h, 2) == 0, do: break(false)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(true)
          [h | list] = list
          if rem(h, 2) == 0, do: break(false)
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "none? pattern: cond + hd/tl parity" do
    list = [1, 2, 3]

    result =
      loop do
        cond do
          list == [] ->
            break(true)

          list != [] ->
            if hd(list) > 10, do: break(false)
            list = tl(list)
        end
      end

    assert result == true
  end

  test "find_value pattern: assignment-based truthy mapper" do
    list = [1, 3, 4, 6]

    result =
      loop do
        if list == [], do: break(nil)
        value = if rem(hd(list), 2) == 0, do: hd(list) * 10, else: nil
        if value, do: break(value)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          value = if rem(hd(list), 2) == 0, do: hd(list) * 10, else: nil
          if value, do: break(value)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 40
  end

  test "find_at pattern: explicit index target" do
    list = [:a, :b, :c, :d]
    wanted = 2

    result =
      loop index: 0 do
        if list == [], do: break(nil)
        [h | list] = list
        if index == wanted, do: break(h)
        index = index + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop index: 0 do
          if list == [], do: break(nil)
          [h | list] = list
          if index == wanted, do: break(h)
          index = index + 1
        end
      end,
      __ENV__
    )

    assert result == :c
  end

  test "find_at pattern: negative index keeps loop semantics (nil)" do
    list = [:a, :b, :c]
    wanted = -1

    result =
      loop index: 0 do
        if list == [], do: break(nil)
        [h | list] = list
        if index == wanted, do: break(h)
        index = index + 1
      end

    assert result == nil
  end

  test "member? pattern: case + hd/tl parity" do
    list = [1, 2, 3, 4]
    target = 3

    result =
      loop do
        case list do
          [] ->
            break(false)

          _ ->
            if hd(list) == target, do: break(true)
            list = tl(list)
        end
      end

    assert result == true
  end

  test "find_index pattern: cond + hd/tl parity" do
    list = [1, 3, 4, 6]

    result =
      loop index: 0 do
        cond do
          list == [] ->
            break(nil)

          list != [] ->
            if rem(hd(list), 2) == 0, do: break(index)
            index = index + 1
            list = tl(list)
        end
      end

    assert result == 2
  end

  test "member? pattern failure: using Enum.empty?" do
    list = [1, 2, 3]

    result =
      loop do
        if Enum.empty?(list), do: break(false)
        [h | list] = list
        if h == 2, do: break(true)
      end

    assert result == true
  end

  test "find_index pattern failure: wrong initial value" do
    list = [1, 2, 3]

    result =
      loop index: 1 do
        if list == [], do: break(nil)
        [h | list] = list
        if h == 2, do: break(index)
        index = index + 1
      end

    # Falls back but still works
    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop index: 1 do
          if list == [], do: break(nil)
          [h | list] = list
          if h == 2, do: break(index)
          index = index + 1
        end
      end,
      __ENV__
    )

    assert result == 2
  end

  test "find_value pattern: default value via break on empty" do
    list = [1, 2, 3, 4]

    result =
      loop do
        if list == [], do: break(:none)
        [h | list] = list
        value = if rem(h, 2) == 0, do: h * 10, else: nil
        if value, do: break(value)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(:none)
          [h | list] = list
          value = if rem(h, 2) == 0, do: h * 10, else: nil
          if value, do: break(value)
        end
      end,
      __ENV__
    )

    assert result == Enum.find_value(list, :none, fn h -> if rem(h, 2) == 0, do: h * 10 end)
  end

  test "find_value pattern failure: mapper must not capture loop list tail" do
    list = [1, 2, 3, 4]

    result =
      loop do
        if list == [], do: break([])
        [h | list] = list
        if h > 2, do: break([h | list])
      end

    assert result == [3, 4]
  end
end
