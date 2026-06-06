using System.Runtime.InteropServices;

namespace NerdKey.Kit;

/// <summary>Configuration for the NerdKey SDK.</summary>
public sealed class NerdKeyConfig
{
    /// <summary>Keygen CE base URL (default: https://nerdkey.localhost).</summary>
    public string BaseUrl { get; set; } = NerdKeyConstants.DefaultBaseUrl;

    /// <summary>Keygen account ID (default: embedded constant).</summary>
    public string AccountId { get; set; } = NerdKeyConstants.AccountId;

    /// <summary>Skip TLS certificate verification (for self-signed / local certs).</summary>
    public bool TlsSkipVerify { get; set; } = true;

    /// <summary>App slug used for license.json storage path.</summary>
    public string AppSlug { get; set; } = "default";

    /// <summary>Override the state directory (for testing multiple fingerprints).</summary>
    public string? StateDirOverride { get; set; }
}

/// <summary>
/// Main NerdKey SDK entry point.
/// Thread-safe; all operations are async.
/// </summary>
public sealed class NerdKeyClient : IDisposable
{
    private readonly NerdKeyConfig _config;
    private readonly LicenseStateStore _store;
    private readonly Ed25519Verifier _verifier;
    private readonly KeygenHttpClient _http;

    public NerdKeyClient(NerdKeyConfig? config = null)
    {
        _config = config ?? new NerdKeyConfig();
        _store = new LicenseStateStore(_config.AppSlug, _config.StateDirOverride);
        _verifier = new Ed25519Verifier();
        _http = new KeygenHttpClient(_config.BaseUrl, _config.AccountId, _config.TlsSkipVerify);
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    /// <summary>
    /// Activate a license key on this machine.
    ///
    /// 1. Verify Ed25519 signature offline.
    /// 2. Call Keygen validate-key to obtain the license ID.
    /// 3. Register this machine via POST /machines.
    /// 4. Persist license.json.
    /// Idempotent: if already activated with the same fingerprint, returns the existing machine ID.
    /// </summary>
    /// <param name="licenseKey">The full key/… string.</param>
    /// <returns>The Keygen machine ID.</returns>
    public async Task<string> ActivateAsync(string licenseKey, CancellationToken ct = default)
    {
        // Offline signature check
        try { _verifier.Verify(licenseKey); }
        catch (InvalidSignatureException) { throw; }
        catch (Exception ex) { throw new InvalidLicenseException($"key structure: {ex.Message}"); }

        var fingerprint = MachineFingerprint.Current();
        var platform = PlatformString();
        var hostname = System.Net.Dns.GetHostName();

        // Idempotent: already activated with same key + fingerprint?
        var existing = _store.Load();
        if (existing is not null &&
            existing.LicenseKey == licenseKey &&
            existing.Fingerprint == fingerprint)
        {
            return existing.MachineId;
        }

        // Online validate-key → get license ID
        var validateResp = await _http.ValidateKeyAsync(licenseKey, fingerprint, ct);
        if (validateResp.Data is null)
            throw new InvalidLicenseException("validate-key returned no data");

        var licenseId = validateResp.Data.Id;
        var status = validateResp.Data.Attributes?.Status ?? "";

        if (status == "REVOKED" || status == "SUSPENDED")
            throw new LicenseRevokedException();
        if (status == "EXPIRED")
            throw new LicenseExpiredException();

        // Activate machine
        var machineResp = await _http.ActivateMachineAsync(
            licenseKey, licenseId, fingerprint, platform, hostname, ct);

        if (machineResp.Data is null)
            throw new InvalidLicenseException("machines endpoint returned no data");

        var machineId = machineResp.Data.Id;

        // Persist
        var state = new LicenseState
        {
            LicenseKey = licenseKey,
            MachineId = machineId,
            Fingerprint = fingerprint,
            LastOnlineCheckAt = DateTimeOffset.UtcNow,
            LastOnlineCheckResult = "ACTIVE",
            CachedKeygenLicenseId = licenseId,
        };
        _store.Save(state);

        return machineId;
    }

    /// <summary>
    /// Validate the license on every app launch.
    ///
    /// 1. Load license.json — throws NotActivatedException if missing.
    /// 2. Verify Ed25519 offline.
    /// 3. If a refresh is due (> REFRESH_DAYS since last online check), do an online check.
    ///    On network failure, apply GRACE_DAYS window.
    /// </summary>
    public async Task ValidateOnLaunchAsync(CancellationToken ct = default)
    {
        var state = _store.Load()
            ?? throw new NotActivatedException();

        // Offline signature check
        try { _verifier.Verify(state.LicenseKey); }
        catch (InvalidSignatureException) { throw; }
        catch (Exception ex) { throw new InvalidLicenseException(ex.Message); }

        // Do we need an online refresh?
        bool needsOnline;
        if (state.LastOnlineCheckAt is null)
        {
            needsOnline = true;
        }
        else
        {
            var age = DateTimeOffset.UtcNow - state.LastOnlineCheckAt.Value;
            needsOnline = age.TotalDays > NerdKeyConstants.RefreshDays;
        }

        if (!needsOnline) return;

        try
        {
            var resp = await _http.ValidateKeyAsync(state.LicenseKey, state.Fingerprint, ct);

            if (!resp.Meta!.Valid)
            {
                var code = resp.Meta.Code ?? "";
                var status = resp.Data?.Attributes?.Status ?? "";
                if (code.Contains("REVOKED", StringComparison.OrdinalIgnoreCase) ||
                    code.Contains("SUSPENDED", StringComparison.OrdinalIgnoreCase) ||
                    code == "NOT_FOUND" ||
                    status == "REVOKED" || status == "SUSPENDED")
                    throw new LicenseRevokedException();

                if (code.Contains("EXPIRED", StringComparison.OrdinalIgnoreCase) || status == "EXPIRED")
                    throw new LicenseExpiredException();

                throw new InvalidLicenseException(resp.Meta.Detail ?? code);
            }

            // Update timestamp
            state.LastOnlineCheckAt = DateTimeOffset.UtcNow;
            state.LastOnlineCheckResult = "VALID";
            _store.Save(state);
        }
        catch (LicenseRevokedException) { throw; }
        catch (LicenseExpiredException) { throw; }
        catch (InvalidLicenseException) { throw; }
        catch
        {
            // Network failure — apply grace window
            if (state.LastOnlineCheckAt is { } last)
            {
                var elapsed = DateTimeOffset.UtcNow - last;
                if (elapsed.TotalDays <= NerdKeyConstants.GraceDays)
                    throw new NetworkErrorWithinGraceException(last.UtcDateTime);
                throw new NetworkErrorGraceExpiredException(last.UtcDateTime);
            }
            throw new NetworkErrorGraceExpiredException(DateTime.MinValue);
        }
    }

    /// <summary>
    /// Deactivate this machine and delete license.json.
    /// Idempotent: if no license.json exists, returns without error.
    /// </summary>
    public async Task DeactivateAsync(CancellationToken ct = default)
    {
        var state = _store.Load();
        if (state is null) return;

        try
        {
            await _http.DeactivateMachineAsync(state.LicenseKey, state.MachineId, ct);
        }
        catch (KeygenHttpException ex) when (ex.StatusCode == 404)
        {
            // Already deleted — idempotent
        }

        _store.Delete();
    }

    // -------------------------------------------------------------------------

    private static string PlatformString()
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX)) return "macOS";
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) return "Windows";
        return "Linux";
    }

    public void Dispose() => _http.Dispose();
}
