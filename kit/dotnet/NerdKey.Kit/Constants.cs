namespace NerdKey.Kit;

/// <summary>
/// Embedded NerdKey / Keygen account constants.
/// SECURITY: accountId and ed25519PublicKeyBase64 are non-secret public values.
/// NEVER embed admin tokens or private keys here.
/// </summary>
public static class NerdKeyConstants
{
    /// <summary>Keygen CE account UUID.</summary>
    public const string AccountId = "6ff939de-b619-496f-ba99-e59bf64349e4";

    /// <summary>
    /// Base64-encoded hex-string of the 32-byte Ed25519 public key.
    /// Obtained via: python3 nerdkey.py account public-key
    /// Decode path: base64 -> UTF-8 hex string -> 32 raw bytes -> Ed25519PublicKey
    /// </summary>
    public const string Ed25519PublicKeyBase64 =
        "NThhMWFlM2Q0OGI5NmQ2NzkzODNiNGQyYzY1YmNhYTFiOGMzMzViMTdkOWUwN2ZmNzk1MTQyODIyNGJiM2ZhNg==";

    /// <summary>Default Keygen CE base URL. Override via NerdKeyConfig.</summary>
    public const string DefaultBaseUrl = "https://nerdkey.localhost";

    /// <summary>Days before proactive online refresh.</summary>
    public const int RefreshDays = 5;

    /// <summary>Days of grace period for offline use when server unreachable.</summary>
    public const int GraceDays = 7;
}
