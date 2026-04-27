# SkipTCA

A macro-free, [Composable Architecture][tca]-shaped runtime that
[**Skip Lite**][skip] transpiles to native Kotlin/Jetpack Compose.

> Write your iOS feature with `Reducer` / `Effect` / `Store`. Build it on iOS
> with Swift. Build it on Android with Skip Lite. Same source.

## Why

[The Composable Architecture][tca] is the de-facto state-management library in
the SwiftUI ecosystem, but its public API leans heavily on Swift macros
(`@Reducer`, `@ObservableState`, `@CasePathable`, `@Dependency`, …) that
[Skip Lite][skip] cannot expand. Trying to transpile a TCA-using feature
under `INCLUDE_SKIP=1 swift build` fails with hundreds of *"Kotlin does not
support this Swift attribute, macro, or property wrapper"* warnings followed
by a cascade of *"Skip is unable to determine the owning type for member"*
errors on every `case .binding`, `case .view(...)`, `send(.foo)` site.

`SkipTCA` is the smallest reasonable replacement: it gives you the same
shapes (`Reducer` / `Effect.run` / `Store.send` / `BindingAction` /
`PresentationAction` / `StackState`) without using a single macro, so Skip
Lite happily emits a Kotlin sealed class for `Effect`, a Kotlin interface
for `Reducer`, and a Compose-aware `Store` class.

```swift
import SkipTCA

struct Counter: Reducer {
  typealias State = Int
  enum Action: Sendable { case increment, decrement }

  func reduce(into state: inout Int, action: Action) -> Effect<Action> {
    switch action {
    case .increment: state += 1
    case .decrement: state -= 1
    }
    return .none
  }
}
```

After `INCLUDE_SKIP=1 swift build` Skip Lite produces:

```kotlin
sealed class Action {
  class IncrementCase: Action()
  class DecrementCase: Action()
}

class Counter: Reducer<Int, Action> {
  override fun reduce(into: InOut<Int>, action: Action): Effect<Action> {
    when (action) {
      is Action.IncrementCase -> { into.value += 1 }
      is Action.DecrementCase -> { into.value -= 1 }
    }
    return Effect.none
  }
}
```

## Status

- 🚧 **Pre-1.0**, public API may change.
- ✅ Compiles and runs on iOS / macOS / watchOS / tvOS / visionOS.
- ✅ Transpiles cleanly under Skip Lite 1.8.11+.
- ✅ Swift Testing test suite (39 tests).
- ✅ Alloy 6 model checks structural invariants (5 properties, scope 5).

## Installation

Add SkipTCA to the dependencies of your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/d-date/skip-tca.git", from: "0.1.0"),
],
targets: [
  .target(
    name: "MyFeature",
    dependencies: [
      .product(name: "SkipTCA", package: "skip-tca"),
    ]
  ),
]
```

## API surface

### Core

| Type | Purpose |
|------|---------|
| `protocol Reducer` | Implement `reduce(into:action:) -> Effect<Action>`. Macro-free. |
| `enum Effect<Action>` | `.none`, `.run`, `.merge`, `.cancellable`, `.cancel`. Flat enum, transpiles to a Kotlin sealed class. |
| `struct Send<Action>` | Closure-style action dispatcher passed to `Effect.run`. |
| `final class Store<State, Action>` | `@Observable` reference container. `Store.send(_:)` runs the reducer; effects are scheduled on `@MainActor`. |

### Cancellation

```swift
return Effect<Action>.cancellable(id: "fetch", cancelInFlight: true) { send in
  let data = try await api.load()
  send(.loaded(data))
}

// elsewhere
return .cancel(id: "fetch")
```

Cancellation IDs are `String` rather than `Hashable & Sendable` because Skip
cannot transpile generic constraints over the `Hashable` protocol on free
functions.

### Bindings

```swift
public enum Action: BindableAction {
  public typealias State = MyFeature.State
  case binding(BindingAction<State>)
  case other
}

// iOS-only convenience
let setName: BindingAction<State> = .set(\.name, to: "Alice")

// Skip-friendly closure form (works on both platforms)
let setAge = BindingAction<State> { $0.age = 42 }
```

### View actions

```swift
public enum Action: ViewAction, Sendable {
  public enum ViewAction: Sendable { case onAppear, retryTapped }
  case view(ViewAction)
  case loaded
}

store.send(view: .onAppear)  // shorthand for store.send(.view(.onAppear))
```

### Dependencies (iOS only)

```swift
struct DataKey: DependencyKey {
  static let liveValue: any DataClient = LiveDataClient()
}

struct MyReducer: Reducer {
  @Dependency(DataKey.self) var data
  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    return .run { send in
      let value = try await data.fetch()
      send(.loaded(value))
    }
  }
}

