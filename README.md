# Sergey

> macOS menu-bar application for orchestrating local AI agents.

Sergey sits in the menu bar, watches your local LLM workload through an agent dashboard, and logs every lifecycle event to persistent history. It uses a clean **Separation of Concerns** architecture: pure data models, dedicated services, JSON persistence, and thin UI panels — no God objects.

## Features

- **Agent Dashboard** — expandable overlay panel listing all active AI agents with real-time state indicators (running / stopped / inactive).
- **Agent Detail View** — click any agent to see its current task description, full lifecycle, and activity log inside the overlay.
- **Activity History** — persistent JSON-backed log of every agent state change, work-description update, and removal across all sessions.
- **Focus Mode** — global toggle (Menu Bar + Settings) that dims the overlay (50% opacity), suppresses status text, and keeps agents running silently in the background.
- **Simulation Engine** — deterministic multi-agent cycle (capped at 10 concurrent agents) for UI testing without external services.

## Architecture

Strict Separation of Concerns across four layers:

```
sergey/
├── AppDelegate.swift              ← slim initializer only (~20 lines)
│
├── Core/Models/                   ← pure data structs (no side effects)
│   ├── AgentModel.swift           ← id, name, state enum, workDescription, color/title helpers
│   └── AgentLogModel.swift        ← timestamped activity entry + root data struct
│
├── Core/Services/                 ← business logic & state management (@MainActor)
│   ├── AgentStatusService.swift   ← singleton: CRUD agents, status message, Published activeAgents
│   └── SimulationOrchestrator.swift ← deterministic cycle (add/update/remove every 1.2s, max 10)
│
├── Persistence/                   ← JSON persistence & key-value configs
│   ├── HistoryStore.swift         ← auto-logs agent lifecycle to ~/.sergey_history.json
│   └── SettingsStore.swift        ← Ollama URL, model name, Focus Mode toggle
│
├── UI/Panels/                     ← NSPanel wrappers + SwiftUI view components
│   ├── StatusOverlayPanel.swift   ← NSPanel size, frame animation, hosting-view binding
│   ├── StatusOverlayFacadeView.swift ← root SwiftUI view (routes list ↔ detail via @State)
│   ├── StatusOverlayHeaderViewView.swift ← collapsible header with status message
│   ├── AgentDetailViewDetailPanel.swift  ← agent detail sheet (header + logs)
│   └── HistoryView.swift          ← history window content (agent list + log viewer)
│
├── UI/Views/                      ← standalone SwiftUI views
│   ├── MenuBarView.swift           ← status icon + Focus Mode toggle
│   └── SettingsView.swift          ← Ollama config form wired to SettingsStore
│
├── Core/Agents/LLM/              ← language model integration
├── Core/System/                  ← hotkeys, communication dispatch, notifications
└── Core/Orchestrator/            ← task execution pipeline (future: action interpreter)
```

## Controls

| Key Combo | Action |
| :--- | :--- |
| Control + Option | Toggle overlay expanded / collapsed |
| Escape | Reset processing state & collapse overlay |

## Configuration

Settings (`SettingsStore.shared`) synced to `~/.sergey_config.json`:

| Key | Default | Description |
| :--- | :--- | :--- |
| `ollamaEndpoint` | `http://localhost:11434` | Local Ollama API URL |
| `modelName` | *(empty)* | Model to use for LLM calls |
| `isFocusModeEnabled` | `false` | Purely visual: dims overlay, hides status text |

## Removed features

These were extracted during the SOA refactor and are **not** in the current codebase:

- Vision / ScreenCaptureKit image processing — stripped from `OllamaClient`, `LLMService`, `HotkeyManager`
- God Object `StatusOverlayManager` — split into `StatusOverlayPanel` (NSPanel) + `AgentStatusService` (state) + facade views
- Conversation-based history session model — replaced by continuous agent activity logging (`HistoryRecordAgent` → `[AgentLog]`)

## Roadmap

### Phase 1 — Core LLM pipeline
- [ ] Reconnect real Ollama streaming to `LLMService` (text-only endpoint, no vision)
- [ ] Wire `ActionInterpreter` to parse tool-use JSON from agent responses
- [ ] Replace simulation with actual multi-agent task fan-out

### Phase 2 — Communication & routing
- [ ] Agent messaging layer: inter-agent pub/sub via `CommunicationDispatcher`
- [ ] Priority queue for status and notification dispatch (currently single-channel)
- [ ] Pluggable provider support (Anthropic, Groq, OpenRouter) alongside Ollama

### Phase 3 — Skills & automation
- [ ] Skill registry: declarative JSON manifest → Swift runtime loader
- [ ] File system scanner skill (recursive index + smart search)
- [ ] Network diagnostic skill (latency ping, DNS lookup, proxy status)

### Phase 4 — UX polish
- [ ] Native `NSTableView` replacement for agent list (performance on large sets)
- [ ] Undo/redo on history records
- [ ] Dark/light appearance sync with system settings
- [ ] Export history as CSV / Markdown report

## Tech Stack

- **Language**: Swift 5.10+ / SwiftUI 4 + Combine
- **Platform**: macOS (menu-bar app, no document-based UI)
- **LLM backend**: Ollama (local-only, zero telemetry)
- **Persistence**: native JSON (`JSONEncoder` / `JSONDecoder`)
- **Build**: Xcode project with file-system-synchronized groups (`PBXFileSystemSynchronizedRootGroup`)

## License

Private — all rights reserved.
