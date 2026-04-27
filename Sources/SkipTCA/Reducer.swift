import Foundation

/// A unit of feature logic that maps a current `State` and incoming `Action`
/// to a new state plus an optional `Effect` of follow-up actions.
///
/// Conformers implement `reduce(into:action:)`. The `body` pattern from
/// The Composable Architecture's macro-generated reducers is intentionally not
/// modeled here: SkipTCA is macro-free so Skip Lite can transpile it.
public protocol Reducer {
  associatedtype State
  associatedtype Action

  func reduce(into state: inout State, action: Action) -> Effect<Action>
}
