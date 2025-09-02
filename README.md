**🎙️ VoiceToText Keyboard**

A custom iOS keyboard extension that allows users to record their voice and instantly transcribe it into text.
Powered by Groq AI’s Whisper transcription model, this keyboard makes typing effortless by letting your voice do the work.

## 🚀 Real Device Testing Guide

Follow these steps to test the keyboard on a real iOS device:

### Step 1: Connect Device and Select as Run Destination
1. Connect your iOS device to your Mac
2. Select your device as the run destination in Xcode

### Step 2: Build and Run the App
1. Build and run the app (⌘+R)
2. After installation, go to:
   - Settings → General → Keyboard → Keyboards → Add New Keyboard…
   - Select "VoiceToTextKeyboard"
   - Tap on it and enable "Allow Full Access"
   - Grant microphone permissions when prompted

### Step 3: Using the Keyboard
1. Open any app with a text field
2. Tap to bring up the keyboard
3. Switch to VoiceToTextKeyboard (🌐 → VoiceToText)
4. Press and hold the mic button to record
5. Release to transcribe and insert text

## 🚀 Features

**🎤 Voice Recording** – Tap mic button to record speech.

**✍️ Instant Transcription** – Speech gets converted to text using Groq API.

**⌨️ Keyboard Integration** – Transcribed text is inserted directly into any text field.

**📡 Real-Time API Response Logging** – Debug-friendly logs to see raw transcription results.

## 🛠️ Setup Instructions

### Prerequisites
- Xcode 14.0+
- iOS 15.0+ device
- Groq API key (get it from [Groq Console](https://console.groq.com/))

### Step 1: Configure the Project
1. Open the project in Xcode:
   ```bash
   open VoiceToTextKeyboard.xcodeproj
   ```

2. Set your development team:
   - Select the "VoiceToTextKeyboard" target
   - Go to "Signing & Capabilities"
   - Select your team
   - Set a unique Bundle Identifier

3. Configure the keyboard extension:
   - Select the "VoiceToTextKeyboardExtension" target
   - Repeat the signing configuration
   - Ensure the bundle ID follows the format: `[MAIN_APP_BUNDLE_ID].keyboard`

### Step 2: Add API Key
1. Open `AudioRecorderViewModel.swift`
2. Locate the `apiKey` constant (around line 251)
3. Replace `YOUR_GROQ_API_KEY` with your actual Groq API key

⚠️ **Security Note**: For production, consider using environment variables or a secure configuration system.

### Step 3: Enable Required Capabilities
1. For the main app target:
   - Add "Microphone Usage Description" in Info.plist
   - Add "Privacy - Microphone Usage Description" with a message like "Voice recording for keyboard input"

2. For the keyboard extension target:
   - Enable "App Groups" if needed
   - Add "Required Background Modes" → "App downloads content from the network"

## 🔍 Troubleshooting

### Microphone Not Working
- Check microphone permissions in Settings → Privacy → Microphone
- Ensure the keyboard has "Allow Full Access" enabled
- Verify the app has microphone usage description in Info.plist

### API Key Issues
- Ensure you've replaced `YOUR_GROQ_API_KEY` with a valid key
- Check Xcode console for API errors
- Verify internet connection

### Keyboard Not Appearing
- Restart the device after installation
- Go to Settings → General → Keyboard → Keyboards and ensure it's added
- Try removing and re-adding the keyboard

**🔑 API Key Configuration**

We’re using Groq API for transcription.

Add Environment Variable (Optional Secure Way)

Instead of storing in plist, you can configure API key via environment variable:

let apiKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""


To add in Xcode:

Go to Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables

Add key GROQ_API_KEY with your value.

**📌 Assumptions Made**

User will always allow microphone access for recording.

API key is valid and has sufficient quota.

Real device testing (since Simulator doesn’t support mic input).

Network connection is available while using keyboard.

Transcription model used = "whisper-large-v3" (Groq).

**🧩 Tech Stack**

Swift / UIKit – For iOS App + Keyboard Extension.

AVFoundation – For audio recording.

Groq API (Whisper) – For speech-to-text transcription.

NotificationCenter – To pass transcribed text from recorder to keyboard.

**🎯 Usage**

Open any app (Messages, Notes, WhatsApp etc.)

Switch to VoiceToTextKeyboard.

Tap 🎤 button → Speak → Stop Recording.

Watch your words magically appear as text ✨.
