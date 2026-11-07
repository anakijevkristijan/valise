import SwiftUI
import UIKit
import Contacts
import ContactsUI

/// Избран контакт (само она што ни треба).
struct PickedContact {
    let name: String
    let phones: [String]
    let emails: [String]
}

/// Системскиот избирач на контакти. Не бара дозвола за целиот именик -
/// апликацијата го гледа само контактот што ќе го избереш.
final class ContactPickerPresenter: NSObject, CNContactPickerDelegate {
    static let shared = ContactPickerPresenter()

    private var completion: ((PickedContact?) -> Void)?

    func present(_ completion: @escaping (PickedContact?) -> Void) {
        self.completion = completion
        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0 OR emailAddresses.@count > 0")
        UIApplication.topViewController?.present(picker, animated: true)
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        let formatted = CNContactFormatter.string(from: contact, style: .fullName)
        let fallback = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let name = (formatted?.isEmpty == false ? formatted : nil) ?? (fallback.isEmpty ? "?" : fallback)
        let picked = PickedContact(
            name: name,
            phones: contact.phoneNumbers.map { $0.value.stringValue },
            emails: contact.emailAddresses.map { $0.value as String }
        )
        let done = completion
        completion = nil
        DispatchQueue.main.async { done?(picked) }
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        let done = completion
        completion = nil
        DispatchQueue.main.async { done?(nil) }
    }
}

extension UIApplication {
    /// Најгорниот прикажан екран (за модални прозорци од UIKit).
    static var topViewController: UIViewController? {
        let scenes = shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
