import Foundation
import SwiftUI

struct VoiceToTextKeyboardView: View {
    @ObservedObject var recorder: AudioRecorderViewModel

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            // 🔊 Waveform दिखाएँ recording/processing में
            if recorder.state == .recording || recorder.state == .processing {
                WaveformView(samples: recorder.waveformSamples)
                    .foregroundStyle(recorder.state == .recording ? .blue : .gray)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(recorder.state == .recording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                        .shadow(radius: 10)
                        .overlay(
                            Group {
                                if recorder.state == .processing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                }
                            }
                        )

                    Image(systemName: "mic.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                }
                // 🎯 अब पूरा ZStack (dot + mic) ek साथ scale hoga
                .scaleEffect(recorder.state == .recording ? 1.1 : 1.0)
                .animation(.easeInOut, value: recorder.state)
            }
            // Press & hold gesture
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.1)
                    .onEnded { _ in
                        recorder.startRecording()
                    }
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        recorder.stopRecording()
                    }
            )

            Text(recorder.statusMessage)
                .font(.footnote)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }
}
