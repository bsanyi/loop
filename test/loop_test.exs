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
end
