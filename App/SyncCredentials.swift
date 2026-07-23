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
        method: AuthenticationMethod = .privateKey
    ) throws {
        let data = Data(token.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
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
    }

    static var isConfigured: Bool {
        !endpoint.isEmpty && !token().isEmpty
    }

    private static let defaults = UserDefaults(suiteName: PersistenceController.appGroupIdentifier) ?? .standard
    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
    }
}
