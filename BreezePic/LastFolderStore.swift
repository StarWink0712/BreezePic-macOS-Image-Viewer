import Foundation

struct LastFolderStore {
    private static let key = "BreezePic.last-folder-bookmark"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ url: URL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: Self.key)
    }

    func resolve() throws -> (url: URL, isStale: Bool)? {
        guard let data = defaults.data(forKey: Self.key) else {
            return nil
        }

        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        return (url.standardizedFileURL, stale)
    }
}
