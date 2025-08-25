**🎙️ VoiceToText Keyboard**

A custom iOS keyboard extension that allows users to record their voice and instantly transcribe it into text.
Powered by Groq AI’s Whisper transcription model, this keyboard makes typing effortless by letting your voice do the work.

__🚀 Features__

**🎤 Voice Recording** – Tap mic button to record speech.

**✍️ Instant Transcription** – Speech gets converted to text using Groq API.

**⌨️ Keyboard Integration** – Transcribed text is inserted directly into any text field.

**📡 Real-Time API Response Logging** – Debug-friendly logs to see raw transcription results.

**🛠️ Setup Instructions**

1. Clone the Repository
git clone [https://github.com/your-username/VoiceToTextKeyboard.git](https://github.com/vikashjaingarg04/VoiceToTextKeyboard)

cd VoiceToTextKeyboard

3. Open in Xcode
open VoiceToTextKeyboard.xcodeproj

4. Add API Key

Create a file Config.plist in your project root.

Add the following entry:

<dict>
   <key>GROQ_API_KEY</key>
   <string>your_api_key_here</string>
</dict>


Never commit your API key to GitHub 🚫.

Add Config.plist to your .gitignore.

4. Update Signing & Capabilities

Go to Xcode Project Settings → Signing & Capabilities.

Select your team and enable:

✅ App Sandbox (Microphone Access)

✅ Microphone Usage

✅ App Groups (for data sharing between app & extension if required)

5. Run the App

Build and run on a real device (since simulators don’t support mic recording).

Go to Settings → General → Keyboard → Keyboards → Add New Keyboard…

Select VoiceToTextKeyboard.

Allow Full Access.

Now you’re ready to test 🎉

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
