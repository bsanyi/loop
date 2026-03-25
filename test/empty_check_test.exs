defmodule EmptyCheckTest do
  use ExUnit.Case, async: true
  use Loop

  # credo:disable-for-this-file Credo.Check.Warning.ExpensiveEmptyEnumCheck

  # Test all the different ways of checking if a list is empty
  # These should all be recognized and optimized to Enum.map

  test "map pattern: list == []" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: [] == list" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if [] == list, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: list === []" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if list === [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: [] === list" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if [] === list, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: Kernel.==(list, [])" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Kernel.==(list, []), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: Kernel.==([], list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Kernel.==([], list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: Kernel.===(list, [])" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Kernel.===(list, []), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: Kernel.===([], list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Kernel.===([], list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: Enum.empty?(list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: length(list) == 0" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if length(list) == 0, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: 0 == length(list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if 0 == length(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: length(list) <= 0" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if length(list) <= 0, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: 0 >= length(list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if 0 >= length(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: length(list) < 1" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if length(list) < 1, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: 1 > length(list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if 1 > length(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: Enum.count(list) == 0" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.count(list) == 0, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: 0 == Enum.count(list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if 0 == Enum.count(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: Enum.count(list) <= 0" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.count(list) <= 0, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: 0 >= Enum.count(list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if 0 >= Enum.count(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: Enum.count(list) < 1" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Enum.count(list) < 1, do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: 1 > Enum.count(list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if 1 > Enum.count(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  # Test with find pattern (using different check)
  test "find pattern: Enum.count(list) == 0" do
    list = [1, 3, 4, 5]

    result =
      loop do
        if Enum.count(list) == 0, do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h)
      end

    assert result == 4
  end

  test "find pattern: length(list) < 1" do
    list = [1, 3, 4, 5]

    result =
      loop do
        if length(list) < 1, do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h)
      end

    assert result == 4
  end

  # Test with count pattern
  test "count pattern: 0 == length(list)" do
    list = [1, 2, 3, 4]

    result =
      loop count: 0 do
        if 0 == length(list), do: break(count)
        [h | list] = list
        count = if rem(h, 2) == 0, do: count + 1, else: count
      end

    assert result == 2
  end

  # Test with reverse pattern
  test "reverse pattern: length(list) == 0" do
    list = [1, 2, 3]

    Loop.TestHelpers.assert_recognized(
      quote do
        loop acc: [] do
          if length(list) == 0, do: break(acc)
          [h | list] = list
          acc = [h | acc]
        end
      end,
      __ENV__,
      &Loop.TestHelpers.enum_reverse_call?/1
    )

    result =
      loop acc: [] do
        if length(list) == 0, do: break(acc)
        [h | list] = list
        acc = [h | acc]
      end

    assert result == [3, 2, 1]
  end

  # Test with member? pattern
  test "member? pattern: Enum.count(list) < 1" do
    list = [1, 2, 3]

    result =
      loop do
        if Enum.count(list) < 1, do: break(false)
        [h | list] = list
        if h == 2, do: break(true)
      end

    assert result == true
  end

  # Test with any pattern
  test "any pattern: length(list) <= 0" do
    list = [1, 2, 3]

    result =
      loop result: false do
        if length(list) <= 0, do: break(result)
        [h | list] = list
        result = result or rem(h, 2) == 0
      end

    assert result == true
  end

  # Test with all pattern
  test "all pattern: 1 > length(list)" do
    list = [2, 4, 6]

    result =
      loop result: true do
        if 1 > length(list), do: break(result)
        [h | list] = list
        result = result and rem(h, 2) == 0
      end

    assert result == true
  end

  # Test with each pattern
  test "each pattern: 0 >= Enum.count(list)" do
    list = [1, 2, 3]

    result =
      loop do
        if 0 >= Enum.count(list), do: break(nil)
        [h | list] = list
        send(self(), {:item, h})
      end

    assert result == :ok
    assert_received {:item, 1}
    assert_received {:item, 2}
    assert_received {:item, 3}
  end

  # Test with sum/reduce pattern
  test "reduce pattern: Enum.count(list) == 0" do
    list = [1, 2, 3]

    result =
      loop sum: 0 do
        if Enum.count(list) == 0, do: break(sum)
        sum = sum + hd(list)
        list = tl(list)
      end

    assert result == 6
  end

  # Test match? patterns
  test "map pattern: match?([], list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if match?([], list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: Kernel.match?([], list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if Kernel.match?([], list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: not match?([_ | _], list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if not match?([_ | _], list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: not Kernel.match?([_ | _], list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if not Kernel.match?([_ | _], list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  # Test case expression
  test "map pattern: case list do [] -> true; _ -> false end" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if(
          case list do
            [] -> true
            _ -> false
          end,
          do: break(Enum.reverse(acc))
        )

        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  # Test List.flatten patterns
  test "map pattern: List.flatten(list) == []" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if List.flatten(list) == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: [] == List.flatten(list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if [] == List.flatten(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: :lists.flatten(list) == []" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if :lists.flatten(list) == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end

  test "map pattern: [] == :lists.flatten(list)" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if [] == :lists.flatten(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 2 | acc]
      end

    assert result == [2, 4, 6]
  end
end
