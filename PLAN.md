# Sergey — Engineering Roadmap

Product plan for Sergey, a local, voice-first macOS assistant: it listens (STT), sees
(screen + vision), acts (task queue with tools), and is being extended toward a fully
interactive browser-controlling co-pilot. Status as of 2026-07-31.

---

## 1. Vision

Sergey is an active macOS assistant that works alongside the user:

- Listens to voice commands (speech-to-text) and transcribes on demand.
- Sees the screen (screen capture + vision models) and answers questions about it.
- Acts: opens pages, reads content, and — eventually — operates a real browser (CDP),
  draws on screen (annotation overlay), and listens to ambient conversation.
- Chains tasks: one agent's output feeds the next; agents can spawn subagents.
- Runs locally via Ollama; no external API keys by default.

Reference scenario: *"Check tomorrow's weather in Poznań and summarize it"* — the agent
searches, opens a page, reads the content, and produces a summary from what it actually saw.

---

## 2. Current State

### 2.1 What works today

| Layer | Components | Status |
|---|---|---|
| UI | Floating overlay (always-on-top panel), live queue list (Queued/Running/Completed/Failed), status ticker | Done |
| Input | Voice: Left Cmd+Opt → agent task; Right Cmd+Opt → transcription into the frontmost app (Parakeet) | Done |
| Queue | Priority, retry (3×), JSON persistence, restore-after-restart | Done |
| Agent loop | TaskExecutor: ReAct (Thought/Action/Observation/Final Answer), max 6 iterations, throttled live status | Done |
| Tools | screen_capture (vision describe), open_url (http/https whitelist), frontmost_app, insert_text (gated), notify | Done |
| LLM | OllamaClient: streaming NDJSON (OpenAI-compatible) + native /api/chat (vision); LLMService | Done |
| Settings | General (URL, model picker synced from Ollama, vision model), Records, History, Agents, Queue | Done |
| Persistence | SettingsStore, TaskQueueManager, HistoryStore (per-task, full-text logs), STTRecordStore, AgentDefinitionStore | Done |
| Windows | Settings = regular window (Cmd+Tab via activation policy, resizable, frame persistence); overlay = floating, always-on-top | Done |

### 2.2 Recent hardening (learned from real testing)

- **Serial queue** (`concurrentLimit = 1`): agents share resources (browser, screen,
  keyboard focus); concurrent execution caused agents to interfere with each other.
- **insert_text disabled by default** (Settings → General → Agent Tools): the agent typed
  into apps without permission on two occasions (Xcode, a browser).
- **Authoritative time in the system prompt**: the vision model misread on-screen clocks
  (10:42 read as "14:56"); agents now receive the real date/time from the system.
- **Honesty rule**: the agent once fabricated article titles when a cookie popup obscured
  the page; the prompt now forbids inventing content.
- **Vision image optimization**: screenshots are resized (max 1280px) and re-encoded as
  JPEG (q75) before being sent to the vision model — 90-97% size reduction (13 MB → 0.4 MB).

### 2.3 Architecture

Layers: Core (Agents/LLM, Agents/Providers, Agents/Tools, Orchestrator, Services, System,
Persistence, Models) + UI (Managers, Panels, Views). Xcode 16 with
`PBXFileSystemSynchronizedRootGroup` (new files auto-sync). Singletons by project convention.

---

## 3. Roadmap

### Phase 1 — Web & Data Tools

Text-based web reading so the agent stops at "opened the link" no longer.

| Tool | Description |
|---|---|
| `search_web(query)` | DuckDuckGo HTML or Bing, keyless; parses top 5 results (title, URL, snippet) into an observation |
| `fetch_url(url)` | URLSession + HTML-to-text extraction (strip tags/scripts, entity decode); size limit ~8k chars; http/https whitelist |
| `weather_forecast(city)` | Open-Meteo API (keyless): geocoding + hourly temperature/precipitation/weather code + timezone; returns a 7-day forecast |

Prompt rule: prefer `fetch_url`/`search_web` over `open_url` unless the user asks to open a page.

Risks: JS-heavy pages return empty text (fallback: vision or an honest message); bot
protection may require retries/user-agent.

### Phase 2 — Browser Automation (CDP) — Priority 1

Real browser control: click, scroll, fill forms, read rendered DOM, screenshot.

Problems from real tests that CDP solves:
- Cookie popup on wykop.pl blocked reading → agent hallucinated article titles. CDP clicks "Accept All" and reads actual content.
- 404 on allegro.pl — agent coped (navigated to homepage), but CDP allows correcting the URL/search directly.
- Google Maps reading (names/ratings/hours) works via vision; CDP provides the DOM instead — more reliable.

