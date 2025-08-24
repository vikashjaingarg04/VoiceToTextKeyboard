//
//  KeyboardViewController.swift
//  VoiceToTextKeyboardExtension
//
//  Created by Ankit Jain on 24/08/25.
//

import UIKit
import SwiftUI

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
        
        // Listen for transcribed text to insert it at cursor
        NotificationCenter.default.addObserver(self, selector: #selector(insertTranscribedText(_:)), name: .insertTranscribedText, object: nil)
    }
    @objc func insertTranscribedText(_ notification: Notification) {
        guard let text = notification.object as? String else { return }
        self.textDocumentProxy.insertText(text)
    }
}
