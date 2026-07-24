# AI Buddy for macOS

An AI assistant that lives on your Mac. Press a hotkey, it sees what you see, listens to your voice, understands the context, and helps you complete tasks

## Concept

AI Buddy runs in the background as a macOS menu bar application.

The user can press a predefined hotkey to:

1. Capture the current screen or selected area.
2. Record a voice command.
3. Convert speech to text.
4. Send the screen context + user request to a local AI model.
5. Receive an answer or execute an action.

Example:

> "What does this text mean? Translate it."

AI Buddy captures the selected area, understands the content, translates it, and displays the result.

Another example:

> "Write a reply to this email."

AI Buddy analyzes the current application context, generates a response, and can insert the text automatically.

---

## Permissions

## Permissions

- **Microphone**: Required for recording voice commands.
- **Speech Recognition**: Required for converting speech to text in real-time.
- **Screen Recording**: Required via ScreenCaptureKit to capture screen context for the AI.
- **Accessibility**: Required for global hotkeys (`Fn + Shift`, global `ESC`) to work system-wide.

* **Swift / SwiftUI** — macOS application and UI
* **ScreenCaptureKit** — screen capture and screenshots
* **CGEvent** — keyboard and mouse automation
* **Accessibility API** — interacting with native macOS UI elements
* **AVFoundation** — microphone recording
* **STT** — speech-to-text
* **Ollama (localhost)** — local LLM and vision models

---

## Architecture

```
User
 |
 | hotkey + voice
 v
Swift macOS App
 |
 +-- ScreenCaptureKit
 |       |
 |       v
 |    Screenshot
 |
 +-- Speech-to-Text
 |       |
 |       v
 |    User prompt
 |
 +-- Ollama Vision / LLM
         |
         v
    Response / Action
         |
         +-- Show answer
         |
         +-- Click / Type / Automate
```

---

## Core Features

### Screen Understanding

* Capture full screen or multiple displays
* Capture selected screen regions
* Analyze visual context using local vision models

### Voice Interaction

* Push-to-talk workflow
* Local speech-to-text processing
* Natural language commands

### AI Reasoning

The assistant receives:

* Current screen context
* Selected image region
* User voice request

and generates a contextual response.

### macOS Automation

The assistant can:

* Click UI elements
* Type text
* Paste generated content
* Interact with applications using Accessibility APIs

---

## Project Structure

```
AI-Buddy/
│
├── App/
│   ├── AI_BuddyApp.swift
│   └── AppDelegate.swift
│
├── Core/
│   ├── HotkeyManager.swift
│   ├── ScreenCapture.swift
│   ├── AudioRecorder.swift
│   ├── SpeechRecognizer.swift
│   ├── OllamaClient.swift
│   └── Agent.swift
│
├── Automation/
│   ├── MouseController.swift
│   └── KeyboardController.swift
│
└── UI/
    ├── MenuBar.swift
    └── SelectionOverlay.swift
```

---

## Example Workflow

```
Press hotkey
      |
      v
Select screen area (optional)
      |
      v
Speak command
      |
      v
Speech-to-text
      |
      v
Send image + prompt to Ollama
      |
      v
Generate answer or execute action
```

---

## Local AI

The application uses Ollama running locally. 

### Configuration

If your Ollama instance is running on a different machine or requires a specific IP, you can configure it without changing the code:

1. **Via Environment Variable** (for terminal launches):
   Set `OLLAMA_URL` before running the app:
   ```bash
   export OLLAMA_URL="http://your-ip-address:11434"
   ./run_app
   ```

2. **Via macOS Defaults** (permanent configuration):
   Use the `defaults` command to set the `OllamaBaseURL`:
   ```bash
   defaults write com.yourcompany.sergey OllamaBaseURL http://your-ip-address:11434
   ```

If no configuration is found, it defaults to `http://localhost:11434`.


## Hotkeys

- **Cmd+Fn+Shift**: Capture screen and send to AI for analysis
- **Cmd+Fn+Ctrl**: Start/stop voice recording

## Goal

Create a private, local AI assistant that understands what you are doing on your Mac and helps you complete tasks through natural conversation.
