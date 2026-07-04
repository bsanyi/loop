defmodule LoopBasicsTest do
  use ExUnit.Case, async: true
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

  test "user-thrown {:break, value} tuples are not swallowed by the loop" do
    caught =
      catch_throw(
        loop do
          _ = 42
          throw({:break, :user_payload})
        end
      )

    assert caught == {:break, :user_payload}
  end

  test "internal break bookkeeping does not clash with a user `loop_ref` variable" do
    result =
      loop i: 0 do
        loop_ref = {:user, i}
        if i == 2, do: break(loop_ref)
        i = i + 1
      end

    Loop.TestHelpers.assert_fallback(
      quote do
        loop i: 0 do
          loop_ref = {:user, i}
          if i == 2, do: break(loop_ref)
          i = i + 1
        end
      end,
      __ENV__
    )

    assert result == {:user, 2}
  end

  test "break inside a nested loop only breaks the inner loop" do
    result =
      loop outer: 0 do
        inner =
          loop do
            break(:inner_done)
          end

        if inner == :inner_done and outer == 2, do: break({:outer_done, outer})
        outer = outer + 1
      end

    assert result == {:outer_done, 2}
  end
end
