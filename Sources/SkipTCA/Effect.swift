import Foundation

/// A side effect that, once executed, may emit zero or more follow-up actions
/// back into the store via the provided `Send`.
///
/// Modeled as a flat (non-nested) `enum` so Skip Lite transpiles it to a
/// Kotlin sealed class. Nested types inside generic types and static members
/// that reference an outer generic both fail to translate.
public enum Effect<Action: Sendable>: Sendable {
  case none
  case run(@Sendable (Send<Action>) async -> Void)
  case merge([Effect<Action>])

  /// A cancellable async effect. The `id` selects which in-flight effect to
  /// cancel via `Effect.cancel(id:)`. When `cancelInFlight` is true, sending
  /// this effect will first cancel any other in-flight effect with the same
  /// `id` before launching this one.
  ///
  /// Cancellation IDs are plain `String`s rather than `AnyHashable` because
  /// Skip cannot translate `Hashable` generic constraints on free functions.
  case cancellable(id: String, cancelInFlight: Bool, work: @Sendable (Send<Action>) async -> Void)

  /// Cancel any in-flight effect that was started with the given cancellation `id`.
  case cancel(id: String)

  /// Variadic convenience matching `Effect.merge(.a, .b, .c)`.
  public static func merge(_ effects: Effect<Action>...) -> Effect<Action> {
    .merge(effects)
  }

  /// Wrap an existing `.run` effect with a cancellation `id`. If applied to
  /// any other case the receiver is returned unchanged.
  public func cancellable(id: String, cancelInFlight: Bool = false) -> Effect<Action> {
    switch self {
    case .run(let work):
      return .cancellable(id: id, cancelInFlight: cancelInFlight, work: work)
    default:
      return self
    }
  }
}

/// A handle passed to `Effect.run` work that lets it dispatch follow-up actions
/// back into the store.
public struct Send<Action: Sendable>: Sendable {
  let dispatch: @Sendable (Action) -> Void

  public init(dispatch: @escaping @Sendable (Action) -> Void) {
    self.dispatch = dispatch
  }

  public func callAsFunction(_ action: Action) {
    dispatch(action)
  }
}
