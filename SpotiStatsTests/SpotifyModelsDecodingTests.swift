import XCTest
@testable import SpotiStats

/// Decoding tests against JSON fixtures. These pin the model shapes to Spotify's real responses,
/// so a future model change that breaks decoding fails loudly here instead of at runtime.
final class SpotifyModelsDecodingTests: XCTestCase {

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    func testDecodesTopTracksPage() throws {
        let page = try makeDecoder().decode(
            SpotifyPage<SpotifyTrack>.self,
            from: Data(SpotifyFixtures.topTracks.utf8)
        )
        XCTAssertEqual(page.items.count, 2)
        let first = page.items[0]
        XCTAssertEqual(first.name, "Sicko Mode")
        XCTAssertEqual(first.durationMs, 312820)
        XCTAssertTrue(first.explicit)
        XCTAssertEqual(first.album.name, "ASTROWORLD")
        XCTAssertEqual(first.album.images.first?.height, 640)
        XCTAssertEqual(first.artistNames, "Travis Scott")
        XCTAssertEqual(page.items[1].artistNames, "Travis Scott, Guest")
    }

    func testDecodesTopArtistsPage() throws {
        let page = try makeDecoder().decode(
            SpotifyPage<SpotifyArtist>.self,
            from: Data(SpotifyFixtures.topArtists.utf8)
        )
        XCTAssertEqual(page.items.count, 2)
        let artist = page.items[0]
        XCTAssertEqual(artist.name, "Travis Scott")
        XCTAssertEqual(artist.genres, ["rap", "hip hop"])
        XCTAssertEqual(artist.popularity, 95)
        XCTAssertEqual(artist.images.first?.url, "https://img/travis")
    }

    /// Live `/me/top/artists` responses sometimes omit `genres`/`popularity`/`images` entirely
    /// (seen in the field 2026-06-10) — one sparse artist must not fail the whole page.
    func testDecodesArtistWithMissingOptionalFields() throws {
        let page = try makeDecoder().decode(
            SpotifyPage<SpotifyArtist>.self,
            from: Data(SpotifyFixtures.topArtists.utf8)
        )
        let sparse = page.items[1]
        XCTAssertEqual(sparse.name, "Sparse Fields")
        XCTAssertEqual(sparse.genres, [])
        XCTAssertNil(sparse.popularity)
        XCTAssertEqual(sparse.images, [])
    }

    func testDecodesRecentlyPlayed() throws {
        let response = try makeDecoder().decode(
            RecentlyPlayedResponse.self,
            from: Data(SpotifyFixtures.recentlyPlayed.utf8)
        )
        XCTAssertEqual(response.items.count, 1)
        XCTAssertEqual(response.items[0].track.name, "Sicko Mode")
        XCTAssertEqual(response.items[0].playedAt, "2026-06-06T10:00:00.000Z")
    }

    func testTimeRangeQueryValuesAndLabels() {
        XCTAssertEqual(SpotifyTimeRange.shortTerm.queryValue, "short_term")
        XCTAssertEqual(SpotifyTimeRange.mediumTerm.queryValue, "medium_term")
        XCTAssertEqual(SpotifyTimeRange.longTerm.queryValue, "long_term")
        XCTAssertEqual(SpotifyTimeRange.longTerm.honestLabel, "Several years")
        XCTAssertEqual(SpotifyTimeRange.allCases.count, 3)
    }
}
