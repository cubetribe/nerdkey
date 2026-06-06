import Foundation

/// All errors that NerdKeyKit can throw.
public enum NerdKeyError: Error, CustomStringConvertible {
    /// No license has been activated on this machine yet.
    case notActivated
    /// The license has reached its seat (machine) limit.
    case seatLimitExceeded
    /// The license has expired.
    case expired
    /// The license has been revoked by the server.
    case revoked
    /// Network unavailable but within the grace window — app may continue.
    case networkErrorWithinGrace(lastCheckAt: Date)
    /// Network unavailable and grace window has elapsed — block the app.
    case networkErrorGraceExpired(lastCheckAt: Date)
    /// The offline Ed25519 signature on the license key is invalid.
    case invalidSignature
    /// General server-side or structural license problem.
    case invalidLicense(detail: String)

    public var description: String {
        switch self {
        case .notActivated:
            return "NerdKey: no activated license found on this machine"
        case .seatLimitExceeded:
            return "NerdKey: seat limit exceeded for this license"
        case .expired:
            return "NerdKey: license has expired"
        case .revoked:
            return "NerdKey: license has been revoked"
        case .networkErrorWithinGrace(let date):
            return "NerdKey: offline — within grace (last online: \(date))"
        case .networkErrorGraceExpired(let date):
            return "NerdKey: offline grace expired (last online: \(date))"
        case .invalidSignature:
            return "NerdKey: license key signature is invalid"
        case .invalidLicense(let detail):
            return "NerdKey: invalid license — \(detail)"
        }
    }
}
