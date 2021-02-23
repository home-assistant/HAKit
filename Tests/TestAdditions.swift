import Foundation
import HAWebSocket

internal extension Array {
    enum GetError: Error {
        case outOfRange(offset: Int, count: Int)
    }

    func get(throwing offset: Int) throws -> Element {
        if count > offset {
            return self[offset]
        } else {
            throw GetError.outOfRange(offset: offset, count: count)
        }
    }
}

internal extension HAData {
    init(testJsonString jsonString: String) {
        self.init(value: try? JSONSerialization.jsonObject(
            with: jsonString.data(using: .utf8)!,
            options: .allowFragments
        ))
    }
}

internal extension HAConnectionConfiguration {
    static var test: Self {
        let url = URL(string: "https://example.com")!
        let accessToken: String = UUID().uuidString

        return .init(
            connectionInfo: { .init(url: url) },
            fetchAuthToken: { $0(.success(accessToken)) }
        )
    }
}
