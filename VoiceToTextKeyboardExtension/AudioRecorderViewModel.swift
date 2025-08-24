import Foundation
import AVFoundation
import SwiftUI




extension NSNotification.Name {
    static let insertTranscribedText = NSNotification.Name("insertTranscribedText")
}

enum RecorderState {
    case idle, recording, processing, complete, error
}

class AudioRecorderViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var state: RecorderState = .idle
    @Published var statusMessage: String = "Press and hold to speak"

    // 🔊 Waveform samples (0...1). 40 bars ~ smooth + cheap.
    @Published var waveformSamples: [CGFloat] = Array(repeating: 0.0, count: 40)

    var audioRecorder: AVAudioRecorder?
    var recordedFileURL: URL?
    private var meterTimer: Timer?

    // MARK: - Recording Logic
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            session.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
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

                            // 🔁 Start metering timer (~20 Hz)
                            self.startMetering()
                        } catch {
                            self.fail("Failed to start recording.", error)
                        }
                    } else {
                        self.fail("Microphone permission denied.", nil)
                    }
                }
            }
        } catch {
            self.fail("Audio session configuration failed.", error)
        }
    }

    func stopRecording() {
        print("stopRecording called")
        audioRecorder?.stop()
        stopMetering()                    // 🛑 stop waveform updates
        self.state = .processing
        self.statusMessage = "Processing..."
        transcribeAudio()
    }

    // MARK: - Metering
    private func startMetering() {
        stopMetering()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            let db = recorder.averagePower(forChannel: 0)  // -160...0 dB
            let level = self.normalizedPower(from: db)     // 0...1
            self.pushSample(level)
        }
        RunLoop.current.add(meterTimer!, forMode: .common)
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func pushSample(_ value: CGFloat) {
        waveformSamples.append(value)
        if waveformSamples.count > 40 { waveformSamples.removeFirst() }
    }

    private func normalizedPower(from decibels: Float) -> CGFloat {
        // Convert dB to linear 0...1 (clamped)
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

    // MARK: - Transcription (endpoint + auth पहले जैसे तुमने सेट किए हैं)
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

        var data = Data()
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"recorded.m4a\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        if let audioData = try? Data(contentsOf: url), !audioData.isEmpty {
            data.append(audioData)
        } else {
            self.fail("Audio file is empty.", nil)
            print("⚠️ Audio file empty or missing at: \(url)")
            return
        }
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("whisper-large-v3\r\n".data(using: .utf8)!)
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = data

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.fail("Network error: \(error.localizedDescription)", error)
                    return
                }
                guard let data = data else {
                    self?.fail("No data received.", nil)
                    return
                }
                if let raw = String(data: data, encoding: .utf8) { print("📩 Raw API Response:\n\(raw)") }

                if let json = try? JSONDecoder().decode([String: String].self, from: data),
                   let transcript = json["text"] {
                    self?.state = .complete
                    self?.statusMessage = "Inserted text"
                    self?.insertTextInKeyboard(transcript)
                } else {
                    self?.fail("Transcription failed.", nil)
                    print("Failed to decode transcription response")
                }
            }
        }.resume()
    }

    // MARK: - Insert text
    func insertTextInKeyboard(_ text: String) {
        NotificationCenter.default.post(name: .insertTranscribedText, object: text)
    }
}