Architecture:
- `Core/Agents/Tools/Browser/CDPClient.swift` — WebSocket client (URLSessionWebSocketTask) for Chrome DevTools Protocol; JSON-RPC with id/result/event, command queueing, timeouts.
- `Core/Agents/Tools/Browser/BrowserSession.swift` — Chrome process management (`--remote-debugging-port=9222 --user-data-dir=<temp>`), port detection, cleanup; fallback: attach to a running instance.
- **One shared browser session** — requires the serial queue (done); if concurrency returns, add a browser lock.
- `BrowserTool` actions: `navigate(url)`, `click(selector|text)`, `read(url|current)` (rendered `innerText`), `elements` (deduplicated DOM structure: interactive tags, text, href, placeholder — capped ~2500 chars), `scroll(direction)`, `screenshot()` (JPEG via CDP), `type(selector, text)` / `press(Enter)`.

**Cost pipeline (agent must follow):** cheapest source first —
`read` (page text) → `elements` (DOM structure, locate/interact targets) → `screenshot` (vision, only for layout/visual questions). Never screenshot when text or elements suffice. The agent's browser is a dedicated, hidden Chrome instance (temp profile, offscreen window); CDP screenshots come from the renderer, never from the user's screen.

Safety: http/https only; out-of-origin navigation requires prompt consent; 15s per-command timeout; configurable domain whitelist. Requires Chrome/Chromium.

Target case: "go to wykop.pl, find three politics articles" → navigate → click("Accept All") → read → summarize.

### Phase 3 — Task Chaining & Multi-Agent Dependencies

Dependent tasks execute sequentially; one agent's result feeds the next.

- `QueuedTask.dependsOnTaskId` — task B does not start until A is `.completed` (or `.failed` → B skipped / "continue despite failure" variant).
- `QueuedTask.inputFrom` — prompt B = `promptB + "\n\nResult from previous task:\n" + finalAnswer(A)`.
- Patterns: Researcher → Summarizer; fan-out (one command → N independent subtasks); fan-in (N results → 1 aggregator).
- Command parsing: "first X, then Y" → two tasks with dependency (a `ChainBuilder`).
- UI: queue rows show the chain (indent / dependency icon) in Settings → Queue.

Risks: dependency cycles (validate on enqueue), deadlocks (timeout on "waiting for parent").
Note: the queue is serial, so chains already run in order; resource locks (browser, screen,
focus) become required only if concurrency is reintroduced.

### Phase 4 — Memory & Context

- **Session memory**: recent task summaries appended to the prompt (clean per-task history already exists — select from it).
- **Long-term memory (RAG, optional)**: embeddings (e.g. nomic-embed-text via Ollama) stored in JSON (no external DB) — "do you remember what we agreed last week?"
- **Context store**: `sergey_context.json` — facts, preferences, reusable data; tools `remember(fact)` / `recall(query)`.

Priority: session memory first (cheap), RAG later.

### Phase 5 — Productivity Integrations

- **Calendar** — EventKit read ("can I take this meeting?"); write with confirmation.
- **Files (sandboxed)** — `file_ops`: list/read/write inside `~/Documents/Sergey/`; operations outside require confirmation.
- **Terminal (gated)** — `shell(command)` with an approval gate for dangerous commands (rm, sudo, git push); whitelist for safe ones (ls, cat, pwd).
- **Clipboard** — read/write ("copy this for me").
- **Scheduled notifications** — `schedule_notify(time, text)`; recurring tasks (see Phase 14).

### Phase 6 — Model Routing & Quality

- **Model routing**: small/fast model for intent classification and action formatting; large model for reasoning. A `fastModel` setting (same pattern as vision model).
- **Structured actions** (optional): model returns JSON `{"tool": ..., "params": {...}}` instead of text ReAct — more stable parsing; supports Ollama function-calling.
- **Model fallback**: retry with a different model if the primary one fails to follow the format.

### Phase 7 — UX Polish

- Configurable shortcuts (Settings → Hotkeys) with conflict detection.
- Screen Recording permission in PermissionManager + onboarding (known gap).
- Auto-pruning of the queue list and `activeAgents` (upper bounds).
- Focus Mode completion (hide ticker, quiet mode).
- In-overlay confirmations for dangerous actions (see Phase 13).

### Phase 8 — Distribution

