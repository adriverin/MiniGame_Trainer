import XCTest
@testable import MiniGameTrainer

@MainActor
final class LibraryPresentationTests: XCTestCase {
    func testRegisteredGamesUseTitleCaseSkillLabels() {
        XCTAssertEqual(GameRegistry.descriptors.count, 19)
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

    func testEveryRegisteredGameHasAUniqueExplicitThemeAndConcisePresentation() {
        let descriptors = GameRegistry.descriptors
        XCTAssertEqual(GamePresentationCatalog.mappedGameIDs, Set(descriptors.map(\.id)))
        XCTAssertEqual(Set(descriptors.map { GamePresentationCatalog.theme(for: $0.id).id }).count, descriptors.count)

        for descriptor in descriptors {
            let theme = GamePresentationCatalog.theme(for: descriptor.id)
            let presentation = GamePresentationCatalog.presentation(for: descriptor)
            XCTAssertEqual(theme.id, descriptor.id)
            XCTAssertFalse(presentation.primaryRule.isEmpty)
            XCTAssertTrue((2...4).contains(presentation.instructions.count), descriptor.name)
        }
    }

    func testUnknownFutureGameGetsSafeFallbackThemeAndCopy() {
        let descriptor = MiniGameDescriptor(
            id: "futureGame",
            name: "Future Game",
            subtitle: "A future rule.",
            instructions: "A future instruction.",
            iconName: "sparkles",
            difficulty: .easy,
            skills: ["Focus"]
        )
        XCTAssertEqual(GamePresentationCatalog.theme(for: descriptor.id).id, "fallback")
        XCTAssertEqual(GamePresentationCatalog.presentation(for: descriptor).primaryRule, descriptor.subtitle)
    }

    func testFreshLibraryUsesDeterministicPianoStarter() {
        let selection = LibraryPresentation.continueSelection(
            descriptors: GameRegistry.descriptors,
            statistics: [:]
        )
        XCTAssertEqual(selection?.descriptor.id, "piano")
        XCTAssertEqual(selection?.hasHistory, false)
    }

    func testContinueResolvesMostRecentlyPlayedGame() {
        var piano = GameStatistics(gameID: "piano")
        piano.record(GameResult(gameID: "piano", score: 8, date: Date(timeIntervalSince1970: 100), duration: 1))
        var react = GameStatistics(gameID: "react")
        react.record(GameResult(
            gameID: "react",
            score: 340,
            scorePresentation: .reactionMilliseconds,
            date: Date(timeIntervalSince1970: 200),
            duration: 1
        ))

        let selection = LibraryPresentation.continueSelection(
            descriptors: GameRegistry.descriptors,
            statistics: ["piano": piano, "react": react]
        )
        XCTAssertEqual(selection?.descriptor.id, "react")
        XCTAssertEqual(selection?.hasHistory, true)
    }

    func testGridFallsBackToOneColumnForAccessibilityText() {
        XCTAssertEqual(LibraryPresentation.columnCount(accessibilityText: false), 2)
        XCTAssertEqual(LibraryPresentation.columnCount(accessibilityText: true), 1)
    }

    func testPersonalBestUsesDescriptorFormatting() {
        let react = GameRegistry.descriptor(for: "react")!
        let centerHit = GameRegistry.descriptor(for: "centerHit")!
        XCTAssertEqual(react.scorePresentation.formatted(350), "350 ms")
        XCTAssertEqual(centerHit.scorePresentation.formatted(9896), "98.96%")
    }
}
