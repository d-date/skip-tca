import Foundation
import Testing

@testable import SkipTCA

@MainActor
@Suite("Store")
struct StoreTests {
  enum TestAction: Sendable, Equatable {
    case increment
    case decrement
    case incrementLater
    case incrementByThreeChained
    case stop
  }

  @Test("send applies the reducer to state synchronously")
  func sendAppliesReducer() {
    let store = Store<Int, TestAction>(initialState: 0) { state, action in
      switch action {
      case .increment:
        state += 1
        return .none
      case .decrement:
        state -= 1
        return .none
      default:
        return .none
      }
    }
    store.send(.increment)
    store.send(.increment)
    store.send(.decrement)
    #expect(store.state == 1)
  }

  @Test("Effect.run can dispatch follow-up actions back into the store")
  func effectRunChainsBack() async {
    let store = Store<Int, TestAction>(initialState: 0) { state, action in
      switch action {
      case .incrementLater:
        return .run { send in
          send(.increment)
        }
      case .increment:
        state += 1
        return .none
      default:
        return .none
      }
    }
    store.send(.incrementLater)
    // The follow-up `.increment` is hopped through Task { @MainActor }, so we
    // need to yield once for it to be observed.
    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(store.state == 1)
  }

  @Test("Chained effects via Effect.merge dispatch every child")
  func mergeDispatchesEveryChild() async {
    let store = Store<Int, TestAction>(initialState: 0) { state, action in
      switch action {
      case .incrementByThreeChained:
        return .merge(
          .run { send in send(.increment) },
          .run { send in send(.increment) },
          .run { send in send(.increment) }
        )
      case .increment:
        state += 1
        return .none
      default:
        return .none
      }
    }
    store.send(.incrementByThreeChained)
    try? await Task.sleep(nanoseconds: 100_000_000)
    #expect(store.state == 3)
  }
}