- Developer ID signing + notarization (notarytool); DMG via existing build.sh.
- Auto-update (Sparkle or a simple GitHub-releases check).
- Crash reporting (optional, file-based; no telemetry by default).

### Phase 9 — Ambient Co-Pilot (system audio + microphone)

A background agent that lives with the user: hears what the user hears (speakers — e.g.
the other side of a video call) and what the user says (microphone), transcribes both
streams in parallel, takes notes, screenshots, and surfaces text in the overlay.
Activated by voice: "hey Sergey, take notes for this call."

Architecture:
- **System audio** → `ScreenCaptureKit` (macOS 13+, same API as screenshots, no drivers; fallback: BlackHole). Microphone → existing `AudioRecordingService`.
- **Two sample streams** → separate transcription ("Speaker: ..." / "You: ...") — gives the conversation structure.
- **Live STT (2-4 s latency)** — sliding-window chunking: every ~2 s transcribe the last 5-8 s window with ~1 s overlap and word-boundary dedupe (patterns from the existing parakeet-yt-stt / call-stt-rag-memo work).
- **Micro-event loop** (instead of one-shot ReAct):
  - transcription accumulates into a rolling context (last ~60 s — bounded)
  - every N seconds / at sentence boundaries → short "extract notes / decide action" prompt to a fast model
  - **local keyword spotting** (no LLM): "screenshot" → immediate capture; "hey Sergey" → start/stop
  - large model only on demand (summary, analysis)
- **Outputs**: notes to a markdown file + overlay preview; screenshots via existing screen_capture + vision; text hints in the overlay.

Steps: P1 ScreenCaptureKit audio (~1 day); P2 streaming/chunked transcription for both streams (~1-2 days); P3 micro-event loop + keyword spotting + notes (~2 days); P4 contextual vision + overlay display (~1 day).

Risks: ASR quality on compressed call audio; window/overlap/dedupe tuning; macOS 13+ and Screen Recording permission.

### Phase 10 — Screen Drawing Co-Pilot (annotation overlay)

The agent points, draws and hints **on screen** through a non-clickable overlay: marker/cursor,
paths, element borders, text next to the cursor ("click here"). Same persona as Phase 9,
with a visual channel added.

**Two modes — two implementations:**

**Mode A — Scripted:** the full sequence drawn at once, no interaction. Example: onboarding
demo — the agent writes "Hello World" on screen as a welcome.
- One `annotate` call with a command list → the app plays it as one animation.

**Mode B — Interactive:** the agent draws step 1 → waits for the user (click or speech) →
draws step 2 → ... "oh, you clicked here — let me find the other one."
- **Session state machine** (separate runtime from TaskExecutor; stateful, not one-shot ReAct):
  states `waiting-for-input / processing / drawing`; per turn: user input → short LLM prompt
  (fast model) → one annotate step → draw → wait. Session context in memory (bounded, last ~10 turns).
- **User input channels:** voice (reuse STT) and optionally clicks — a global mouse monitor
  (NSEvent.addGlobalMonitor, already used for hotkeys) so Sergey sees where the user clicked
  and can verify ("you clicked the highlighted button — now..."). The overlay stays
  click-through; we only observe.
- Idle timeout: no reaction for N seconds → the agent may prompt or end the session.
- Mode selection: the model decides from context ("write Hello World" = A; "guide me step by step" = B).

**Key principle (both modes) — the LLM writes the script, the app animates:**
The model is never in the render loop (~1 s per "draw" call would make the agent feel dead).
Mode A sends the whole script; Mode B sends one step per turn while the app animates that
step (cursor interpolation, stroke progress) as the LLM thinks about the next one.
Interpolation of the thousands of pixels between endpoints is done app-side
(CADisplayLink / Core Animation); the model provides only endpoints:
`cursor(x,y)`, `path([p1,p2,p3])`, `box(x,y,w,h)`, `text(x,y,"...")`, `clear()`.

Architecture: full-screen click-through NSPanel (`ignoresMouseEvents = true`, pattern from
StatusOverlayPanel) + canvas; `AnnotationEngine` (play(script) / play(step) + pause + clear);
`CoPilotSession` for Mode B. Coordinates normalized (0-1000) from the vision model, mapped
to pixels by the app (resolution-independent). With CDP: `box(elementId)` →
`getBoundingClientRect()` — pixel-accurate frames without vision guessing.

### Phase 11 — Extended Toolset

New agent tools. All approved.