await withDependencies {
  $0[DataKey.self] = MockDataClient()
} operation: {
  // Test code that resolves DataKey to the mock.
}
```

`@Dependency`, `withDependencies`, and `DependencyKey` are gated on
`#if !SKIP`. Skip's coroutine-context model and Swift `TaskLocal` value
propagation do not line up, and Skip cannot expand property wrappers. On
Android, **inject your dependencies through the reducer's initializer**:

```swift
struct MyReducer: Reducer {
  let fetch: @Sendable () async throws -> Data
  // ...
}
```

### Navigation

```swift
public struct State: Sendable {
  public var destination: PresentationState<DetailFeature.State> = .init()
  public var path: StackState<RouteState> = StackState([])
}

public enum Action: Sendable {
  case destination(PresentationAction<DetailFeature.Action>)
  case path(StackAction<RouteState, RouteAction>)
}
```

`StackState<Element>` is array-backed (no `IdentifiedArray` dependency) so
it transpiles trivially. `StackAction` indexes by position rather than ID.

### TestStore (iOS only)

```swift
@MainActor
@Test
func myFeature() async {
  let store = TestStore<State, Action>(initialState: .init(), reducer: MyReducer().reduce(into:action:))
  store.dependencies[DataKey.self] = MockDataClient()
  await store.send(.kickoff)
  await store.receive(.loaded(.fixture)) { state in
    #expect(state.value == .fixture)
  }
  await store.finish()
}
```

`TestStore` is iOS only because it depends on Swift Testing's `Issue.record`
and `SourceLocation`. Production reducers and stores ship to Android via
Skip without it.

## Migrating from `swift-composable-architecture`

| TCA | SkipTCA |
|-----|---------|
| `@Reducer struct Feature {}` | `struct Feature: Reducer {}` |
| `@ObservableState struct State {}` | plain `struct State: Sendable {}` (observability lives on `Store`) |
| `var body: some ReducerOf<Self> { Reduce { ... } }` | `func reduce(into:action:) -> Effect<Action> { switch action { ... } }` |
| `@CasePathable enum Action {}` | plain `enum Action: Sendable {}` |
| `@Dependency(\.foo) var foo` | iOS: `@Dependency(FooKey.self)`; Skip: `let foo: FooClient` injected via `init` |
| `@DependencyClient struct Client {}` | hand-written `struct Client { var fetch: ... }` with explicit `init` |
| `BindingReducer()` | `case .binding(let action): action.apply(to: &state); return .none` |
| `@ViewAction(for: Feature.self)` | `Store.send(view:)` extension |
| `@Presents var destination: ...?` | `var destination: PresentationState<...> = .init()` |
| `StackState` (identified) | `StackState` (array-backed) |
| `TestStore` | `SkipTCA.TestStore` (iOS-only) |

## Skip Lite compatibility notes

While building SkipTCA we hit the following Skip Lite constraints. Each one
is documented inline in the relevant source file:

1. **Nested types inside a generic outer type** don't translate. `Effect<Action>.Operation` was rejected; flatten to a top-level enum case.
2. **Static members on a generic type** can't reference the outer generic from a Kotlin companion object.
3. **Constructors / functions can't introduce additional generics** beyond the owning type.
4. **Generic constraints over a Swift protocol** don't translate. `func makeStore<R: Reducer>(...)` was rejected.
5. **Constrained typealiases** don't translate. `typealias StoreOf<R: Reducer>` was rejected.
6. **Property wrappers** don't translate; `@Dependency` is gated on `#if !SKIP`.
7. **`AnyHashable`-based generic constraints** on free functions don't translate; we use plain `String` cancellation IDs.
8. **`Hashable & Sendable` generic constraints** on free functions don't translate either.

These observations are useful upstream feedback for `skiptools/skip` and the
TCA team.

## Testing

```bash
swift test                            # run the Swift Testing suite
INCLUDE_SKIP=1 swift build            # verify the Skip Lite transpiler is happy
brew install alloy-analyzer           # install Alloy 6 if you don't have it yet
alloy exec -f -c '*' Specs/SkipTCA.als  # check structural invariants
```

## Roadmap

- `IdentifiedArray`-backed `StackState` (when SkipFoundation supports it).
- `forEach` reducer composition helper.
- `BindingViewState` / `@Bindable` ergonomics.
- Optional `swift-composable-architecture` interop layer (use TCA on iOS, SkipTCA on Android, sharing State/Action enums).
- Investigate exposing Kotlin coroutine `CoroutineContext`-based dependency
  scoping that mirrors `withDependencies` on Skip.

## Inspiration & prior art

- [Point-Free's swift-composable-architecture][tca] — the API we're shaping after.
- [Skip][skip] — the Swift→Kotlin transpiler whose constraints shaped this design.

## License

MIT — see [LICENSE](./LICENSE).

[tca]: https://github.com/pointfreeco/swift-composable-architecture
[skip]: https://skip.tools
