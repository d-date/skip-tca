#if !SKIP

  import Foundation
  import SkipTCATesting
  import Testing

  @testable import SkipTCA

  @MainActor
  @Suite("TestStore")
  struct TestStoreTests {
    enum Action: Sendable, Equatable {
      case kickoff
      case fetched(Int)
    }

    private static func reducer(state: inout Int, action: Action) -> Effect<Action> {
      switch action {
      case .kickoff:
        return .run { send in
          send(.fetched(42))
        }
      case .fetched(let value):
        state = value
        return .none
      }
    }

    @Test("send + receive happy path")
    func sendReceive() async {
      let store = TestStore<Int, Action>(initialState: 0, reducer: Self.reducer)
      await store.send(.kickoff)
      await store.receive(.fetched(42)) { state in
        #expect(state == 42)
      }
      await store.finish()
    }

    @Test("send asserts post-state directly when no effect is emitted")
    func sendAssertsState() async {
      let store = TestStore<Int, Action>(initialState: 0, reducer: Self.reducer)
      await store.send(.fetched(7)) { state in
        #expect(state == 7)
      }
      await store.finish()
    }

    @Test("dependencies override is visible to the reducer through DependencyValues.current")
    func dependenciesOverride() async {
      struct Greeting: DependencyKey { static let liveValue = "live" }
      let captured = LockedBox<String>("")
      let store = TestStore<Int, Action>(initialState: 0) { state, action in
        captured.mutate { $0 = DependencyValues.current[Greeting.self] }
        if case .fetched(let v) = action { state = v }
        return .none
      }
      store.dependencies[Greeting.self] = "test"
      await store.send(.fetched(1))
      #expect(captured.value == "test")
    }
  }

#endif
