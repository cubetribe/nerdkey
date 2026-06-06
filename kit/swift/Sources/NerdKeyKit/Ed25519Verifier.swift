import Foundation
import Crypto

/// Offline Ed25519 verification for Keygen ED25519_SIGN license keys.
///
/// Key format:  key/<base64url-payload>.<base64url-sig>
/// The signature is produced over the ASCII bytes of <base64url-payload>.
/// Public key encoding from Keygen CLI: base64( hex-string( 32-byte raw Ed25519 public key ) )
public struct Ed25519Verifier {

    public enum VerificationError: Error {
        case malformedKeyFormat
        case malformedPublicKey
        case signatureInvalid
    }

    private let publicKey: Curve25519.Signing.PublicKey

    /// Load verifier using the constant embedded in Constants.swift.
    public init() throws {
        try self.init(base64EncodedHexKey: NerdKeyConstants.ed25519PublicKeyBase64)
    }

    /// Load verifier from an arbitrary base64-encoded hex-string public key.
    public init(base64EncodedHexKey: String) throws {
        guard
            let hexData = Data(base64Encoded: base64EncodedHexKey),
            let hexString = String(data: hexData, encoding: .utf8)
        else {
            throw VerificationError.malformedPublicKey
        }
        guard hexString.count == 64,
              let rawBytes = Data(hexString: hexString)
        else {
            throw VerificationError.malformedPublicKey
        }
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: rawBytes)
        } catch {
            throw VerificationError.malformedPublicKey
        }
    }

    /// Verify a Keygen license key string offline.
    /// - Returns: Decoded payload JSON data on success.
    /// - Throws: VerificationError on any structural or cryptographic failure.
    @discardableResult
    public func verify(licenseKey: String) throws -> LicenseKeyPayload {
        // Strip "key/" prefix
        guard licenseKey.hasPrefix("key/") else {
            throw VerificationError.malformedKeyFormat
        }
        let stripped = String(licenseKey.dropFirst(4))

        // Split at last "."
        guard let dotRange = stripped.range(of: ".", options: .backwards) else {
            throw VerificationError.malformedKeyFormat
        }
        let payloadB64 = String(stripped[stripped.startIndex..<dotRange.lowerBound])
        let sigB64Url  = String(stripped[dotRange.upperBound...])

        // Keygen ED25519_SIGN: the message is "key/<payload>" (i.e. the full key minus the last ".sig" part)
        // Confirmed by testing: signed over "key/" + payloadB64 as ASCII bytes
        let messageBytes = Data(("key/" + payloadB64).utf8)

        // Decode signature (base64url, padded as needed)
        guard let sigBytes = Data(base64URLEncoded: sigB64Url) else {
            throw VerificationError.malformedKeyFormat
        }

        // Verify
        guard publicKey.isValidSignature(sigBytes, for: messageBytes) else {
            throw VerificationError.signatureInvalid
        }

        // Decode payload JSON
        guard let payloadData = Data(base64Encoded: payloadB64) else {
            throw VerificationError.malformedKeyFormat
        }
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(LicenseKeyPayload.self, from: payloadData) else {
            throw VerificationError.malformedKeyFormat
        }
        return payload
    }
}

/// The JSON payload embedded inside a Keygen ED25519_SIGN license key.
public struct LicenseKeyPayload: Decodable {
    public struct LicenseInfo: Decodable {
        public let id: String
        public let created: String
        public let expiry: String?
    }
    public struct PolicyInfo: Decodable {
        public let id: String
        public let duration: Int?
    }
    public let license: LicenseInfo
    public let policy: PolicyInfo
}

// MARK: - Helpers

extension Data {
    /// Decode base64url (with or without padding).
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: base64)
    }

    /// Decode a lowercase hex string into bytes.
    init?(hexString: String) {
        let hex = hexString.lowercased()
        guard hex.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            bytes.append(byte)
            index = nextIndex
        }
        self.init(bytes)
    }
}
