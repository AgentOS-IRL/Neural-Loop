import Foundation

final class MockStreamingURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let headers: [String: String]
        let chunks: [Data]
        let error: Error?

        init(
            statusCode: Int = 200,
            headers: [String: String] = ["Content-Type": "text/event-stream"],
            chunks: [Data] = [],
            error: Error? = nil
        ) {
            self.statusCode = statusCode
            self.headers = headers
            self.chunks = chunks
            self.error = error
        }
    }

    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> Stub)?
    nonisolated(unsafe) static var capturedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.capturedRequests.append(request)

        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let stub = try handler(request)
            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }

            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for chunk in stub.chunks {
                client?.urlProtocol(self, didLoad: chunk)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() {
        requestHandler = nil
        capturedRequests = []
    }
}
