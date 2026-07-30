import Foundation

struct TaliAccountSummary: Codable, Equatable, Sendable {
    let paired: Bool
    let phone: String?
}

struct TaliSignInResult: Sendable {
    let accessToken: String
    let refreshToken: String
    let accessExpiresAt: String
    let sessionExpiresAt: String
    let account: TaliAccountSummary
}

struct TaliSessionTokens: Sendable {
    let accessToken: String
    let refreshToken: String
    let accessExpiresAt: String
    let sessionExpiresAt: String
}

struct TaliPairingCode: Sendable {
    let code: String
    let expiresAt: String
}

struct TaliSessionSummary: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let deviceName: String
    let createdAt: String
    let lastUsedAt: String
    let expiresAt: String
    let current: Bool
}

enum TaliAccountError: LocalizedError {
    case invalidEndpoint
    case unauthorized
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Tali’s server address is invalid."
        case .unauthorized:
            return "This sign-in is no longer valid. Sign in again to reconnect."
        case .server(let message):
            return message
        case .invalidResponse:
            return "Tali received an invalid account response."
        }
    }
}

enum TaliAccountService {
    static func signIn(
        endpoint: String,
        identityToken: String,
        nonce: String,
        deviceName: String,
        session: URLSession = .shared
    ) async throws -> TaliSignInResult {
        let url = try route("v1/auth/apple", endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SignInRequest(
            identityToken: identityToken,
            nonce: nonce,
            timeZone: TimeZone.current.identifier,
            deviceName: deviceName
        ))
        let response: SignInResponse = try await send(request, session: session)
        return TaliSignInResult(
            accessToken: response.accessToken ?? response.token,
            refreshToken: response.refreshToken ?? "",
            accessExpiresAt: response.accessExpiresAt ?? response.expiresAt,
            sessionExpiresAt: response.sessionExpiresAt ?? response.expiresAt,
            account: response.account
        )
    }

    static func refresh(
        endpoint: String,
        refreshToken: String,
        session: URLSession = .shared
    ) async throws -> TaliSessionTokens {
        var request = URLRequest(url: try route("v1/auth/refresh", endpoint: endpoint))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RefreshRequest(refreshToken: refreshToken))
        let response: RefreshResponse = try await send(request, session: session)
        return TaliSessionTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            accessExpiresAt: response.accessExpiresAt,
            sessionExpiresAt: response.sessionExpiresAt
        )
    }

    static func account(
        endpoint: String,
        token: String,
        session: URLSession = .shared
    ) async throws -> TaliAccountSummary {
        var request = URLRequest(url: try route("v1/account", endpoint: endpoint))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let response: AccountResponse = try await send(request, session: session)
        return response.account
    }

    static func createPairingCode(
        endpoint: String,
        token: String,
        session: URLSession = .shared
    ) async throws -> TaliPairingCode {
        var request = URLRequest(url: try route("v1/pairing/code", endpoint: endpoint))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let response: PairingResponse = try await send(request, session: session)
        return TaliPairingCode(code: response.code, expiresAt: response.expiresAt)
    }

    static func sessions(
        endpoint: String,
        token: String,
        session: URLSession = .shared
    ) async throws -> [TaliSessionSummary] {
        var request = URLRequest(url: try route("v1/sessions", endpoint: endpoint))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let response: SessionsResponse = try await send(request, session: session)
        return response.sessions
    }

    static func revokeSession(
        id: String,
        endpoint: String,
        token: String,
        session: URLSession = .shared
    ) async throws {
        var request = URLRequest(url: try route("v1/sessions/\(id)", endpoint: endpoint))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        try await sendEmpty(request, session: session)
    }

    static func revokeAllSessions(
        endpoint: String,
        token: String,
        session: URLSession = .shared
    ) async throws {
        var request = URLRequest(url: try route("v1/sessions", endpoint: endpoint))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        try await sendEmpty(request, session: session)
    }

    static func exportData(
        endpoint: String,
        token: String,
        session: URLSession = .shared
    ) async throws -> Data {
        var request = URLRequest(url: try route("v1/account/export", endpoint: endpoint))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data = try await sendData(request, session: session)
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["formatVersion"] as? Int == 1 else {
            throw TaliAccountError.invalidResponse
        }
        return data
    }

    static func deleteAccount(
        endpoint: String,
        token: String,
        session: URLSession = .shared
    ) async throws {
        var request = URLRequest(url: try route("v1/account", endpoint: endpoint))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DeleteAccountRequest(confirmation: "DELETE"))
        try await sendEmpty(request, session: session)
    }

    static func signOut(
        endpoint: String,
        token: String,
        session: URLSession = .shared
    ) async {
        guard let url = try? route("v1/session", endpoint: endpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
    }

    private static func route(_ path: String, endpoint: String) throws -> URL {
        let value = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: value),
              components.scheme == "https",
              components.host != nil else {
            throw TaliAccountError.invalidEndpoint
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, path].filter { !$0.isEmpty }.joined(separator: "/")
        guard let url = components.url else { throw TaliAccountError.invalidEndpoint }
        return url
    }

    private static func send<Response: Decodable>(
        _ request: URLRequest,
        session: URLSession
    ) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw TaliAccountError.invalidResponse
        }
        if response.statusCode == 401 { throw TaliAccountError.unauthorized }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data).error)
                ?? "Tali’s server returned HTTP \(response.statusCode)."
            throw TaliAccountError.server(message)
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw TaliAccountError.invalidResponse
        }
        return decoded
    }

    private static func sendData(
        _ request: URLRequest,
        session: URLSession
    ) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private static func sendEmpty(
        _ request: URLRequest,
        session: URLSession
    ) async throws {
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw TaliAccountError.invalidResponse
        }
        if response.statusCode == 401 { throw TaliAccountError.unauthorized }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data).error)
                ?? "Tali’s server returned HTTP \(response.statusCode)."
            throw TaliAccountError.server(message)
        }
    }
}

private struct SignInRequest: Encodable {
    let identityToken: String
    let nonce: String
    let timeZone: String
    let deviceName: String
}

private struct SignInResponse: Decodable {
    let token: String
    let expiresAt: String
    let accessToken: String?
    let refreshToken: String?
    let accessExpiresAt: String?
    let sessionExpiresAt: String?
    let account: TaliAccountSummary
}

private struct RefreshRequest: Encodable {
    let refreshToken: String
}

private struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let accessExpiresAt: String
    let sessionExpiresAt: String
}

private struct AccountResponse: Decodable {
    let account: TaliAccountSummary
}

private struct PairingResponse: Decodable {
    let code: String
    let expiresAt: String
}

private struct SessionsResponse: Decodable {
    let sessions: [TaliSessionSummary]
}

private struct DeleteAccountRequest: Encodable {
    let confirmation: String
}

private struct ErrorResponse: Decodable {
    let error: String
}
