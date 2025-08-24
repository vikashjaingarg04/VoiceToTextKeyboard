//
//  ContentView.swift
//  VoiceToTextKeyboard
//
//  Created by Ankit Jain on 24/08/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("Voice-To-Text Keyboard")
                .font(.title)
                .bold()
            Text("To use this keyboard:\n- Enable 'VoiceToTextKeyboard' in Settings > Keyboards.\n- Select it in any app.\n- Press & hold the button to record.\n- Release to transcribe and insert text.")
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
