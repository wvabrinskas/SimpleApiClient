import XCTest
@testable import SimpleApiClient

struct API: SimpleApiClient {
    
    func getScreen(completion: @escaping (Result<Screen?, Error>?) -> ()) {
        self.get(endpoint: "https://next.json-generator.com/api/json/get/VkjN2KyEd", completion: completion)
    }
}

struct Model: Decodable {
    var title: String
}

struct Screen: Decodable {
    var data: [Model]
}

final class SimpleApiClientTests: XCTestCase {
    func testGETApi() {
        let wait = XCTWaiter()
        let expectation = XCTestExpectation(description: "get")
        
        API().getScreen { result in
            switch result {
            case .success(let screen):
                guard let data = screen else {
                    XCTFail("Could not get Screen")
                    return
                }

                XCTAssert(data.data.count > 0, "No data")

                data.data.forEach { (model) in
                    XCTAssert(model.title == "UNIT_TEST", "Model not decoded properly")
                }

            case .failure(let error):
                XCTFail(error.localizedDescription)
            case .none:
                XCTFail("default")
            }
            expectation.fulfill()
        }
        wait.wait(for: [expectation], timeout: 10)
    }

    static var allTests = [
        ("testGETApi", testGETApi),
    ]
}
