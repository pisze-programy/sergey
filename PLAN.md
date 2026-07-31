# PLAN — Sergey: roadmapa rozwoju agenta

Dokument planistyczny: rozszerzenie Sergey z "otwieracza linków" do w pełni interaktywnego agenta
(przeglądarka, łańcuchy zadań, pamięć, integracje). Na podstawie stanu z 2026-07-31.

---

## 1. Wizja

Sergey ma być aktywnym asystentem macOS: słucha (STT), widzi (screen + wizja), **działa w przeglądarce**
(CDP), **czyta** strony (fetch/search), **łączy zadania w łańcuchy** i pamięta kontekst.
Użytkownik mówi: *"Sprawdź pogodę na jutro i podsumuj"* → agent sam wyszukuje, wchodzi, czyta, podsumowuje.

## 2. Stan obecny (co już mamy — fundament)

| Warstwa | Elementy | Status |
|---|---|---|
| **UI** | Overlay (NSPanel floating, zawsze-na-wierzchu), lista kolejki ze statusami na żywo (Queued/Running/Completed/Failed), ticker statusów | ✅ |
| **Wejście** | STT głosowe: Left ⌘+⌥ → agent, Right ⌘+⌥ → transkrypcja do aplikacji; dyktowanie Parakeet | ✅ |
| **Kolejka** | TaskQueueManager (priorytet, retry 3×, persistence JSON, sortowanie), TaskDispatcher (4 równoległe, health-check Ollama), odzyskiwanie po restarcie | ✅ |
| **Pętla agenta** | TaskExecutor: ReAct (Thought/Action/Observation/Final Answer), max 6 iteracji, streaming do tickera (throttled), statusy krótkie | ✅ |
| **Narzędzia** | screen_capture (+ opis wizyjny gdy skonfigurowany), open_url (http/https whitelist), frontmost_app, insert_text (bezpieczny prompt), notify | ✅ |
| **LLM** | OllamaClient: streaming NDJSON (OpenAI-compat) + natywny /api/chat (wizja), LLMService | ✅ |
| **Ustawienia** | General (URL, picker modeli z Ollamy, vision model), Records, History, Agents, Queue | ✅ |
| **Persistence** | SettingsStore, TaskQueueManager, HistoryStore (per-zadanie, logi czyste ≤300 zn.), STTRecordStore, AgentDefinitionStore | ✅ |
| **Okna** | Settings = normalne okno (Cmd+Tab przez aktywację .regular/.accessory, resize, pozycja), overlay = floating | ✅ |
| **Bezpieczeństwo** | open_url whitelist, insert_text zakazany bez jawnej prośby, uczciwość modelu w promptcie | ✅ |

**Architektura:** warstwy Core (Agents/LLM, Agents/Providers, Agents/Tools, Orchestrator, Services, System, Persistence, Models) + UI (Managers, Panels, Views). Xcode 16 z PBXFileSystemSynchronizedRootGroup (nowe pliki auto-sync). Singletony (konwencja projektu).

---

## 3. Roadmapa fazowa

### Faza 1 — Web & dane (tekstowe czytanie stron) 🟢 ~0.5–1 dzień
Agent przestaje tylko otwierać linki — **czyta ich treść**.

- **Tool `search_web(query)`** — DuckDuckGo HTML (`html.duckduckgo.com/html/?q=`) lub Bing (`bing.com/search?q=`) bez klucza API; parser regex → top 5 (tytuł, URL, snippet) jako obserwacja
- **Tool `fetch_url(url)`** — URLSession + ekstrakcja tekstu z HTML (strip tagów, entity decode, usuń script/style); limit rozmiaru (np. 8k znaków); whitelist http/https
- **Tool `weather_forecast(city)`** — Open-Meteo API (bez klucza): geokodowanie + `hourly=temperature_2m,precipitation,weathercode` + timezone; zwraca prognozę na 7 dni — **pewne dane pogodowe** zamiast zgadywania
- **Prompt**: poinformować model o nowych narzędziach; reguła: wolno `fetch_url`/`search_web` zamiast `open_url`, chyba że użytkownik prosi o otwarcie
- **Risks**: JS-heavy strony → pusty tekst (fallback: wizja albo komunikat); blokady botów (DDG czasem CAPTCHA — retry/fetch z user-agent)

