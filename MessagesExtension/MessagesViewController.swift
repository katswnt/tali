import HabitCore
import Messages
import SwiftData
import SwiftUI

@MainActor
final class MessagesViewController: MSMessagesAppViewController {
    private let container: ModelContainer
    private var hostingController: UIHostingController<AnyView>?

    required init?(coder: NSCoder) {
        do {
            container = try PersistenceController.makeContainer()
        } catch {
            return nil
        }
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        installRootView()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        installRootView()
    }

    private func installRootView() {
        let rootView = AnyView(
            MessagesRootView { [weak self] receipt in
                self?.insert(receipt: receipt)
            }
            .modelContainer(container)
        )

        if let hostingController {
            hostingController.rootView = rootView
            return
        }

        let controller = UIHostingController(rootView: rootView)
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        hostingController = controller
    }

    private func insert(receipt: HabitReceipt) {
        guard let conversation = activeConversation else { return }

        let layout = MSMessageTemplateLayout()
        layout.caption = "✓ \(receipt.habitName)"
        layout.subcaption = "Logged \(HabitFormatting.timestamp(receipt.occurredAt))"

        let message = MSMessage()
        message.layout = layout
        message.summaryText = "Logged \(receipt.habitName) in Tali"

        var components = URLComponents()
        components.scheme = "tali"
        components.host = "event"
        components.queryItems = [
            URLQueryItem(name: "habit", value: receipt.habitName),
            URLQueryItem(name: "date", value: receipt.occurredAt.ISO8601Format())
        ]
        message.url = components.url

        conversation.insert(message) { [weak self] error in
            guard error == nil else { return }
            Task { @MainActor in
                self?.requestPresentationStyle(.compact)
            }
        }
    }
}
