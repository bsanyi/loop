defmodule Loop.Analyzer do
  @moduledoc false

  def analyze(initials, body, opts) do
    normalize = Keyword.fetch!(opts, :normalize)
    try_patterns = Keyword.fetch!(opts, :try_patterns)
    desugar_tuple_assign = Keyword.fetch!(opts, :desugar_tuple_assign)

    body = normalize.(body)

    try_patterns.(initials, body) ||
      case desugar_tuple_assign.(body) do
        nil -> nil
        alternatives -> Enum.find_value(alternatives, &try_patterns.(initials, &1))
      end
  end
end
