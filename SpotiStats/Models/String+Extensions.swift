import Foundation

// MARK: - String Utility Extensions

/// Convenience extensions used across the app for display formatting,
/// truncation, and text processing.
extension String {

      // MARK: - Truncation

      /// Returns the string truncated to `maxLength` characters with a trailing
      /// ellipsis if it exceeds the limit. Returns the original string if it fits.
      ///
      /// - Parameter maxLength: Maximum number of characters before truncation.
      /// - Returns: The (possibly truncated) string.
      func truncated(to maxLength: Int) -> String {
                guard count > maxLength, maxLength > 0 else { return self }
                let endIndex = index(startIndex, offsetBy: maxLength)
                return String(self[..<endIndex]) + "\u{2026}"
      }

      // MARK: - Whitespace Helpers

      /// A trimmed copy with leading and trailing whitespace and newlines removed.
      var trimmed: String {
                trimmingCharacters(in: .whitespacesAndNewlines)
      }

      /// `true` when the string is empty or contains only whitespace.
      var isBlank: Bool {
                trimmed.isEmpty
      }

      // MARK: - Display Formatting

      /// Formats a large number into a compact, human-readable string.
      ///
      /// Examples:
      /// - `"1234".compactNumber`       -> `"1.2K"`
      /// - `"1500000".compactNumber`    -> `"1.5M"`
      /// - `"999".compactNumber`        -> `"999"`
      ///
      /// Returns the original string if it cannot be parsed as an integer.
      var compactNumber: String {
                guard let value = Int(self) else { return self }
                return value.compactFormatted
      }

      /// Capitalizes only the first character, leaving the rest unchanged.
      ///
      /// Unlike `capitalized` (which title-cases every word), this only
      /// touches the very first character.
      var sentenceCased: String {
                guard let first = first else { return self }
                return first.uppercased() + dropFirst()
      }

      // MARK: - Artist / Track Name Helpers

      /// Strips common parenthetical suffixes from track names for cleaner display.
      ///
      /// Removes patterns like "(feat. ...)", "(Remastered ...)", "(Deluxe ...)",
      /// "[Bonus Track]", etc.
      var cleanedTrackName: String {
                let patterns = [
                              #"\s*[\(\[](?:feat\.|ft\.|featuring)\s+[^\)\]]+[\)\]]"#,
                                                                                  #"\s*[\(\[](?:Remaster(?:ed)?|Deluxe|Bonus Track|Live|Acoustic|Radio Edit|Single Version)[^\)\]]*[\)\]]"#,
                                                                                                                                                                           ]
                                                                              var result = self
                                                                              for pattern in patterns {
                                                                                            // swiftlint:disable:next force_try
                                                                                            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                                                                                            result = regex.stringByReplacingMatches(
                                                                                                              in: result,
                                                                                                              range: NSRange(result.startIndex..., in: result),
                                                                                                              withTemplate: ""
                                                                                            )
                                                                              }
                                                                              return result.trimmed
                                                                     }

                      /// Joins multiple artist names with commas and "&" before the last one.
                      ///
                      /// - Parameter artists: Array of artist name strings.
                      /// - Returns: A natural-language formatted artist list.
                      static func formattedArtistList(_ artists: [String]) -> String {
                                switch artists.count {
                                          case 0: return ""
                                          case 1: return artists[0]
                                          case 2: return "\(artists[0]) & \(artists[1])"
                                          default:
                                              let allButLast = artists.dropLast().joined(separator: ", ")
                                              return "\(allButLast) & \(artists.last!)"
                                }
                      }
                }

        // MARK: - Int Compact Formatting

        extension Int {

              /// Formats the integer into a compact human-readable string.
              ///
              /// - `999`       -> `"999"`
              /// - `1_200`     -> `"1.2K"`
              /// - `1_500_000` -> `"1.5M"`
              /// - `2_000_000_000` -> `"2B"`
              var compactFormatted: String {
                        let absValue = abs(self)
                        let sign = self < 0 ? "-" : ""

                        switch absValue {
                                  case 0..<1_000:
                                      return "\(sign)\(absValue)"
                                  case 1_000..<1_000_000:
                                      let thousands = Double(absValue) / 1_000.0
                                      return "\(sign)\(formatDecimal(thousands))K"
                                  case 1_000_000..<1_000_000_000:
                                      let millions = Double(absValue) / 1_000_000.0
                                      return "\(sign)\(formatDecimal(millions))M"
                                  default:
                                      let billions = Double(absValue) / 1_000_000_000.0
                                      return "\(sign)\(formatDecimal(billions))B"
                        }
              }

              private func formatDecimal(_ value: Double) -> String {
                        let formatted = String(format: "%.1f", value)
                        // Drop trailing ".0" for cleaner display
                        return formatted.hasSuffix(".0")
                            ? String(formatted.dropLast(2))
                            : formatted
              }
        }
