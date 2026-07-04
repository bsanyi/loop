defmodule LoopPatternsUpstreamRegressionsTest do
  use ExUnit.Case, async: true
  use Loop

  # Regression tests for the eight unreachable-matcher bugs reported against 0.2.0.
  # Root causes: raw 2-tuple vs tagged {:{}, _, [...]} AST confusion, and matchers
  # written against pre-normalization shapes (P047 flip, P052 decomposition,
  # unstripped remote-call metadata).
  #
  # Recognition is asserted on AST parsed from source strings because
  # Code.string_to_quoted!/1 attaches line metadata exactly like the real
  # compiler does, while a plain `quote` block does not — bug 7 (metadata-
  # sensitive == comparisons) is invisible under metadata-free quoted input.

  import Loop.TestHelpers, only: [ast_contains?: 2, enum_call?: 1, code_eval_quoted?: 1]

  defp expand!(source, env) do
    source
    |> Code.string_to_quoted!()
    |> Macro.expand(env)
  end

  defp assert_compiles_to(source, env, enum_fun) do
    expanded = expand!(source, env)

    assert ast_contains?(expanded, enum_call?(enum_fun)),
           "expected loop to compile to Enum.#{enum_fun}, got:\n#{Macro.to_string(expanded)}"

    refute ast_contains?(expanded, &code_eval_quoted?/1),
           "expected loop to optimize (no Code.eval_quoted fallback)"

    expanded
  end

  # Bug 1: the matcher expected the AST of &((&1 + 1) / 2) instead of &(&1 + 1),
  # so frequencies_by_pattern used to shadow frequencies_pattern.
  test "frequencies pattern: &(&1 + 1) capture compiles to Enum.frequencies" do
    list = [:a, :b, :a, :c, :a]

    result =
      loop freq: %{} do
        if list == [], do: break(freq)
        [h | list] = list
        freq = Map.update(freq, h, 1, &(&1 + 1))
      end

    expanded =
      assert_compiles_to(
        """
        loop freq: %{} do
          if list == [], do: break(freq)
          [h | list] = list
          freq = Map.update(freq, h, 1, &(&1 + 1))
        end
        """,
        __ENV__,
        :frequencies
      )

    refute ast_contains?(expanded, enum_call?(:frequencies_by)),
           "expected Enum.frequencies, not Enum.frequencies_by"

    assert result == %{a: 3, b: 1, c: 1}
  end

  # Bug 2: zip_with_pattern's plain-tuple exclusion guard compared against a tagged
  # {:{}, [], [x, y]} that a 2-tuple never produces, shadowing zip_pattern.
  test "zip pattern: plain tuple pairing compiles to Enum.zip, not zip_with" do
    a = [1, 2, 3]
    b = [:a, :b]

    result =
      loop acc: [] do
        if a == [] or b == [], do: break(Enum.reverse(acc))
        [x | a] = a
        [y | b] = b
        acc = [{x, y} | acc]
      end

    expanded =
      assert_compiles_to(
        """
        loop acc: [] do
          if a == [] or b == [], do: break(Enum.reverse(acc))
          [x | a] = a
          [y | b] = b
          acc = [{x, y} | acc]
        end
        """,
        __ENV__,
        :zip
      )

    refute ast_contains?(expanded, enum_call?(:zip_with)),
           "expected Enum.zip, not Enum.zip_with"

    assert result == [{1, :a}, {2, :b}]
  end

  # Bug 3: normalize P052 decomposes {running, acc} = {expr, [expr | acc]} before
  # matchers run, so scan_tuple_pattern must accept the decomposed statement order.
  test "scan tuple pattern: tuple state update compiles to Enum.scan" do
    list = [1, 2, 3]

    result =
      loop acc: [], running: 0 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        {running, acc} = {running + h, [running + h | acc]}
      end

    assert_compiles_to(
      """
      loop acc: [], running: 0 do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        {running, acc} = {running + h, [running + h | acc]}
      end
      """,
      __ENV__,
      :scan
    )

    assert result == [1, 3, 6]
  end

  # Bug 4: flat_map_reduce_prepend_roles only matched a tagged tuple break payload,
  # but break({Enum.concat(Enum.reverse(mapped)), state}) is a raw 2-tuple.
  test "flat_map_reduce prepend pattern: raw 2-tuple break compiles to Enum.flat_map_reduce" do
    list = [1, 2, 3]

    result =
      loop mapped: [], sum: 0 do
        if list == [], do: break({Enum.concat(Enum.reverse(mapped)), sum})
        [h | list] = list
        mapped = [[h, h * 10] | mapped]
        sum = sum + h
      end

    assert_compiles_to(
      """
      loop mapped: [], sum: 0 do
        if list == [], do: break({Enum.concat(Enum.reverse(mapped)), sum})
        [h | list] = list
        mapped = [[h, h * 10] | mapped]
        sum = sum + h
      end
      """,
      __ENV__,
      :flat_map_reduce
    )

    assert result == {[1, 10, 2, 20, 3, 30], 6}
  end

  # Bug 5: split_while_append matched tagged-tuple break payloads that
  # break({left, []}) and break({left, [h | list]}) never produce.
  test "split_while append pattern: raw 2-tuple breaks compile to Enum.split_while" do
    list = [1, 2, 7, 3]

    result =
      loop left: [] do
        if list == [], do: break({left, []})
        [h | list] = list
        left = if h < 5, do: left ++ [h], else: break({left, [h | list]})
      end

    assert_compiles_to(
      """
      loop left: [] do
        if list == [], do: break({left, []})
        [h | list] = list
        left = if h < 5, do: left ++ [h], else: break({left, [h | list]})
      end
      """,
      __ENV__,
      :split_while
    )

    assert result == {[1, 2], [7, 3]}
  end

  # Bug 5 (empty-exit branch): the whole list satisfies the predicate.
  test "split_while append pattern: predicate never fails" do
    list = [1, 2, 3]

    result =
      loop left: [] do
        if list == [], do: break({left, []})
        [h | list] = list
        left = if h < 5, do: left ++ [h], else: break({left, [h | list]})
      end

    assert result == {[1, 2, 3], []}
  end

  # Bug 6: dedup_by_acc_if matched a bare cons in the else branch, but [h | acc]
  # is a cons wrapped in a list.
  test "dedup_by pattern: keyed dedup compiles to Enum.dedup_by" do
    list = [1, 3, 2, 4, 7]

    result =
      loop acc: [], prev_key: nil do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        key = rem(h, 2)
        acc = if key == prev_key, do: acc, else: [h | acc]
        prev_key = key
      end

    assert_compiles_to(
      """
      loop acc: [], prev_key: nil do
        if Enum.empty?(list), do: break(Enum.reverse(acc))
        [h | list] = list
        key = rem(h, 2)
        acc = if key == prev_key, do: acc, else: [h | acc]
        prev_key = key
      end
      """,
      __ENV__,
      :dedup_by
    )

    assert result == [1, 2, 7]
  end

  # Bug 7: chunk_by_pattern compares sub-expressions with structural ==, which
  # requires normalize to strip metadata from remote-call nodes such as
  # Enum.reverse(chunk); real compiler input carries [line: N] there.
  test "chunk_by pattern: keyed chunking compiles to Enum.chunk_by" do
    list = [1, 3, 2, 4, 5]

    result =
      loop chunks: [], chunk: [], key: nil, started: false do
        if list == [],
          do:
            break(Enum.reverse(if chunk == [], do: chunks, else: [Enum.reverse(chunk) | chunks]))

        [h | list] = list
        current_key = rem(h, 2)

        {chunks, chunk, key, started} =
          if started and current_key != key do
            {[Enum.reverse(chunk) | chunks], [h], current_key, true}
          else
            {chunks, [h | chunk], current_key, true}
          end
      end

    assert_compiles_to(
      """
      loop chunks: [], chunk: [], key: nil, started: false do
        if list == [],
          do: break(Enum.reverse(if chunk == [], do: chunks, else: [Enum.reverse(chunk) | chunks]))

        [h | list] = list
        current_key = rem(h, 2)

        {chunks, chunk, key, started} =
          if started and current_key != key do
            {[Enum.reverse(chunk) | chunks], [h], current_key, true}
          else
            {chunks, [h | chunk], current_key, true}
          end
      end
      """,
      __ENV__,
      :chunk_by
    )

    assert result == [[1, 3], [2, 4], [5]]
  end

  # Bug 8: normalize P047 rewrites `candidate_key > max_key` into
  # `max_key < candidate_key`, so the max branch must accept the swapped-operand
  # form instead of a literal :> comparison.
  test "min_max_by pattern: tracked min and max compile to Enum.min_max_by" do
    list = [3, -7, 2, -1]

    result =
      loop min_val: hd(list),
           min_key: abs(hd(list)),
           max_val: hd(list),
           max_key: abs(hd(list)) do
        list = tl(list)
        if list == [], do: break({min_val, max_val})
        candidate = hd(list)
        candidate_key = abs(candidate)

        {min_val, min_key} =
          if candidate_key < min_key, do: {candidate, candidate_key}, else: {min_val, min_key}

        {max_val, max_key} =
          if candidate_key > max_key, do: {candidate, candidate_key}, else: {max_val, max_key}
      end

    assert_compiles_to(
      """
      loop min_val: hd(list), min_key: abs(hd(list)), max_val: hd(list), max_key: abs(hd(list)) do
        list = tl(list)
        if list == [], do: break({min_val, max_val})
        candidate = hd(list)
        candidate_key = abs(candidate)

        {min_val, min_key} =
          if candidate_key < min_key, do: {candidate, candidate_key}, else: {min_val, min_key}

        {max_val, max_key} =
          if candidate_key > max_key, do: {candidate, candidate_key}, else: {max_val, max_key}
      end
      """,
      __ENV__,
      :min_max_by
    )

    assert result == {-1, -7}
  end
end
