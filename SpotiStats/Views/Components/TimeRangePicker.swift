import SwiftUI

/// Segmented picker over Spotify's three affinity windows, labeled honestly (`honestLabel`
/// deliberately never says "all time"), with a caption that keeps the claim modest.
struct TimeRangePicker: View {
    @Binding var selection: SpotifyTimeRange

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Picker("Time range", selection: $selection) {
                ForEach(SpotifyTimeRange.allCases, id: \.self) { range in
                    Text(range.honestLabel).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selection) { _, _ in HapticManager.shared.selection() }

            Text("Spotify's listening windows — not lifetime totals.")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }
}
