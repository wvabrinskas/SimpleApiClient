import XCTest
import Combine
@testable import SimpleApiClient

struct API: SimpleApiClient {
  static var authorizationHeaders: [String : String]?
  private let endpoint = "http://echo.jsontest.com/test/test/key/value"
  
  func getScreen(completion: @escaping (Result<Model?, Error>?) -> ()) {
    self.get(endpoint: endpoint, completion: completion)
  }
  
  func getScreen() -> AnyPublisher<Result<Model?, Error>, Error> {
    self.get(endpoint: endpoint)
  }
  
  func getScreen() async -> Result<Model?, Error> {
    await self.get(endpoint: endpoint)
  }
}

struct Model: Decodable {
  var test: String
  var key: String
}

final class SimpleApiClientTests: XCTestCase {
  func testGETApi() {
    let wait = XCTWaiter()
    let expectation = XCTestExpectation(description: "get")
    
    API().getScreen { result in
      self.checkModel(result: result)
      expectation.fulfill()
    }
    wait.wait(for: [expectation], timeout: 10)
  }
  
  func testAsyncAwaitGETApi() async {
    let result = await API().getScreen()
    self.checkModel(result: result)
  }
  
  func testPublisherGETApi() {
    let wait = XCTWaiter()
    let expectation = XCTestExpectation(description: "get")
    
    var cancellables: Set<AnyCancellable> = []
    API().getScreen()
      .sink { _ in
      } receiveValue: { model in
        self.checkModel(result: model)
        expectation.fulfill()
      }
      .store(in: &cancellables)
    
    wait.wait(for: [expectation], timeout: 10)
  }
  
  static var allTests = [
    ("testGETApi", testGETApi),
  ]
  
  private func checkModel(result: Result<Model?, Error>?) {
    switch result {
    case .success(let screen):
      guard let model = screen else {
        XCTFail("Could not get Screen")
        return
      }
      
      XCTAssert(model.test == "test")
      XCTAssert(model.key == "value")
    case .failure(let error):
      XCTFail(error.localizedDescription)
    case .none:
      XCTFail("default")
    }
  }
}
