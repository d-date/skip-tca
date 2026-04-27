import Foundation

#if !SKIP
  import Observation
#endif

/// A reference-typed observable container that owns a feature's `State` and
/// runs a reducer function whenever an `Action` is sent.
///
/// `Store` deliberately takes the reducer as a closure rather than a
/// `Reducer`-conforming generic parameter: Skip cannot translate constructors
/// that introduce additional generics or generic constraints over a protocol.
/// Use the free function `makeStore(_:reducer:)` to build a `Store` from a
/// `Reducer` value.
@MainActor
#if !SKIP
  @Observable
#endif
public final class Store<State, Action: Sendable> {
  public private(set) var state: State

  private let reducerFn: @MainActor (inout State, Action) -> Effect<Action>

  /// In-flight cancellable effects keyed by their cancellation `id`. The list
  /// per id allows multiple `cancellable` effects with the same id to coexist
  /// when `cancelInFlight` is false; otherwise the oldest are cancelled before
  /// the new one is started.
  private var cancellableTasks: [String: [Task<Void, Never>]] = [:]

  public init(
    initialState: State,
    reducer: @escaping @MainActor (inout State, Action) -> Effect<Action>
  ) {
    self.state = initialState
    self.reducerFn = reducer
  }

  public func send(_ action: Action) {
    let effect = reducerFn(&state, action)
    runEffect(effect)
  }

  private func runEffect(_ effect: Effect<Action>) {
    switch effect {
    case .none:
      return
    case .run(let work):
      let send = makeSend()
      Task { @MainActor in
        await work(send)
      }
    case .merge(let children):
      for child in children {
        runEffect(child)
      }
    case .cancellable(let id, let cancelInFlight, let work):
      if cancelInFlight {
        cancelTasks(id: id)
      }
      let send = makeSend()
      let task = Task { @MainActor in
        await work(send)
      }
      cancellableTasks[id, default: []].append(task)
    case .cancel(let id):
      cancelTasks(id: id)
    }
  }

  private func makeSend() -> Send<Action> {
    Send<Action> { [weak self] action in
      Task { @MainActor [weak self] in
        self?.send(action)
      }
    }
  }

  private func cancelTasks(id: String) {
    if let tasks = cancellableTasks.removeValue(forKey: id) {
      for task in tasks {
        task.cancel()
      }
    }
  }
}

// `makeStore<R: Reducer>(reducer: R)` was tempting but Skip cannot translate
// "function generic constrained by a Swift protocol" into a Kotlin signature.
// Construct `Store` directly with a closure that delegates to your reducer:
//
//     let myReducer = SpikeReducer()
//     let store = Store<SpikeState, SpikeAction>(
//       initialState: SpikeState(),
//       reducer: { state, action in
//         myReducer.reduce(into: &state, action: action)
//       }
//     )
