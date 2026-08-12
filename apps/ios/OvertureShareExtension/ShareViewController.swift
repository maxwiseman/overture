import SwiftUI
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let host = UIHostingController(
            rootView: ShareImportView(
                extensionContext: extensionContext,
                cancel: { [weak self] in self?.extensionContext?.cancelRequest(withError: ShareImportError.cancelled) }
            )
        )
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }
}

private enum ShareImportError: LocalizedError {
    case cancelled

    var errorDescription: String? { "The Overture import was cancelled." }
}
