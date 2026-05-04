# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-05-04

### Changed

- **BREAKING**: `TestStore` moved from the `SkipTCA` library into a new `SkipTCATesting` library. Test code that previously imported `SkipTCA` for `TestStore` now needs `import SkipTCATesting`. This split prevents the main `SkipTCA` library from pulling `import Testing` (and transitively `_Testing_Foundation`) into every consumer, which broke Xcode App-target builds even though `swift build` succeeded.

### Removed

- `Specs/SkipTCA.als` Alloy 6 model and the `alloy.yml` GitHub Actions workflow. Alloy was a useful spike-time sanity check, but the structural invariants it covered are already enforced by the Swift type system and the Swift Testing suite, so the extra dependency on the Alloy toolchain is not worth its CI cost.

## [0.1.0] - 2026-04-28

### Added

- `protocol Reducer` with `reduce(into:action:)` returning `Effect<Action>`.
- `enum Effect<Action: Sendable>` with cases `.none`, `.run`, `.merge`, `.cancellable(id:cancelInFlight:work:)`, `.cancel(id:)`. Variadic `.merge(_:_:)` convenience and `Effect.cancellable(id:cancelInFlight:)` chainable form on `.run` effects.
- `struct Send<Action>` with `callAsFunction(_:)` for use inside `Effect.run` work.
- `final class Store<State, Action>` (`@Observable` on iOS) with `send(_:)` and per-id cancellable task management.
- `BindingAction<State>` (closure-based on both platforms; `.set(\.path, to:)` on iOS only) and `protocol BindableAction`.
- `protocol ViewAction` plus `Store.send(view:)` extension.
- `protocol DependencyKey`, `struct DependencyValues`, `withDependencies(_:operation:)` (sync + async), and `@Dependency` property wrapper. iOS only.
- `PresentationState`, `PresentationAction`, `StackState` (array-backed), `StackAction` for navigation modeling.
- `final class TestStore<State, Action>` for Swift Testing-based reducer tests with `send`, `receive`, `finish(timeout:)`, `dependencies`, and `Exhaustivity` mode. iOS only.
- Swift Testing test suite (39 tests, 13 suites).
- Initial public release as `github.com/d-date/skip-tca`.

[Unreleased]: https://github.com/d-date/skip-tca/compare/0.2.0...HEAD
[0.2.0]: https://github.com/d-date/skip-tca/releases/tag/0.2.0
[0.1.0]: https://github.com/d-date/skip-tca/releases/tag/0.1.0
