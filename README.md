# Sergey

An intelligent macOS menu-bar companion designed to orchestrate AI agents that interact with your system context, screen, and tools in real-time.

## Why Sergey?
Most AI tools require manual input (copy-paste). **Sergey observes.** By leveraging accessibility APIs, screen context, and speech-to-text, Sergey turns passive LLMs into active system participants that can watch your workflow, manage your calendar, and execute background tasks without interrupting your focus.

## Current State
Currently, Sergey functions as a **foundation for agent orchestration**. It provides the infrastructure for:
- **Persistent Agent Logs**: Every action, not even every thought, and status change is logged and searchable.
- **System Integration**: Interface for keyboard shortcuts and macOS notifications.

- **Local LLM Support**: Out-of-the-box integration with Ollama for private, local execution.
- **Overlay UI**: A non-intrusive, animated panel to monitor agent progress in the corner of your screen.

## Planned Capabilities (The Roadmap)
- **Vision & Context**: Using Screen Capture and Accessibility APIs to "see" what you are working on.
- **Voice Command (STT)**: Integrated Parakeet/Whisper for hands-free instructions.
- **Advanced Researcher Agent**: A specialized agent capable of web-searching, scraping, and synthesizing information.
- **Asynchronous Task Queue**: Running complex, multi-step tasks (e.g., "Backup this folder, then update my Jira") in the background while you work.
- **Calendar & Schedule Management**: Cross-referencing your screen context with your calendar to manage meetings and focus time.
- **Tool Extensions**: Acts as a UI/UX extension for existing tools like Claude Code, OpenCode, or terminal-based agents, providing a visual "progress layer."

## Usage Examples

### Example 1: The Researcher (Web Search)
**[User]**: *(Via Voice)* "Sergey, find me the latest pricing for Nvidia H100 GPUs and summarize it."  
**[Sergey]**: Spawns `Researcher` agent $\rightarrow$ Performs Web Search $\rightarrow$ Scrapes results.  
**[System]**: Notifies user via Overlay: "Summary ready in clipboard."

### Example 2: Contextual Automation (Calendar + Screen)
**[User]**: *(Via Text Input)* "Check if I can take this meeting."  
**[Sergey]**: Scans Calendar $\rightarrow$ Checks current active window activity.  
**[System]**: Overlay Update: "Meeting at 3 PM is clear. You have no high-priority tasks pending."

### Example 3: Background Tasking (Async Queue)
**[User]**: "Run a full project backup and notify me when done."  
**[Sergey]**: Adds `Backup` task to queue $\rightarrow$ Executes via local shell.  
**[System]**: [Background Process running...] $\rightarrow$ *Notification*: "Backup Complete: 1.2GB processed."

## Shortcuts
| Combo | Action |
| :--- | :--- |
| `Ctrl + Opt` | Toggle Overlay Expand/Collapse |
| `Escape` | Collapse & Reset Task Execution |

## Configuration
Settings are persisted in:
- **App Config**: `~/.sergey_config.json` (O																																	       

