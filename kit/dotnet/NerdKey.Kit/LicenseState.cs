using System.Text.Json;
using System.Text.Json.Serialization;
using System.Runtime.InteropServices;

namespace NerdKey.Kit;

/// <summary>
/// Persisted license state written to license.json.
/// Locations:
///   macOS:   ~/Library/Application Support/nerdsmiths/{appSlug}/license.json
///   Windows: %APPDATA%\nerdsmiths\{appSlug}\license.json
///   Linux:   ~/.local/share/nerdsmiths/{appSlug}/license.json
/// </summary>
public sealed class LicenseState
{
    [JsonPropertyName("schemaVersion")]
    public int SchemaVersion { get; set; } = 1;

    [JsonPropertyName("licenseKey")]
    public string LicenseKey { get; set; } = "";

    [JsonPropertyName("machineId")]
    public string MachineId { get; set; } = "";

    [JsonPropertyName("fingerprint")]
    public string Fingerprint { get; set; } = "";

    [JsonPropertyName("lastOnlineCheckAt")]
    public DateTimeOffset? LastOnlineCheckAt { get; set; }

    [JsonPropertyName("lastOnlineCheckResult")]
    public string? LastOnlineCheckResult { get; set; }

    [JsonPropertyName("cachedKeygenLicenseId")]
    public string? CachedKeygenLicenseId { get; set; }
}

/// <summary>Manages reading and writing license.json.</summary>
public sealed class LicenseStateStore
{
    private readonly string _filePath;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    public LicenseStateStore(string appSlug, string? stateDirOverride = null)
    {
        string dir;
        if (stateDirOverride is not null)
        {
            dir = stateDirOverride;
        }
        else
        {
            dir = Path.Combine(DefaultBaseDirectory(), "nerdsmiths", appSlug);
        }
        Directory.CreateDirectory(dir);
        _filePath = Path.Combine(dir, "license.json");
    }

    private static string DefaultBaseDirectory()
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            return Path.Combine(home, "Library", "Application Support");
        }
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            return Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        }
        // Linux
        var xdgData = Environment.GetEnvironmentVariable("XDG_DATA_HOME");
        if (!string.IsNullOrEmpty(xdgData)) return xdgData;
        var homeDir = Environment.GetEnvironmentVariable("HOME") ?? "/tmp";
        return Path.Combine(homeDir, ".local", "share");
    }

    public string FilePath => _filePath;

    public LicenseState? Load()
    {
        if (!File.Exists(_filePath)) return null;
        var json = File.ReadAllText(_filePath);
        return JsonSerializer.Deserialize<LicenseState>(json, JsonOptions);
    }

    public void Save(LicenseState state)
    {
        var json = JsonSerializer.Serialize(state, JsonOptions);
        File.WriteAllText(_filePath, json);
    }

    public void Delete()
    {
        if (File.Exists(_filePath))
            File.Delete(_filePath);
    }
}
