import XCTest
@testable import CodexAppServerKit

final class CodexJSONValueTests: XCTestCase {
    func testDecodesRateLimitResponse() throws {
        let json = #"""
        {
          "rateLimits": {
            "limitId": "codex",
            "limitName": null,
            "primary": { "usedPercent": 25, "windowDurationMins": 15, "resetsAt": 1730947200 },
            "secondary": null,
            "rateLimitReachedType": null
          },
          "rateLimitsByLimitId": {
            "codex": {
              "limitId": "codex",
              "limitName": null,
              "primary": { "usedPercent": 25, "windowDurationMins": 15, "resetsAt": 1730947200 },
              "secondary": null,
              "rateLimitReachedType": null
            }
          }
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CodexRateLimitsReadResult.self, from: json)
        XCTAssertEqual(decoded.preferredBucket?.limitId, "codex")
        XCTAssertEqual(decoded.preferredBucket?.primary?.usedPercent, 25)
        XCTAssertEqual(decoded.preferredBucket?.primary?.windowDurationMins, 15)
        XCTAssertNotNil(decoded.preferredBucket?.primary?.resetDate)
    }

    func testJSONValueRoundTrip() throws {
        let value: CodexJSONValue = .object([
            "method": .string("account/read"),
            "id": .int(1),
            "params": .object(["refreshToken": .bool(false)])
        ])

        let data = try JSONEncoder.codexRPC.encode(value)
        let decoded = try JSONDecoder.codexRPC.decode(CodexJSONValue.self, from: data)
        XCTAssertEqual(decoded["method"]?.stringValue, "account/read")
        XCTAssertEqual(decoded["id"]?.intValue, 1)
        XCTAssertEqual(decoded["params"]?["refreshToken"]?.boolValue, false)
    }
}
