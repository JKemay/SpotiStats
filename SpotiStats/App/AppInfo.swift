import Foundation

/// App-level identity constants. The public-facing **display name** lives here (and in
/// `project.yml`'s `CFBundleDisplayName`) so a rebrand is a one-line change.
///
/// "SpotiStats" remains the internal codename (repo, Xcode project, bundle id
/// `com.spotistats.SpotiStats`, Supabase project ref) — those don't change. Spotify's branding
/// rules forbid public app names starting with "Spot" or containing "Spotify", so the shipping
/// name is "Nocturne" (a night-themed musical piece — fits the lo-fi night-city scene).
enum AppInfo {
    /// The user-facing app name shown in UI copy.
    static let name = "Nocturne"
}
