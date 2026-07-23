import AuthenticationServices
import CryptoKit
import SwiftUI

struct TaliAppleSignInButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let isWorking: Bool
    let completion: (_ identityToken: String, _ nonce: String) -> Void
    let failure: (_ message: String) -> Void

    @State private var nonce = ""

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            let rawNonce = UUID().uuidString
            nonce = rawNonce
            request.requestedScopes = []
            request.nonce = sha256(rawNonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let data = credential.identityToken,
                      let identityToken = String(data: data, encoding: .utf8),
                      !nonce.isEmpty else {
                    failure("Apple didn’t return the information Tali needs. Try again.")
                    return
                }
                completion(identityToken, nonce)
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code != .canceled {
                    failure(error.localizedDescription)
                }
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .allowsHitTesting(!isWorking)
        .opacity(isWorking ? 0.6 : 1)
        .accessibilityLabel("Continue with Apple")
    }

    private func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
