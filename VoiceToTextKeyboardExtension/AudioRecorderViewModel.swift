import Foundation
import AVFoundation
import SwiftUI
import UIKit

// MARK: - Notification name used by KeyboardViewController


enum RecorderState {
    case idle, recording, processing, complete, error
}

struct TranscriptionResponse: Codable {
    let text: String
    let x_groq: XGroq?
    
    struct XGroq: Codable {
        let id: String
    }
}
func setupAudioSession() {
    do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        print("Audio session configured successfully")
    } catch {
        print("Audio session configuration failed: \(error.localizedDescription)")
    }
}

class AudioRecorderViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var state: RecorderState = .idle
    @Published var statusMessage: String = "Press and hold to speak"
    @Published var waveformSamples: [CGFloat] = Array(repeating: 0.0, count: 40)

    // Device (real) recording
    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    // Simulator fake waveform
    private var fakeWaveTimer: Timer?

    var recordedFileURL: URL?

    // MARK: - Haptic Feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Audio Session Management
    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
        )
        try session.setPreferredIOBufferDuration(0.1) // Lower latency for speech
        try session.setPreferredSampleRate(44100.0) // Standard sample rate
        try session.setActive(true, options: [.notifyOthersOnDeactivation, .init(rawValue: AVAudioSession.CategoryOptions.duckOthers.rawValue)])
    }
    
    private func resetAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error resetting audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Recording Logic (NO real-time transcription)
    func startRecording() {
        guard state != .recording else { return } // prevent double start
        
        // Prepare haptics
        impactFeedback.prepare()
        notificationFeedback.prepare()
        
        // Reset any previous recording
        recordedFileURL = nil

        #if targetEnvironment(simulator)
        // -------- SIMULATOR PATH: don't touch AVAudioSession, just simulate recording --------
        self.state = .recording
        self.statusMessage = "Recording (simulated)…"
        impactFeedback.impactOccurred()

        // test.m4a must be added to the Keyboard Extension target!
        let bundle = Bundle(for: AudioRecorderViewModel.self)
        if let testURL = bundle.url(forResource: "test", withExtension: "m4a") {
            self.recordedFileURL = testURL
        } else {
            self.fail("test.m4a not found in extension bundle.", nil)
            return
        }

        // animate fake waveform so UI looks alive
        startFakeWave()
        #else
        // -------- REAL DEVICE PATH: use AVAudioRecorder --------
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // First deactivate any active session
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Configure audio session with minimal options
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .mixWithOthers]
            )
            
            // Request record permission
            audioSession.requestRecordPermission { [weak self] (allowed: Bool) in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    guard allowed else {
                        self.fail("Microphone permission denied.", nil)
                        return
                    }

                    self.state = .recording
                    self.statusMessage = "Recording..."

                    let settings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 44_100.0,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                        AVEncoderBitRateKey: 128_000,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsFloatKey: false,
                        AVSampleRateConverterAudioQualityKey: AVAudioQuality.high.rawValue
                    ]

                    let tempDir = FileManager.default.temporaryDirectory
                    let fileURL = tempDir.appendingPathComponent("recorded.m4a")
                    self.recordedFileURL = fileURL

                    do {
                        self.audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
                        self.audioRecorder?.delegate = self
                        self.audioRecorder?.isMeteringEnabled = true
                        
                        // Activate audio session and start recording
                        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                        self.recordingStartTime = Date()
                        self.audioRecorder?.record()
                        self.startMetering()
                        
                        // Start recording timer
                        self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                            guard let self = self, let startTime = self.recordingStartTime else { return }
                            let elapsed = Date().timeIntervalSince(startTime)
                            self.statusMessage = String(format: "Recording... %.1fs", elapsed)
                        }
                    } catch {
                        self.fail("Failed to start recording: \(error.localizedDescription)", error)
                    }
                }
            }
        } catch {
            fail("Audio session configuration failed.", error)
        }
        #endif
    }

    func stopRecording() {
        guard state == .recording else { 
            print("⚠️ stopRecording called but not in recording state")
            return 
        }
        print("⏹️ stopRecording called")
        
        // Provide haptic feedback
        impactFeedback.impactOccurred()
        
        // Stop any ongoing recording
        #if targetEnvironment(simulator)
        stopFakeWave()
        #else
        guard let recorder = audioRecorder else {
            self.fail("No active recording", nil)
            return
        }
        
        // Get duration before stopping
        let duration = recorder.currentTime
        recorder.stop()
        stopMetering()
        
        // No minimum duration required
        
        // Deactivate audio session on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                
                // Only proceed with transcription if we have a valid recording
                DispatchQueue.main.async {
                    self?.state = .processing
                    self?.statusMessage = "Processing..."
                    self?.transcribeAudio()
                }
            } catch {
                print("Error deactivating audio session: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.fail("Error finalizing recording.", error)
                }
            }
        }
        #endif
    }

    // MARK: - Metering for real device waveform
    private func startMetering() {
        stopMetering()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let r = self.audioRecorder else { return }
            r.updateMeters()
            let db = r.averagePower(forChannel: 0) // -160...0 dB
            let level = self.normalized(db)
            self.pushSample(level)
        }
        if let timer = meterTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }

    // MARK: - Fake waveform for simulator
    private func startFakeWave() {
        stopFakeWave()
        fakeWaveTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // random-ish level 0...1
            let value = CGFloat(Double.random(in: 0.05...1.0))
            self.pushSample(value)
        }
        if let timer = fakeWaveTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func stopFakeWave() {
        fakeWaveTimer?.invalidate()
        fakeWaveTimer = nil
    }

    // MARK: - Waveform helpers
    private func pushSample(_ value: CGFloat) {
        waveformSamples.append(value)
        if waveformSamples.count > 40 { waveformSamples.removeFirst() }
    }

    private func normalized(_ decibels: Float) -> CGFloat {
        if decibels <= -80 { return 0 }
        let linear = pow(10.0, decibels / 20.0)
        return CGFloat(min(max(linear, 0), 1))
    }

    private func fail(_ message: String, _ error: Error?) {
        self.state = .error
        self.statusMessage = message
        if let error { 
            print("❌ \(message) – \(error.localizedDescription)")
        } else { 
            print("❌ \(message)")
        }
        notificationFeedback.notificationOccurred(.error)
        stopMetering()
        stopFakeWave()
        resetAudioSession()
    }

    // MARK: - AVAudioRecorderDelegate
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Encoding error: \(error.localizedDescription)")
            DispatchQueue.main.async { self.fail("Recording encoding error.", error) }
        }
    }

    // MARK: - Transcription (only after stop)
    func transcribeAudio() {
        guard let url = recordedFileURL else {
            self.fail("Recording file not found.", nil)
            print("No recorded file at URL")
            return
        }
        
        // Verify file exists and has content
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? Int64, fileSize > 0 else {
                self.fail("Recording file is empty.", nil)
                return
            }
            print("📁 File size: \(fileSize) bytes")
        } catch {
            self.fail("Error reading recording file: \(error.localizedDescription)", error)
            return
        }

