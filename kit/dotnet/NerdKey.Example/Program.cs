using NerdKey.Kit;
using System.Runtime.InteropServices;

// Entry point — top-level statements
var cli = NerdKeyExampleCli.ParseArgs(args);

if (cli.Command == "run-proof")
{
    return await NerdKeyExampleCli.RunProofSequenceAsync(cli);
}

if (string.IsNullOrEmpty(cli.LicenseKey))
{
    Console.Error.WriteLine("Error: --license-key is required");
    return 1;
}

var config = new NerdKeyConfig
{
    BaseUrl = cli.BaseUrl,
    AccountId = cli.AccountId,
    TlsSkipVerify = cli.TlsSkipVerify,
    AppSlug = "sdk-test",
    StateDirOverride = cli.StateDir,
};

using var client = new NerdKeyClient(config);
try
{
    switch (cli.Command)
    {
        case "activate":
            var machineId = await client.ActivateAsync(cli.LicenseKey);
            Console.WriteLine($"Activated. machineId={machineId}");
            break;
        case "validate":
            await client.ValidateOnLaunchAsync();
            Console.WriteLine("Valid.");
            break;
        case "deactivate":
            await client.DeactivateAsync();
            Console.WriteLine("Deactivated.");
            break;
        default:
            Console.Error.WriteLine($"Unknown command: {cli.Command}");
            return 1;
    }
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}

// ---------------------------------------------------------------------------
// CLI helpers (in a class to avoid top-level statement ordering issues)
// ---------------------------------------------------------------------------

