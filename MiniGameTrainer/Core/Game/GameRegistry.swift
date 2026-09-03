import Foundation

/// Single source of truth for the games available in the app. Adding a game = adding one line here.
@MainActor
enum GameRegistry {
    static let modules: [any MiniGameModule.Type] = [
        PianoGameModule.self,
        TrampboxGameModule.self,
        ReactGameModule.self,
        TowerStackGameModule.self,
        CenterHitGameModule.self,
        KeepUpGameModule.self,
        TimesUpGameModule.self,
    ]

    static var descriptors: [MiniGameDescriptor] {
        modules.map { $0.descriptor }
    }

    static func module(for gameID: String) -> (any MiniGameModule.Type)? {
        modules.first { $0.descriptor.id == gameID }
    }

    static func descriptor(for gameID: String) -> MiniGameDescriptor? {
        module(for: gameID)?.descriptor
    }
}
