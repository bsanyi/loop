defmodule LoopGenericTest do
  use ExUnit.Case, async: true
  use Loop

  alias Loop.Patterns.Advanced

  test "generic loop: multiple variables with complex logic" do
    result =
      loop x: 0, y: 10 do
        if x >= y, do: break(x)
        x = x + 1
        y = y - 1
      end

    assert result == 5
  end

  test "generic loop: fibonacci sequence" do
    result =
      loop a: 0, b: 1, n: 10 do
        if n == 0, do: break(a)
        temp = a
        a = b
        b = temp + b
        n = n - 1
      end

    assert result == 55
  end

  test "generic loop: nested control flow" do
    result =
      loop i: 1, sum: 0 do
        if i > 10, do: break(sum)

        sum =
          if rem(i, 2) == 0 do
            sum + i * 2
          else
            sum + i
          end

        i = i + 1
      end

    assert result == 85
  end

  test "generic loop: loop with case statement" do
    result =
      loop i: 1, sum: 0 do
        if i > 5, do: break(sum)

        sum =
          case rem(i, 3) do
            0 -> sum + 10
            1 -> sum + 1
            2 -> sum + 2
          end

        i = i + 1
      end

    # i=1: rem=1, sum=0+1=1
    # i=2: rem=2, sum=1+2=3
    # i=3: rem=0, sum=3+10=13
    # i=4: rem=1, sum=13+1=14
    # i=5: rem=2, sum=14+2=16
    assert result == 16
  end

  test "generic loop: complex accumulation pattern" do
    list = [1, 2, 3, 4, 5]

    result =
      loop evens: [], odds: [] do
        if list == [], do: break({evens, odds})

        [h | list] = list

        {evens, odds} =
          if rem(h, 2) == 0 do
            {[h | evens], odds}
          else
            {evens, [h | odds]}
          end

        {evens, odds}
      end

    assert result == {[4, 2], [5, 3, 1]}
  end

  test "generic loop: non-standard list traversal" do
    list = [1, 2, 3, 4, 5]

    result =
      loop sum: 0, idx: 0 do
        if idx >= length(list), do: break(sum)
        sum = sum + Enum.at(list, idx)
        idx = idx + 1
      end

    assert result == 15
  end

  test "generic loop: early exit with multiple conditions" do
    result =
      loop x: 1, y: 1 do
        if x > 100, do: break(:x_overflow)
        if y > 50, do: break(:y_overflow)
        if x * y > 200, do: break(:product_limit)
        x = x * 2
        y = y + 3
      end

    assert result == :product_limit
  end

  test "edge case: three initial bindings" do
    result =
      loop a: 1, b: 2, c: 3 do
        if a > 10, do: break({a, b, c})
        a = a + 1
        b = b + 2
        c = c + 3
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop a: 1, b: 2, c: 3 do
          if a > 10, do: break({a, b, c})
          a = a + 1
          b = b + 2
          c = c + 3
        end
      end,
      __ENV__
    )

    assert result == {11, 22, 33}
  end

  test "edge case: breaking with tuple" do
    list = [1, 2, 3]

    result =
      loop sum: 0, count: 0 do
        if list == [], do: break({sum, count})
        [h | list] = list
        sum = sum + h
        count = count + 1
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop sum: 0, count: 0 do
          if list == [], do: break({sum, count})
          [h | list] = list
          sum = sum + h
          count = count + 1
        end
      end,
      __ENV__
    )

    assert result == {6, 3}
  end

  test "edge case: breaking with map" do
    list = [1, 2, 3]

    result =
      loop do
        if list == [], do: break(%{sum: 6, count: 3})
        [h | list] = list
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(%{sum: 6, count: 3})
          [h | list] = list
        end
      end,
      __ENV__
    )

    assert result == %{sum: 6, count: 3}
  end

  test "edge case: loop body with two statements" do
    result =
      loop i: 0 do
        if i >= 5, do: break(i)
        i = i + 1
      end

    assert result == 5
  end

  test "edge case: loop body with four statements" do
    result =
      loop a: 0, b: 1 do
        if a > 10, do: break(a)
        temp = a
        a = b
        b = temp + b
      end

    assert result == 13
  end

  test "edge case: nested loops" do
    result =
      loop outer: 0, inner_sum: 0 do
        if outer >= 3, do: break(inner_sum)

        inner_result =
          loop i: 1 do
            if i > 3, do: break(i - 1)
            i = i + 1
          end

        inner_sum = inner_sum + inner_result
        outer = outer + 1
      end

    assert result == 9
  end

  test "edge case: loop with single statement body" do
    result = loop(do: break(42))
    assert result == 42
  end

  test "edge case: loop with cond statement" do
    result =
      loop i: 1, sum: 0 do
        if i > 5, do: break(sum)

        sum =
          cond do
            i == 1 -> sum + 10
            i == 3 -> sum + 30
            true -> sum + i
          end

        i = i + 1
      end

    # i=1: sum=0+10=10
    # i=2: sum=10+2=12
    # i=3: sum=12+30=42
    # i=4: sum=42+4=46
    # i=5: sum=46+5=51
    assert result == 51
  end

  test "edge case: sum pattern with float zero" do
    list = [1.5, 2.5, 3.0]

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

    assert result == 7.0
  end

  test "edge case: reduce with different accumulator name" do
    list = [1, 2, 3, 4]

    result =
      loop total: 0 do
        if list == [], do: break(total)
        total = total + hd(list)
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop total: 0 do
          if list == [], do: break(total)
          total = total + hd(list)
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == 10
  end

  test "each pattern: side effect with destructure" do
    list = [1, 2, 3]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        send(self(), {:item, h})
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          [h | list] = list
          send(self(), {:item, h})
        end
      end,
      __ENV__
    )

    assert result == :ok
    assert_received {:item, 1}
    assert_received {:item, 2}
    assert_received {:item, 3}
  end

  test "each pattern: empty list" do
    list = []

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        send(self(), {:item, h})
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          [h | list] = list
          send(self(), {:item, h})
        end
      end,
      __ENV__
    )

    assert result == :ok
    refute_received {:item, _}
  end

  test "each pattern: hd/tl variant" do
    list = [1, 2, 3]

    result =
      loop do
        if list == [], do: break(nil)
        send(self(), {:item, hd(list)})
        list = tl(list)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if list == [], do: break(nil)
          send(self(), {:item, hd(list)})
          list = tl(list)
        end
      end,
      __ENV__
    )

    assert result == :ok
    assert_received {:item, 1}
    assert_received {:item, 2}
    assert_received {:item, 3}
  end

  test "each pattern: with Enum.empty? exit" do
    list = [10, 20]

    result =
      loop do
        if Enum.empty?(list), do: break(nil)
        [h | list] = list
        send(self(), {:val, h})
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop do
          if Enum.empty?(list), do: break(nil)
          [h | list] = list
          send(self(), {:val, h})
        end
      end,
      __ENV__
    )

    assert result == :ok
    assert_received {:val, 10}
    assert_received {:val, 20}
  end

  # P084 — Complex break expression canonicalizer tests
  test "P084 normalize_break_expr: Enum.reverse(acc) ++ tail" do
    acc_var = {:acc, [], nil}
    list_var = {:list, [], nil}
    tail = {:tail, [], nil}

    break_expr =
      {:++, [],
       [
         {{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [acc_var]},
         tail
       ]}

    assert {:reverse_acc_append, ^acc_var, ^tail} =
             Advanced.normalize_break_expr(break_expr, acc_var, list_var)
  end

  test "P084 normalize_break_expr: Enum.reverse([value | acc]) ++ tail" do
    acc_var = {:acc, [], nil}
    list_var = {:list, [], nil}
    tail = {:tail, [], nil}
    value = {:val, [], nil}

    break_expr =
      {:++, [],
       [
         {{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [[{:|, [], [value, acc_var]}]]},
         tail
       ]}

    assert {:cons_reverse_acc_append, ^value, ^acc_var, ^tail} =
             Advanced.normalize_break_expr(break_expr, acc_var, list_var)
  end

  test "P084 normalize_break_expr: [value | Enum.reverse(acc)]" do
    acc_var = {:acc, [], nil}
    list_var = {:list, [], nil}
    value = {:val, [], nil}

    break_expr = [
      {:|, [], [value, {{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [acc_var]}]}
    ]

    assert {:cons_reverse_acc, ^value, ^acc_var} =
             Advanced.normalize_break_expr(break_expr, acc_var, list_var)
  end

  test "P084 normalize_break_expr: Enum.reverse(Enum.reverse(acc) ++ tail)" do
    acc_var = {:acc, [], nil}
    list_var = {:list, [], nil}
    tail = {:tail, [], nil}

    inner =
      {:++, [],
       [
         {{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [acc_var]},
         tail
       ]}

    break_expr = {{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [inner]}

    assert {:reverse_reverse_acc_append, ^acc_var, ^tail} =
             Advanced.normalize_break_expr(break_expr, acc_var, list_var)
  end

  test "P084 normalize_break_expr: plain acc" do
    acc_var = {:acc, [], nil}
    list_var = {:list, [], nil}

    assert {:plain_acc, ^acc_var} =
             Advanced.normalize_break_expr(acc_var, acc_var, list_var)
  end

  test "P084 normalize_break_expr: Enum.reverse(acc)" do
    acc_var = {:acc, [], nil}
    list_var = {:list, [], nil}

    break_expr = {{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [acc_var]}

    assert {:reverse_acc, ^acc_var} =
             Advanced.normalize_break_expr(break_expr, acc_var, list_var)
  end

  test "P084 normalize_break_expr: unrecognized form returns nil" do
    acc_var = {:acc, [], nil}
    list_var = {:list, [], nil}
    break_expr = {:something_else, [], []}

    assert nil == Advanced.normalize_break_expr(break_expr, acc_var, list_var)
  end

  test "P084 normalize_break_expr: Enum.reverse([value | acc])" do
    acc_var = {:acc, [], nil}
    list_var = {:list, [], nil}
    value = {:val, [], nil}

    break_expr =
      {{:., [], [{:__aliases__, [], [:Enum]}, :reverse]}, [], [[{:|, [], [value, acc_var]}]]}

    assert {:reverse_cons_acc, ^value, ^acc_var} =
             Advanced.normalize_break_expr(break_expr, acc_var, list_var)
  end
end
