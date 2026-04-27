import Foundation
import Testing

@testable import SkipTCA

@Suite("Effect")
struct EffectTests {
  enum TestAction: Sendable, Equatable {
    case ping
    case pong
    case bang
  }

  @Test(".none case identity")
  func noneCase() {
    let effect: Effect<TestAction> = .none
    if case .none = effect {
      // ok
    } else {
      Issue.record("Expected .none case")
    }
  }

  @Test(".run case captures async work")
  func runCase() async {
    let effect: Effect<TestAction> = .run { send in
      send(.ping)
    }
    guard case .run(let work) = effect else {
      Issue.record("Expected .run case")
      return
    }
    let received = LockedBox<[TestAction]>([])
    let send = Send<TestAction> { action in received.mutate { $0.append(action) } }
    await work(send)
    #expect(received.value == [.ping])
  }

  @Test(".merge wraps a list of effects")
  func mergeArrayCase() {
    let effect: Effect<TestAction> = .merge([.none, .none])
    guard case .merge(let children) = effect else {
      Issue.record("Expected .merge case")
      return
    }
    #expect(children.count == 2)
  }

  @Test("variadic .merge equals array .merge")
  func mergeVariadicEqualsArray() {
    let array: Effect<TestAction> = .merge([.none, .none])
    let variadic: Effect<TestAction> = .merge(.none, .none)
    guard case .merge(let a) = array, case .merge(let b) = variadic else {
      Issue.record("Expected .merge in both")
      return
    }
    #expect(a.count == b.count)
  }
}

/// Tiny thread-safe box to collect side effects from `Effect.run` work
/// without requiring Combine. Lives in tests only.
final class LockedBox<Value>: @unchecked Sendable {
  private var _value: Value
  private let lock = NSLock()

  init(_ value: Value) {
    self._value = value
  }

  var value: Value {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  func mutate(_ transform: (inout Value) -> Void) {
    lock.lock()
    defer { lock.unlock() }
    transform(&_value)
  }
}