| Tool | Purpose | Example |
|---|---|---|
| `speak(text)` | Text-to-speech via AVSpeechSynthesizer — Sergey answers aloud | "say the summary out loud" |
| `ocr(image)` | On-device OCR via Vision framework (VNRecognizeTextRequest) — fast, reliable text extraction without a vision model | "read the text in this screenshot" |
| `describe_ui()` | Accessibility tree of the frontmost app — exact element names for native apps (more accurate than vision) | "what buttons are on this window?" |
| `clipboard_read` / `clipboard_write` | System clipboard | "copy this for me" |
| `screenshot_region(x,y,w,h)` | Capture a region (screencapture -R) — lighter, less noise for vision | "screenshot just the chart" |
| `window_info()` | Titles/frames of open windows | "which tab am I on?" |
| `edit_input(text)` | Read and **replace** the text of the focused input field **without submitting** — never presses Enter; the user reviews and sends manually | see below |

**`edit_input` — safe input translation/editing (user request):**

The agent can take text already typed in an input field (with the app's visual/language
context), and when told "translate this", it:
1. Locates the focused input (AX `kAXFocusedUIElement` + value) — works for native apps and web inputs.
2. Reads the current value.
3. Translates/corrects it to the target language with the LLM (respecting the app's
   context language) — or applies a requested edit.
4. Replaces the text in the input (AX set value; fallback: select-all + type).
5. **Never presses Enter** — the swap is only a draft; the user reviews and submits it
   manually, preventing accidental sends and errors.

Example: user has an English message typed in a chat input and says *"translate this to
Polish"* → the agent reads the input, replaces it with the Polish draft, and does not send.
Example: *"fix the typos in what I wrote"* → corrected draft replaces the selection.

### Phase 12 — Agent Personas, Permissions & Subagents

User-defined agents, wired into the actual execution path.

- **C1 — Use AgentDefinitionStore in the loop.** Definitions exist in Settings → Agents but
  are not used by TaskExecutor today. Wire persona (name, system prompt, model, allowed
  tools, scope) into execution.
- **C2 — Built-in personas:** Researcher (web), Scribe (meeting notes), UI Guide (Phase 10),
  Automator (gated shell/files), Translator (STT → LLM → TTS/insert), Monitor (calendar/notifications).
  Select a persona by voice: "activate Researcher".
- **C3 — Per-agent tool permissions:** a whitelist per persona — e.g. Researcher has no
  access to insert_text or shell.
- **Per-agent model assignment** (Settings → Agents): each agent definition selects its
  model from the Ollama list (same picker as General).
- **F2 — Subagents:** an agent may spawn a subagent to help complete a task (e.g. a
  Researcher spawning a Summarizer). Subagent scope is configured in Settings → Agents the
  same way as permissions: allowed tools, system prompt, model, output contract. Parent
  waits for the subagent's result and continues.

### Phase 13 — Interaction & Feedback

- **D1 — In-overlay confirmations** (Confirm/Cancel) for dangerous actions — the user
  clicks in the overlay, the agent waits. Replaces textual gates for shell/files/out-of-domain CDP.
- **D2 — Answer rating** (thumbs up/down in the overlay) → quality log per model.
- **D3 — TTS responses** (pairs with `speak`): a "read aloud" mode for long answers.

### Phase 14 — Proactive Scheduling (cron-lite)

- **E1 — Recurring tasks:** "every morning summarize my calendar", "every Friday at 17:00
  back up the project". Implemented as scheduled queue tasks (a cron-lite evaluator).
- **Corner case — machine asleep / lid closed:** a scheduled task that fires while the
  laptop is closed or sleeping must **not be skipped**. The queue persists tasks; the
  dispatcher runs on wake, so a missed window executes as soon as the machine is active
  (optionally with an "executed late" marker in history and a notification). The same
  deferral applies to recurring tasks whose slot was missed.

### Phase 15 — Context Quality

- **F1 — Context compression:** long observations are summarized by the LLM before being
  appended (instead of truncating), keeping prompts small and responses fast — applies to
  web fetches, vision descriptions, and long transcripts.

### Phase 16 — Phone Automation (iOS) — stretch, future, non-critical

Sergey drives the user's iPhone the same way it drives the browser: accessibility-first,
element-level taps, device-rendered screenshots — for tasks like composing an SMS draft or
checking a service app's availability.

Reference scenario: "Open Booksy and find a barber available today, then prepare a reply" →
the agent opens the app, reads the accessibility tree, filters today's availability,
screenshots the calendar only if visual confirmation is needed, and returns a draft answer
the user reviews before anything is sent.

**Architecture — two paths:**

