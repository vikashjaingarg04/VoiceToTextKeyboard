// KeyboardViewController.swift

import UIKit
import SwiftUI
import Foundation

extension Notification.Name {
    static let insertTranscribedText = Notification.Name("insertTranscribedText")
}


class KeyboardViewController: UIInputViewController {
    let recorder = AudioRecorderViewModel()
    var hostingController: UIHostingController<VoiceToTextKeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let rootView = VoiceToTextKeyboardView(recorder: recorder)
        let hc = UIHostingController(rootView: rootView)
        hc.view.frame = view.bounds
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hc.view)
        hostingController = hc

        // 🔔 Observe transcription text from ViewModel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(insertTranscribedText(_:)),
            name: .insertTranscribedText,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .insertTranscribedText, object: nil)
    }

    // 🔤 Insert into host app via textDocumentProxy
    @objc private func insertTranscribedText(_ notification: Notification) {
        guard let text = notification.object as? String else { return }

        // Always on main thread
        DispatchQueue.main.async {
            self.textDocumentProxy.insertText(text)
            // (Optional) Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.prepare()
            impact.impactOccurred()
            print("✅ Text inserted via keyboard: \(text)")
        }
    }
}
