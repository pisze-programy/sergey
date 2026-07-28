# Sergey

An AI-powered macOS assistant that sees what you see and automates tasks via specialized Skills.

## How It Works

Sergey follows a ReAct (Reasoning/Action) pattern:
1. Trigger: Press the hotkey to activate.
2. Observe: The agent receives your current screen context.
3. Think: Uses a local LLM (via Ollama) to reason about your request.
4. Act: Executes specific Skills (e.g., Screen Capture, UI Automation) based on the reasoning.

## Controls

| Key Combo | Action |
| :--- | :--- |
| Control + Option | Activate: Starts processing and captures context. |
| Escape | Dismiss: Cancels active request or clears overlays. |

## Core Capabilities (Skills)

Sergey is modular. New capabilities can be added without changing the core engine:
- Visual Context: Analyzes screenshots using vision models.
- Automation: Executes macOS-specific tasks through a registry of Skills.

## Configuration

Settings are stored in ~/.sergey_config.json:
- Ollama URL: Default http://localhost:11434
- Model Name: e.g., gemma4:26mu-a4b-it-q4_K_M

## Tech Stack

- Language: Swift / SwiftUI
- Intelligence: Ollama (Local LLM)
- Vision: ScreenCaptureKit
- Automation: macOS Accessibility APIs
