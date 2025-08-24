import Foundation
import AVFoundation
import SwiftUI

// MARK: - Notification name used by KeyboardViewController
extension Notification.Name {
    static let insertTranscribedText = Notification.Name("insertTranscribedText")
}

enum RecorderState {
    case idle, recording, processing, complete, error
}

class AudioRecorderViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var state: RecorderState = .idle
    @Published var statusMessage: String = "Press and hold to speak"

    // Optional: waveform (safe if you’ve added WaveformView)
    @Published var waveformSamples: [CGFloat] = Array(repeating: 0.0, count: 40)

    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?
    var recordedFileURL: URL?

    // MARK: - Recording Logic (no real-time transcription)
    func startRecording() {
        guard state != .recording else { return } // prevent double start

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
    }

    func stopRecording() {
        guard state == .recording else { return } // stop only if recording
        print("stopRecording called")
        audioRecorder?.stop()
        stopMetering()

        // IMPORTANT: Only after full recording is completed, we transcribe
        self.state = .processing
        self.statusMessage = "Processing..."
        transcribeAudio()
    }

    // MARK: - Metering (optional for waveform)
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

        let endpoint = "https://api.groq.com/openai/v1/audio/transcriptions"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer mI4DheHfLEdGLShJRd1cMZiseT9fkXB2", forHTTPHeaderField: "Authorization")

        var body = Data()
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
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-large-v3\r\n".data(using: .utf8)!)
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

                // Debug raw
                if let raw = String(data: data, encoding: .utf8) { print("📩 Raw API Response:\n\(raw)") }

                if let json = try? JSONDecoder().decode([String: String].self, from: data),
                   let transcript = json["text"] {
                    self.state = .complete
                    self.statusMessage = "Inserted text"
                    self.insertTextInKeyboard(transcript)
                } else {
                    self.fail("Transcription failed.", nil)
                    print("Failed to decode transcription response")
                }
            }
        }.resume()
    }

    // MARK: - Insert text into host app via keyboard
    func insertTextInKeyboard(_ text: String) {
        NotificationCenter.default.post(name: .insertTranscribedText, object: text)
    }
}
