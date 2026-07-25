# Sergey

An AI assistant that lives on your Mac. Press a hotkey, it sees what you see, listens to your voice, understands the context, and helps you complete tasks.

## Concept

Sergey runs in the background as a macOS menu bar application. The user can press a predefined hotkey to:

1. Capture the current screen or selected area.
2. Record a voice command.
3. Convert speech to text.
4. Send the screen context + user request to a local AI model (via Ollama).
5. Receive an answer as a floating overlay.

### Example Workflow

> **User:** (Presses Hotkey) "What does this text mean? Translate it."
> **Sergey:** Analyzes visual context, translates the content, and displays the result in a beautiful overlay.

---

## Permissions & Requirements

- **Microphone**: Required for recording voice commands.
- **Speech Recognition**: Required for converting speech to text in real-time.
- **Screen Recording**: Required via ScreenCaptureKit to capture screen context.
- **Accessibility**: Required for global hotkeys and macOS automation.

**Technologies Used:**
* **Swift / SwiftUI** — macOS application and UI
* **Ollama** — Local LLM and vision models integration
* **ScreenCaptureKit / AVFoundation** — Screen capture and audio recording
* **Speech Framework** — Real-time speech-to-text (STT)

---

## Core Features

### AI Interaction
* **Vision Support**: Analyze screenshots using local vision models.
* **Voice Prompting**: Use push-to-talk for natural language commands.
* **Context Awareness**: The assistant receives both screen context and user request.

### Automation & Tools
* **macOS Automation**: Capability to interact with UI elements using Accessibility APIs.

* **Session History**: Persistent storage of conversation history (queries and answers) in `~/Library/Application Support/sergey/history.json`.

---

## Project Structure

```
sergey/
├── sergeyApp.swift
├── AppDelegate.swift
├── Core/
│   ├── Agent.swift
│   ├── AudioRecorder.swift
│   ├── HotkeyManager.swift
│   ├── OllamaClient.swift
│   ├── ScreenCapture.swift
│   ├── SettingsStore.swift
│   └── SpeechRecognizer.swift
└── UI/
    ├── Components/
    │   └── MenuBar.swift
    ├── Managers/
    │   ├── HistoryWindowManager.swift
    │   ├── ResponseOverlayManager.swift
    │   └── SettingsWindowManager.swift
    └── Views/
        ├── HistoryView.swift
        ├── ResponseOverlayView.swift
        └── SettingsView.swift
```

---

## Configuration

Settings are managed via the application's menu bar and persist in `~/.sergey_config.json`.

**Default Settings:**
- **Ollama URL**: `http://localhost:11434`
- **Model Name**: `gemma4:26b-a4b-it-q4_K_M`

---

## Hotkeys

- **Control + Option**: Trigger screen capture and voice prompt.
- **Escape**: Dismiss active overlays.
