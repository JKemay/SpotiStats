import SwiftUI

/// Renders a `LoadState<[Item]>` as the four screens every list needs: a spinner while loading,
/// an error with a retry button, a friendly empty state, and the themed list itself.
///
/// Centralizing this means each tab only describes its row — the lifecycle UI stays identical
/// across the app. Rows receive `(index, item)` because Spotify items aren't reliably
/// `Identifiable` (local tracks have nil ids), so position is the honest list identity here.
struct LoadableList<Item, Row: View>: View {
    let state: LoadState<[Item]>
    let emptyMessage: String
    let retry: () async -> Void
    @ViewBuilder let row: (Int, Item) -> Row

    var body: some View {
        switch state {
        case .idle, .loading:
            spinner
        case .failed(let message):
            StatusPanel(systemImage: "wifi.exclamationmark", message: message) {
                Button("Retry") {
                    Task { await retry() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.accent)
            }
        case .loaded(let items) where items.isEmpty:
            StatusPanel(systemImage: "music.note", message: emptyMessage) { EmptyView() }
        case .loaded(let items):
            list(items)
        }
    }

    private var spinner: some View {
        ProgressView()
            .tint(Theme.Colors.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func list(_ items: [Item]) -> some View {
        List {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                row(index, item)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.Colors.accent.opacity(0.15))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await retry() }
    }
}

/// A centered icon + message, optionally with an action below — shared by error and empty states.
struct StatusPanel<Action: View>: View {
    let systemImage: String
    let message: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.Colors.accent)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            action()
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
