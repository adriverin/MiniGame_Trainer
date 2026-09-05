import XCTest
@testable import MiniGameTrainer

final class JumpyGestureTests: XCTestCase {
    func testShortGestureIsTapForward() {
        XCTAssertEqual(JumpyGestureInterpreter.move(from: .zero, to: CGPoint(x: 10, y: 10), threshold: 24), .up)
    }
    func testDominantHorizontalSwipes() {
        XCTAssertEqual(JumpyGestureInterpreter.move(from: .zero, to: CGPoint(x: -30, y: 8), threshold: 24), .left)
        XCTAssertEqual(JumpyGestureInterpreter.move(from: .zero, to: CGPoint(x: 30, y: 8), threshold: 24), .right)
    }
    func testDominantVerticalSwipesAndTie() {
        XCTAssertEqual(JumpyGestureInterpreter.move(from: .zero, to: CGPoint(x: 8, y: 30), threshold: 24), .up)
        XCTAssertEqual(JumpyGestureInterpreter.move(from: .zero, to: CGPoint(x: 8, y: -30), threshold: 24), .down)
        XCTAssertEqual(JumpyGestureInterpreter.move(from: .zero, to: CGPoint(x: -30, y: -30), threshold: 24), .down)
    }
    func testRecognizedSwipeProducesSingleMovementCommand() {
        let move = JumpyGestureInterpreter.move(from: .zero, to: CGPoint(x: -40, y: 2), threshold: 24)
        XCTAssertEqual(move, .left)
        XCTAssertNotEqual(move, .up)
    }
}
