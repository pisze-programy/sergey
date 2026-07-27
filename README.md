# Sergey

An AI-powered macOS assistant that sees what you see, hears what you say, and automates tasks via specialized Skills.

## How It Works

Sergey follows a ReAct (Reason/Action) pattern:
1. Trigger: Press the hotkey to activate.
2. Observe: The agent receives your voice command and current screen context.
3. Think: Uses a local LLM (via Ollama) to reason about your request.
4. Act: Executes specific Skills (e.g., Screen Capture, UI Automation) based on the reasoning.

## Controls

| Key Combo | Action |
| :--- | :--- |
| Control + Option | Activate: Starts listening and captures context. |
| Escape | Dismiss: Cancels active request or clears overlays. |

## Core Capabilities (Skills)

Sergey is modular. New capabilities can be added without changing the core engine:
- Visual Context: Analyzes screenshots using vision models.
- Voice Interface: Natural language interaction via Speech-to-Text.
- Automation: Executes macOS-specific tasks through a registry of Skills.

## Configuration

Settings are stored in ~/.sergey_config.json:
- Ollama URL: Default http://localhost:11434
- Model Name: e.g., gemma4:26-a4...
- Voice Activation: Enable/Disable voice processing.

## Tech Stack

- Language: Swift / SwiftUI
- Intelligence: Ollama (Local LLM)
- Vision & Audio: ScreenCaptureKit / AVFoundation / Speech Framework
- Automation: macOS Accessibility APIs
