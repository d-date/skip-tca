# Contributing to SkipTCA

Thanks for your interest in improving SkipTCA! This document covers the
conventions and tooling for sending changes upstream.

## Local setup

```bash
git clone https://github.com/d-date/skip-tca.git
cd skip-tca
swift test                     # iOS-side test suite (Swift Testing)
INCLUDE_SKIP=1 swift build     # confirm Skip Lite still transpiles
brew install alloy-analyzer    # for the formal model
alloy exec -f -c '*' Specs/SkipTCA.als
```

You'll need:

- Xcode 26 / Swift 6.3 toolchain or newer.
- [Skip][skip] CLI installed (`brew tap skiptools/skip && brew install skip`).
- An Android emulator if you intend to actually run the transpiled output.

## Constraints to remember when adding to the public API

SkipTCA's API surface is constrained by what Skip Lite can transpile. Before
introducing a new type or function, check:

- Are you using a property wrapper? **Don't.** Skip cannot expand them.
- Are you adding a generic constraint on a protocol to a free function or
  initializer? **Don't.** Skip rejects `<T: Reducer>(...)`-style constraints.
- Are you using a Swift macro? **Don't.** None of `@Reducer`, `@DependencyClient`,
  `@CasePathable`, etc. transpile.
- Are you nesting a type inside a generic outer type? **Don't.** Nested types
  inside generics produce Kotlin that can't access the outer's generics.
- Are you referencing the outer generic from a `static var`? **Don't.** Kotlin
  companion objects cannot.

If a feature absolutely requires one of the above, gate it on `#if !SKIP`
and provide an alternative that works on Android (see `Sources/SkipTCA/Dependency.swift`
for the canonical example).

## Tests

Use **Swift Testing** (`@Test`, `@Suite`, `#expect`, `Issue.record`). XCTest is
not used in this project. Tests live in `Tests/SkipTCATests/`.

Both iOS test runs (`swift test`) and Skip transpilation
(`INCLUDE_SKIP=1 swift build`) must pass. Add coverage for any new public
API.

## Alloy model

Structural invariants belong in `Specs/SkipTCA.als`. Add a new `assert ...`
followed by `check ... for 5` whenever you introduce or change an algebraic
property. Keep the model small — quantitative properties (sequence length,
multiset equality) are better expressed in Swift Testing because Alloy's
relational logic struggles with aggregation.

## Pull requests

- Branch naming: `feature/<short-name>`, `fix/<short-name>`, `docs/<short-name>`.
- One logical change per PR.
- Update the `CHANGELOG.md` under `[Unreleased]` with a one-line entry.
- Commit messages in English. Body explains *why*, not *what*.

## Reporting issues

Open a GitHub issue with:

- The Skip Lite version (`skip --version`).
- Whether the bug appears on iOS, on the Skip transpile, or both.
- A minimal reproducer.

[skip]: https://skip.tools
