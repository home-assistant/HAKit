import Foundation
import XCTest

internal class StubbingURLProtocol: URLProtocol {
    typealias PendingResult = Result<(HTTPURLResponse, Data?), Error>
    private static var pending = [URL: PendingResult]()
    static var received = [URL: URLRequest]()

    class func register(
        _ url: URL,
        result: PendingResult
    ) {
        pending[url] = result
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        // default implementation asserts
        request
    }

    override func startLoading() {
        guard let url = request.url, let result = Self.pending.removeValue(forKey: url) else {
            XCTFail("unexpected request: \(request)")
            return
        }

        guard let client = client else {
            XCTFail("unable to complete")
            return
        }

        Self.received[url] = request

        switch result {
        case let .success((response, data)):
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client.urlProtocol(self, didLoad: data)
            }
            client.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
