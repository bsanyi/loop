defmodule LoopDesugaringTest do
  use ExUnit.Case, async: true
  use Loop

  test "tuple desugar: if == [] with product" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          if list == [], do: break(product), else: {tl(list), product * hd(list)}
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1 do
          {list, product} =
            if list == [], do: break(product), else: {tl(list), product * hd(list)}
        end
      end,
      __ENV__
    )

    assert result == 24
  end

  test "tuple desugar: if != [] with product" do
    list = [2, 3, 4]

    result =
      loop product: 1 do
        {list, product} =
          if list != [], do: {tl(list), product * hd(list)}, else: break(product)
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1 do
          {list, product} =
            if list != [], do: {tl(list), product * hd(list)}, else: break(product)
        end
      end,
      __ENV__
    )

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

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop sum: 0 do
          {list, sum} =
            if list == [], do: break(sum), else: {tl(list), sum + hd(list)}
        end
      end,
      __ENV__
    )

    assert result == 60
  end

  test "tuple desugar: if == [] with generic reduce (subtraction)" do
    list = [5, 3, 2]

    result =
      loop acc: 100 do
        {list, acc} =
          if list == [], do: break(acc), else: {tl(list), acc - hd(list)}
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: 100 do
          {list, acc} =
            if list == [], do: break(acc), else: {tl(list), acc - hd(list)}
        end
      end,
      __ENV__
    )

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

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1 do
          {product, list} =
            if list == [], do: break(product), else: {product * hd(list), tl(list)}
        end
      end,
      __ENV__
    )

    assert result == 24
  end

  test "tuple desugar: empty list" do
    list = []

    result =
      loop product: 1 do
        {list, product} =
          if list == [], do: break(product), else: {tl(list), product * hd(list)}
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop product: 1 do
          {list, product} =
            if list == [], do: break(product), else: {tl(list), product * hd(list)}
        end
      end,
      __ENV__
    )

    assert result == 1
  end

  test "tuple desugar: single element list" do
    list = [42]

    result =
      loop sum: 0 do
        {list, sum} =
          if list == [], do: break(sum), else: {tl(list), sum + hd(list)}
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop sum: 0 do
          {list, sum} =
            if list == [], do: break(sum), else: {tl(list), sum + hd(list)}
        end
      end,
      __ENV__
    )

    assert result == 42
  end

  test "tuple desugar: string concatenation" do
    list = ["Hello", " ", "World"]

    result =
      loop acc: "" do
        {list, acc} =
          if list == [], do: break(acc), else: {tl(list), acc <> hd(list)}
      end

    Loop.TestHelpers.assert_pattern_recognized(
      result,
      quote do
        loop acc: "" do
          {list, acc} =
            if list == [], do: break(acc), else: {tl(list), acc <> hd(list)}
        end
      end,
      __ENV__
    )

    assert result == "Hello World"
  end

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
end