internal static class NerdKeyExampleCli
{
    public static CliArgs ParseArgs(string[] args)
    {
        var command = "run-proof";
        var licenseKey = "";
        var baseUrl = NerdKeyConstants.DefaultBaseUrl;
        var accountId = NerdKeyConstants.AccountId;
        var tlsSkipVerify = true;
        string? stateDir = null;

        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--license-key":     licenseKey    = args[++i]; break;
                case "--keygen-base-url": baseUrl       = args[++i]; break;
                case "--account-id":      accountId     = args[++i]; break;
                case "--tls-skip-verify": tlsSkipVerify = true;      break;
                case "--state-dir":       stateDir      = args[++i]; break;
                default:
                    if (!args[i].StartsWith("--")) command = args[i];
                    break;
            }
        }
        return new CliArgs(command, licenseKey, baseUrl, accountId, tlsSkipVerify, stateDir);
    }

    public static async Task<int> RunProofSequenceAsync(CliArgs cli)
    {
        if (string.IsNullOrEmpty(cli.LicenseKey))
        {
            Console.Error.WriteLine("Error: --license-key is required for run-proof");
            return 1;
        }

        const string stateDir1 = "/tmp/nerdkey-dotnet-proof-m1";
        const string stateDir2 = "/tmp/nerdkey-dotnet-proof-m2";
        const string stateDir3 = "/tmp/nerdkey-dotnet-proof-m3";

        foreach (var dir in new[] { stateDir1, stateDir2, stateDir3 })
            if (Directory.Exists(dir)) Directory.Delete(dir, recursive: true);

        NerdKeyClient MakeClient(string stateDir) => new(new NerdKeyConfig
        {
            BaseUrl     = cli.BaseUrl,
            AccountId   = cli.AccountId,
            TlsSkipVerify = cli.TlsSkipVerify,
            AppSlug     = "sdk-proof",
            StateDirOverride = stateDir,
        });

        Console.WriteLine("========================================");
        Console.WriteLine("NerdKey .NET SDK Proof Sequence");
        Console.WriteLine($"License key: {cli.LicenseKey[..Math.Min(44, cli.LicenseKey.Length)]}...");
        Console.WriteLine($"Base URL: {cli.BaseUrl}");
        Console.WriteLine("========================================\n");

        string machineId1;

        // STEP 1
        Console.WriteLine("[STEP 1] ActivateAsync(licenseKey) -> machine 1");
        Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", "dotnet-proof-machine-001");
        try
        {
            using var c = MakeClient(stateDir1);
            machineId1 = await c.ActivateAsync(cli.LicenseKey);
            Console.WriteLine($"  PASS: machineId={machineId1}\n");
        }
        catch (Exception ex) { Console.WriteLine($"  FAIL: {ex.Message}\n"); return 1; }
        finally { Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", null); }

        // STEP 2
        Console.WriteLine("[STEP 2] ValidateOnLaunchAsync() -> expect VALID");
        Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", "dotnet-proof-machine-001");
        try
        {
            using var c = MakeClient(stateDir1);
            await c.ValidateOnLaunchAsync();
            Console.WriteLine("  PASS: valid\n");
        }
        catch (Exception ex) { Console.WriteLine($"  FAIL: {ex.Message}\n"); return 1; }
        finally { Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", null); }

        // STEP 3
        Console.WriteLine("[STEP 3] ActivateAsync(licenseKey) again -> idempotent success");
        Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", "dotnet-proof-machine-001");
        try
        {
            using var c = MakeClient(stateDir1);
            var idAgain = await c.ActivateAsync(cli.LicenseKey);
            if (idAgain != machineId1)
            { Console.WriteLine($"  FAIL: different machineId: {idAgain}\n"); return 1; }
            Console.WriteLine($"  PASS: machineId={idAgain} (same)\n");
        }
        catch (Exception ex) { Console.WriteLine($"  FAIL: {ex.Message}\n"); return 1; }
        finally { Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", null); }

        // STEP 4
        Console.WriteLine("[STEP 4] ActivateAsync(licenseKey) machine 2 -> success (seat 2 of 2)");
        Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", "dotnet-proof-machine-002");
        try
        {
            using var c = MakeClient(stateDir2);
            var id2 = await c.ActivateAsync(cli.LicenseKey);
            Console.WriteLine($"  PASS: machineId={id2}\n");
        }
        catch (Exception ex) { Console.WriteLine($"  FAIL: {ex.Message}\n"); return 1; }
        finally { Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", null); }

        // STEP 5
        Console.WriteLine("[STEP 5] ActivateAsync(licenseKey) machine 3 -> expect SeatLimitExceededException");
        Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", "dotnet-proof-machine-003");
        try
        {
            using var c = MakeClient(stateDir3);
            _ = await c.ActivateAsync(cli.LicenseKey);
            Console.WriteLine("  FAIL: expected SeatLimitExceededException but activation succeeded\n");
            return 1;
        }
        catch (SeatLimitExceededException)
        { Console.WriteLine("  PASS: SeatLimitExceededException thrown as expected\n"); }
        catch (Exception ex)
        { Console.WriteLine($"  FAIL: unexpected: {ex.GetType().Name}: {ex.Message}\n"); return 1; }
        finally { Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", null); }

        // STEP 6
        Console.WriteLine("[STEP 6] DeactivateAsync() machines 1 and 2");
        Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", "dotnet-proof-machine-001");
        try
        {
            using var c = MakeClient(stateDir1);
            await c.DeactivateAsync();
            Console.WriteLine("  PASS: machine 1 deactivated");
        }
        catch (Exception ex) { Console.WriteLine($"  FAIL machine 1: {ex.Message}\n"); return 1; }
        finally { Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", null); }

        Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", "dotnet-proof-machine-002");
        try
        {
            using var c = MakeClient(stateDir2);
            await c.DeactivateAsync();
            Console.WriteLine("  PASS: machine 2 deactivated\n");
        }
        catch (Exception ex) { Console.WriteLine($"  FAIL machine 2: {ex.Message}\n"); return 1; }
        finally { Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", null); }

        // STEP 7
        Console.WriteLine("[STEP 7] ValidateOnLaunchAsync() after deactivate -> expect NotActivatedException");
        Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", "dotnet-proof-machine-001");
        try
        {
            using var c = MakeClient(stateDir1);
            await c.ValidateOnLaunchAsync();
            Console.WriteLine("  FAIL: expected NotActivatedException but validate returned normally\n");
            return 1;
        }
        catch (NotActivatedException)
        { Console.WriteLine("  PASS: NotActivatedException thrown as expected\n"); }
        catch (Exception ex)
        { Console.WriteLine($"  FAIL: unexpected: {ex.GetType().Name}: {ex.Message}\n"); return 1; }
        finally { Environment.SetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE", null); }

        Console.WriteLine("========================================");
        Console.WriteLine("ALL PROOF STEPS PASSED");
        Console.WriteLine("========================================");
        return 0;
    }
}

// ---------------------------------------------------------------------------
// DTO record
// ---------------------------------------------------------------------------
internal sealed record CliArgs(
    string Command,
    string LicenseKey,
    string BaseUrl,
    string AccountId,
    bool TlsSkipVerify,
    string? StateDir
);
