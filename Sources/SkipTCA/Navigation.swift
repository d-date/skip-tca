import Foundation

// MARK: - Presentation

/// Wraps an optional child feature state. Mirrors TCA's `@Presents` macro
/// without using a property wrapper (Skip cannot transpile property wrappers).
///
///     public struct State: Sendable {
///       public var destination: PresentationState<Destination.State> = .init()
///     }
public struct PresentationState<State: Sendable>: Sendable {
  public var value: State?

  public init(_ value: State? = nil) {
    self.value = value
  }
}

/// Action that targets a presented child feature, plus an explicit dismissal.
public enum PresentationAction<Action: Sendable>: Sendable {
  case dismiss
  case presented(Action)
}

// MARK: - Stack

/// A stack of child feature states, identified by their position. Models the
/// TCA `StackState` API in array form so Skip can transpile it: identified
/// collections are not modeled by Skip-foundation.
public struct StackState<Element: Sendable>: Sendable {
  public private(set) var elements: [Element]

  public init(_ elements: [Element] = []) {
    self.elements = elements
  }

  public var count: Int { elements.count }
  public var isEmpty: Bool { elements.isEmpty }
  public var last: Element? { elements.last }

  public mutating func append(_ element: Element) {
    elements.append(element)
  }

  public mutating func popLast() -> Element? {
    elements.popLast()
  }

  public mutating func removeAll() {
    elements.removeAll()
  }

  /// Replace the element at `index`. No-op if the index is out of bounds.
  public mutating func setElement(_ element: Element, at index: Int) {
    guard elements.indices.contains(index) else { return }
    elements[index] = element
  }
}

/// Action targeting a `StackState`. Indexed by position rather than identity
/// for Skip compatibility.
public enum StackAction<Element: Sendable, ElementAction: Sendable>: Sendable {
  case push(Element)
  case pop
  case popToRoot
  case element(index: Int, action: ElementAction)
}
