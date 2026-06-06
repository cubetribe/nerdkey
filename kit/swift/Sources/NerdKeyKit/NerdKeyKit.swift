import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Configuration for the NerdKey SDK.
public struct NerdKeyConfig {
    /// Keygen CE base URL (default: https://nerdkey.localhost).
    public var baseURL: String
    /// Keygen account ID (default: embedded constant).
    public var accountId: String
    /// Skip TLS certificate verification (useful for self-signed / local certs).
    public var tlsSkipVerify: Bool
    /// App slug used for license.json storage path.
    public var appSlug: String
    /// Override the state directory (used for testing with multiple fingerprints).
    public var stateDirOverride: String?

    public init(
        baseURL: String = NerdKeyConstants.defaultBaseURL,
        accountId: String = NerdKeyConstants.accountId,
        tlsSkipVerify: Bool = true,
        appSlug: String = "default",
        stateDirOverride: String? = nil
    ) {
        self.baseURL = baseURL
        self.accountId = accountId
        self.tlsSkipVerify = tlsSkipVerify
        self.appSlug = appSlug
        self.stateDirOverride = stateDirOverride
    }
}

/// Main SDK entry point.
public final class NerdKey {

    private let config: NerdKeyConfig
    private let store: LicenseStateStore
    private let verifier: Ed25519Verifier
    private let client: KeygenClient

    public init(config: NerdKeyConfig = NerdKeyConfig()) throws {
        self.config = config
        self.store = LicenseStateStore(appSlug: config.appSlug, stateDir: config.stateDirOverride)
        self.verifier = try Ed25519Verifier()
        self.client = try KeygenClient(
            baseURL: config.baseURL,
            accountId: config.accountId,
            tlsSkipVerify: config.tlsSkipVerify
        )
    }

    // MARK: - Public API

    /// Activate a license key on this machine.
    ///
    /// - Verifies the Ed25519 signature offline first.
    /// - Calls Keygen to validate and register this machine.
    /// - Persists license.json.
    /// - Idempotent: if already activated with the same fingerprint, succeeds immediately.
    ///
    /// - Parameter licenseKey: The full `key/<payload>.<sig>` string.
    /// - Returns: The machine ID assigned by Keygen.
    @discardableResult
    public func activate(licenseKey: String) async throws -> String {
        // 1. Offline Ed25519 verification
        do {
            try verifier.verify(licenseKey: licenseKey)
        } catch Ed25519Verifier.VerificationError.signatureInvalid {
            throw NerdKeyError.invalidSignature
        } catch {
            throw NerdKeyError.invalidLicense(detail: "key structure error: \(error)")
        }

        let fingerprint = MachineFingerprint.current()
        let platform = platformString()
        let hostname = ProcessInfo.processInfo.hostName

        // 2. Check if already activated (idempotent path)
        if let existing = try? store.load(),
           existing.licenseKey == licenseKey,
           existing.fingerprint == fingerprint {
            return existing.machineId
        }

        // 3. Online validate-key to obtain the license ID
        let validateResponse = try await client.validateKey(licenseKey: licenseKey, fingerprint: fingerprint)

        let licenseId: String
        if let data = validateResponse.data {
            // May be valid=false because not yet activated — that's fine; we have the id
            licenseId = data.id
        } else {
            throw NerdKeyError.invalidLicense(detail: "validate-key returned no data")
        }

        // Check for revoked / expired status from server
        if let status = validateResponse.data?.attributes.status {
            if status == "REVOKED" || status == "SUSPENDED" { throw NerdKeyError.revoked }
            if status == "EXPIRED" { throw NerdKeyError.expired }
        }

        // 4. Activate machine
        let machineResponse = try await client.activateMachine(
            licenseKey: licenseKey,
            licenseId: licenseId,
            fingerprint: fingerprint,
            platform: platform,
            name: hostname
        )
        let machineId = machineResponse.data.id

        // 5. Persist
        let state = LicenseState(
            licenseKey: licenseKey,
            machineId: machineId,
            fingerprint: fingerprint,
            lastOnlineCheckAt: Date(),
            lastOnlineCheckResult: "ACTIVE",
            cachedKeygenLicenseId: licenseId
        )
        try store.save(state)

        return machineId
    }

