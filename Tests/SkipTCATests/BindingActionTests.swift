import Foundation
import Testing

@testable import SkipTCA

@Suite("BindingAction")
struct BindingActionTests {
  struct Form: Sendable, Equatable {
    var name: String = ""
    var age: Int = 0
  }

  @Test("BindingAction(closure) mutates the field it captures")
  func closureBased() {
    var form = Form()
    let setName = BindingAction<Form> { $0.name = "Alice" }
    setName.apply(to: &form)
    #expect(form.name == "Alice")
  }

  @Test("BindingAction.set(_:to:) updates by KeyPath (iOS only path)")
  func keyPathBased() {
    var form = Form()
    let setAge = BindingAction<Form>.set(\.age, to: 42)
    setAge.apply(to: &form)
    #expect(form.age == 42)
  }

  @Test("BindableAction.binding wraps a BindingAction in the case")
  func bindableActionRoundTrip() {
    enum Action: BindableAction, Sendable {
      typealias State = Form
      case binding(BindingAction<Form>)
      case other
    }
    let bind = Action.binding(BindingAction { $0.name = "Bob" })
    if case .binding(let inner) = bind {
      var f = Form()
      inner.apply(to: &f)
      #expect(f.name == "Bob")
    } else {
      Issue.record("Expected .binding case")
    }
  }
}
