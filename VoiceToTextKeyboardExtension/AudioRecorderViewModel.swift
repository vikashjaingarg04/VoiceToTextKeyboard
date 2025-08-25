import Foundation
import AVFoundation
import SwiftUI

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


class AudioRecorderViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var state: RecorderState = .idle
    @Published var statusMessage: String = "Press and hold to speak"
    @Published var waveformSamples: [CGFloat] = Array(repeating: 0.0, count: 40)

    // Device (real) recording
    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?

    // Simulator fake waveform
    private var fakeWaveTimer: Timer?

    var recordedFileURL: URL?

    // MARK: - Recording Logic (NO real-time transcription)
    func startRecording() {
        guard state != .recording else { return } // prevent double start

        #if targetEnvironment(simulator)
        // -------- SIMULATOR PATH: don't touch AVAudioSession, just simulate recording --------
        self.state = .recording
        self.statusMessage = "Recording (simulated)…"

        // test.m4a must be added to the Keyboard Extension target!
        let bundle = Bundle(for: AudioRecorderViewModel.self)
        if let testURL = bundle.url(forResource: "test", withExtension: "m4a") {
            self.recordedFileURL = testURL
        } else {
            self.fail("test.m4a not found in extension bundle.", nil)
        }

        // animate fake waveform so UI looks alive
        startFakeWave()
        #else
        // -------- REAL DEVICE PATH: use AVAudioRecorder --------
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            session.requestRecordPermission { [weak self] allowed in
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
                        AVSampleRateKey: 44_100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]

                    let tempDir = FileManager.default.temporaryDirectory
                    let fileURL = tempDir.appendingPathComponent("recorded.m4a")
                    self.recordedFileURL = fileURL

                    do {
                        self.audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
                        self.audioRecorder?.delegate = self
                        self.audioRecorder?.isMeteringEnabled = true
                        self.audioRecorder?.record()
                        self.startMetering()
                    } catch {
                        self.fail("Failed to start recording.", error)
                    }
                }
            }
        } catch {
            fail("Audio session configuration failed.", error)
        }
        #endif
    }

    func stopRecording() {
        guard state == .recording else { return }
        print("stopRecording called")

        #if targetEnvironment(simulator)
        stopFakeWave()
        #else
        audioRecorder?.stop()
        stopMetering()
        #endif

        self.state = .processing
        self.statusMessage = "Processing..."
        transcribeAudio()
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
        if let error { print("❌ \(message) – \(error.localizedDescription)") } else { print("❌ \(message)") }
        stopMetering()
        stopFakeWave()
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
        

        let endpoint = "https://api.groq.com/openai/v1/audio/transcriptions"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer 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", forHTTPHeaderField: "Authorization") // <- use your real key

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

                if let json = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) {
                    let transcript = json.text
                    self.state = .complete
                    self.statusMessage = "Inserted text"
                    self.insertTextInKeyboard(transcript)
                    print("✅ Transcript Inserted: \(transcript)")
                }
 else {
                    self.fail("Transcription failed.", nil)
                    print("Failed to decode transcription response")
                }

            }
        }.resume()
    }

    // MARK: - Insert text into host app via keyboard
    // AudioRecorderViewModel.swift
    func insertTextInKeyboard(_ text: String) {
        NotificationCenter.default.post(name: .insertTranscribedText, object: text)
    }

}
