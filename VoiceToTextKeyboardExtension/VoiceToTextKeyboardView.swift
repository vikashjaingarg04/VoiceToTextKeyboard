import Foundation
import SwiftUI

struct VoiceToTextKeyboardView: View {
    @ObservedObject var recorder: AudioRecorderViewModel
    var theme: KeyboardTheme = .systemDefault   // 🔑 default theme
    
    // Haptic feedback
    private let impactMed = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            // Waveform
            if recorder.state == .recording || recorder.state == .processing {
                WaveformView(samples: recorder.waveformSamples)
                    .foregroundStyle(theme.buttonColor)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(recorder.state == .recording ? Color.red : theme.buttonColor)
                        .frame(width: 80, height: 80)
                        .shadow(color: theme.textColor.opacity(0.25), radius: 10)
                        .overlay(
                            Group {
                                if recorder.state == .processing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: theme.textColor))
                                }
                            }
                        )
                        .scaleEffect(recorder.state == .recording ? 1.1 : 1.0)
                        .animation(.easeInOut, value: recorder.state)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                }
            }
            // Press & hold gestures
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.1)
                    .onEnded { _ in
                        impactHeavy.impactOccurred()
                        recorder.startRecording()
                    }
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        impactMed.impactOccurred()
                        recorder.stopRecording()
                    }
            )

            Text(recorder.statusMessage)
                .font(.footnote)
                .foregroundColor(theme.textColor)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.background)
    }
}
