import XCTest
@testable import MiniGameTrainer

@MainActor
final class LibraryPresentationTests: XCTestCase {
    func testRegisteredGamesUseTitleCaseSkillLabels() {
        XCTAssertEqual(GameRegistry.descriptors.count, 16)
        for descriptor in GameRegistry.descriptors {
            XCTAssertFalse(descriptor.skills.isEmpty, descriptor.name)
            for skill in descriptor.skills {
                for word in skill.split(whereSeparator: { $0 == " " || $0 == "·" }) {
                    XCTAssertFalse(word.isEmpty, descriptor.name)
                    XCTAssertTrue(word.first?.isUppercase == true, "\(descriptor.name) skill '\(skill)'")
                }
            }
        }
    }
}