### Faza 2 — CDP: prawdziwe sterowanie przeglądarką 🔴 ~2–4 dni (priorytet użytkownika)
Agent **klika, scrolluje, wypełnia formularze, czyta zrenderowany DOM, robi screenshoty**.

**Architektura (proponowana):**
- `Core/Agents/Tools/Browser/CDPClient.swift` — klient WebSocket (URLSessionWebSocketTask) do Chrome DevTools Protocol; JSON-RPC (id/result/event), kolejkowanie komend, timeouty
- `Core/Agents/Tools/Browser/BrowserSession.swift` — zarządzanie procesem Chrome: uruchomienie z `--remote-debugging-port=9222 --user-data-dir=<temp>`, detekcja portu, cleanup przy wyjściu; fallback: podpięcie do działającej instancji
- `Core/Agents/Tools/Browser/BrowserTool.swift` — narzędzie z akcjami:
  - `navigate(url)` → `Page.navigate`
  - `click(selector|text)` → `Runtime.evaluate` (querySelector + click) — selektor albo wyszukanie tekstu
  - `read(url|current)` → pobranie `document.body.innerText` (zrenderowany tekst!)
  - `scroll(direction)` → `Runtime.evaluate(window.scrollBy)`
  - `screenshot()` → `Page.captureScreenshot` → zapis PNG + opcjonalnie wizja
  - `type(selector, text)` / `press(Enter)` → formularze
- **Obserwacja do modelu**: tekst strony / wynik akcji (krótkie, ≤2k zn.)
- **Bezpieczeństwo**: akcje TYLKO na http/https; `navigate` poza domeną startową wymaga zgody w promptcie; timeout na każdą komendę (15 s); konfigurowalne "dowolne strony" vs "whitelist domen"
- **Wymaganie**: zainstalowany Chrome/Chromium (wykrywanie przez `NSWorkspace` / `open -a`)
- **Kejs docelowy**: "wejdź na stronę pogodową, znajdź jutro 14:00, podsumuj" — agent: navigate → read → podsumowanie
- **Risks**: WebSocket + CDP to sporo kodu niskopoziomowego; strony z anti-bot (Cloudflare) — ograniczone; przetestować na: wikipedia, wttr.in, open-meteo, portal pogodowy

### Faza 3 — Chaining: łańcuchy zadań i wieloagentowość 🟡 ~1–2 dni
Zadania zależne wykonują się sekwencyjnie, a wynik jednego agenta zasila kolejnego.

- **Zależności w kolejce** — `QueuedTask.dependsOnTaskId: UUID?`: TaskDispatcher nie startuje zadania B, dopóki A nie ma statusu `.completed` (lub `.failed` → B się nie uruchamia / wariant "kontynuuj mimo błędu")
- **Przekazywanie wyniku** — `QueuedTask.inputFrom: UUID?`: prompt B = `promptB + "\n\nResult from previous task:\n" + finalAnswer(A)`; wariant: osobny kanał `task.output`
- **Wieloagentowe wzorce**:
  - *Researcher → Summarizer*: agent A zbiera (search/fetch/CDP), agent B podsumowuje
  - *Fan-out*: jedno polecenie → N niezależnych podzadań (np. "sprawdź 3 źródła") równolegle (kolejka to umie)
  - *Fan-in*: wyniki N zadań → 1 agregator
- **Składnia poleceń** (przykłady): "najpierw X, potem Y" → 2 zadania z dependsOn; konwersja w TaskExecutor/nowym `ChainBuilder`
- **UI**: wiersze w kolejce pokazują łańcuch (indent / ikona zależności); wizualizacja w Settings → Queue
- **Risks**: cykle w zależnościach (walidacja przy enqueue); martwe blokady (timeout na "czekanie na rodzica"); kolejka ma limit 4 równoległych — łańcuch to też zadania

### Faza 4 — Pamięć i kontekst 🟡 ~1–2 dni
- **Pamięć sesyjna**: historia konwersacji per "temat" (last N zadań) — TaskExecutor dokleja podsumowania poprzednich zadań do promptu (już mamy czystą historię per-zadanie — wystarczy selektor)
- **Pamięć długoterminowa (RAG, opcjonalnie)**: embeddingi (np. nomic-embed-text przez Ollama) + zapis wektorowy w pliku JSON (bez zewn. baz) — "pamiętasz, co ustaliliśmy w zeszłym tygodniu?"
- **Notatki/context store**: `sergey_context.json` — fakty, preferencje użytkownika, dane wielokrotnego użytku; tool `remember(fact)` / `recall(query)`
- **Risks**: kontrola rozmiaru promptu; priorytet: sesyjna pamięć najpierw (tania), RAG później

