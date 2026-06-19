import Foundation

// MARK: - Safe Subscript

extension Collection {
      /// Returns the element at the specified index if it is within bounds, otherwise `nil`.
      ///
      /// Use this instead of force-subscripting to avoid index-out-of-range crashes
      /// when working with dynamic data from the Spotify API.
      ///
      /// ```swift
      /// let tracks: [Track] = ...
      /// let third = tracks[safe: 2] // Track? instead of crash
      /// ```
      subscript(safe index: Index) -> Element? {
                indices.contains(index) ? self[index] : nil
      }
}

// MARK: - Array Convenience

extension Array where Element: Hashable {
      /// Returns the array with duplicate elements removed, preserving first-occurrence order.
      ///
      /// Useful for deduplicating play history entries that may appear more than once
      /// due to overlapping collection windows.
      func uniqued() -> [Element] {
                var seen: Set<Element> = []
                return filter { seen.insert($0).inserted }
      }
}

extension Array {
      /// Splits the array into chunks of the given size.
      ///
      /// The last chunk may contain fewer than `size` elements.
      /// Handy for batching API requests (e.g., fetching track details in groups of 50).
      ///
      /// ```swift
      /// let ids = ["a", "b", "c", "d", "e"]
      /// ids.chunked(into: 2) // [["a", "b"], ["c", "d"], ["e"]]
      /// ```
      func chunked(into size: Int) -> [[Element]] {
                guard size > 0 else { return [] }
                return stride(from: 0, to: count, by: size).map {
                              Array(self[$0..<Swift.min($0 + size, count)])
                }
      }
}

// MARK: - Optional Unwrap Helpers

extension Optional where Wrapped: Collection {
      /// Returns `true` if the optional is `nil` or the wrapped collection is empty.
      ///
      /// Reduces boilerplate in view models that guard against missing or empty data:
      /// ```swift
      /// if viewModel.recentPlays.isNilOrEmpty {
      ///     showEmptyState()
      /// }
      /// ```
      var isNilOrEmpty: Bool {
                self?.isEmpty ?? true
      }
}
