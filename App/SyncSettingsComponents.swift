import Contacts
import ContactsUI
import SwiftUI
import UIKit

struct TextingConnectionHeader: View {
    let title: String
    let detail: String
    var connected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                title,
                systemImage: connected ? "link.circle.fill" : "message.badge.waveform.fill"
            )
            .font(.headline)
            .foregroundStyle(.blue)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct TextingStatusRows: View {
    let resultMessage: String?
    let errorMessage: String?

    var body: some View {
        if let resultMessage {
            Label(resultMessage, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.blue)
                .accessibilityLabel("Complete: \(resultMessage)")
                .accessibilityAddTraits(.updatesFrequently)
        }
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Error: \(errorMessage)")
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

struct TaliContactSheet: UIViewControllerRepresentable {
    let completion: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()
        contact.givenName = "Tali"
        contact.organizationName = "Tali"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+1 445-545-2123"))
        ]
        contact.urlAddresses = [
            CNLabeledValue(label: CNLabelURLAddressHomePage, value: "https://tali-sms.katswint.workers.dev/sms" as NSString)
        ]
        contact.imageData = appIconData()

        let contactController = CNContactViewController(forNewContact: contact)
        contactController.delegate = context.coordinator
        contactController.allowsEditing = true
        contactController.allowsActions = false
        contactController.message = "Save Tali so her texts have a name and photo."
        return UINavigationController(rootViewController: contactController)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        private let completion: (Bool) -> Void

        init(completion: @escaping (Bool) -> Void) {
            self.completion = completion
        }

        func contactViewController(
            _ viewController: CNContactViewController,
            didCompleteWith contact: CNContact?
        ) {
            completion(contact != nil)
        }
    }

    private func appIconData() -> Data? {
        guard
            let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let filenames = primary["CFBundleIconFiles"] as? [String]
        else { return nil }

        for filename in filenames.reversed() {
            if let image = UIImage(named: filename), let data = image.pngData() {
                return data
            }
            if let url = Bundle.main.url(forResource: filename, withExtension: "png"),
               let data = try? Data(contentsOf: url) {
                return data
            }
        }
        return nil
    }
}
