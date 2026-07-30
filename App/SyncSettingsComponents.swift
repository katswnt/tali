import Contacts
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
            .foregroundStyle(Color.accentColor)
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
                .foregroundStyle(Color.accentColor)
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

enum TaliContactService {
    private static let phoneNumber = "+1 445-545-2123"
    private static let homepage = "https://tali-sms.katswint.workers.dev/sms"

    static func save() async throws -> Bool {
        let store = CNContactStore()
        guard try await canWriteContacts(using: store) else {
            throw TaliContactError.accessDenied
        }
        guard let imageData = UIImage(named: "TaliContact")?.jpegData(compressionQuality: 0.92) else {
            throw TaliContactError.missingImage
        }

        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactTypeKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
        ]
        let matches = try store.unifiedContacts(
            matching: CNContact.predicateForContacts(
                matching: CNPhoneNumber(stringValue: phoneNumber)
            ),
            keysToFetch: keys
        )
        let existing = matches.first
        let contact = (existing?.mutableCopy() as? CNMutableContact) ?? CNMutableContact()

        contact.contactType = .organization
        contact.givenName = "Tali"
        contact.organizationName = "Tali"
        contact.imageData = imageData
        if !contact.phoneNumbers.contains(where: { samePhone($0.value.stringValue, phoneNumber) }) {
            contact.phoneNumbers.append(
                CNLabeledValue(
                    label: CNLabelPhoneNumberMobile,
                    value: CNPhoneNumber(stringValue: phoneNumber)
                )
            )
        }
        if !contact.urlAddresses.contains(where: { $0.value as String == homepage }) {
            contact.urlAddresses.append(
                CNLabeledValue(label: CNLabelURLAddressHomePage, value: homepage as NSString)
            )
        }

        let request = CNSaveRequest()
        if existing == nil {
            request.add(contact, toContainerWithIdentifier: nil)
        } else {
            request.update(contact)
        }
        try store.execute(request)
        return existing != nil
    }

    private static func canWriteContacts(using store: CNContactStore) async throws -> Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return try await store.requestAccess(for: .contacts)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private static func samePhone(_ lhs: String, _ rhs: String) -> Bool {
        lhs.filter(\.isNumber) == rhs.filter(\.isNumber)
    }
}

private enum TaliContactError: LocalizedError {
    case accessDenied
    case missingImage

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Allow Tali to access Contacts in Settings, then try again."
        case .missingImage:
            return "Tali couldn’t load its contact photo. Reinstall this build and try again."
        }
    }
}
