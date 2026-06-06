using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace NerdKey.Kit;

/// <summary>
/// Computes a stable machine fingerprint as SHA-256 hex.
/// NERDKEY_FINGERPRINT_OVERRIDE env var allows test overrides.
/// Platform sources:
///   macOS:   serial number via system_profiler, fallback: kern.uuid via sysctl
///   Windows: Win32_ComputerSystemProduct UUID via WMI, fallback: MachineGuid registry
///   Linux:   /etc/machine-id, fallback: hostname + first non-loopback MAC
/// </summary>
public static class MachineFingerprint
{
    public static string Current()
    {
        var overrideVal = Environment.GetEnvironmentVariable("NERDKEY_FINGERPRINT_OVERRIDE");
        if (!string.IsNullOrEmpty(overrideVal))
            return Sha256Hex(overrideVal);

        return Sha256Hex(RawIdentifier());
    }

    private static string RawIdentifier()
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            return MacOsIdentifier();
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            return WindowsIdentifier();
        return LinuxIdentifier();
    }

    private static string MacOsIdentifier()
    {
        try
        {
            var psi = new System.Diagnostics.ProcessStartInfo("/usr/sbin/system_profiler")
            {
                ArgumentList = { "SPHardwareDataType" },
                RedirectStandardOutput = true,
                UseShellExecute = false,
            };
            using var proc = System.Diagnostics.Process.Start(psi)!;
            var output = proc.StandardOutput.ReadToEnd();
            proc.WaitForExit();
            foreach (var line in output.Split('\n'))
            {
                var trimmed = line.Trim();
                if (trimmed.StartsWith("Serial Number", StringComparison.OrdinalIgnoreCase))
                {
                    var colon = trimmed.IndexOf(':');
                    if (colon >= 0)
                        return trimmed[(colon + 1)..].Trim();
                }
            }
        }
        catch { /* fall through */ }

        // Fallback: kern.uuid via sysctl
        try
        {
            var psi = new System.Diagnostics.ProcessStartInfo("/usr/sbin/sysctl")
            {
                ArgumentList = { "-n", "kern.uuid" },
                RedirectStandardOutput = true,
                UseShellExecute = false,
            };
            using var proc = System.Diagnostics.Process.Start(psi)!;
            var result = proc.StandardOutput.ReadToEnd().Trim();
            proc.WaitForExit();
            if (!string.IsNullOrEmpty(result)) return result;
        }
        catch { /* fall through */ }

        return System.Net.Dns.GetHostName();
    }

    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
    private static string WindowsIdentifier()
    {
        // Try registry MachineGuid (always present on Windows)
        try
        {
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                @"SOFTWARE\Microsoft\Cryptography");
            if (key?.GetValue("MachineGuid") is string guid && !string.IsNullOrEmpty(guid))
                return guid;
        }
        catch { /* fall through */ }

        return System.Net.Dns.GetHostName();
    }

    private static string LinuxIdentifier()
    {
        // Try /etc/machine-id
        try
        {
            var id = File.ReadAllText("/etc/machine-id").Trim();
            if (!string.IsNullOrEmpty(id)) return id;
        }
        catch { /* fall through */ }

        // Fallback: hostname + first MAC
        var hostname = System.Net.Dns.GetHostName();
        var mac = FirstMacAddress();
        return string.IsNullOrEmpty(mac) ? hostname : $"{hostname}:{mac}";
    }

    private static string? FirstMacAddress()
    {
        try
        {
            foreach (var iface in System.Net.NetworkInformation.NetworkInterface.GetAllNetworkInterfaces())
            {
                if (iface.NetworkInterfaceType == System.Net.NetworkInformation.NetworkInterfaceType.Loopback)
                    continue;
                var bytes = iface.GetPhysicalAddress().GetAddressBytes();
                if (bytes.Length == 6 && bytes.Any(b => b != 0))
                    return string.Join(":", bytes.Select(b => b.ToString("x2")));
            }
        }
        catch { /* fall through */ }
        return null;
    }

    public static string Sha256Hex(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
