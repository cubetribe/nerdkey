import Foundation

/// Persisted license state written to license.json.
public struct LicenseState: Codable {
    public var schemaVersion: Int = 1
    public var licenseKey: String
    public var machineId: String
    public var fingerprint: String
    public var lastOnlineCheckAt: Date?
    public var lastOnlineCheckResult: String?
    public var cachedKeygenLicenseId: String?

    public init(
        licenseKey: String,
        machineId: String,
        fingerprint: String,
        lastOnlineCheckAt: Date? = nil,
        lastOnlineCheckResult: String? = nil,
        cachedKeygenLicenseId: String? = nil
    ) {
        self.licenseKey = licenseKey
        self.machineId = machineId
        self.fingerprint = fingerprint
        self.lastOnlineCheckAt = lastOnlineCheckAt
        self.lastOnlineCheckResult = lastOnlineCheckResult
        self.cachedKeygenLicenseId = cachedKeygenLicenseId
    }
}

/// Manages reading and writing license.json from the platform-appropriate location.
public struct LicenseStateStore {
    private let fileURL: URL

    public init(appSlug: String, stateDir: String? = nil) {
        if let override = stateDir {
            let dir = URL(fileURLWithPath: override, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            fileURL = dir.appendingPathComponent("license.json")
        } else {
            let baseDir = LicenseStateStore.defaultBaseDirectory(appSlug: appSlug)
            try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
            fileURL = baseDir.appendingPathComponent("license.json")
        }
    }

    private static func defaultBaseDirectory(appSlug: String) -> URL {
        #if os(macOS)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("nerdsmiths/\(appSlug)", isDirectory: true)
        #elseif os(Linux)
        let home = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"
        return URL(fileURLWithPath: "\(home)/.local/share/nerdsmiths/\(appSlug)", isDirectory: true)
        #else
        // Windows fallback (not reachable on Apple/Linux platforms this code targets)
        let appData = ProcessInfo.processInfo.environment["APPDATA"] ?? "/tmp"
        return URL(fileURLWithPath: "\(appData)/nerdsmiths/\(appSlug)", isDirectory: true)
        #endif
    }

    public func load() throws -> LicenseState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LicenseState.self, from: data)
    }

    public func save(_ state: LicenseState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    public func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    public var filePath: String { fileURL.path }
}
