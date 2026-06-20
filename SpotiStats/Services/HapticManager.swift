import UIKit

/// Centralised haptic feedback manager for Nocturne.
///
/// Wraps UIKit's feedback generators behind a thin, mockable interface so
/// views can trigger haptics with a single call (e.g. `HapticManager.shared.impact(.light)`).
/// Generators are lazily prepared on first use and re-prepared after each trigger
/// to keep latency low.
///
/// Usage:
/// ```swift
/// HapticManager.shared.impact(.medium)
/// HapticManager.shared.notification(.success)
/// HapticManager.shared.selection()
/// ```
final class HapticManager: @unchecked Sendable {

      // MARK: - Singleton

      /// Shared instance used throughout the app.
      static let shared = HapticManager()

      // MARK: - Generators

      private let lightImpact = UIImpactFeedbackGenerator(style: .light)
      private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
      private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
      private let softImpact = UIImpactFeedbackGenerator(style: .soft)
      private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
      private let selectionGenerator = UISelectionFeedbackGenerator()
      private let notificationGenerator = UINotificationFeedbackGenerator()

      // MARK: - Init

      private init() {
                prepareAll()
      }

      // MARK: - Impact

      /// Triggers an impact haptic with the given style.
      ///
      /// - Parameters:
      ///   - style: The impact feedback style (`.light`, `.medium`, `.heavy`, `.soft`, `.rigid`).
      ///   - intensity: Optional intensity override (0.0 to 1.0). Defaults to `nil` (system default).
      func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat? = nil) {
                let generator = generator(for: style)
                if let intensity {
                              generator.impactOccurred(intensity: intensity)
                } else {
                              generator.impactOccurred()
                }
                generator.prepare()
      }

      // MARK: - Selection

      /// Triggers a light selection haptic, ideal for picker changes or toggle switches.
      func selection() {
                selectionGenerator.selectionChanged()
                selectionGenerator.prepare()
      }

      // MARK: - Notification

      /// Triggers a notification haptic for success, warning, or error feedback.
      ///
      /// - Parameter type: The notification type (`.success`, `.warning`, `.error`).
      func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
                notificationGenerator.notificationOccurred(type)
                notificationGenerator.prepare()
      }

      // MARK: - Convenience

      /// Light tap — use for subtle UI interactions (e.g. toggling a heart icon).
      func tap() {
                impact(.light)
      }

      /// Success notification — use after completing an action (e.g. sharing a stat card).
      func success() {
                notification(.success)
      }

      /// Error notification — use when an action fails (e.g. network error).
      func error() {
                notification(.error)
      }

      // MARK: - Private Helpers

      private func generator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
                switch style {
                          case .light:  return lightImpact
                          case .medium: return mediumImpact
                          case .heavy:  return heavyImpact
                          case .soft:   return softImpact
                          case .rigid:  return rigidImpact
                          @unknown default: return mediumImpact
                }
      }

      private func prepareAll() {
                lightImpact.prepare()
                mediumImpact.prepare()
                heavyImpact.prepare()
                softImpact.prepare()
                rigidImpact.prepare()
                selectionGenerator.prepare()
                notificationGenerator.prepare()
      }
}

// MARK: - Protocol for Testing

/// Protocol that mirrors HapticManager's public API, enabling dependency injection
/// and mocking in unit tests.
protocol HapticProviding: Sendable {
      func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat?)
      func selection()
      func notification(_ type: UINotificationFeedbackGenerator.FeedbackType)
      func tap()
      func success()
      func error()
}

extension HapticManager: HapticProviding {}
