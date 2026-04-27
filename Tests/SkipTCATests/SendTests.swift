import Foundation
import Testing

@testable import SkipTCA

@Suite("Send")
struct SendTests {
  enum TestAction: Sendable, Equatable {
    case a, b, c
  }

  @Test("Send forwards actions to its dispatch closure")
  func dispatchClosureCalled() {
    let received = LockedBox<[TestAction]>([])
    let send = Send<TestAction> { action in
      received.mutate { $0.append(action) }
    }
    send(.a)
    send(.b)
    send(.c)
    #expect(received.value == [.a, .b, .c])
  }

  @Test("Send.callAsFunction is the same as the explicit dispatch")
  func callAsFunctionIsExplicitDispatch() {
    let received = LockedBox<[TestAction]>([])
    let send = Send<TestAction> { action in
      received.mutate { $0.append(action) }
    }
    send(.a)
    send.callAsFunction(.b)
    #expect(received.value == [.a, .b])
  }
}
