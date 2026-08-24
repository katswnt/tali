import Foundation
import HabitCore
import Security

@MainActor
enum SyncCredentials {
    enum AuthenticationMethod: String {
        case privateKey
        case apple
    }

    static let defaultEndpoint = "https://tali-sms.katswint.workers.dev"
    static let smsPhoneNumber = "+1 (445) 545-2123"

    static let endpointKey = "smsSyncEndpoint"
    private static let authenticationMethodKey = "smsSyncAuthenticationMethod"
    private static let tokenAccount = "smsSyncToken"
    private static let service = "com.kathrynswint.Tali.sync"
    private static let accessTokenRefresh = AsyncSingleFlight<String>()

    static var endpoint: String {
        get {
            if let stored = defaults.string(forKey: endpointKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !stored.isEmpty {
                return stored
            }
            return defaultEndpoint
        }
        set { defaults.set(newValue, forKey: endpointKey) }
    }

    static func token() -> String {
        credentialEnvelope()?.accessToken ?? storedCredential()
    }

    static func validAccessToken(session: URLSession = .shared) async throws -> String {
        let accessToken = token()
        guard authenticationMethod == .apple,
              let envelope = credentialEnvelope(),
              !envelope.refreshToken.isEmpty else {
            return accessToken
        }

        if let expiration = try? Date(envelope.accessExpiresAt, strategy: .iso8601),
           expiration.timeIntervalSinceNow > 60 {
            return accessToken
        }

        let refreshToken = envelope.refreshToken
        let refreshEndpoint = endpoint
        return try await accessTokenRefresh.run {
            let refreshed = try await TaliAccountService.refresh(
                endpoint: refreshEndpoint,
                refreshToken: refreshToken,
                session: session
            )
            try save(
                endpoint: refreshEndpoint,
                token: refreshed.accessToken,
                refreshToken: refreshed.refreshToken,
                accessExpiresAt: refreshed.accessExpiresAt,
                sessionExpiresAt: refreshed.sessionExpiresAt,
                method: .apple
            )
            return refreshed.accessToken
        }
    }

    static func refreshToken() -> String {
        credentialEnvelope()?.refreshToken ?? ""
    }

    private static func storedCredential() -> String {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    static var authenticationMethod: AuthenticationMethod {
        AuthenticationMethod(rawValue: defaults.string(forKey: authenticationMethodKey) ?? "") ?? .privateKey
    }

    static func save(
        endpoint: String,
        token: String,
        refreshToken: String? = nil,
        accessExpiresAt: String? = nil,
        sessionExpiresAt: String? = nil,
        method: AuthenticationMethod = .privateKey
    ) throws {
        let cleanedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let data: Data
        if method == .apple, let refreshToken, let accessExpiresAt, let sessionExpiresAt {
            data = try JSONEncoder().encode(CredentialEnvelope(
                accessToken: cleanedToken,
                refreshToken: refreshToken,
                accessExpiresAt: accessExpiresAt,
                sessionExpiresAt: sessionExpiresAt
            ))
        } else {
            data = Data(cleanedToken.utf8)
        }
        let attributes = [kSecValueData as String: data]
        var status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            status = SecItemAdd(query as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Tali couldn't save the sync token securely."]
            )
        }
        self.endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(method.rawValue, forKey: authenticationMethodKey)
    }

    static func clear() throws {
        let previousEndpoint = endpoint
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Tali couldn't remove the private connection key."]
            )
        }
        defaults.removeObject(forKey: endpointKey)
        defaults.removeObject(forKey: authenticationMethodKey)
        TaliSyncService.resetCursor(endpoint: previousEndpoint)
    }

    static var isConfigured: Bool {
        !TaliTestEnvironment.isUITesting && !endpoint.isEmpty && !token().isEmpty
    }

    @discardableResult
    static func invalidateIfNeeded(for error: Error) -> Bool {
        let isUnauthorized: Bool
        if let accountError = error as? TaliAccountError,
           case .unauthorized = accountError {
            isUnauthorized = true
        } else if let syncError = error as? TaliSyncError,
                  case .unauthorized = syncError {
            isUnauthorized = true
        } else {
            isUnauthorized = false
        }

        guard isUnauthorized, authenticationMethod == .apple else { return false }
        try? clear()
        return true
    }

    private static let defaults = UserDefaults(suiteName: PersistenceController.appGroupIdentifier) ?? .standard

    private static func credentialEnvelope() -> CredentialEnvelope? {
        guard let data = storedCredential().data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CredentialEnvelope.self, from: data)
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
    }
}

private struct CredentialEnvelope: Codable {
    let accessToken: String
    let refreshToken: String
    let accessExpiresAt: String
    let sessionExpiresAt: String
}