#if targetEnvironment(simulator)
        // Simulator tip: you can still hit the API from simulator.
        // If you want to completely avoid network during UI testing,
        // uncomment the next 4 lines to mock a response.
        /*
        self.state = .complete
        self.statusMessage = "Inserted text"
        self.insertTextInKeyboard("This is a simulated transcription from test.m4a")
        return
        */
#endif
        

        // Get API key from Keychain or configuration
        // In a real app, you should use the Keychain to store sensitive data
        // For now, we'll use a placeholder - replace with your actual API key
        let apiKey = "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" // TODO: Replace with your actual API key
        
        guard !apiKey.isEmpty, apiKey != "YOUR_GROQ_API_KEY" else {
            self.fail("API key not configured. Please update in AudioRecorderViewModel.swift", nil)
            return
        }
        
        let endpoint = "https://api.groq.com/openai/v1/audio/transcriptions"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var body = Data()
        // file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recorded.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        if let audioData = try? Data(contentsOf: url), !audioData.isEmpty {
            body.append(audioData)
        } else {
            self.fail("Audio file is empty.", nil)
            print("⚠️ Audio file empty or missing at: \(url)")
            return
        }
        body.append("\r\n".data(using: .utf8)!)

        // model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-large-v3".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // language
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body


        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.fail("Network error: \(error.localizedDescription)", error)
                    return
                }
                guard let data = data else {
                    self.fail("No data received.", nil)
                    return
                }

                // Debug raw body (helpful during dev)
                if let raw = String(data: data, encoding: .utf8) {
                    print("📩 Raw API Response:\n\(raw)")
                }

                do {
                    let json = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
                    let transcript = json.text
                    self.state = .complete
                    self.statusMessage = "Inserted text"
                    self.insertTextInKeyboard(transcript)
                    print("✅ Transcript Inserted: \(transcript)")
                } catch {
                    self.fail("Failed to decode transcription response: \(error.localizedDescription)", error)
                    print("Failed to decode transcription response: \(error)")
                }

            }
        }.resume()
    }

    // MARK: - Insert text into host app via keyboard
    // AudioRecorderViewModel.swift
    func insertTextInKeyboard(_ text: String) {
        NotificationCenter.default.post(name: .insertTranscribedText, object: text)
        notificationFeedback.notificationOccurred(.success)
    }

}
