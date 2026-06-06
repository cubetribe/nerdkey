# NerdKey Client SDK — Integration Guide

> How to embed software licensing (activation, offline validation, seat limits, revoke) into your macOS/Swift or Windows+Linux/.NET application using the NerdKey Client SDK (`kit/`).

---

## Overview

The SDK provides three operations:

| Operation | When to call | What it does |
|-----------|-------------|--------------|
| `activate(licenseKey)` | User enters their license key | Verifies Ed25519 offline → registers this machine with Keygen → saves `license.json`. Idempotent. |
| `validateOnLaunch()` | Every app launch | Offline Ed25519 verify → online refresh (every 5 days) → grace window (7 days) → throws typed error |
| `deactivate()` | User clicks "Deactivate" | Removes machine from Keygen → deletes `license.json`. Idempotent. |

### Embedded constants (already baked in)

| Constant | Value |
|----------|-------|
| Account ID | `6ff939de-b619-496f-ba99-e59bf64349e4` |
| Ed25519 public key (base64) | `NThhMWFlM2Q0OGI5NmQ2NzkzODNiNGQyYzY1YmNhYTFiOGMzMzViMTdkOWUwN2ZmNzk1MTQyODIyNGJiM2ZhNg==` |
| Default base URL | `https://nerdkey.localhost` ← change to your production URL |

The **public key** is non-secret and safe to ship inside a compiled binary. Never embed admin tokens or private keys.

---

## macOS / Swift Integration

### 1. Add the dependency

In your app's `Package.swift` (or in Xcode → Swift Packages):

```swift
.package(url: "https://github.com/your-org/NerdKey.git", from: "1.0.0"),
```

Or copy `kit/swift/Sources/NerdKeyKit/` directly into your project.

The library requires **swift-crypto** (already declared in `Package.swift`):

```swift
.package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
```

### 2. Embed constants

`Constants.swift` already contains the correct values. For production, update `NerdKeyConstants.defaultBaseURL` to your production Keygen host:

```swift
// Constants.swift
public enum NerdKeyConstants {
    public static let accountId = "6ff939de-b619-496f-ba99-e59bf64349e4"
    public static let ed25519PublicKeyBase64 = "NThhMWFlM2Q0OGI5NmQ2NzkzODNiNGQyYzY1YmNhYTFiOGMzMzViMTdkOWUwN2ZmNzk1MTQyODIyNGJiM2ZhNg=="
    public static let defaultBaseURL = "https://your-keygen-host.example.com"
    public static let refreshDays: Int = 5
    public static let graceDays:   Int = 7
}
```

### 3. Create the SDK object

```swift
import NerdKeyKit

let config = NerdKeyConfig(
    baseURL:        "https://your-keygen-host.example.com",
    appSlug:        "your-app-slug",   // determines license.json folder
    tlsSkipVerify:  false              // true only for local self-signed certs
)
let sdk = try NerdKey(config: config)
```

### 4. Activation flow (licensing UI)

```swift
// Called when the user enters their license key and clicks "Activate"
func activateLicense(_ key: String) async {
    do {
        let machineId = try await sdk.activate(licenseKey: key)
        print("Activated on machine \(machineId)")
        // Show success UI, persist nothing else — sdk handles license.json
    } catch NerdKeyError.invalidSignature {
        showError("This license key is not valid.")
    } catch NerdKeyError.seatLimitExceeded {
        showError("Seat limit reached — deactivate another machine first.")
    } catch NerdKeyError.expired {
        showError("This license has expired.")
    } catch NerdKeyError.revoked {
        showError("This license has been revoked.")
    } catch {
        showError("Activation failed: \(error)")
    }
}
```

### 5. Validate on every launch

