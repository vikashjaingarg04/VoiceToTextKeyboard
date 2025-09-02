import Foundation
import SwiftUI

struct VoiceToTextKeyboardView: View {
    @ObservedObject var recorder: AudioRecorderViewModel
    @State private var isPressed = false
    
    // Theme configuration
    private var theme: KeyboardTheme {
        return KeyboardTheme.systemDefault
    }
    
    // Haptic feedback
    private let impactMed = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    
    // Button background color based on state
    private var buttonBackground: Color {
        switch recorder.state {
        case .recording: return .red
        case .processing: return theme.buttonColor.opacity(0.7)
        case .error: return .red.opacity(0.8)
        case .complete: return .green.opacity(0.8)
        default: return theme.buttonColor
        }
    }
    
    // Button icon based on state
    private var buttonIcon: String {
        switch recorder.state {
        case .recording: return "waveform"
        case .processing: return "hourglass"
        case .error: return "exclamationmark.triangle"
        case .complete: return "checkmark"
        default: return "mic.fill"
        }
    }

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
                    // Pulsing animation when recording
                    if recorder.state == .recording {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .scaleEffect(isPressed ? 1.0 : 1.2)
                            .opacity(isPressed ? 0.7 : 0.0)
                            .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPressed)
                    }
                    
                    // Main button
                    Circle()
                        .fill(buttonBackground)
                        .frame(width: 80, height: 80)
                        .shadow(color: theme.textColor.opacity(0.25), radius: 10)
                        .overlay(
                            Group {
                                if recorder.state == .processing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: buttonIcon)
                                        .font(.system(size: 34))
                                        .foregroundColor(.white)
                                }
                            }
                        )
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                }
            }
            // Press & hold gestures
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.1)
                    .onChanged { _ in
                        isPressed = true
                        impactHeavy.impactOccurred()
                        recorder.startRecording()
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        isPressed = false
                        impactMed.impactOccurred()
                        recorder.stopRecording()
                        
                        // Reset button state after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation {
                                isPressed = false
                            }
                        }
                    }
            )

            Text(recorder.statusMessage)
                .font(.footnote)
                .foregroundColor(recorder.state == .error ? .red : theme.textColor)
                .padding(.top, 4)
                .multilineTextAlignment(.center)
                .frame(height: 40)
                .transition(.opacity)
                .animation(.easeInOut, value: recorder.statusMessage)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.background)
        .onAppear {
            // Prepare haptics
            impactMed.prepare()
            impactHeavy.prepare()
        }
    }
}
