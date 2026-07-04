# AGENTS.md

## What this project is

`loop` is an Elixir macro that lets users write imperative-style `loop`/`break` code while compiling recognized loop shapes into idiomatic functional code (`Enum.*`, `Map.*`, `MapSet.*`, etc.).

If no pattern is recognized, `loop` safely falls back to a generic runtime evaluator (`Code.eval_quoted`) with preserved loop semantics.

## Key architecture

- Entry point: `lib/loop.ex`
  - `defmacro loop/2` → calls `Loop.Analyzer.analyze/2`; on `nil` compiles the
    `Code.eval_quoted` fallback with ref-scoped `break` throws (`add_break/1`).
- Analyzer: `lib/loop/analyzer.ex`
  - Normalizes the body, tries direct patterns via `Loop.Patterns.try_all/2`,
    then tuple-assignment desugaring alternatives via `Loop.Desugar`.
- Canonicalization: `lib/loop/normalize.ex` (`Loop.Normalize.normalize/1`)
  - Metadata stripping, operator/branch canonicalization, block alias
    inlining, tuple-assign decomposition, split-destructure merging.
- Desugaring: `lib/loop/desugar.ex` (`Loop.Desugar.desugar_tuple_assign/1`)
  - Rewrites `{v1, v2} = if/case ...` bodies into block alternatives.
- Matcher pipeline: `lib/loop/patterns.ex` (`Loop.Patterns.try_all/2`)
  - `@table` is the ordered matcher list; earlier entries win.
  - `Core`/`Search`/`Reduce`/`Transform` entries are called as
    `pattern(initials, body)`; `Advanced`/`Collection` entries additionally
    receive `Loop.Patterns.Helpers.standard_callbacks()`.
- Pattern family modules (all import `Loop.Patterns.Helpers`):
  - `lib/loop/patterns/core.ex` — classic list transforms (map/filter/each/
    count/any/all/take_while/... and their append/while variants).
  - `lib/loop/patterns/search.ex` — find/member/fetch/find_at/find_index.
  - `lib/loop/patterns/reduce.ex` — reduce/scan/min-max/filter_count/while_multi.
  - `lib/loop/patterns/transform.ex` — with_index/zip/dedup/frequencies/
    map_new/into_mapset.
  - `lib/loop/patterns/advanced.ex`, `lib/loop/patterns/collection.ex` —
    callback-based matchers (legacy 3-arity API).
- Shared matcher utilities: `lib/loop/patterns/helpers.ex`
  - `list_loop_ir/1` and friends, empty-list/zero checks, `has_var?/2`,
    alias/assignment resolution, `standard_callbacks/0`.

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
   - Implement the matcher as a public `def <name>_pattern(initials, body)` in the
     fitting family module (`Core`/`Search`/`Reduce`/`Transform`), importing
     `Loop.Patterns.Helpers` for shared utilities.
   - Add a `{Module, :<name>_pattern}` entry to `@table` in `lib/loop/patterns.ex`.
   - Ordering matters: place specialized matchers before generic ones (`reduce_pattern/2` is broad).
   - Only `Advanced`/`Collection` use the legacy 3-arity callback API; new matchers should not.

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
- Match initials name-generically (`[{acc_name, init}]`, never `[acc: init]`) and pin the
  constructed `{acc_name, [], nil}` var against the accumulator extracted from the body —
  accepting any name while rejecting loops whose break variable differs from the declared initial.
- Keep new semantic guardrails in mind:
  - `chunk_every` discard optimization only applies to strict short-tail checks (`length/count < size`), not non-strict forms like `<=`.
  - `with_index` offset optimization currently applies only when the initial offset is an integer.

## Practical checklist (copy/paste)

- [ ] Added matcher function(s) in the fitting `lib/loop/patterns/*.ex` family module
- [ ] Added `@table` entry in `lib/loop/patterns.ex` at the right position
- [ ] Added positive and failure tests in `test/loop_test.exs`
- [ ] Used targeted test loop while iterating (`mix test test/...` or `:line`)
- [ ] Ran `mix precommit` as the final validation step
- [ ] Verified no semantic regression on fallback paths
