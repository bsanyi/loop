defmodule LoopPatternsFailuresTest do
  use ExUnit.Case, async: true
  use Loop

  test "map pattern failure: wrong exit condition (list == [] instead of Enum.empty?)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern failure: missing Enum.reverse in break" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(acc)
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [6, 4, 2]
  end

  test "map pattern failure: transform doesn't use element variable" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [42 | acc]
      end

    assert result == [42, 42, 42]
  end

  test "map pattern failure: using ++ instead of cons operator" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(acc)
        [h | list] = list
        acc = acc ++ [h * 2]
      end

    assert result == [2, 4, 6]
  end

  test "filter pattern failure: element transformation in accumulation" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: [h * 2 | acc], else: acc
      end

    assert result == [4, 8]
  end

  test "filter pattern failure: missing else clause" do
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

        # Extra statement to break 3-statement pattern
        _ = :dummy
      end

    # This will fail to recognize as filter pattern due to 4 statements
    assert result == [2, 4]
  end

  test "filter pattern failure: using || instead of if...else" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = (rem(h, 2) == 0 && [h | acc]) || acc
      end

    assert result == [2, 4]
  end

  test "find pattern failure: using Enum.empty? instead of list == []" do
    list = [1, 3, 4, 5]

    result =
      loop do
        if Enum.empty?(list), do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h)
      end

    assert result == 4
  end

  test "find pattern failure: breaking with non-nil when empty" do
    list = []

    result =
      loop do
        if list == [], do: break(:not_found)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h)
      end

    assert result == :not_found
  end

  test "find pattern failure: breaking with transformed element" do
    list = [1, 3, 4, 5]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h * 10)
      end

    assert result == 40
  end

  test "count pattern failure: increment by 2 instead of 1" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if rem(h, 2) == 0, do: count + 2, else: count
      end

    assert result == 6
  end

  test "count pattern failure: using Enum.empty? instead of list == []" do
    list = [1, 2, 3, 4]

    result =
      loop count: 0 do
        if Enum.empty?(list), do: break(count)
        [h | list] = list
        count = if rem(h, 2) == 0, do: count + 1, else: count
      end

    assert result == 2
  end

  test "count pattern failure: mismatched variable names" do
    list = [1, 2, 3, 4]

    result =
      loop cnt: 0 do
        if list == [], do: break(cnt)
        [h | list] = list
        cnt = if rem(h, 2) == 0, do: cnt + 1, else: cnt
      end

    assert result == 2
  end

  test "any pattern failure: using || instead of or" do
    list = [1, 3, 5, 6]

    result =
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result || rem(h, 2) == 0
      end

    assert result == true
  end

  test "any pattern failure: using Enum.empty? instead of list == []" do
    list = [1, 2, 3]

    result =
      loop result: false do
        if Enum.empty?(list), do: break(result)
        [h | list] = list
        result = result or rem(h, 2) == 0
      end

    assert result == true
  end

  test "any pattern failure: mismatched variable names" do
    list = [1, 2, 3]

    result =
      loop found: false do
        if list == [], do: break(found)
        [h | list] = list
        found = found or rem(h, 2) == 0
      end

    assert result == true
  end

  test "all pattern failure: using && instead of and" do
    list = [2, 4, 6]

    result =
      loop result: true do
        if list == [], do: break(result)
        [h | list] = list
        result = result && rem(h, 2) == 0
      end

    assert result == true
  end

  test "all pattern failure: using Enum.empty? instead of list == []" do
    list = [1, 2, 3]

    result =
      loop result: true do
        if Enum.empty?(list), do: break(result)
        [h | list] = list
        result = result and h > 0
      end

    assert result == true
  end

  test "all pattern failure: mismatched variable names" do
    list = [2, 4, 6]

    result =
      loop check: true do
        if list == [], do: break(check)
        [h | list] = list
        check = check and rem(h, 2) == 0
      end

    assert result == true
  end

  test "find pattern failure: default expression depends on loop state" do
    list = [1, 2]

    result =
      loop do
        if list == [], do: break(list)
        [h | list] = list
        if h > 10, do: break(h)
      end

    assert result == []
  end
end
