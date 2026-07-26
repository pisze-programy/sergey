# Sergey

An AI assistant that lives on your Mac. Press a hotkey, it sees what you see, listens to your voice, understands the context, and helps you complete tasks.

## Concept

Sergey is a modular AI assistant driven by **Skills**. Instead of hardcoded behaviors, Sergey uses LLM reasoning to trigger specific Skills (capabilities) based on your voice or screen context.

The user can press a predefined hotkey to:
1. Activate the agent via push-to-talk.
2. Provide visual/audio context.
3. Allow the AI to execute **Skills** (e.g., screen capture, automation).

### Extensibility (Skills)

The core of Sergey is its ability to execute **Skills**. A Skill can be triggered by the LLM using the syntax:  
`ACTION:skill_id(parameter1=value1,...)`

This allows Sergey to perform complex tasks like interacting with the macOS UI, capturing specific parts of the screen, or running scripts without changing the core application logic.

## Prompt Configuration

The behavior of the Agent and the system prompt for Ollama are managed via markdown files in the `sergey/Prompts/` directory (e.g., `OLLAMA_SYSTEM_PROMPT.md`). This allows for easy fine-tuning of Sergey's personality and capabilities without recompiling the app.

### Prompting Architecture

The agent operates using a dual-layered prompting strategy:

*   **System Prompt (`OLLAMA_SYSTEM_PROMPT.md`)**: Defines Sergey's core identity, personality, and global rules (e.g., "be concise"). This remains constant across all interactions.
*   **Agent ReAct Prompt (`AGENT_REACT_PROMPT.md`)**: Provides dynamic context for the current task. It dynamically injects:
    *   **Skill Inventory**: A list of currently available tools/skills.
    *   **User Request**: The specific instruction from the user.
    *   **ReAct Framework**: Instructions on how to reason using the **Thought $\to$ Action $\to$ Observation** pattern to interact with macOS via skills.

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
│   ├── SettingsStore.swift
│   └── SpeechRecognizer.swift
├── Prompts/
│   ├── AGENT_FALLBACK_PROMPT.md
│   ├── AGENT_REACT_PROMPT.md
│   └── OLLAMA_SYSTEM_PROMPT.md
├── Skills/
│   └── [Skill Modules]
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
