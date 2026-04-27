# SkipTCA Alloy model

`SkipTCA.als` is a small [Alloy 6][alloy] specification that captures the
structural invariants we want SkipTCA to maintain. Alloy is a model finder:
each `assert ... check ... for N` clause asks the SAT solver to look for a
counterexample within the given scope. If the solver answers `UNSAT`, the
property holds for all instances of that size.

## Why Alloy in addition to Swift Testing?

The two tools cover different ground:

- **Swift Testing** (in `Tests/SkipTCATests/`) exercises the actual Swift
  implementation against concrete inputs. Excellent for behavioural and
  algebraic laws (`Effect.merge` identity, `Effect.merge` associativity,
  `Send` purity, etc.) where you can write quantitative assertions easily.
- **Alloy 6** is a counterexample finder over relational logic. It's good
  for *structural* invariants (case disjointness, type provenance,
  acyclicity, function totality / partiality) and is useful as a regression
  guard when refactoring shapes.

We deliberately keep quantitative properties in Swift Testing — Alloy is
weak at sequence concatenation and multiset equality.

## What is checked

| # | Property | What it guards against |
|---|----------|------------------------|
| 1 | `ReducerIsDeterministic` | A future refactor accidentally turning `reduce[s][a]` into a one-to-many relation. |
| 2 | `EveryEffectHasOneCase` | Two `Effect` cases collapsing into one, or a new top-level Effect being added without a sub-sig. |
| 3 | `CancelTargetsValidCancellationID` | `EffectCancel.targetId` drifting outside the `CancellationID` universe. |
| 4 | `EmitElementsAreActions` | `EffectRun.emits` / `EffectCancellable.work` containing non-action atoms. |
| 5 | `TraceIndexesAreNonNegative` | Negative or non-integer trace indexes appearing in `Store`. |

All five run at scope 5 — i.e. up to 5 atoms of every signature. Alloy will
exhaustively search every distinct instance of that size; counterexamples,
if any, surface within seconds.

## Running the model

### Install Alloy

```bash
brew install alloy-analyzer        # macOS, installs the `alloy` CLI
alloy --help                       # confirm 6.x is on PATH
```

If Homebrew is not available, download the
[`org.alloytools.alloy`](https://github.com/AlloyTools/org.alloytools.alloy/releases)
release JAR and run `java -jar alloy.jar exec ...` instead.

### Check every property

```bash
cd skip-tca
alloy exec -f -c '*' Specs/SkipTCA.als
```

Expected output (each line is one command):

```
00. check ReducerIsDeterministic                  0   UNSAT
01. check EveryEffectHasOneCase                   0   UNSAT
02. check CancelTargetsValidCancellationID        0   UNSAT
03. check EmitElementsAreActions                  0   UNSAT
04. check TraceIndexesAreNonNegative              0   UNSAT
```

`UNSAT` for the five `check` commands means *no counterexample found*: the
property holds. `SAT` for the `run` command means the solver successfully
generated a non-trivial sample world (used as a sanity-only sample).

### Generate an instance interactively

The Alloy GUI (`alloy gui`) opens the model finder with all five commands
listed in the side panel and lets you visualise instances. Useful when
introducing a new property — first `run` with relaxed constraints to see
what the world looks like, then tighten with `check`.

## Adding a property

1. Add the assertion next to the existing ones, with a comment explaining
   the regression you're guarding against.
2. Add a `check NewAssert for 5` line.
3. Re-run `alloy exec -f -c '*' Specs/SkipTCA.als` and confirm `UNSAT`.
4. Update the table above.
5. If the property has a quantitative flavor (sequence equality, multiset
   counts), add a corresponding Swift Testing test in
   `Tests/SkipTCATests/` — it'll be far more expressive there.

[alloy]: https://alloytools.org
