import Foundation
import Testing

@testable import SkipTCA

@MainActor
@Suite("Effect cancellation")
struct EffectCancellationTests {
  enum TestAction: Sendable, Equatable {
    case start
    case startCancellable
    case stop
    case completed
  }

  @Test(".cancellable wraps a .run with an id")
  func cancellableWrapsRun() {
    let run: Effect<TestAction> = .run { send in send(.completed) }
    let effect = run.cancellable(id: "task")
    if case .cancellable(let id, _, _) = effect {
      #expect(id == "task")
    } else {
      Issue.record("Expected .cancellable case")
    }
  }

  @Test(".cancellable on non-.run leaves the effect untouched")
  func cancellableOnOtherCasesIsIdentity() {
    let none: Effect<TestAction> = .none
    let stillNone = none.cancellable(id: "task")
    if case .none = stillNone {
      // ok
    } else {
      Issue.record("Expected .cancellable to be identity on .none")
    }
  }

  @Test(".cancel(id:) stops an in-flight cancellable effect")
  func cancelStopsInFlightTask() async {
    let cancelled = LockedBox<Bool>(false)
    let store = Store<Int, TestAction>(initialState: 0) { state, action in
      switch action {
      case .startCancellable:
        return Effect<TestAction>.cancellable(
          id: "long",
          cancelInFlight: false,
          work: { _ in
            do {
              try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
              cancelled.mutate { $0 = true }
            }
          })
      case .stop:
        return Effect<TestAction>.cancel(id: "long")
      default:
        return .none
      }
    }
    store.send(.startCancellable)
    // Yield once so the cancellable Task is registered before .stop runs.
    try? await Task.sleep(nanoseconds: 10_000_000)
    store.send(.stop)
    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(cancelled.value == true)
  }

  @Test("cancelInFlight: true stops the previous task with the same id")
  func cancelInFlightStopsPrevious() async {
    let firstCancelled = LockedBox<Bool>(false)
    let secondCompleted = LockedBox<Bool>(false)
    let store = Store<Int, TestAction>(initialState: 0) { state, action in
      switch action {
      case .start:
        return .cancellable(
          id: "fetch",
          cancelInFlight: true,
          work: { _ in
            do {
              try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
              firstCancelled.mutate { $0 = true }
            }
          })
      case .startCancellable:
        return .cancellable(
          id: "fetch",
          cancelInFlight: true,
          work: { _ in
            secondCompleted.mutate { $0 = true }
          })
      default:
        return .none
      }
    }
    store.send(.start)
    try? await Task.sleep(nanoseconds: 10_000_000)
    store.send(.startCancellable)
    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(firstCancelled.value == true)
    #expect(secondCompleted.value == true)
  }
}
