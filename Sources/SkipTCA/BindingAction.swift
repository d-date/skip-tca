import Foundation

/// A mutation that, when applied to a `State`, updates one of its fields.
///
/// `BindingAction` is built around an opaque closure rather than a `KeyPath`.
/// Skip Lite cannot reliably transpile `WritableKeyPath`-based generic
/// constructors, so closures are the lowest-common-denominator that survives
/// the Kotlin emitter intact. iOS code can use the `.set(_:to:)` helper for
/// the familiar `\.path`-style call site.
public struct BindingAction<State>: Sendable {
  public let mutate: @Sendable (inout State) -> Void

  public init(_ mutate: @escaping @Sendable (inout State) -> Void) {
    self.mutate = mutate
  }

  /// Apply the binding to the given state in-place.
  public func apply(to state: inout State) {
    mutate(&state)
  }
}

#if !SKIP
  extension BindingAction {
    /// `.set(\.searchText, to: "hello")` style convenience — iOS-only.
    /// `WritableKeyPath` plus a generic `Value: Sendable` constraint does not
    /// transpile under Skip Lite, so the helper is gated on `#if !SKIP`. Skip
    /// callers should use `BindingAction { $0.field = value }` directly.
    public static func set<Value: Sendable>(
      _ keyPath: WritableKeyPath<State, Value> & Sendable,
      to value: Value
    ) -> BindingAction<State> {
      BindingAction { state in state[keyPath: keyPath] = value }
    }
  }
#endif

/// Marker protocol for action enums that include a `binding` case carrying a
/// `BindingAction<State>`. Conforming types should declare:
///
///     public enum Action: BindableAction {
///       public typealias State = MyFeature.State
///       case binding(BindingAction<State>)
///       // ...
///     }
///
/// The `binding(_:)` static requirement matches the way the iOS TCA macros
/// project a binding constructor; in `SkipTCA` the case itself satisfies it.
public protocol BindableAction {
  associatedtype State

  static func binding(_ action: BindingAction<State>) -> Self
}
