import HabitCore
import Messages
import SwiftData
import SwiftUI

@MainActor
final class MessagesViewController: MSMessagesAppViewController {
    private var container: ModelContainer?
    private var storeErrorMessage: String?
    private var hostingController: UIHostingController<AnyView>?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        openStore()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        openStore()
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
        let rootView: AnyView
        if let container {
            rootView = AnyView(
                MessagesRootView { [weak self] receipt in
                    self?.insert(receipt: receipt)
                }
                .modelContainer(container)
            )
        } else {
            rootView = AnyView(
                MessagesStoreUnavailableView(
                    message: storeErrorMessage ?? "Tali couldn’t open its shared habit data."
                ) { [weak self] in
                    self?.openStore()
                    self?.installRootView()
                }
            )
        }

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

    private func openStore() {
        do {
            container = try PersistenceController.makeContainer()
            storeErrorMessage = nil
        } catch {
            container = nil
            storeErrorMessage = error.localizedDescription
        }
    }

    private func insert(receipt: HabitReceipt) {
        guard let conversation = activeConversation else { return }

        let text = "✓ \(receipt.habitName) — Logged "
            + "\(HabitFormatting.timestamp(receipt.occurredAt)) with Tali"
        conversation.insertText(text) { [weak self] error in
            guard error == nil else { return }
            Task { @MainActor in
                self?.requestPresentationStyle(.compact)
            }
        }
    }
}

private struct MessagesStoreUnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Tali couldn’t open your habits", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}
