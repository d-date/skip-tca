#if !SKIP

  import Foundation
  import Testing

  @testable import SkipTCA

  @Suite("Dependency")
  struct DependencyTests {
    private struct GreetingKey: DependencyKey {
      static let liveValue: String = "live-hello"
    }

    @Test("DependencyValues returns liveValue when nothing is overridden")
    func liveValueDefault() {
      let values = DependencyValues()
      #expect(values[GreetingKey.self] == "live-hello")
    }

    @Test("DependencyValues subscript stores and reads back overrides")
    func overrideStoredAndReadBack() {
      var values = DependencyValues()
      values[GreetingKey.self] = "test-hello"
      #expect(values[GreetingKey.self] == "test-hello")
    }

    @Test("withDependencies scopes overrides to the operation closure (async)")
    func withDependenciesAsyncScope() async {
      let outsideBefore = DependencyValues.current[GreetingKey.self]
      let inside: String = await withDependencies {
        $0[GreetingKey.self] = "scoped"
      } operation: {
        DependencyValues.current[GreetingKey.self]
      }
      let outsideAfter = DependencyValues.current[GreetingKey.self]
      #expect(outsideBefore == "live-hello")
      #expect(inside == "scoped")
      #expect(outsideAfter == "live-hello")
    }

    @Test("withDependencies scopes overrides (sync)")
    func withDependenciesSyncScope() {
      let inside: String = withDependencies {
        $0[GreetingKey.self] = "scoped-sync"
      } operation: {
        DependencyValues.current[GreetingKey.self]
      }
      #expect(inside == "scoped-sync")
    }

    @Test("@Dependency reads through DependencyValues.current at access time")
    func propertyWrapperResolvesAtAccess() async {
      struct Caller {
        @Dependency(GreetingKey.self) var greeting
      }
      let caller = Caller()
      let inside: String = await withDependencies {
        $0[GreetingKey.self] = "wrapper-scoped"
      } operation: {
        caller.greeting
      }
      #expect(inside == "wrapper-scoped")
    }
  }

#endif
