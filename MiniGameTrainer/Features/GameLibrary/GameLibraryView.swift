import SwiftUI

struct LibraryContinueSelection: Equatable {
    let descriptor: MiniGameDescriptor
    let hasHistory: Bool
}

enum LibraryPresentation {
    static func continueSelection(
        descriptors: [MiniGameDescriptor],
        statistics: [String: GameStatistics]
    ) -> LibraryContinueSelection? {
        let mostRecent = descriptors.compactMap { descriptor -> (MiniGameDescriptor, Date)? in
            guard let date = statistics[descriptor.id]?.lastPlayed else { return nil }
            return (descriptor, date)
        }
        .max { lhs, rhs in lhs.1 < rhs.1 }

        if let mostRecent {
            return LibraryContinueSelection(descriptor: mostRecent.0, hasHistory: true)
        }

        guard let starter = descriptors.first(where: { $0.id == GamePresentationCatalog.starterGameID })
            ?? descriptors.first else { return nil }
        return LibraryContinueSelection(descriptor: starter, hasHistory: false)
    }

    static func columnCount(accessibilityText: Bool) -> Int {
        accessibilityText ? 1 : 2
    }
}

/// Retention-first library: one quick return path followed by a dense, scalable catalog.
struct GameLibraryView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.md, alignment: .top),
            count: LibraryPresentation.columnCount(accessibilityText: dynamicTypeSize.isAccessibilitySize)
        )
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
            if let selection = LibraryPresentation.continueSelection(
                descriptors: GameRegistry.descriptors,
                statistics: statistics.statistics
            ) {
                section(title: selection.hasHistory ? "Continue" : "Start training") {
                    ContinueGameCard(
                        descriptor: selection.descriptor,
                        statistics: statistics.statistics(for: selection.descriptor.id),
                        hasHistory: selection.hasHistory,
                        onPlay: { router.showIntro(for: selection.descriptor.id) }
                    )
                }
            }

            section(title: "All Games", detail: "\(GameRegistry.descriptors.count) ways to improve") {
                LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.md) {
                    ForEach(GameRegistry.descriptors) { descriptor in
                        GameCardView(
                            descriptor: descriptor,
                            statistics: statistics.statistics(for: descriptor.id),
                            onPlay: { router.showIntro(for: descriptor.id) }
                        )
                    }
                }
            }
        }
    }

    private func section<Content: View>(
        title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppTheme.Fonts.heading)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            content()
        }
    }
}
