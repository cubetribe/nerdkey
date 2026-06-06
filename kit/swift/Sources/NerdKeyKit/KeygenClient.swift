import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Low-level HTTP client for the Keygen CE v1 API.
public struct KeygenClient {

    private let baseURL: URL
    private let accountId: String
    private let tlsSkipVerify: Bool

    private static let jsonAPIContentType = "application/vnd.api+json"

    public init(baseURL: String = NerdKeyConstants.defaultBaseURL,
                accountId: String = NerdKeyConstants.accountId,
                tlsSkipVerify: Bool = true) throws {
        guard let url = URL(string: baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL) else {
            throw NerdKeyError.invalidLicense(detail: "invalid base URL: \(baseURL)")
        }
        self.baseURL = url
        self.accountId = accountId
        self.tlsSkipVerify = tlsSkipVerify
    }

    // MARK: - Public API endpoints

    /// POST /v1/accounts/{acct}/licenses/actions/validate-key
    /// Auth: none (public endpoint)
    public func validateKey(licenseKey: String, fingerprint: String) async throws -> ValidateKeyResponse {
        let path = "/v1/accounts/\(accountId)/licenses/actions/validate-key"
        let body: [String: Any] = [
            "meta": [
                "key": licenseKey,
                "scope": ["fingerprint": fingerprint]
            ]
        ]
        let data = try await post(path: path, body: body, authHeader: nil)
        return try decode(ValidateKeyResponse.self, from: data)
    }

    /// POST /v1/accounts/{acct}/machines
    /// Auth: License <licenseKey>
    public func activateMachine(licenseKey: String,
                                licenseId: String,
                                fingerprint: String,
                                platform: String,
                                name: String) async throws -> MachineResponse {
        let path = "/v1/accounts/\(accountId)/machines"
        let body: [String: Any] = [
            "data": [
                "type": "machines",
                "attributes": [
                    "fingerprint": fingerprint,
                    "platform": platform,
                    "name": name
                ],
                "relationships": [
                    "license": [
                        "data": ["type": "licenses", "id": licenseId]
                    ]
                ]
            ]
        ]
        do {
            let data = try await post(path: path, body: body, authHeader: "License \(licenseKey)")
            return try decode(MachineResponse.self, from: data)
        } catch let httpError as HTTPError {
            if httpError.statusCode == 422 {
                // Check if it's machine limit exceeded
                if let body = httpError.body,
                   let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                   let errors = json["errors"] as? [[String: Any]] {
                    let codes = errors.compactMap { $0["code"] as? String }
                    if codes.contains(where: { $0.lowercased().contains("machine_limit") || $0.lowercased().contains("limit_exceeded") }) {
                        throw NerdKeyError.seatLimitExceeded
                    }
                    let detail = errors.compactMap { $0["detail"] as? String }.joined(separator: "; ")
                    throw NerdKeyError.invalidLicense(detail: detail)
                }
                throw NerdKeyError.seatLimitExceeded
            }
            throw httpError
        }
    }

    /// DELETE /v1/accounts/{acct}/machines/{machineId}
    /// Auth: License <licenseKey>
    public func deactivateMachine(licenseKey: String, machineId: String) async throws {
        let path = "/v1/accounts/\(accountId)/machines/\(machineId)"
        _ = try await delete(path: path, authHeader: "License \(licenseKey)")
    }

    // MARK: - HTTP primitives

    private func post(path: String, body: [String: Any], authHeader: String?) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Self.jsonAPIContentType, forHTTPHeaderField: "Content-Type")
        request.setValue(Self.jsonAPIContentType, forHTTPHeaderField: "Accept")
        if let auth = authHeader {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    private func delete(path: String, authHeader: String?) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(Self.jsonAPIContentType, forHTTPHeaderField: "Accept")
        if let auth = authHeader {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let session: URLSession
        if tlsSkipVerify {
            let config = URLSessionConfiguration.default
            session = URLSession(configuration: config, delegate: TLSSkipDelegate(), delegateQueue: nil)
        } else {
            session = URLSession.shared
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw NerdKeyError.invalidLicense(detail: "non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) || http.statusCode == 204 else {
            throw HTTPError(statusCode: http.statusCode, body: data.isEmpty ? nil : data)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NerdKeyError.invalidLicense(detail: "response parse error: \(error)")
        }
    }
}

// MARK: - TLS skip delegate

private final class TLSSkipDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - Response types

struct HTTPError: Error {
    let statusCode: Int
    let body: Data?
}

public struct ValidateKeyResponse: Decodable {
    public struct Meta: Decodable {
        public let valid: Bool
        public let detail: String?
        public let code: String?
    }
    public struct LicenseData: Decodable {
        public let id: String
        public struct Attributes: Decodable {
            public let status: String?
            public let expiry: String?
        }
        public let attributes: Attributes
    }
    public let meta: Meta
    public let data: LicenseData?
}

public struct MachineResponse: Decodable {
    public struct MachineData: Decodable {
        public let id: String
        public struct Attributes: Decodable {
            public let fingerprint: String
            public let platform: String?
            public let name: String?
        }
        public let attributes: Attributes
    }
    public let data: MachineData
}
