import Foundation
import Testing

@testable import SkipTCA

@MainActor
@Suite("ViewAction")
struct ViewActionTests {
  enum FeatureAction: Sendable, Equatable, ViewAction {
    enum ViewAction: Sendable, Equatable {
      case onAppear
      case retryTapped
    }
    case view(ViewAction)
    case loaded
  }

  @Test("Store.send(view:) wraps a view action in the parent .view case")
  func storeSendViewWraps() {
    let received = LockedBox<[FeatureAction]>([])
    let store = Store<Int, FeatureAction>(initialState: 0) { state, action in
      received.mutate { $0.append(action) }
      return .none
    }
    store.send(view: .onAppear)
    store.send(view: .retryTapped)
    #expect(received.value == [.view(.onAppear), .view(.retryTapped)])
  }

  @Test("ViewAction.view(_:) round-trips a nested view action")
  func roundTrip() {
    let action = FeatureAction.view(.onAppear)
    if case .view(let viewAction) = action {
      #expect(viewAction == .onAppear)
    } else {
      Issue.record("Expected .view case")
    }
  }
}
