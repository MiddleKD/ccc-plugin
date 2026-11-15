# typed-value-migration

Harness for migrating a primitive value type (e.g. float money to Decimal) across several modules under a strict type checker.

## Fit

- **Use when**: multi-module refactor that changes a core value type, has a strict type checker and a test suite.
- **Avoid when**: single-file edits or behaviour changes unrelated to the type.

## Components

- **Enabled Plugins**: none beyond globals. Type checker and tests come from the project's own dev environment.
- **Bundled Components**: none.

## Situations

### Value-type migration
1. Baseline: run tests and type checker, record results. Gate: commands run, output noted.
2. Change the type at its source (data definitions), then propagate to consumers. Construct from strings, never from floats. Gate: type checker reports no errors.
3. Implement rounding explicitly at the one place the spec says (quantize with the named rounding mode). Gate: tests covering the half-way case pass.
4. Remove xfail markers for tests the migration fixes. Gate: strict xfail would fail otherwise; full test suite green.
5. Verify output formatting unchanged. Gate: rendered output compared against pre-change output for sample inputs.
6. Gate: `git diff --stat` limited to intended source and test files.

Traps (observed and expected):
- Baseline snapshot scripts must use the module's real public API; a guessed constant name failed once. Read the module before scripting the snapshot.
- Tests that add fixtures to module-level registries must clean up in try/finally or a fixture.
- Tracked generated artifacts (e.g. bytecode caches) get dirtied by running tools; restore them before committing so the diff gate holds.
- Check the diff gate before reporting done.
- `Decimal(1.1)` captures float error; `round()` on Decimal is banker's rounding, use `quantize(..., ROUND_HALF_UP)`; f-string formatting of Decimal differs from float for `:.2f` only if quantum is lost, so check; leftover `float` annotations and `0.0` literals fail strict mode.

## Init Decisions

- Project facts live in AGENTS.md only.

## Smoke Check

- **Task**: List loaded Components, confirm the project test runner and type checker both run.
- **Pass criteria**: both commands execute and report current baseline.
