# Sergey

An AI assistant that lives on your Mac. Press a hotkey, it sees what you see, listens to your voice, understands the context, and helps you complete tasks

## Concept

Sergey runs in the background as a macOS menu bar application.

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
- **Accessibility**: Required for global hotkeys (`Control + Option`, global `ESC`) to work system-wide.

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
    ├── MenuBar.swift
    ├── ResponseOverlay.swift
    ├── SettingsView.swift
    └── SettingsWindowManager.swift
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

**To configure the connection (URL or Model):**

1.  Open the **Settings** window from the Menu Bar.
2.  Update the **Ollama URL** and/or **Model Name**.
3.  The settings are automatically saved to `~/.sergey_config.json` and persist even after application reinstallation.

If no configuration is provided, it defaults to:
- **URL**: `http://localhost:11434`
- **Model**: `gemma4:26b-a4b-it-q4_K_M`


## Hotkeys

- **Control + Option**: Capture screen and send to AI for analysis

## Goal

Create a private, local AI assistant that understands what you are doing on your Mac and helps you complete tasks through natural conversation.
