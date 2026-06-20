import SwiftUI
import UIKit

/// A thin `UIViewControllerRepresentable` that presents `UIActivityViewController`
/// for sharing items (e.g. a PNG file URL). Used when `ShareLink` over a freshly-
/// rendered file URL needs a presentation context from within a `NavigationStack`.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
