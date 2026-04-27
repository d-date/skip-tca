import Foundation

/// Marker protocol for action enums that wrap a nested view-only action set:
///
///     public enum Action: ViewAction {
///       public enum ViewAction: Sendable { case onAppear, retryTapped }
///       case view(ViewAction)
///       // ...
///     }
///
/// On the iOS-side, TCA exposes a `@ViewAction(for:)` macro plus a
/// `store.send(view: .onAppear)` shorthand. SkipTCA does not provide a macro
/// (Skip Lite cannot expand custom macros) but does provide the same
/// `Store.send(view:)` extension so feature code can read the same way.
public protocol ViewAction {
  associatedtype ViewAction: Sendable

  static func view(_ action: ViewAction) -> Self
}

@MainActor
extension Store where Action: ViewAction {
  /// Wrap and send a view-level action through the parent action's `view` case.
  public func send(view viewAction: Action.ViewAction) {
    self.send(Action.view(viewAction))
  }
}
