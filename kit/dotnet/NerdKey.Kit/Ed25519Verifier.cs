using System.Text;
using Org.BouncyCastle.Crypto.Parameters;
using Org.BouncyCastle.Crypto.Signers;

namespace NerdKey.Kit;

/// <summary>
/// Offline Ed25519 signature verification for Keygen ED25519_SIGN license keys.
///
/// Key format: key/&lt;base64url-payload&gt;.&lt;base64url-sig&gt;
/// Signed message: UTF-8 bytes of "key/" + base64url-payload
/// Public key encoding (from Keygen CLI): base64( hex-string( 32-byte raw Ed25519 public key ) )
/// </summary>
public sealed class Ed25519Verifier
{
    private readonly Ed25519PublicKeyParameters _publicKey;

    /// <summary>Initialize using the constant embedded in NerdKeyConstants.</summary>
    public Ed25519Verifier() : this(NerdKeyConstants.Ed25519PublicKeyBase64) { }

    /// <summary>Initialize from a base64-encoded hex-string public key.</summary>
    public Ed25519Verifier(string base64EncodedHexKey)
    {
        var hexBytes = Convert.FromBase64String(base64EncodedHexKey);
        var hexString = Encoding.ASCII.GetString(hexBytes);
        if (hexString.Length != 64)
            throw new InvalidSignatureException();
        var rawKey = Convert.FromHexString(hexString);
        _publicKey = new Ed25519PublicKeyParameters(rawKey, 0);
    }

    /// <summary>
    /// Verify a Keygen ED25519_SIGN license key offline.
    /// Returns the decoded payload JSON on success.
    /// Throws InvalidSignatureException or InvalidLicenseException on failure.
    /// </summary>
    public LicenseKeyPayload Verify(string licenseKey)
    {
        if (!licenseKey.StartsWith("key/", StringComparison.Ordinal))
            throw new InvalidLicenseException("key must start with 'key/'");

        var stripped = licenseKey[4..]; // drop "key/"
        var lastDot = stripped.LastIndexOf('.');
        if (lastDot < 0)
            throw new InvalidLicenseException("key missing signature separator '.'");

        var payloadB64 = stripped[..lastDot];
        var sigB64Url = stripped[(lastDot + 1)..];

        // Message is "key/" + payloadB64 as UTF-8
        var message = Encoding.ASCII.GetBytes("key/" + payloadB64);

        // Decode base64url signature
        var sigBytes = Base64UrlDecode(sigB64Url);

        var verifier = new Ed25519Signer();
        verifier.Init(false, _publicKey);
        verifier.BlockUpdate(message, 0, message.Length);
        if (!verifier.VerifySignature(sigBytes))
            throw new InvalidSignatureException();

        // Decode the payload JSON
        var payloadBytes = Convert.FromBase64String(PadBase64(payloadB64));
        var json = Encoding.UTF8.GetString(payloadBytes);
        var payload = System.Text.Json.JsonSerializer.Deserialize<LicenseKeyPayload>(json);
        if (payload is null)
            throw new InvalidLicenseException("could not parse license key payload");
        return payload;
    }

    private static byte[] Base64UrlDecode(string base64Url)
    {
        return Convert.FromBase64String(PadBase64(
            base64Url.Replace('-', '+').Replace('_', '/')));
    }

    private static string PadBase64(string s)
    {
        int rem = s.Length % 4;
        if (rem == 2) return s + "==";
        if (rem == 3) return s + "=";
        return s;
    }
}

/// <summary>Decoded payload from a Keygen ED25519_SIGN license key.</summary>
public sealed class LicenseKeyPayload
{
    [System.Text.Json.Serialization.JsonPropertyName("license")]
    public LicenseInfo? License { get; set; }

    [System.Text.Json.Serialization.JsonPropertyName("policy")]
    public PolicyInfo? Policy { get; set; }

    public sealed class LicenseInfo
    {
        [System.Text.Json.Serialization.JsonPropertyName("id")]
        public string Id { get; set; } = "";

        [System.Text.Json.Serialization.JsonPropertyName("expiry")]
        public string? Expiry { get; set; }
    }

    public sealed class PolicyInfo
    {
        [System.Text.Json.Serialization.JsonPropertyName("id")]
        public string Id { get; set; } = "";

        [System.Text.Json.Serialization.JsonPropertyName("duration")]
        public int? Duration { get; set; }
    }
}