Call this **before** showing your main window:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await checkLicense() }
        }
    }

    func checkLicense() async {
        do {
            try await sdk.validateOnLaunch()
            // License is valid — proceed normally
        } catch NerdKeyError.notActivated {
            // Show license-entry screen
        } catch NerdKeyError.revoked {
            showBlockingError("Your license has been revoked.")
        } catch NerdKeyError.expired {
            showBlockingError("Your license has expired.")
        } catch NerdKeyError.networkErrorWithinGrace(let last) {
            // Offline but within 7-day grace — allow use with a warning
            showWarning("Working offline. Last validated: \(last).")
        } catch NerdKeyError.networkErrorGraceExpired(_) {
            showBlockingError("Cannot verify license — offline grace period has elapsed.")
        } catch NerdKeyError.invalidSignature {
            showBlockingError("License key is corrupted.")
        } catch {
            showBlockingError("License check failed: \(error)")
        }
    }
}
```

### 6. Deactivation flow

```swift
func deactivate() async {
    do {
        try await sdk.deactivate()
        // Show "machine deactivated" confirmation
    } catch {
        showError("Deactivation failed: \(error)")
    }
}
```

### 7. Machine fingerprint

The SDK computes a stable SHA-256 fingerprint from:
- **macOS**: `system_profiler` serial number, fallback `kern.uuid`
- **Linux**: `/etc/machine-id`, fallback hostname+MAC

### 8. license.json location (macOS)

```
~/Library/Application Support/nerdsmiths/<appSlug>/license.json
```

---

## Windows + Linux / .NET Integration

### 1. Add the project reference or NuGet package

Copy `kit/dotnet/NerdKey.Kit/` into your solution, or reference it from your `.csproj`:

```xml
<ProjectReference Include="../NerdKey.Kit/NerdKey.Kit.csproj" />
```

Add the BouncyCastle dependency for Ed25519:

```xml
<PackageReference Include="BouncyCastle.Cryptography" Version="2.4.0" />
```

### 2. Embed constants

`Constants.cs` already contains the correct values. For production, update `DefaultBaseUrl`:

```csharp
// Constants.cs
public static class NerdKeyConstants
{
    public const string AccountId = "6ff939de-b619-496f-ba99-e59bf64349e4";
    public const string Ed25519PublicKeyBase64 =
        "NThhMWFlM2Q0OGI5NmQ2NzkzODNiNGQyYzY1YmNhYTFiOGMzMzViMTdkOWUwN2ZmNzk1MTQyODIyNGJiM2ZhNg==";
    public const string DefaultBaseUrl = "https://your-keygen-host.example.com";
    public const int RefreshDays = 5;
    public const int GraceDays = 7;
}
```

### 3. Create the SDK object

```csharp
using NerdKey.Kit;

var config = new NerdKeyConfig
{
    BaseUrl       = "https://your-keygen-host.example.com",
    AppSlug       = "your-app-slug",
    TlsSkipVerify = false,   // true only for local self-signed certs
};
using var nerdKey = new NerdKeyClient(config);
```

### 4. Activation flow

```csharp
async Task ActivateLicenseAsync(string licenseKey)
{
    try
    {
        var machineId = await nerdKey.ActivateAsync(licenseKey);
        MessageBox.Show($"Activated on machine {machineId}");
    }
    catch (InvalidSignatureException)
    {
        ShowError("This license key is not valid.");
    }
    catch (SeatLimitExceededException)
    {
        ShowError("Seat limit reached — deactivate another machine first.");
    }
    catch (LicenseExpiredException)
    {
        ShowError("This license has expired.");
    }
    catch (LicenseRevokedException)
    {
        ShowError("This license has been revoked.");
    }
    catch (Exception ex)
    {
        ShowError($"Activation failed: {ex.Message}");
    }
}
```

### 5. Validate on every launch

```csharp
// In Application.OnStartup or Program.cs, before showing the main window
async Task CheckLicenseAsync()
{
    try
    {
        await nerdKey.ValidateOnLaunchAsync();
        // License is valid — proceed normally
    }
    catch (NotActivatedException)
    {
        // Navigate to license-entry screen
        ShowLicenseEntryScreen();
    }
    catch (LicenseRevokedException)
    {
        ShowBlockingError("Your license has been revoked. Contact support.");
        Environment.Exit(1);
    }
    catch (LicenseExpiredException)
    {
        ShowBlockingError("Your license has expired. Please renew.");
        Environment.Exit(1);
    }
    catch (NetworkErrorWithinGraceException ex)
    {
        ShowWarning($"Working offline. Last validated: {ex.LastCheckAt:g}.");
        // Allow use with warning
    }
    catch (NetworkErrorGraceExpiredException)
    {
        ShowBlockingError("Cannot verify license — offline grace expired.");
        Environment.Exit(1);
    }
    catch (InvalidSignatureException)
    {
        ShowBlockingError("License key is corrupted — contact support.");
        Environment.Exit(1);
    }
}
```

### 6. Deactivation flow

```csharp
async Task DeactivateAsync()
{
    try
    {
        await nerdKey.DeactivateAsync();
        MessageBox.Show("Machine deactivated. You can now activate on another machine.");
    }
    catch (Exception ex)
    {
        ShowError($"Deactivation failed: {ex.Message}");
    }
}
```

### 7. Machine fingerprint

The SDK computes a stable SHA-256 fingerprint from:
- **Windows**: `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid` registry key
- **Linux**: `/etc/machine-id`, fallback hostname + first MAC address
- **macOS (if using .NET)**: `system_profiler` serial number, fallback `sysctl kern.uuid`

### 8. license.json location

| Platform | Path |
|----------|------|
| Windows  | `%APPDATA%\nerdsmiths\<appSlug>\license.json` |
| macOS    | `~/Library/Application Support/nerdsmiths/<appSlug>/license.json` |
| Linux    | `~/.local/share/nerdsmiths/<appSlug>/license.json` |

---

## Offline / Grace Model

```
Day 0: activate()        → lastOnlineCheckAt = now
Day 1-4: launches        → offline verify only (no network call)
Day 5: launch            → online check triggered (REFRESH_DAYS=5)
       ├── server reachable → update timestamp, continue
       └── server unreachable → grace period starts
             ├── days 5-12 → NetworkErrorWithinGrace (allow with warning)
             └── day 13+ → NetworkErrorGraceExpired (block)