*Path A — WebDriverAgent + libimobiledevice (robust, tree-first):*
- WebDriverAgent (an XCTest runner) is installed once on the phone via Xcode with a free
  Apple ID provisioning profile; re-signed after iOS updates.
- Connection: USB via `iproxy` (libimobiledevice) tunneling WDA's HTTP API (port 8100) to
  localhost; **WiFi after the one-time USB pairing** (remote-first per user preference).
  Connection state (device name, iOS version, USB/WiFi) surfaced in Settings → Phone.
- `PhoneClient` (HTTP → WDA session API) + `phone` tool mirroring the browser pipeline:
  `elements` (accessibility tree snapshot: role, label, frame; capped ~2500 chars),
  `open_app(bundleID)`, `tap(text|index)`, `type(text)`, `scroll(direction)`, `back`,
  `screenshot` (device renderer via WDA — not the macOS screen).
- Same cost pipeline as the browser: elements first, screenshot only for visual/layout.

*Path B — iPhone Mirroring + vision (zero setup, fallback):*
- Uses the macOS iPhone Mirroring window (iOS 18+/macOS 15+); the phone appears as a
  macOS window.
- Existing `screen_capture` + vision locate targets; synthetic clicks (CGEvent) are
  forwarded by the mirror; requires D1 overlay confirmations and the mirror window visible.
- No accessibility tree → vision-only: more tokens, less reliable. Fallback when Path A is
  unavailable.

**Safety (non-negotiable):**
- `allowPhone` gate, default OFF (mirrors the `insert_text`/`browser` gates).
- SMS is **never sent**: compose drafts in Messages via accessibility taps/typing, never
  press Send — the same principle as `edit_input` (draft only; the user sends manually).
- Read-only by default (availability, calendar, contacts); taps happen only when the user
  explicitly asked for that action and confirms in the overlay (D1).
- All phone actions logged in History (per-task logs) with the same transparency as macOS
  actions.

**Steps:** P1 bridge (`iproxy` USB/WiFi pairing, state in Settings) → P2 `PhoneClient` +
`phone` toolset (elements/tap/type/screenshot/open_app) → P3 safety (gates, draft-only
SMS, confirmations) → P4 recipes (Booksy availability scenario) → P5 voice activation
("write a draft SMS to…").

**Dependencies:** Phase 2 (cost-pipeline pattern), Phase 11 (tool conventions),
Phase 13 (D1 confirmations), Phase 15 (context compression for long accessibility
snapshots).

**Risks:** WDA re-signing after iOS updates; iOS 17+ WDA quirks; iPhone Mirroring is
Apple-controlled and private (fragile, feature-gated); vision-path token cost; first-time
setup friction (Xcode + provisioning required for Path A).

---

## 4. Ordering & Dependencies

```
Phase 2 (CDP)               ← Priority 1: clicks/reads pages (cookie popups, DOM)
   ↓
Phase 1 (web tools)          ← cheap complement: text reading without images
   ↓
Phase 3 (chaining)           ← builds on Phases 1-2
Phase 4 (memory)             ← builds on existing clean history
Phase 5-8                    ← independent, by priority
Phase 9-10 (ambient + drawing) ← long-term co-pilot vision; need Phases 2, 6, live STT
Phase 11-15                  ← toolset, personas/subagents, interaction, scheduling, context
Phase 16 (phone)             ← future stretch; needs Phases 2, 11, 13, 15
```

Recommended next iteration: Phase 2 (CDP), then Phase 1, then Phase 12 (personas — the
largest untapped value in existing UI), then scheduling (Phase 14) with the wake corner case.

---

## 5. Non-Goals (current)

- Mobile/web client — macOS only (no companion iPhone app; phone control in Phase 16 runs
  through a WebDriverAgent runner on the device, a dev tool, not an App Store app).
- External API keys (OpenAI, paid services) — local-first (Ollama); exceptions only on request.
- MCP / external tool servers and JSON-defined skills — **explicitly deferred** (not in this cycle).
- Contextual app triggers ("when I open Slack, remind me") — deferred.
- Unattended automation: all destructive actions (shell, files outside the sandbox, CDP
  out-of-origin) require confirmation.
- Playwright with a bundled Node runtime — too heavy; CDP against the user's Chrome instead.

---

## 6. Testing & Validation

Each phase: (1) `xcodebuild ... build`; (2) update the cases in TESTING.md; (3) run manual
voice scenarios (Left Cmd+Opt) — voice is the primary interface. Vision/screen scenarios
should be validated on real pages and real calls before sign-off.
