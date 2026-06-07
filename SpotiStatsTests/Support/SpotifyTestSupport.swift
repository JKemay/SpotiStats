import Foundation
@testable import SpotiStats

enum TestError: Error {
    case badResponse
}

/// Builds an `HTTPURLResponse` without force-unwrapping (keeps SwiftLint `--strict` happy).
func makeHTTPResponse(
    url: URL?,
    status: Int,
    headers: [String: String] = [:]
) throws -> HTTPURLResponse {
    guard let url,
          let response = HTTPURLResponse(
              url: url,
              statusCode: status,
              httpVersion: "HTTP/1.1",
              headerFields: headers
          ) else {
        throw TestError.badResponse
    }
    return response
}

/// A configurable stub token provider that records how many times a refresh was requested.
final class StubTokenProvider: SpotifyTokenProviding {
    private(set) var current: String
    private let refreshed: String
    private(set) var refreshCallCount = 0

    init(current: String = "tok-initial", refreshed: String = "tok-refreshed") {
        self.current = current
        self.refreshed = refreshed
    }

    func accessToken() async throws -> String { current }

    func refreshedAccessToken() async throws -> String {
        refreshCallCount += 1
        current = refreshed
        return refreshed
    }
}

/// Inline JSON fixtures mirroring real Spotify response shapes (snake_case on purpose).
enum SpotifyFixtures {
    static let topTracks = """
    {
      "items": [
        {
          "id": "track1",
          "name": "Sicko Mode",
          "duration_ms": 312820,
          "explicit": true,
          "artists": [{ "id": "art1", "name": "Travis Scott" }],
          "album": {
            "name": "ASTROWORLD",
            "images": [{ "url": "https://img/astroworld", "height": 640, "width": 640 }]
          }
        },
        {
          "id": "track2",
          "name": "Serenade",
          "duration_ms": 200000,
          "explicit": false,
          "artists": [
            { "id": "art1", "name": "Travis Scott" },
            { "id": "art2", "name": "Guest" }
          ],
          "album": { "name": "Singles", "images": [] }
        }
      ]
    }
    """

    static let topArtists = """
    {
      "items": [
        {
          "id": "art1",
          "name": "Travis Scott",
          "genres": ["rap", "hip hop"],
          "popularity": 95,
          "images": [{ "url": "https://img/travis", "height": 640, "width": 640 }]
        }
      ]
    }
    """

    static let recentlyPlayed = """
    {
      "items": [
        {
          "track": {
            "id": "track1",
            "name": "Sicko Mode",
            "duration_ms": 312820,
            "explicit": true,
            "artists": [{ "id": "art1", "name": "Travis Scott" }],
            "album": { "name": "ASTROWORLD", "images": [] }
          },
          "played_at": "2026-06-06T10:00:00.000Z"
        }
      ]
    }
    """
}
