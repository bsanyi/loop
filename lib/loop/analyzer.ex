defmodule Loop.Analyzer do
  @moduledoc false

  def analyze(initials, body) do
    body = Loop.Normalize.normalize(body)

    Loop.Patterns.try_all(initials, body) ||
      case Loop.Desugar.desugar_tuple_assign(body) do
        nil -> nil
        alternatives -> Enum.find_value(alternatives, &Loop.Patterns.try_all(initials, &1))
      end
  end
end