    /// Validate the license on every app launch.
    ///
    /// Flow:
    /// 1. Load license.json — throw `notActivated` if missing.
    /// 2. Offline Ed25519 verify — throw `invalidSignature` if bad.
    /// 3. If `lastOnlineCheckAt` is nil or older than REFRESH_DAYS, do an online check.
    ///    - Online success → update timestamp, return.
    ///    - Online fail with `valid=false` and code REVOKED → throw `revoked`.
    ///    - Online fail with `valid=false` and code EXPIRED → throw `expired`.
    ///    - Network error → check grace window.
    /// 4. Otherwise return without network call.
    public func validateOnLaunch() async throws {
        guard let state = try store.load() else {
            throw NerdKeyError.notActivated
        }

        // Offline signature check
        do {
            try verifier.verify(licenseKey: state.licenseKey)
        } catch Ed25519Verifier.VerificationError.signatureInvalid {
            throw NerdKeyError.invalidSignature
        } catch {
            throw NerdKeyError.invalidLicense(detail: "\(error)")
        }

        // Determine if we need an online refresh
        let needsOnlineCheck: Bool = {
            guard let last = state.lastOnlineCheckAt else { return true }
            let age = Date().timeIntervalSince(last)
            return age > Double(NerdKeyConstants.refreshDays * 86400)
        }()

        guard needsOnlineCheck else { return }

        // Attempt online check
        do {
            let response = try await client.validateKey(licenseKey: state.licenseKey, fingerprint: state.fingerprint)
            if response.meta.valid == false {
                let code = response.meta.code ?? ""
                let detail = response.meta.detail ?? code
                let upperCode = code.uppercased()
                // Revoked or suspended
                if upperCode.contains("REVOKED") || upperCode.contains("SUSPENDED")
                    || response.data?.attributes.status == "REVOKED"
                    || response.data?.attributes.status == "SUSPENDED"
                    || upperCode == "NOT_FOUND" {
                    throw NerdKeyError.revoked
                }
                if upperCode.contains("EXPIRED") || response.data?.attributes.status == "EXPIRED" {
                    throw NerdKeyError.expired
                }
                throw NerdKeyError.invalidLicense(detail: detail)
            }
            // Success — update timestamp
            var updated = state
            updated.lastOnlineCheckAt = Date()
            updated.lastOnlineCheckResult = "VALID"
            try store.save(updated)

        } catch let nkErr as NerdKeyError {
            throw nkErr
        } catch {
            // Network failure — apply grace window
            if let last = state.lastOnlineCheckAt {
                let elapsed = Date().timeIntervalSince(last)
                let graceSecs = Double(NerdKeyConstants.graceDays * 86400)
                if elapsed <= graceSecs {
                    throw NerdKeyError.networkErrorWithinGrace(lastCheckAt: last)
                } else {
                    throw NerdKeyError.networkErrorGraceExpired(lastCheckAt: last)
                }
            } else {
                // Never had a successful check and network is down
                throw NerdKeyError.networkErrorGraceExpired(lastCheckAt: Date.distantPast)
            }
        }
    }

    /// Deactivate this machine and delete license.json.
    ///
    /// Idempotent: if no license.json exists, returns without error.
    public func deactivate() async throws {
        guard let state = try store.load() else { return }
        do {
            try await client.deactivateMachine(licenseKey: state.licenseKey, machineId: state.machineId)
        } catch let httpErr as HTTPError {
            // 404 means already deleted — treat as idempotent success
            if httpErr.statusCode != 404 {
                throw httpErr
            }
        }
        store.delete()
    }

    // MARK: - Helpers

    private func platformString() -> String {
        #if os(macOS)
        return "macOS"
        #elseif os(Linux)
        return "Linux"
        #elseif os(Windows)
        return "Windows"
        #else
        return "Unknown"
        #endif
    }
}
