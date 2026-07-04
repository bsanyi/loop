defmodule LoopPatternsFailuresTest do
  use ExUnit.Case, async: true
  use Loop

  # Each test here pins BOTH the runtime value and which compilation path the
  # loop takes: `assert_fallback` for shapes the matchers must reject, and
  # `assert_pattern_recognized` for shapes that used to fall back but are now
  # canonicalized into a recognized pattern. If a normalize/matcher change
  # moves a loop from one group to the other, the pin fails and the test must
  # be reclassified consciously.

  test "map recognized: list == [] exit is canonicalized" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if list == [], do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [h * 2 | acc]
        end
      end,
      __ENV__
    )

    assert result == [2, 4, 6]
  end

  test "map recognized: any accumulator name works" do
    list = [1, 2, 3]

    result =
      loop out: [] do
        if Enum.empty?(list), do: break(Enum.reverse(out))
        [h | list] = list
        out = [h * 2 | out]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop out: [] do
          if Enum.empty?(list), do: break(Enum.reverse(out))
          [h | list] = list
          out = [h * 2 | out]
        end
      end,
      __ENV__
    )

    assert result == [2, 4, 6]
  end

  test "map fallback: break variable differs from the declared accumulator" do
    # `other` is never initialized by the loop's own bindings, so rewriting this
    # to Enum.map would change semantics; the matcher must reject it.
    Loop.TestHelpers.assert_fallback(
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(other))
          [h | list] = list
          other = [h * 2 | other]
        end
      end,
      __ENV__
    )
  end

  test "map fallback: missing Enum.reverse in break" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(acc)
        [h | list] = list
        acc = [h * 2 | acc]
      end

    Loop.TestHelpers.assert_fallback(
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(acc)
          [h | list] = list
          acc = [h * 2 | acc]
        end
      end,
      __ENV__
    )

    assert result == [6, 4, 2]
  end

  test "map fallback: transform ignores element variable" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [42 | acc]
      end

    Loop.TestHelpers.assert_fallback(
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = [42 | acc]
        end
      end,
      __ENV__
    )

    assert result == [42, 42, 42]
  end

  test "map recognized: ++ append form instead of cons" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(acc)
        [h | list] = list
        acc = acc ++ [h * 2]
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(acc)
          [h | list] = list
          acc = acc ++ [h * 2]
        end
      end,
      __ENV__
    )

    assert result == [2, 4, 6]
  end

  test "filter+map recognized: transformation inside filter accumulation" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: [h * 2 | acc], else: acc
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = if rem(h, 2) == 0, do: [h * 2 | acc], else: acc
        end
      end,
      __ENV__
    )

    assert result == [4, 8]
  end

  test "filter fallback: extra statement breaks the pattern shape" do
    list = [1, 2, 3, 4, 5]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list

        acc =
          if rem(h, 2) == 0 do
            [h | acc]
          else
            acc
          end

        _ = :dummy
      end

    Loop.TestHelpers.assert_fallback(
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list

          acc =
            if rem(h, 2) == 0 do
              [h | acc]
            else
              acc
            end

          _ = :dummy
        end
      end,
      __ENV__
    )

    assert result == [2, 4]
  end

  test "filter fallback: && / || instead of if...else" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = (rem(h, 2) == 0 && [h | acc]) || acc
      end

    Loop.TestHelpers.assert_fallback(
      quote do
        loop acc: [] do
          if Enum.empty?(list), do: break(Enum.reverse(acc))
          [h | list] = list
          acc = (rem(h, 2) == 0 && [h | acc]) || acc
        end
      end,
      __ENV__
    )

    assert result == [2, 4]
  end

  test "find recognized: Enum.empty? exit is canonicalized" do
    list = [1, 3, 4, 5]

    result =
      loop do
        if Enum.empty?(list), do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if Enum.empty?(list), do: break(nil)
          [h | list] = list
          if rem(h, 2) == 0, do: break(h)
        end
      end,
      __ENV__
    )

    assert result == 4
  end

  test "find recognized: non-nil default becomes Enum.find/3" do
    list = []

    result =
      loop do
        if list == [], do: break(:not_found)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(:not_found)
          [h | list] = list
          if rem(h, 2) == 0, do: break(h)
        end
      end,
      __ENV__
    )

    assert result == :not_found
  end

  test "find_value recognized: break with transformed element" do
    list = [1, 3, 4, 5]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h * 10)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          [h | list] = list
          if rem(h, 2) == 0, do: break(h * 10)
        end
      end,
      __ENV__
    )

    assert result == 40
  end

  test "count fallback: increment by 2 instead of 1" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if rem(h, 2) == 0, do: count + 2, else: count
      end

    Loop.TestHelpers.assert_fallback(
      quote do
        loop count: 0 do
          if list == [], do: break(count)
          [h | list] = list
          count = if rem(h, 2) == 0, do: count + 2, else: count
        end
      end,
      __ENV__
    )

    assert result == 6
  end

  test "count recognized: Enum.empty? exit is canonicalized" do
    list = [1, 2, 3, 4]

    result =
      loop count: 0 do
        if Enum.empty?(list), do: break(count)
        [h | list] = list
        count = if rem(h, 2) == 0, do: count + 1, else: count
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop count: 0 do
          if Enum.empty?(list), do: break(count)
          [h | list] = list
          count = if rem(h, 2) == 0, do: count + 1, else: count
        end
      end,
      __ENV__
    )

    assert result == 2
  end

  test "count recognized: any accumulator name works" do
    list = [1, 2, 3, 4]

    result =
      loop cnt: 0 do
        if list == [], do: break(cnt)
        [h | list] = list
        cnt = if rem(h, 2) == 0, do: cnt + 1, else: cnt
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop cnt: 0 do
          if list == [], do: break(cnt)
          [h | list] = list
          cnt = if rem(h, 2) == 0, do: cnt + 1, else: cnt
        end
      end,
      __ENV__
    )

    assert result == 2
  end

  test "any fallback: || instead of or" do
    list = [1, 3, 5, 6]

    result =
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result || rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_fallback(
      quote do
        loop result: false do
          if list == [], do: break(result)
          [h | list] = list
          result = result || rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "any recognized: Enum.empty? exit is canonicalized" do
    list = [1, 2, 3]

    result =
      loop result: false do
        if Enum.empty?(list), do: break(result)
        [h | list] = list
        result = result or rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: false do
          if Enum.empty?(list), do: break(result)
          [h | list] = list
          result = result or rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "any recognized: any accumulator name works" do
    list = [1, 2, 3]

    result =
      loop found: false do
        if list == [], do: break(found)
        [h | list] = list
        found = found or rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop found: false do
          if list == [], do: break(found)
          [h | list] = list
          found = found or rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "all fallback: && instead of and" do
    list = [2, 4, 6]

    result =
      loop result: true do
        if list == [], do: break(result)
        [h | list] = list
        result = result && rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_fallback(
      quote do
        loop result: true do
          if list == [], do: break(result)
          [h | list] = list
          result = result && rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "all recognized: Enum.empty? exit is canonicalized" do
    list = [1, 2, 3]

    result =
      loop result: true do
        if Enum.empty?(list), do: break(result)
        [h | list] = list
        result = result and h > 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop result: true do
          if Enum.empty?(list), do: break(result)
          [h | list] = list
          result = result and h > 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "all recognized: any accumulator name works" do
    list = [2, 4, 6]

    result =
      loop check: true do
        if list == [], do: break(check)
        [h | list] = list
        check = check and rem(h, 2) == 0
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop check: true do
          if list == [], do: break(check)
          [h | list] = list
          check = check and rem(h, 2) == 0
        end
      end,
      __ENV__
    )

    assert result == true
  end

  test "find fallback: default expression depends on loop state" do
    list = [1, 2]

    result =
      loop do
        if list == [], do: break(list)
        [h | list] = list
        if h > 10, do: break(h)
      end

    Loop.TestHelpers.assert_fallback(
      quote do
        loop do
          if list == [], do: break(list)
          [h | list] = list
          if h > 10, do: break(h)
        end
      end,
      __ENV__
    )

    assert result == []
  end
end
