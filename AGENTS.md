# AGENTS.md

## What this project is

`loop` is an Elixir macro that lets users write imperative-style `loop`/`break` code while compiling recognized loop shapes into idiomatic functional code (`Enum.*`, `Map.*`, `MapSet.*`, etc.).

If no pattern is recognized, `loop` safely falls back to a generic runtime evaluator (`Code.eval_quoted`) with preserved loop semantics.

## Key architecture

- Entry point: `lib/loop.ex`
  - `defmacro loop/2` → calls `analyze/2`.
  - `analyze/2` delegates to `Loop.Analyzer`.
  - `try_all_patterns/2` is the ordered matcher pipeline.
- Pattern helper modules:
  - `lib/loop/patterns/collection.ex`
  - `lib/loop/patterns/advanced.ex`
- Analyzer: `lib/loop/analyzer.ex`
  - Normalizes AST metadata.
  - Tries direct patterns first, then tuple-assignment desugaring alternatives.

## How to add a new recognized pattern

1. **Pick semantic target first**
   - Identify the exact functional equivalent (`Enum.map_reduce/3`, `Enum.frequencies_by/2`, etc.).
   - Decide the loop shape(s) you will support (strict canonical vs broader IR-based variants).

2. **Implement matcher returning quoted replacement or `nil`**
   - Pattern fns must return quoted optimized AST when matched, otherwise `nil`.
   - Be conservative: if anything is ambiguous, return `nil` to preserve fallback behavior.

3. **Use existing IR/helpers whenever possible**
   - `list_loop_ir/1` for broad list-loop recognition (`if/case/cond`, `[h | t]` and `hd/tl` styles).
   - `empty_list_check?/1`, `non_empty_list_check?/1`, `conditional_break/1`.
   - `has_var?/2`, alias resolution helpers, assignment resolution helpers.
   - These are designed to keep matching robust across syntax variants.

4. **Preserve semantics carefully**
   - Ensure break payload and accumulator ordering match exactly.
   - Guard against false positives when side effects or unrelated state updates exist.
   - Do not optimize if rewritten code could skip side effects or change return values.

5. **Wire matcher into pipeline**
   - Add matcher to `try_all_patterns/2` in `lib/loop.ex`.
   - Ordering matters: place specialized matchers before generic ones (`reduce_pattern/2` is broad).
   - If implemented in a patterns module, add wrapper in `lib/loop.ex` that passes callbacks.

6. **Add tests in `test/loop_test.exs`**
   - Positive tests: canonical form + at least one variant form.
   - Failure tests: similar shape that must **not** optimize (to protect semantics).
   - Keep naming consistent: `"<pattern> pattern: ..."` and `"<pattern> pattern failure: ..."`.

7. **Run validators**
   - During iteration, prefer fast feedback:
     - `mix test test/xxx_test.exs`
     - `mix test test/xxx_test.exs:NN`
     - `mix test` (still faster than full precommit)
   - `mix precommit` is the final gate and should be the last step.
   - Note: `mix precommit` already runs format + full tests + credo + dialyzer.

## Pattern authoring conventions in this repo

- Prefer small helper functions over large monolithic matchers.
- Match both operator and `Kernel.*` call forms when appropriate.
- Keep AST checks explicit and metadata-agnostic.
- Reuse existing callback-based structure in `Loop.Patterns.*` modules.
- Avoid editing README/docs for each pattern; tests and matcher code are the source of truth.
- Keep new semantic guardrails in mind:
  - `chunk_every` discard optimization only applies to strict short-tail checks (`length/count < size`), not non-strict forms like `<=`.
  - `with_index` offset optimization currently applies only when the initial offset is an integer.

## Practical checklist (copy/paste)

- [ ] Added matcher function(s) (`lib/loop.ex` or `lib/loop/patterns/*.ex`)
- [ ] Added/updated wrapper + `try_all_patterns/2` ordering
- [ ] Added positive and failure tests in `test/loop_test.exs`
- [ ] Used targeted test loop while iterating (`mix test test/...` or `:line`)
- [ ] Ran `mix precommit` as the final validation step
- [ ] Verified no semantic regression on fallback paths
