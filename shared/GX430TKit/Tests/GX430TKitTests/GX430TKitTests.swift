import Foundation
import XCTest
@testable import GX430TKit

final class GX430TKitTests: XCTestCase {
    func testPrintKindContract() {
        XCTAssertEqual(
            GX430TPrintKind.allCases.map(\.rawValue),
            ["text", "code128", "code39", "qr"]
        )

        XCTAssertEqual(
            GX430TPrintKind.allCases.map(\.title),
            ["Text", "Code 128", "Code 39", "QR"]
        )
    }

    func testPrintRequestEncoding() throws {
        let request = GX430TPrintRequest(
            kind: .code128,
            value: "987654321",
            copies: 1
        )

        let data = try JSONEncoder().encode(request)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any]
        )

        XCTAssertEqual(
            object["kind"] as? String,
            "code128"
        )

        XCTAssertEqual(
            object["value"] as? String,
            "987654321"
        )

        XCTAssertEqual(
            (object["copies"] as? NSNumber)?.intValue,
            1
        )
    }

    func testQueueStateDecoding() throws {
        let json = """
        {
          "ok": true,
          "version": "0.3.3",
          "counts": {
            "queued": 1,
            "printed": 0,
            "error": 0
          },
          "jobs": [
            {
              "id": 7,
              "created": 1.0,
              "position": 1.0,
              "source_file": "queue.csv",
              "source_row": 2,
              "barcode": "987654321",
              "title": "987654321",
              "status": "queued",
              "printed": null,
              "last_error": null
            }
          ]
        }
        """

        let state = try JSONDecoder().decode(
            GX430TQueueState.self,
            from: Data(json.utf8)
        )

        XCTAssertTrue(state.ok)
        XCTAssertEqual(state.version, "0.3.3")
        XCTAssertEqual(state.counts.queued, 1)
        XCTAssertEqual(state.jobs.count, 1)
        XCTAssertEqual(state.jobs[0].id, "job-7")
        XCTAssertEqual(
            state.jobs[0].barcode,
            "987654321"
        )
    }
}
