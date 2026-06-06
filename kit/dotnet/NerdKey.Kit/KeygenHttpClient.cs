using System.Net.Http.Json;
using System.Net.Security;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace NerdKey.Kit;

/// <summary>Low-level HTTP client for the Keygen CE v1 API.</summary>
public sealed class KeygenHttpClient : IDisposable
{
    private readonly HttpClient _http;
    private readonly string _baseUrl;
    private readonly string _accountId;
    private const string JsonApi = "application/vnd.api+json";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    public KeygenHttpClient(string baseUrl, string accountId, bool tlsSkipVerify)
    {
        _baseUrl = baseUrl.TrimEnd('/');
        _accountId = accountId;

        var handler = new HttpClientHandler();
        if (tlsSkipVerify)
        {
            handler.ServerCertificateCustomValidationCallback =
                (_, _, _, _) => true;
        }
        _http = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(30) };
        _http.DefaultRequestHeaders.Accept.Clear();
        _http.DefaultRequestHeaders.Add("Accept", JsonApi);
    }

    // POST /v1/accounts/{acct}/licenses/actions/validate-key (no auth)
    public async Task<ValidateKeyResponse> ValidateKeyAsync(string licenseKey, string fingerprint,
        CancellationToken ct = default)
    {
        var path = $"/v1/accounts/{_accountId}/licenses/actions/validate-key";
        var body = new
        {
            meta = new
            {
                key = licenseKey,
                scope = new { fingerprint }
            }
        };
        var response = await PostAsync(path, body, authHeader: null, ct);
        return Deserialize<ValidateKeyResponse>(response);
    }

    // POST /v1/accounts/{acct}/machines  (auth: License <key>)
    public async Task<MachineResponse> ActivateMachineAsync(
        string licenseKey, string licenseId,
        string fingerprint, string platform, string name,
        CancellationToken ct = default)
    {
        var path = $"/v1/accounts/{_accountId}/machines";
        var body = new
        {
            data = new
            {
                type = "machines",
                attributes = new { fingerprint, platform, name },
                relationships = new
                {
                    license = new { data = new { type = "licenses", id = licenseId } }
                }
            }
        };
        try
        {
            var response = await PostAsync(path, body, authHeader: $"License {licenseKey}", ct);
            return Deserialize<MachineResponse>(response);
        }
        catch (KeygenHttpException ex) when (ex.StatusCode == 422)
        {
            // Check if it's machine limit exceeded
            if (ex.ResponseBody is not null)
            {
                try
                {
                    var errDoc = JsonSerializer.Deserialize<JsonApiErrorDocument>(ex.ResponseBody, JsonOptions);
                    if (errDoc?.Errors?.Any(e =>
                            e.Code?.Contains("MACHINE_LIMIT", StringComparison.OrdinalIgnoreCase) == true ||
                            e.Code?.Contains("LIMIT_EXCEEDED", StringComparison.OrdinalIgnoreCase) == true ||
                            e.Title?.Contains("machine limit", StringComparison.OrdinalIgnoreCase) == true) == true)
                    {
                        throw new SeatLimitExceededException();
                    }
                    var detail = string.Join("; ",
                        errDoc?.Errors?.Select(e => e.Detail ?? e.Title ?? e.Code ?? "unknown") ?? []);
                    if (!string.IsNullOrEmpty(detail))
                        throw new InvalidLicenseException(detail);
                }
                catch (SeatLimitExceededException) { throw; }
                catch (InvalidLicenseException) { throw; }
                catch { /* fall through to SeatLimitExceeded default */ }
            }
            throw new SeatLimitExceededException();
        }
    }

    // DELETE /v1/accounts/{acct}/machines/{machineId}  (auth: License <key>)
    public async Task DeactivateMachineAsync(string licenseKey, string machineId,
        CancellationToken ct = default)
    {
        var url = $"{_baseUrl}/v1/accounts/{_accountId}/machines/{machineId}";
        var request = new HttpRequestMessage(HttpMethod.Delete, url);
        request.Headers.Add("Authorization", $"License {licenseKey}");
        request.Headers.Accept.Clear();
        request.Headers.Add("Accept", JsonApi);

        var resp = await _http.SendAsync(request, ct);
        if (!resp.IsSuccessStatusCode && resp.StatusCode != System.Net.HttpStatusCode.NotFound)
            throw new KeygenHttpException((int)resp.StatusCode, null);
    }

    // -------------------------------------------------------------------------

    private async Task<string> PostAsync(string path, object body, string? authHeader,
        CancellationToken ct)
    {
        var url = $"{_baseUrl}{path}";
        var json = JsonSerializer.Serialize(body, JsonOptions);
        using var content = new StringContent(json, Encoding.UTF8, JsonApi);

        var request = new HttpRequestMessage(HttpMethod.Post, url) { Content = content };
        request.Headers.Accept.Clear();
        request.Headers.Add("Accept", JsonApi);
        if (authHeader is not null)
            request.Headers.Add("Authorization", authHeader);

        var resp = await _http.SendAsync(request, ct);
        var respBody = await resp.Content.ReadAsStringAsync(ct);

        if (!resp.IsSuccessStatusCode)
            throw new KeygenHttpException((int)resp.StatusCode, respBody);

        return respBody;
    }

    private static T Deserialize<T>(string json)
    {
        var result = JsonSerializer.Deserialize<T>(json, JsonOptions);
        if (result is null)
            throw new InvalidLicenseException("empty or null API response");
        return result;
    }

    public void Dispose() => _http.Dispose();
}

// DTO types

public sealed class ValidateKeyResponse
{
    [JsonPropertyName("meta")]
    public ValidateMeta? Meta { get; set; }

    [JsonPropertyName("data")]
    public LicenseData? Data { get; set; }

    public sealed class ValidateMeta
    {
        [JsonPropertyName("valid")]
        public bool Valid { get; set; }

        [JsonPropertyName("detail")]
        public string? Detail { get; set; }

        [JsonPropertyName("code")]
        public string? Code { get; set; }
    }

    public sealed class LicenseData
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = "";

        [JsonPropertyName("attributes")]
        public LicenseAttrs? Attributes { get; set; }

        public sealed class LicenseAttrs
        {
            [JsonPropertyName("status")]
            public string? Status { get; set; }
        }
    }
}

public sealed class MachineResponse
{
    [JsonPropertyName("data")]
    public MachineData? Data { get; set; }

    public sealed class MachineData
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = "";

        [JsonPropertyName("attributes")]
        public MachineAttrs? Attributes { get; set; }

        public sealed class MachineAttrs
        {
            [JsonPropertyName("fingerprint")]
            public string Fingerprint { get; set; } = "";
        }
    }
}

public sealed class JsonApiErrorDocument
{
    [JsonPropertyName("errors")]
    public List<JsonApiError>? Errors { get; set; }
}

public sealed class JsonApiError
{
    [JsonPropertyName("title")]
    public string? Title { get; set; }

    [JsonPropertyName("detail")]
    public string? Detail { get; set; }

    [JsonPropertyName("code")]
    public string? Code { get; set; }
}

public sealed class KeygenHttpException : Exception
{
    public int StatusCode { get; }
    public string? ResponseBody { get; }

    public KeygenHttpException(int statusCode, string? body)
        : base($"Keygen API returned HTTP {statusCode}")
    {
        StatusCode = statusCode;
        ResponseBody = body;
    }
}
