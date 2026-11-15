# typed-value-migration

Harness for migrating a primitive value representation across multiple modules under a strict type checker.

## Fit

- **Use when**: a cross-module representation change has a strict type checker, behavioral tests, and compatibility requirements at public boundaries.
- **Avoid when**: a single-file edit or unrelated behavior change.

## Components

- **Enabled Plugins**: none beyond globals; use the project's own type checker and test runner.
- **Bundled Components**: none.

## Situations

### Cross-module value migration
1. Inspect public APIs, source, tests, package manager, and baseline behavior. Install dependencies from the lockfile if needed before baseline checks. Gate: record baseline test and typecheck results.
2. Identify invariants and all representation boundaries; change the source-of-truth type and propagate through consumers while keeping public input/output contracts explicit. Gate: strict typecheck passes and changed state uses the new representation consistently.
3. Implement domain-required rounding/conversion explicitly. Add representative boundary tests, including an exact halfway case whose input avoids conversion ambiguity. Gate: specified rounding behavior passes those tests.
4. Remove todo/xfail markers only after completing their assertions. Gate: full suite passes with zero todo/xfail cases.
5. Verify externally visible output and compatibility against existing examples. Gate: output-format tests remain unchanged and pass.
6. Review scope and whitespace. Gate: typecheck, full test suite, and diff check pass; diff contains only intended source/tests.

Traps:
- Public types may have unchanged syntax but changed units; document the internal unit and convert only at explicit boundaries.
- Binary floating-point input can make a nominal halfway conversion ambiguous. Choose test values that yield the exact boundary through the real API, and validate invalid/non-finite/too-small inputs before conversion.
- Python: avoid `Decimal(float)` because it captures binary approximation; `round()` on `Decimal` uses ties-to-even, so use `quantize(..., ROUND_HALF_UP)` when half-up is required.
- JavaScript/TypeScript: integer minor units avoid repeated float arithmetic; `Math.round` does not implement symmetric half-up for negative ties, so define the signed rounding policy explicitly if negative values are valid.
- A test without an inline todo option may still be reported as todo if another marker remains; inspect the runner summary and require zero todos.
- Do not assume dependencies are present: install from the lockfile when the type checker is missing.
- Check output formatting and diff scope, not only typechecking.

## Init Decisions

- Keep project-specific paths and commands in AGENTS.md.
- Add only components needed beyond the project test/typecheck tools.

## Smoke Check

- **Task**: list loaded Components, then run project tests and strict type check.
- **Pass criteria**: expected Components are visible; both commands run and report baseline results.
