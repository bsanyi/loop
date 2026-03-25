defmodule Loop.TestHelpers do
  @moduledoc false

  import ExUnit.Assertions

  def expand_loop(ast, env) do
    Macro.expand(ast, env)
  end

  def assert_recognized(ast, env, matcher_fun, message \\ nil) do
    expanded = expand_loop(ast, env)

    assert ast_contains?(expanded, matcher_fun),
           message || "expected loop macro to expand to recognized pattern"

    refute ast_contains?(expanded, &code_eval_quoted?/1),
           "expected loop macro to optimize (no Code.eval_quoted fallback)"

    expanded
  end

  def assert_fallback(ast, env) do
    expanded = expand_loop(ast, env)

    assert ast_contains?(expanded, &code_eval_quoted?/1),
           "expected loop macro to fall back to Code.eval_quoted"

    expanded
  end

  def assert_pattern_recognized(result, ast, env) do
    expanded = expand_loop(ast, env)

    refute ast_contains?(expanded, &code_eval_quoted?/1),
           "expected loop macro to optimize (no Code.eval_quoted fallback)"

    result
  end

  # Generic matcher factory for module.function calls
  def module_call?(module_name, function_name) do
    fn node ->
      match?({{:., _, [{:__aliases__, _, [^module_name]}, ^function_name]}, _, _}, node)
    end
  end

  # Enum matchers
  def enum_call?(function_name) do
    module_call?(:Enum, function_name)
  end

  def enum_reverse_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :reverse]}, _, [_]}, node)
  end

  def enum_map_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :map]}, _, [_, _]}, node)
  end

  def enum_filter_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :filter]}, _, [_, _]}, node)
  end

  def enum_reject_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :reject]}, _, [_, _]}, node)
  end

  def enum_find_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :find]}, _, [_, _]}, node)
  end

  def enum_find_index_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :find_index]}, _, [_, _]}, node)
  end

  def enum_find_value_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :find_value]}, _, [_, _]}, node)
  end

  def enum_count_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :count]}, _, [_, _]}, node)
  end

  def enum_any_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :any?]}, _, [_, _]}, node)
  end

  def enum_all_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :all?]}, _, [_, _]}, node)
  end

  def enum_sum_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :sum]}, _, [_]}, node)
  end

  def enum_product_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :product]}, _, [_]}, node)
  end

  def enum_reduce_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :reduce]}, _, [_, _, _]}, node)
  end

  def enum_reduce_while_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :reduce_while]}, _, [_, _, _]}, node)
  end

  def enum_scan_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :scan]}, _, _}, node)
  end

  def enum_flat_map_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :flat_map]}, _, [_, _]}, node)
  end

  def enum_each_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :each]}, _, [_, _]}, node)
  end

  def enum_with_index_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :with_index]}, _, _}, node)
  end

  def enum_take_while_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :take_while]}, _, [_, _]}, node)
  end

  def enum_drop_while_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :drop_while]}, _, [_, _]}, node)
  end

  def enum_uniq_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :uniq]}, _, _}, node)
  end

  def enum_uniq_by_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :uniq_by]}, _, [_, _]}, node)
  end

  def enum_dedup_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :dedup]}, _, _}, node)
  end

  def enum_dedup_by_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :dedup_by]}, _, [_, _]}, node)
  end

  def enum_min_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :min]}, _, _}, node)
  end

  def enum_max_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :max]}, _, _}, node)
  end

  def enum_min_by_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :min_by]}, _, [_, _]}, node)
  end

  def enum_max_by_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :max_by]}, _, [_, _]}, node)
  end

  def enum_frequencies_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :frequencies]}, _, _}, node)
  end

  def enum_frequencies_by_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :frequencies_by]}, _, [_, _]}, node)
  end

  def enum_group_by_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :group_by]}, _, [_, _]}, node)
  end

  def enum_zip_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :zip]}, _, _}, node)
  end

  def enum_zip_with_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :zip_with]}, _, _}, node)
  end

  def enum_concat_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :concat]}, _, _}, node)
  end

  def enum_join_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :join]}, _, _}, node)
  end

  def enum_map_join_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :map_join]}, _, _}, node)
  end

  def enum_intersperse_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :intersperse]}, _, _}, node)
  end

  def enum_map_intersperse_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Enum]}, :map_intersperse]}, _, _}, node)
  end

  # Map matchers
  def map_new_call?(node) do
    match?({{:., _, [{:__aliases__, _, [:Map]}, :new]}, _, _}, node)
  end

  def code_eval_quoted?(node) do
    match?({{:., _, [{:__aliases__, _, [:Code]}, :eval_quoted]}, _, _}, node)
  end

  def ast_contains?(ast, fun) do
    {_, found} =
      Macro.prewalk(ast, false, fn node, acc ->
        {node, acc or fun.(node)}
      end)

    found
  end
end
