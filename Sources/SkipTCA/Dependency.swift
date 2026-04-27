import Foundation

#if !SKIP

  /// Type-erased registration key for a dependency. Conformers declare the
  /// `Value` they vend and a `liveValue` factory used in production.
  ///
  /// This protocol — and the surrounding `@Dependency` / `withDependencies`
  /// helpers — is iOS-only. Skip cannot transpile a protocol with both an
  /// associatedtype and a static requirement (Kotlin companion objects do
  /// not have access to their declaring type's generics) and Swift property
  /// wrappers do not transpile either. Skip-side reducers should accept
  /// dependencies via `init(...)` injection instead.
  public protocol DependencyKey {
    associatedtype Value
    static var liveValue: Value { get }
  }

  /// Bag of overridable dependencies available at the current actor scope.
  /// Look-up is keyed by the dependency's `Key.Type`, identified by
  /// `ObjectIdentifier`. Values are stored type-erased and re-cast on read.
  public struct DependencyValues: @unchecked Sendable {
    private var storage: [ObjectIdentifier: Any] = [:]

    public init() {}

    public subscript<Key: DependencyKey>(_ key: Key.Type) -> Key.Value {
      get {
        let id = ObjectIdentifier(key)
        if let value = storage[id] as? Key.Value {
          return value
        }
        return Key.liveValue
      }
      set {
        storage[ObjectIdentifier(key)] = newValue
      }
    }

    /// The dependencies in scope for the current task. Override with
    /// `withDependencies(_:operation:)`.
    @TaskLocal public static var current: DependencyValues = DependencyValues()
  }

  /// Run `operation` with a scoped override of the current `DependencyValues`.
  ///
  /// Async variant.
  public func withDependencies<R>(
    _ updateValuesForOperation: (inout DependencyValues) -> Void,
    operation: () async throws -> R
  ) async rethrows -> R {
    var values = DependencyValues.current
    updateValuesForOperation(&values)
    return try await DependencyValues.$current.withValue(values) {
      try await operation()
    }
  }

  /// Run `operation` with a scoped override of the current `DependencyValues`.
  ///
  /// Sync variant.
  public func withDependencies<R>(
    _ updateValuesForOperation: (inout DependencyValues) -> Void,
    operation: () throws -> R
  ) rethrows -> R {
    var values = DependencyValues.current
    updateValuesForOperation(&values)
    return try DependencyValues.$current.withValue(values) {
      try operation()
    }
  }

  /// Property wrapper that reads a dependency from `DependencyValues.current`
  /// at access time, so values resolved inside `withDependencies` see overrides.
  @propertyWrapper
  public struct Dependency<Value>: Sendable {
    private let resolve: @Sendable () -> Value

    public init<Key: DependencyKey>(_ key: Key.Type) where Key.Value == Value {
      self.resolve = { DependencyValues.current[key] }
    }

    public var wrappedValue: Value {
      resolve()
    }
  }

#endif
