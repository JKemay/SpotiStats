import Foundation

/// The lifecycle of any asynchronously loaded value, as one value the UI can switch over.
///
/// Modeling load state as a single enum (instead of separate `isLoading` / `error` / `items`
/// properties) makes illegal combinations unrepresentable — a screen can't be "loading" and
/// "failed" at once. The failure case carries a user-facing message, not the raw `Error`,
/// so views never have to interpret transport errors themselves.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    /// The loaded value, if any — convenient for views that only care about content.
    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

extension LoadState: Equatable where Value: Equatable {}

/// Translates thrown errors into short, honest, user-facing messages.
///
/// Centralized so every screen fails with the same wording, and so raw `URLError` /
/// `SpotifyAPIError` details never leak into the UI.
enum UserFacingError {
    static func message(for error: Error) -> String {
        switch error {
        case let urlError as URLError:
            return message(for: urlError)
        case SpotifyAPIError.unauthorized:
            return "Your Spotify session expired. Try signing out and back in."
        case SpotifyAPIError.rateLimited:
            return "Spotify is busy right now. Give it a moment, then retry."
        case let SpotifyAPIError.http(status):
            return "Spotify returned an error (HTTP \(status)). Please retry."
        case is DecodingError:
            return "Spotify sent something we couldn't read. Please retry."
        default:
            return error.localizedDescription
        }
    }

    private static func message(for urlError: URLError) -> String {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return "You're offline. Check your connection and retry."
        case .timedOut:
            return "The request timed out. Please retry."
        default:
            return "A network error occurred. Please retry."
        }
    }
}