```

You control `REFRESH_DAYS` and `GRACE_DAYS` in `Constants.swift` / `Constants.cs`.

---

## Re-embedding the public key (if Keygen account changes)

1. Get the new public key:
   ```bash
   python3 scripts/nerdkey.py account public-key
   ```
2. Copy the output (a base64 string).
3. Update `NerdKeyConstants.ed25519PublicKeyBase64` (Swift) or `NerdKeyConstants.Ed25519PublicKeyBase64` (.NET).
4. Rebuild and re-ship your app. Old activations remain valid as long as the key hasn't changed on the server.

---

## Proof commands used during development (on this host)

```bash
# Issue test licenses
python3 scripts/nerdkey.py license issue --product nerdsmiths-demo --name "sdk-test-1" --json

# Build Swift SDK
cd kit/swift
swift build

# Run Swift proof sequence (all 7 steps pass against live NerdKey)
.build/debug/nerdkey-cli \
  --license-key "key/..." \
  --keygen-base-url "https://nerdkey.localhost" \
  run-proof

# Build .NET SDK (via Docker, since dotnet is not installed on the host)
docker run --rm \
  --add-host=nerdkey.localhost:host-gateway \
  -v $(pwd)/kit/dotnet:/workspace \
  mcr.microsoft.com/dotnet/sdk:8.0 \
  bash -c "cd /workspace && dotnet build NerdKey.sln"

# Run .NET proof sequence (all 7 steps pass against live NerdKey via Docker)
docker run --rm \
  --add-host=nerdkey.localhost:host-gateway \
  -v $(pwd)/kit/dotnet:/workspace \
  mcr.microsoft.com/dotnet/sdk:8.0 \
  bash -c "cd /workspace && dotnet run --project NerdKey.Example/NerdKey.Example.csproj -- \
    --license-key 'key/...' \
    --keygen-base-url 'https://nerdkey.localhost' \
    run-proof"

# Revoke a license
python3 scripts/nerdkey.py license revoke <license-id>

# After revoking, patch license.json to force an online check, then validate:
# (set lastOnlineCheckAt to 8 days ago)
# validateOnLaunch() throws: "NerdKey: license has been revoked"
```

---

## Error taxonomy quick-reference

| Exception (Swift) | Exception (.NET) | When thrown |
|-------------------|-----------------|-------------|
| `NerdKeyError.notActivated` | `NotActivatedException` | No `license.json` found |
| `NerdKeyError.seatLimitExceeded` | `SeatLimitExceededException` | Keygen returns 422 machine-limit |
| `NerdKeyError.expired` | `LicenseExpiredException` | Server or payload says EXPIRED |
| `NerdKeyError.revoked` | `LicenseRevokedException` | Server returns REVOKED/SUSPENDED/NOT_FOUND |
| `NerdKeyError.networkErrorWithinGrace` | `NetworkErrorWithinGraceException` | Offline, within `GRACE_DAYS` |
| `NerdKeyError.networkErrorGraceExpired` | `NetworkErrorGraceExpiredException` | Offline, past `GRACE_DAYS` |
| `NerdKeyError.invalidSignature` | `InvalidSignatureException` | Ed25519 verify fails |
| `NerdKeyError.invalidLicense(detail:)` | `InvalidLicenseException` | Other server or structural error |
