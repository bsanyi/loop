defmodule LoopTest do
  use ExUnit.Case
  use Loop

  test "loop runs infinitely" do
    pid =
      spawn_link(fn ->
        loop do
          :nothing
        end
      end)

    Process.sleep(1_000)
    assert Process.alive?(pid)
    Process.exit(pid, :normal)
  end

  test "loop can sum up numbers" do
    list = [4, 5, 6, 7, 8]

    value =
      loop sum: 0 do
        if list == [], do: break(sum)
        sum = sum + hd(list)
        list = tl(list)
      end

    assert value == Enum.sum(list)
  end

  test "break(value) makes `loop` return the `value`" do
    returned =
      loop do
        _ = 42
        break(123)
      end

    assert returned == 123
  end

  test "break() makes `loop` return `nil`" do
    returned =
      loop do
        _ = 42
        break()
      end

    assert returned == nil
  end

  # Map Pattern Tests
  test "map pattern: double each element" do
    list = [1, 2, 3, 4, 5]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [2 * h | acc]
      end

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

    assert result == []
  end

  # Filter Pattern Tests
  test "filter pattern: filter even numbers" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: [h | acc], else: acc
      end

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

    assert result == []
  end

  # Find Pattern Tests
  test "find pattern: find first even number" do
    list = [1, 3, 5, 6, 8, 10]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(h)
      end

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

    assert result == nil
  end

  # Count Pattern Tests
  test "count pattern: count even numbers" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [h | list] = list
        count = if rem(h, 2) == 0, do: count + 1, else: count
      end

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

    assert result == 0
  end

  # Any Pattern Tests
  test "any pattern: check if any even numbers exist" do
    list = [1, 3, 5, 6, 7]

    result =
      loop result: false do
        if list == [], do: break(result)
        [h | list] = list
        result = result or rem(h, 2) == 0
      end

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

    assert result == false
  end

  # All Pattern Tests
  test "all pattern: check if all numbers are positive" do
    list = [1, 2, 3, 4, 5]

    result =
      loop result: true do
        if list == [], do: break(result)
        [h | list] = list
        result = result and h > 0
      end

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

    assert result == true
  end

  # ============================================================================
  # Pattern Matching Failure Tests
  # ============================================================================
  # These tests trigger pattern recognition failures, causing fallback to
  # generic loop execution (Code.eval_quoted path)
  # ============================================================================

  # Map Pattern Failures
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

  # Filter Pattern Failures
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

  # Find Pattern Failures
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

  # Count Pattern Failures
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

  # Any Pattern Failures
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

  # All Pattern Failures
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

  # Reduce Pattern Failures
  test "reduce pattern failure: using head(list) instead of hd(list)" do
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

  # ============================================================================
  # Non-Sum Reduce Operations
  # ============================================================================
  # These tests exercise the generic reduce pattern with operators other than +
  # ============================================================================

  test "reduce pattern: multiply all elements" do
    list = [2, 3, 4]

    result =
      loop acc: 1 do
        if list == [], do: break(acc)
        acc = acc * hd(list)
        list = tl(list)
      end

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

    assert result == 9
  end

  # ============================================================================
  # Generic Loop Fallback Tests
  # ============================================================================
  # These tests don't match any pattern and use Code.eval_quoted path
  # ============================================================================

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

  # ============================================================================
  # Edge Cases and Boundary Conditions
  # ============================================================================

  test "edge case: three initial bindings" do
    result =
      loop a: 1, b: 2, c: 3 do
        if a > 10, do: break({a, b, c})
        a = a + 1
        b = b + 2
        c = c + 3
      end

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

    assert result == {6, 3}
  end

  test "edge case: breaking with map" do
    list = [1, 2, 3]

    result =
      loop do
        if list == [], do: break(%{sum: 6, count: 3})
        [h | list] = list
      end

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

    assert result == 10
  end

  # ============================================================================
  # Additional Edge Case Tests
  # ============================================================================
  test "sum pattern: basic integer sum" do
    list = [10, 20, 30]

    result =
      loop sum: 0 do
        if list == [], do: break(sum)
        sum = sum + hd(list)
        list = tl(list)
      end

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

    assert result == 100
  end

  test "map pattern: single element" do
    list = [5]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [h * 3 | acc]
      end

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

    assert result == false
  end

  # ============================================================================
  # Reject Pattern Tests
  # ============================================================================

  test "reject pattern: reject even numbers" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: acc, else: [h | acc]
      end

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

    assert result == []
  end

  # ============================================================================
  # Product Pattern Tests
  # ============================================================================

  test "product pattern: multiply integers" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        if list == [], do: break(product)
        product = product * hd(list)
        list = tl(list)
      end

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

    assert result == 6.0
  end

  # ============================================================================
  # Reverse Pattern Tests
  # ============================================================================

  test "reverse pattern: reverse a list" do
    list = [1, 2, 3, 4, 5]

    result =
      loop acc: [] do
        if list == [], do: break(acc)
        [h | list] = list
        acc = [h | acc]
      end

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

    assert result == [3, 2, 1]
  end

  # ============================================================================
  # Length Pattern Tests
  # ============================================================================

  test "length pattern: count elements" do
    list = [1, 2, 3, 4, 5]

    result =
      loop count: 0 do
        if list == [], do: break(count)
        [_ | list] = list
        count = count + 1
      end

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

    assert result == 3
  end

  # ============================================================================
  # Member? Pattern Tests
  # ============================================================================

  test "member? pattern: element found" do
    list = [1, 2, 3, 4, 5]

    result =
      loop do
        if list == [], do: break(false)
        [h | list] = list
        if h == 3, do: break(true)
      end

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

    assert result == true
  end

  # ============================================================================
  # Each Pattern Tests
  # ============================================================================

  test "each pattern: side effect with destructure" do
    list = [1, 2, 3]

    result =
      loop do
        if list == [], do: break(nil)
        [h | list] = list
        send(self(), {:item, h})
      end

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

    assert result == :ok
    assert_received {:val, 10}
    assert_received {:val, 20}
  end

  # ============================================================================
  # Find Index Pattern Tests
  # ============================================================================

  test "find_index pattern: find first even" do
    list = [1, 3, 4, 5, 6]

    result =
      loop index: 0 do
        if list == [], do: break(nil)
        [h | list] = list
        if rem(h, 2) == 0, do: break(index)
        index = index + 1
      end

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

    assert result == 1
  end

  # ============================================================================
  # Take While Pattern Tests
  # ============================================================================

  test "take_while pattern: take while positive" do
    list = [1, 2, 3, -1, 4, 5]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h > 0, do: [h | acc], else: break(Enum.reverse(acc))
      end

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

    assert result == []
  end

  # ============================================================================
  # Drop While Pattern Tests
  # ============================================================================

  test "drop_while pattern: drop while less than 3" do
    list = [1, 2, 3, 4, 5]

    result =
      loop do
        if list == [], do: break([])
        [h | list] = list
        unless h < 3, do: break([h | list])
      end

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

    assert result == []
  end

  # ============================================================================
  # With Index Pattern Tests
  # ============================================================================

  test "with_index pattern: basic" do
    list = [:a, :b, :c]

    result =
      loop acc: [], i: 0 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = [{h, i} | acc]
        i = i + 1
      end

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

  # ============================================================================
  # Zip Pattern Tests
  # ============================================================================

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

    assert result == []
  end

  # ============================================================================
  # Reduce While Pattern Tests
  # ============================================================================

  test "reduce_while pattern: sum until threshold" do
    list = [1, 2, 3, 4, 5]

    result =
      loop acc: 0 do
        if list == [], do: break(acc)
        [h | list] = list
        if acc + h > 6, do: break(acc)
        acc = acc + h
      end

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

    assert result == 42
  end

  # ============================================================================
  # Dedup Pattern Tests
  # ============================================================================

  test "dedup pattern: remove consecutive duplicates" do
    list = [1, 1, 2, 2, 2, 3, 1, 1]

    result =
      loop acc: [], prev: nil do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if h == prev, do: acc, else: [h | acc]
        prev = h
      end

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

    assert result == []
  end

  # ============================================================================
  # Max/Min Pattern Tests
  # ============================================================================

  test "max pattern: find maximum" do
    list = [3, 7, 2, 9, 4]

    result =
      loop best: hd(list) do
        list = tl(list)
        if list == [], do: break(best)
        best = max(best, hd(list))
      end

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

    assert result == 1
  end

  # ============================================================================
  # Frequencies Pattern Tests
  # ============================================================================

  test "frequencies pattern: count occurrences" do
    list = [:a, :b, :a, :c, :b, :a]

    result =
      loop freq: %{} do
        if list == [], do: break(freq)
        [h | list] = list
        freq = Map.update(freq, h, 1, &(&1 + 1))
      end

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

    assert result == %{1 => 1, 2 => 1, 3 => 1}
  end

  # ============================================================================
  # Map.new Pattern Tests
  # ============================================================================

  test "map_new pattern: create map from list" do
    list = [{:a, 1}, {:b, 2}, {:c, 3}]

    result =
      loop acc: %{} do
        if list == [], do: break(acc)
        [h | list] = list
        acc = Map.put(acc, elem(h, 0), elem(h, 1))
      end

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

    assert result == %{}
  end

  # ============================================================================
  # Scan Pattern Tests
  # ============================================================================

  test "scan pattern: running sum" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [], running: 0 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        running = running + h
        acc = [running | acc]
      end

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

    assert result == []
  end

  # ============================================================================
  # Filter+Map Pattern Tests
  # ============================================================================

  test "filter_map pattern: filter and transform" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop acc: [] do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: [h * 10 | acc], else: acc
      end

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

    assert result == []
  end

  # ============================================================================
  # Partition/Take/Drop/Split Pattern Tests
  # ============================================================================

  test "partition pattern: split by predicate" do
    list = [1, 2, 3, 4, 5, 6]

    result =
      loop left: [], right: [] do
        if Enum.empty?(list), do: break({Enum.reverse(left), Enum.reverse(right)})
        [h | list] = list
        {left, right} = if rem(h, 2) == 0, do: {[h | left], right}, else: {left, [h | right]}
      end

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

    assert result == {[], []}
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

  # ============================================================================
  # Wave 2 Pattern + IR Generalization Tests
  # ============================================================================

  test "none? pattern: returns true when no element matches" do
    list = [1, 3, 5, 7]

    result =
      loop do
        if list == [], do: break(true)
        [h | list] = list
        if rem(h, 2) == 0, do: break(false)
      end

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

  test "into_mapset pattern: identity" do
    list = [1, 2, 2, 3]

    result =
      loop set: MapSet.new() do
        if list == [], do: break(set)
        [h | list] = list
        set = MapSet.put(set, h)
      end

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

    assert result == MapSet.new([10, 20, 30])
  end

  test "find pattern: hd/tl parity" do
    list = [1, 3, 5, 8]

    result =
      loop do
        if list == [], do: break(nil)
        if rem(hd(list), 2) == 0, do: break(hd(list))
        list = tl(list)
      end

    assert result == 8
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

  # ============================================================================
  # New Pattern Failure/Fallback Tests
  # ============================================================================

  test "reject pattern failure: wrong exit (list == [] instead of Enum.empty?)" do
    list = [1, 2, 3, 4]

    result =
      loop acc: [] do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if rem(h, 2) == 0, do: acc, else: [h | acc]
      end

    # Falls back to generic loop - should still produce correct result
    assert result == [1, 3]
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
    assert result == 2
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

  # ============================================================================
  # Tuple-Destructuring Pattern Tests
  # ============================================================================

  test "tuple desugar: if == [] with product" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          if list == [], do: break(product), else: {tl(list), product * hd(list)}
      end

    assert result == 24
  end

  test "tuple desugar: if != [] with product" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          if list != [], do: {tl(list), product * hd(list)}, else: break(product)
      end

    assert result == 24
  end

  test "tuple desugar: case with _ wildcard and product" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          case list do
            [] -> break(product)
            _ -> {tl(list), product * hd(list)}
          end
      end

    assert result == 24
  end

  test "tuple desugar: if == [] with sum" do
    list = [10, 20, 30]

    result =
      loop sum: 0 do
        {list, sum} =
          if list == [], do: break(sum), else: {tl(list), sum + hd(list)}
      end

    assert result == 60
  end

  test "tuple desugar: if == [] with generic reduce (subtraction)" do
    list = [5, 3, 2]

    result =
      loop acc: 100 do
        {list, acc} =
          if list == [], do: break(acc), else: {tl(list), acc - hd(list)}
      end

    assert result == 90
  end

  test "tuple desugar: case with [h | rest] pattern and map" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        {list, acc} =
          case list do
            [] -> break(Enum.reverse(acc))
            [h | rest] -> {rest, [h * 10 | acc]}
          end
      end

    assert result == [10, 20, 30]
  end

  test "tuple desugar: reversed variable order {acc, list}" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {product, list} =
          if list == [], do: break(product), else: {product * hd(list), tl(list)}
      end

    assert result == 24
  end

  test "tuple desugar: empty list" do
    list = []

    result =
      loop product: 1 do
        {list, product} =
          if list == [], do: break(product), else: {tl(list), product * hd(list)}
      end

    assert result == 1
  end

  test "tuple desugar: single element list" do
    list = [42]

    result =
      loop sum: 0 do
        {list, sum} =
          if list == [], do: break(sum), else: {tl(list), sum + hd(list)}
      end

    assert result == 42
  end

  test "tuple desugar: string concatenation" do
    list = ["Hello", " ", "World"]

    result =
      loop acc: "" do
        {list, acc} =
          if list == [], do: break(acc), else: {tl(list), acc <> hd(list)}
      end

    assert result == "Hello World"
  end

  # ============================================================================
  # Tuple Desugar: Block Continue (assignments + return tuple matching LHS)
  # ============================================================================

  test "tuple desugar block: if == [] with product" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          if list == [] do
            break(product)
          else
            product = product * hd(list)
            list = tl(list)
            {list, product}
          end
      end

    assert result == 24
  end

  test "tuple desugar block: if != [] with product" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          if list != [] do
            product = product * hd(list)
            list = tl(list)
            {list, product}
          else
            break(product)
          end
      end

    assert result == 24
  end

  test "tuple desugar block: case with product" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          case list do
            [] ->
              break(product)

            _ ->
              product = product * hd(list)
              list = tl(list)
              {list, product}
          end
      end

    assert result == 24
  end

  test "tuple desugar block: sum" do
    list = [10, 20, 30]

    result =
      loop sum: 0 do
        {list, sum} =
          if list == [] do
            break(sum)
          else
            sum = sum + hd(list)
            list = tl(list)
            {list, sum}
          end
      end

    assert result == 60
  end

  test "tuple desugar block: empty list" do
    list = []

    result =
      loop product: 1 do
        {list, product} =
          if list == [] do
            break(product)
          else
            product = product * hd(list)
            list = tl(list)
            {list, product}
          end
      end

    assert result == 1
  end

  test "tuple desugar block: reversed variable order {acc, list}" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {product, list} =
          if list == [] do
            break(product)
          else
            product = product * hd(list)
            list = tl(list)
            {product, list}
          end
      end

    assert result == 24
  end

  # ============================================================================
  # Tuple Desugar: Collapse Block (intermediate vars inlined into final tuple)
  # ============================================================================

  test "tuple desugar collapse: intermediate variable with product" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          if list == [] do
            break(product)
          else
            prod = product * hd(list)
            {tl(list), prod}
          end
      end

    assert result == 24
  end

  test "tuple desugar collapse: intermediate variable with sum" do
    list = [10, 20, 30]

    result =
      loop sum: 0 do
        {list, sum} =
          if list == [] do
            break(sum)
          else
            s = sum + hd(list)
            {tl(list), s}
          end
      end

    assert result == 60
  end

  test "tuple desugar collapse: case with intermediate variable" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          case list do
            [] ->
              break(product)

            _ ->
              p = product * hd(list)
              {tl(list), p}
          end
      end

    assert result == 24
  end

  test "tuple desugar collapse: if != [] with intermediate variable" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          if list != [] do
            p = product * hd(list)
            {tl(list), p}
          else
            break(product)
          end
      end

    assert result == 24
  end

  test "tuple desugar collapse: multiple intermediate variables" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          if list == [] do
            break(product)
          else
            head = hd(list)
            prod = product * head
            {tl(list), prod}
          end
      end

    assert result == 24
  end

  test "tuple desugar collapse: empty list" do
    list = []

    result =
      loop sum: 0 do
        {list, sum} =
          if list == [] do
            break(sum)
          else
            s = sum + hd(list)
            {tl(list), s}
          end
      end

    assert result == 0
  end

  test "tuple desugar collapse: string concatenation" do
    list = ["Hello", " ", "World"]

    result =
      loop acc: "" do
        {list, acc} =
          if list == [] do
            break(acc)
          else
            new_acc = acc <> hd(list)
            {tl(list), new_acc}
          end
      end

    assert result == "Hello World"
  end

  # ============================================================================
  # New Pattern Recognizers
  # ============================================================================

  test "flat_map pattern: append mapped lists" do
    list = [1, 2, 3]

    result =
      loop acc: [] do
        if list == [], do: break(acc)
        [h | list] = list
        acc = acc ++ [h, -h]
      end

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

  test "find pattern: default value via break on empty" do
    list = [1, 2, 3]

    result =
      loop do
        if list == [], do: break(:none)
        [h | list] = list
        if h > 10, do: break(h)
      end

    assert result == Enum.find(list, :none, &(&1 > 10))
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

  test "find_value pattern: default value via break on empty" do
    list = [1, 2, 3, 4]

    result =
      loop do
        if list == [], do: break(:none)
        [h | list] = list
        value = if rem(h, 2) == 0, do: h * 10, else: nil
        if value, do: break(value)
      end

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

  test "uniq pattern: keep first occurrence per element" do
    list = [1, 2, 1, 3, 2, 4, 4]

    result =
      loop acc: [], seen: MapSet.new() do
        if list == [], do: break(Enum.reverse(acc))
        [h | list] = list
        acc = if MapSet.member?(seen, h), do: acc, else: [h | acc]
        seen = MapSet.put(seen, h)
      end

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
end
