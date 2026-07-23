import Foundation

struct TaliAccountSummary: Codable, Equatable, Sendable {
    let paired: Bool
    let phone: String?
}

struct TaliSignInResult: Sendable {
    let token: String
    let expiresAt: String
    let account: TaliAccountSummary
}

struct TaliPairingCode: Sendable {
    let code: String
    let expiresAt: String
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
        session: URLSession = .shared
    ) async throws -> TaliSignInResult {
        let url = try route("v1/auth/apple", endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SignInRequest(
            identityToken: identityToken,
            nonce: nonce,
            timeZone: TimeZone.current.identifier
        ))
        let response: SignInResponse = try await send(request, session: session)
        return TaliSignInResult(
            token: response.token,
            expiresAt: response.expiresAt,
            account: response.account
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
}

private struct SignInRequest: Encodable {
    let identityToken: String
    let nonce: String
    let timeZone: String
}

private struct SignInResponse: Decodable {
    let token: String
    let expiresAt: String
    let account: TaliAccountSummary
}

private struct AccountResponse: Decodable {
    let account: TaliAccountSummary
}

private struct PairingResponse: Decodable {
    let code: String
    let expiresAt: String
}

private struct ErrorResponse: Decodable {
    let error: String
}
