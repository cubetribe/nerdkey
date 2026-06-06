/// Embedded NerdKey / Keygen account constants.
///
/// SECURITY NOTE:
/// - `accountId` is a non-secret public identifier.
/// - `ed25519PublicKeyBase64` is the BASE-64 encoded hex-string of the 32-byte
///   Ed25519 public key.  Public keys are safe to embed in distributed software.
/// - NEVER embed admin tokens or private keys here.
public enum NerdKeyConstants {
    /// Keygen account UUID.
    public static let accountId = "6ff939de-b619-496f-ba99-e59bf64349e4"

    /// Base64( hex-string( 32-byte Ed25519 public key ) )
    /// Obtained via: python3 nerdkey.py account public-key
    /// Decode path: base64 -> hex-string -> 32 raw bytes -> Ed25519PublicKey
    public static let ed25519PublicKeyBase64 =
        "NThhMWFlM2Q0OGI5NmQ2NzkzODNiNGQyYzY1YmNhYTFiOGMzMzViMTdkOWUwN2ZmNzk1MTQyODIyNGJiM2ZhNg=="

    /// Default base URL.  Override via NerdKeyConfig.baseURL.
    public static let defaultBaseURL = "https://nerdkey.localhost"

    /// Days before the SDK proactively refreshes the online validation cache.
    public static let refreshDays: Int = 5

    /// Days of grace period when the server cannot be reached.
    public static let graceDays: Int = 7
}
