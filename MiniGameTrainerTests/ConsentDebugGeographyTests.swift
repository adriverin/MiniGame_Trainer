import XCTest
@testable import MiniGameTrainer

#if DEBUG
@MainActor
final class ConsentDebugGeographyTests: XCTestCase {
    func testOtherMapsToNoRegulationGeography() {
        XCTAssertEqual(ConsentManager.DebugGeography.parse("other"), .other)
        XCTAssertEqual(ConsentManager.DebugGeography.parse("notrequired"), .other)
        XCTAssertEqual(ConsentManager.DebugGeography.parse("OTHER"), .other)
    }

    func testDisabledStaysDisabled() {
        XCTAssertEqual(ConsentManager.DebugGeography.parse("disabled"), .disabled)
        XCTAssertNotEqual(ConsentManager.DebugGeography.parse("other"), .disabled)
        XCTAssertNotEqual(ConsentManager.DebugGeography.parse("notrequired"), .disabled)
    }

    func testEEAAndRegulatedAliases() {
        XCTAssertEqual(ConsentManager.DebugGeography.parse("eea"), .eea)
        XCTAssertEqual(ConsentManager.DebugGeography.parse("regulated"), .regulatedUSState)
    }

    func testUnknownValueIsIgnored() {
        XCTAssertNil(ConsentManager.DebugGeography.parse("unknown"))
        XCTAssertNil(ConsentManager.DebugGeography.parse(""))
    }

    func testOtherAndDisabledBindToDifferentUMPValues() {
        XCTAssertNotEqual(
            ConsentManager.DebugGeography.other.umpGeography,
            ConsentManager.DebugGeography.disabled.umpGeography
        )
    }
}
#endif