### Faza 5 — Integracje produktywności 🟡 ~1–2 dni
- **Kalendarz** — odczyt EventKit (kalendarz lokalny): "czy mogę wziąć to spotkanie?"; zapis z potwierdzeniem
- **Pliki (bezpieczne operacje)** — tool `file_ops`: list/read/write w `~/Documents/Sergey/` (piaskownica katalogowa), kopiowanie, podsumowanie pliku; ZAKAZ operacji poza dozwolonym katalogiem bez potwierdzenia
- **Terminal (z potwierdzeniem)** — tool `shell(command)` z gatem: wymagane potwierdzenie użytkownika (UI w overlayu) dla komend "niebezpiecznych" (rm, sudo, git push...); biała lista bezpiecznych (ls, cat, pwd)
- **Schowek** — read/write clipboard (przydatne: "skopiuj mi to")
- **Powiadomienia/planowanie** — `schedule_notify(time, text)` (odroczone powiadomienia), powtarzalne zadania w kolejce (cron-lite)

### Faza 6 — Jakość modelu i routing 🟡 ~1 dzień
- **Routing modeli**: mały/szybki model do klasyfikacji intencji i formatowania akcji; duży do rozumowania. Ustawienie `fastModel` (jak vision/correction — wiemy już, jak to dodać)
- **Strukturalne akcje zamiast tekstowego ReAct** (opcjonalnie): model zwraca JSON `{"tool": "...", "params": {...}}` — parsowanie stabilniejsze niż regex; wsparcie function-calling w Ollama (tools w /api/chat)
- **Fallback modelu** — jeśli główny model nie odpowie w formacie → retry z innym modelem

### Faza 7 — UX i dopracowanie 🟢 ~1 dzień
- **Konfigurowalne skróty** (Settings → Hotkeys): przypisanie akcji do kombinacji; wykrywanie konfliktów
- **Screen Recording w PermissionManager + onboarding** (brakuje — znany gap)
- **Auto-pruning** listy zadań (stare completed znikają po N) i activeAgents (górny limit)
- **Focus Mode** — dokończyć (ukrywanie tickera, tryb cichy)
- **Potwierdzenia w overlayu** dla niebezpiecznych akcji (gate dla shell/CDP poza whitelistem)

### Faza 8 — Dystrybucja 🟡 ~1–2 dni
- Podpisanie (Developer ID) + notaryzacja (notarytool), DMG (build.sh już jest)
- Auto-update (Sparkle lub prosty check github releases)
- Crash reporting (opcjonalnie) — raporty do pliku, bez telemetrii domyślnie

---

## 4. Kolejność i zależności

```
Faza 1 (web/search/weather)  ← fundament czytania; tania; robi kejs pogodowy
   ↓
Faza 2 (CDP)                  ← wymaga fetch/search mentalnie; niezależne technicznie
   ↓
Faza 3 (chaining)             ← korzysta z F1/F2 (łańcuchy webowych zadań)
   ↓
Faza 4 (pamięć)               ← korzysta z czystej historii (już jest)
   ↓
Fazy 5–8                      ← niezależne, wg priorytetu użytkownika
```

**Rekomendowana najbliższa iteracja:** Faza 1 (search_web + fetch_url + weather_forecast) — domyka kejs pogodowy bez CDP; potem Faza 2 (CDP) — klikanie, o które pytałeś.

## 5. Świadome "nie" (non-goals na teraz)

- Aplikacja webowa/telefon — tylko macOS
- Zewnętrzne API z kluczami (OpenAI, serwisy płatne) — priorytet lokalność (Ollama); wyjątki tylko na wyraźne życzenie
- Pełna automatyzacja bez zgody — wszystkie akcje destrukcyjne (shell, pliki poza sandboxem, CDP poza domeną) wymagają potwierdzenia
- Playwright z bundlowanym Node — zbyt ciężkie; wybieramy CDP (Chrome użytkownika)

## 6. Jak testować (w skrócie)

Każda faza: 1) build `xcodebuild ... build`, 2) kejsy w TESTING.md (aktualizować na bieżąco),
3) manualne kejsy głosowe (Left ⌘+⌥) — bo to główny interfejs.
