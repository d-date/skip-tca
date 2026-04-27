import Foundation
import Testing

@testable import SkipTCA

@Suite("Reducer")
struct ReducerTests {
  /// A counter reducer used as the canonical fixture across the test suite.
  /// Mirrors the toy `Counter` reducer from the upstream TCA test suite,
  /// rewritten without macros so it stays Skip-transpilable.
  struct Counter: Reducer {
    typealias State = Int

    enum Action: Sendable, Equatable {
      case increment
      case decrement
      case set(Int)
    }

    func reduce(into state: inout Int, action: Action) -> Effect<Action> {
      switch action {
      case .increment:
        state += 1
        return .none
      case .decrement:
        state -= 1
        return .none
      case .set(let n):
        state = n
        return .none
      }
    }
  }

  @Test("reduce mutates inout State")
  func reduceMutatesInoutState() {
    var state = 0
    let counter = Counter()
    _ = counter.reduce(into: &state, action: .increment)
    #expect(state == 1)
    _ = counter.reduce(into: &state, action: .increment)
    #expect(state == 2)
  }

  @Test("reduce is deterministic for the same (State, Action)")
  func reduceIsDeterministic() {
    let counter = Counter()
    var stateA = 5
    var stateB = 5
    _ = counter.reduce(into: &stateA, action: .set(42))
    _ = counter.reduce(into: &stateB, action: .set(42))
    #expect(stateA == stateB)
  }

  @Test("reduce returns .none for state-only mutations")
  func reduceReturnsNoneForStateOnly() {
    let counter = Counter()
    var state = 0
    let effect = counter.reduce(into: &state, action: .increment)
    if case .none = effect {
      // ok
    } else {
      Issue.record("Expected .none, got \(effect)")
    }
  }
}
