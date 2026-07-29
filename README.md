# Sergey

macOS menu-bar application for local AI agent orchestration. Sits in the status bar, exposes an expandable overlay with real-time agent state, and persists every lifecycle event to disk.

## Current capabilities

- **Agent overlay** — borderless NSPanel anchored to bottom-right. Collapsed: 55px header with status message and chevron. Expanded: agent list, detail drill-down, input field. Expand/collapse animated via `withAnimation` + delayed `setFrame`.
- **Agent states** — Running (green), Stopped (orange), Inactive (gray). Click any agent to view full log history inside the overlay.
- **Persistent history** — all state changes logged per-agent to JSON. Survives restarts. Full history visible via menu-bar "Agent History" window.
- **Focus mode** — toggle from menu bar or settings window. Sets overlay opacity to 50% and suppresses `CommunicationDispatcher` status updates. Agent execution continues unaffected.
- **Simulation engine** — timer-driven cycle (every 1.2 s) that adds, updates, and removes agents from a pool of 5 names (Coder, Researcher, Designer, QA, Architect). Capped at 10 concurrent agents. Used for UI regression testing without live LLM.

## Architecture

```
sergey/
├── AppDelegate.swift                      slim bootstrapper: init panel + service + hotkeys + simulation
│
├── Core/Models/                           pure data — no I/O, no side effects
│   ├── AgentModel.swift                   id, name, workDescription, StateFlag enum (color/icon/title computed properties)
│   └── AgentLogModel.swift               timestamped log entry; HistoryRecordAgent (agent-scoped log list); HistoryDataRoot (file-root container)
│
├── Core/Services/                         @MainActor singletons — state owners
│   ├── AgentStatusService                 CRUD agents, status text, Published activeAgents + statusMessage
│   └── SimulationOrchestrator             timer loop: 5-phase cycle, max 10 agents
│
├── Core/Persistence/                      JSON key-value config
│   └── SettingsStore                     ollamaURL, modelName, isFocusModeEnabled → ~/.sergey_config.json
│
├── Persistence/                           full-disk persistence
│   └── HistoryStore                      HistoryDataRoot → ~/Library/Application Support/sergey/history.json
│
├── Core/Agents/LLM/                       Ollama integration (text-only, streaming)
│   ├── LLMService                        generateScopedResponse(systemPrompt, prompt, onChunk) → LLMResponse
│   └── Providers/OllamaClient             AsyncThrowingStream over HTTP POST to /api/chat
│
├── Core/Orchestrator/                     action parsing pipeline (not yet wired)
│   ├── ActionInterpreter                 parse "Action: skill_name(param=value)" → ActionInterpretationResult
│   └── TaskExecutor                      isProcessing guard, resetProcessing
│
├── Core/System/                           cross-cutting utilities
│   ├── CommunicationDispatcher           router: notifications + overlay status per priority + focus-mode gate
│   ├── HotkeyManager                     global monitors: Ctrl+Opt = toggle expand, Escape = collapse + reset
│   ├── MessagingManager                  static prompt strings (idle, listening, thinking, error)
│   ├── PromptManager                     load .md templates from Bundle.main/Prompts/
│   └── SystemNotificationService         UNUserNotificationCenter wrapper with interruption-level mapping
│
├── UI/Panels/                             NSPanel wrappers + SwiftUI components
│   ├── StatusOverlayPanel                KeyPanel subclass (canBecomeKey = true), frame math, lifecycle
│   ├── StatusOverlayFacadeView           root SwiftUI view: header + conditional agent list/detail routing
│   ├── StatusOverlayHeaderViewView       status dot, message text (animated transitions), chevron icon
│   ├── AgentDetailViewDetailPanel        detail sheet with per-agent log viewer
│   └── HistoryView                       history window content: agent list + log table
│
├── UI/Managers/                           NSWindow factories
│   ├── HistoryWindowManager              floating window (780x460), reusable instance
│   └── SettingsWindowManager             floating window (400x500)
│
├── UI/Views/                              menu-bar + config UI
│   ├── MenuBarView                       Agent History, Settings, Focus Mode toggle, Quit
│   └── SettingsView                      ollamaURL input, modelName dropdown, Focus Mode toggle
│
└── sergeyApp.swift                        @main entry point with MenuBarExtra scene
```

## Config files

| File | Path | Format |
| --- | --- | --- |
| Settings | `~/.sergey_config.json` | JSON keys: `ollamaURL`, `modelName`, `isFocusModeEnabled` |
| History | `~/Library/Application Support/sergey/history.json` | `HistoryDataRoot.agents[]` list, each with `logs[]` |

Default settings (first run): Ollama URL `http://localhost:11434`, model `gemma4:26mu-a4b-it-q4_K_M`.

## Keyboard shortcuts

| Combo | Action |
| --- | --- |
| Ctrl + Opt | Toggle overlay expand/collapse |
| Escape | Collapse overlay, reset task executor |

## LLM pipeline status

`OllamaClient` and `LLMService` implement streaming text chat. `ActionInterpreter` can parse ReAct-style responses into skill invocations. Neither is wired through `TaskExecutor` yet — execution path currently guarded by `isProcessing` with a stub body.

## Roadmap

- Wire `ActionInterpreter` output to actual skill executors via `TaskExecutor`
- Replace simulation with real user input flow (command field → LLM → action dispatch)
- Add pluggable provider abstraction beyond Ollama
- Persist Prompts directory outside bundle for runtime editing
- Swap agent list view to native `NSTableView` for scale
