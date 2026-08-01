import XCTest
@testable import ObsidianSync

final class PairingQRCodeTests: XCTestCase {
    func testPayloadParserTrimsAndReturnsCanonicalID() throws {
        var received: String?
        let parser = DeviceIDPayloadParser { candidate in
            received = candidate
            return "CANONICAL-ID"
        }

        let result = try parser.parse("  scanned-device-id\n")

        XCTAssertEqual(received, "scanned-device-id")
        XCTAssertEqual(result, "CANONICAL-ID")
    }

    func testPayloadParserRejectsEmptyAndInvalidCodes() {
        let parser = DeviceIDPayloadParser { _ in
            throw CocoaError(.validationMissingMandatoryProperty)
        }

        XCTAssertThrowsError(try parser.parse("  \n")) { error in
            XCTAssertEqual(
                error.localizedDescription,
                DeviceIDPayloadError.empty.localizedDescription
            )
        }
        XCTAssertThrowsError(try parser.parse("https://example.com/not-a-device")) { error in
            XCTAssertEqual(
                error.localizedDescription,
                DeviceIDPayloadError.invalid.localizedDescription
            )
        }
    }

    func testQRCodeRendererProducesAVisibleImage() throws {
        let image = try XCTUnwrap(QRCodeRenderer.image(for: "SYNCTHING-DEVICE-ID"))

        XCTAssertGreaterThan(image.size.width, 100)
        XCTAssertGreaterThan(image.size.height, 100)
        XCTAssertEqual(image.size.width, image.size.height)
    }
}
