import Foundation
import Testing

@testable import SkipTCA

@Suite("PresentationState")
struct PresentationStateTests {
  struct Detail: Sendable, Equatable {
    var title: String
  }

  @Test("Defaults to nil")
  func defaultsToNil() {
    let state = PresentationState<Detail>()
    #expect(state.value == nil)
  }

  @Test("Can wrap an initial value")
  func wrapsInitialValue() {
    let state = PresentationState<Detail>(Detail(title: "hi"))
    #expect(state.value?.title == "hi")
  }

  @Test("Mutable: assigning a new value clears or replaces")
  func reassignment() {
    var state = PresentationState<Detail>(Detail(title: "first"))
    state.value = Detail(title: "second")
    #expect(state.value?.title == "second")
    state.value = nil
    #expect(state.value == nil)
  }
}

@Suite("PresentationAction")
struct PresentationActionTests {
  enum DetailAction: Sendable, Equatable {
    case loaded
  }

  @Test(".dismiss is a distinct case")
  func dismissCase() {
    let action: PresentationAction<DetailAction> = .dismiss
    if case .dismiss = action {
      // ok
    } else {
      Issue.record("Expected .dismiss")
    }
  }

  @Test(".presented carries the inner action")
  func presentedCase() {
    let action: PresentationAction<DetailAction> = .presented(.loaded)
    if case .presented(let inner) = action {
      #expect(inner == .loaded)
    } else {
      Issue.record("Expected .presented")
    }
  }
}

@Suite("StackState")
struct StackStateTests {
  @Test("append + last + count")
  func appendObservable() {
    var stack = StackState<Int>([1, 2])
    stack.append(3)
    #expect(stack.count == 3)
    #expect(stack.last == 3)
  }

  @Test("popLast returns and removes top")
  func popLast() {
    var stack = StackState<Int>([1, 2, 3])
    let popped = stack.popLast()
    #expect(popped == 3)
    #expect(stack.count == 2)
    #expect(stack.last == 2)
  }

  @Test("removeAll empties the stack")
  func removeAll() {
    var stack = StackState<String>(["a", "b"])
    stack.removeAll()
    #expect(stack.isEmpty)
  }

  @Test("setElement replaces by index, ignores out-of-bounds")
  func setElement() {
    var stack = StackState<Int>([1, 2, 3])
    stack.setElement(99, at: 1)
    #expect(stack.elements == [1, 99, 3])
    stack.setElement(0, at: 100)  // out of bounds: no-op
    #expect(stack.elements == [1, 99, 3])
  }
}

@Suite("StackAction")
struct StackActionTests {
  enum ChildAction: Sendable, Equatable {
    case tap
  }

  @Test("Cases distinguish push, pop, popToRoot, element")
  func cases() {
    let push: StackAction<String, ChildAction> = .push("hello")
    let pop: StackAction<String, ChildAction> = .pop
    let popRoot: StackAction<String, ChildAction> = .popToRoot
    let elem: StackAction<String, ChildAction> = .element(index: 2, action: .tap)

    var pushCount = 0
    var popCount = 0
    var popRootCount = 0
    var elemCount = 0
    for action in [push, pop, popRoot, elem] {
      switch action {
      case .push: pushCount += 1
      case .pop: popCount += 1
      case .popToRoot: popRootCount += 1
      case .element: elemCount += 1
      }
    }
    #expect((pushCount, popCount, popRootCount, elemCount) == (1, 1, 1, 1))
  }
}
