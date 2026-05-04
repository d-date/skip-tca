#if !SKIP

  import Foundation
  import SkipTCA
  import Testing

  /// A testable, exhaustive Store for use with Swift Testing.
  ///
  /// `TestStore` mirrors The Composable Architecture's TestStore semantics:
  /// every action sent into the store may produce follow-up actions through
  /// effects, and the test must explicitly `receive` each one (in exhaustive
  /// mode) or be willing to discard them (in non-exhaustive mode). Mismatches
  /// are reported via Swift Testing's `Issue.record`, so failures attribute
  /// to the call site that detected them.
  ///
  /// `TestStore` is iOS-only because it depends on Swift Testing
  /// (`#expect`, `Issue.record`, `SourceLocation`). Production code that runs
  /// on Android via Skip should use the regular `Store` and rely on test
  /// runs hosted on macOS or iOS Simulator.
  @MainActor
  public final class TestStore<State, Action: Sendable & Equatable> {
    public private(set) var state: State

    public enum Exhaustivity: Sendable {
      case on
      case off
    }
    public var exhaustivity: Exhaustivity = .on

    /// Override `DependencyValues` for the duration of this store's tests.
    /// Same shape as `withDependencies(_:operation:)` but persists across calls.
    public var dependencies: DependencyValues = .current

    private let reducerFn: @MainActor (inout State, Action) -> Effect<Action>
    private var pendingActions: [Action] = []
    private var effectTasks: [Task<Void, Never>] = []

    public init(
      initialState: State,
      reducer: @escaping @MainActor (inout State, Action) -> Effect<Action>
    ) {
      self.state = initialState
      self.reducerFn = reducer
    }

    /// Send an action and optionally assert that the post-reduce state matches
    /// expectations. The closure receives the new state.
    public func send(
      _ action: Action,
      _ assert: ((State) -> Void)? = nil,
      sourceLocation: SourceLocation = #_sourceLocation
    ) async {
      let effect = withDependenciesScope { [self] in
        reducerFn(&self.state, action)
      }
      runEffect(effect)
      assert?(state)
      // Give effects a tick to register their first dispatch.
      await Task.yield()
    }

    /// Wait for an effect-emitted action to arrive, then feed it through the
    /// reducer and optionally assert post-state.
    public func receive(
      _ expected: Action,
      _ assert: ((State) -> Void)? = nil,
      timeout: Duration = .seconds(1),
      sourceLocation: SourceLocation = #_sourceLocation
    ) async {
      let deadline = ContinuousClock.now.advanced(by: timeout)
      while pendingActions.isEmpty {
        if ContinuousClock.now > deadline {
          Issue.record(
            "Expected to receive \(expected) but no action was emitted within \(timeout)",
            sourceLocation: sourceLocation
          )
          return
        }
        try? await Task.sleep(nanoseconds: 5_000_000)
      }
      let received = pendingActions.removeFirst()
      if received != expected {
        Issue.record(
          "Expected to receive \(expected), got \(received)",
          sourceLocation: sourceLocation
        )
        // Still feed it through so subsequent assertions are meaningful.
      }
      let effect = withDependenciesScope { [self] in
        reducerFn(&self.state, received)
      }
      runEffect(effect)
      assert?(state)
      await Task.yield()
    }

    /// Wait for all in-flight effects to complete, and (in exhaustive mode)
    /// fail if any actions were left unreceived.
    public func finish(
      timeout: Duration = .seconds(2),
      sourceLocation: SourceLocation = #_sourceLocation
    ) async {
      // Snapshot and clear before awaiting so any new effects spawned by
      // these tasks land in a fresh registry.
      let snapshot = effectTasks
      effectTasks.removeAll()

      // A timeout task cancels every snapshot task if it elapses.
      let timedOut = TimeoutFlag()
      let timeoutTask = Task { @Sendable in
        try? await Task.sleep(for: timeout)
        await timedOut.mark()
        for task in snapshot { task.cancel() }
      }
      for task in snapshot {
        await task.value
      }
      timeoutTask.cancel()

      if await timedOut.value {
        Issue.record(
          "TestStore did not finish within \(timeout)",
          sourceLocation: sourceLocation
        )
      }
      if exhaustivity == .on, !pendingActions.isEmpty {
        Issue.record(
          "TestStore finished with unhandled actions: \(pendingActions)",
          sourceLocation: sourceLocation
        )
      }
    }

    /// Discard any pending actions without asserting. Useful in non-exhaustive
    /// flows where the test only cares about a specific milestone.
    public func skipReceivedActions() {
      pendingActions.removeAll()
    }

    private func withDependenciesScope<R>(_ body: () -> R) -> R {
      DependencyValues.$current.withValue(dependencies, operation: body)
    }

    private func runEffect(_ effect: Effect<Action>) {
      switch effect {
      case .none:
        return
      case .run(let work):
        let send = makeSend()
        let task = Task { @MainActor in
          await work(send)
        }
        effectTasks.append(task)
      case .merge(let children):
        for child in children {
          runEffect(child)
        }
      case .cancellable(_, _, let work):
        // For test purposes we treat cancellable identically to .run:
        // cancellation behavior is exercised in EffectCancellationTests
        // against the production Store.
        let send = makeSend()
        let task = Task { @MainActor in
          await work(send)
        }
        effectTasks.append(task)
      case .cancel:
        // No-op in tests: cancellation semantics are tested at the Store level.
        return
      }
    }

    private func makeSend() -> Send<Action> {
      Send<Action> { [weak self] action in
        Task { @MainActor [weak self] in
          self?.pendingActions.append(action)
        }
      }
    }
  }

  /// Tiny actor-based flag for `TestStore.finish`. Lets the timeout task
  /// signal "we hit the deadline" without needing `Sendable` mutable state.
  private actor TimeoutFlag {
    private(set) var value: Bool = false
    func mark() { value = true }
  }

#endif
