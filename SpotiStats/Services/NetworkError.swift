import Foundation

/// Structured error type for network and Spotify API failures.
///
/// Provides user-facing descriptions alongside the underlying technical detail,
/// making it easy for view models to display appropriate messages without
/// parsing raw error strings.
enum NetworkError: LocalizedError, Equatable {

    // MARK: - Transport

    /// The device appears to be offline.
    case noConnection

    /// The request timed out before a response was received.
    case timeout

    // MARK: - HTTP

    /// The server returned a non-success status code.
    case httpError(statusCode: Int)

    /// The Spotify access token has expired or been revoked.
    case unauthorized

    /// The app has exceeded the Spotify API rate limit.
    case rateLimited(retryAfterSeconds: Int?)

    // MARK: - Decoding

    /// The response body could not be decoded into the expected model.
    case decodingFailed(underlyingMessage: String)

    // MARK: - Generic

    /// A catch-all for errors that don't fit the categories above.
    case unknown(message: String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection. Check your Wi-Fi or cellular data and try again."
        case .timeout:
            return "The request took too long. Please try again."
        case .httpError(let statusCode):
            return "Server error (HTTP \(statusCode)). Please try again later."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Too many requests. Try again in \(seconds) seconds."
            }
            return "Too many requests. Please wait a moment and try again."
        case .decodingFailed:
            return "Something went wrong reading the response. Please try again."
        case .unknown(let message):
            return message.isEmpty ? "An unexpected error occurred." : message
        }
    }

    // MARK: - Helpers

    /// Whether the error is likely transient and worth retrying automatically.
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .rateLimited:
            return true
        case .httpError(let code):
            return code >= 500
        case .unauthorized, .decodingFailed, .unknown:
            return false
        }
    }

    /// Maps a URL-session / Foundation networking error into a `NetworkError`.
    static func from(_ error: Error) -> NetworkError {
        let nsError = error as NSError

        switch nsError.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorDataNotAllowed:
            return .noConnection
        case NSURLErrorTimedOut:
            return .timeout
        default:
            return .unknown(message: error.localizedDescription)
        }
    }
}
