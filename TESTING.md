# TESTING — Instrukcja testowania Sergey

Prosta instrukcja: jak uruchomić aplikację, przetestować agenta i czego się spodziewać.

---

## 1. Wymagania wstępne

1. **Uruchom Ollama** (serwer lokalny):
   ```bash
   ollama serve
   ```
2. **Sprawdź, czy model istnieje**:
   ```bash
   ollama list
   ```
   Model ustawiony w aplikacji musi być na tej liście.
   Jeśli go nie ma — zmień model w **Settings → General** (np. `qwen2.5:14b`, `llama3.1`, `mistral`).

## 2. Uruchomienie aplikacji

- **Z Xcode:** otwórz `sergey.xcodeproj` → Run (⌘R)
- **Z build scripta:** `./build.sh --no-dmg`

### Po uruchomieniu spodziewaj się:

| Co | Jak wygląda |
|---|---|
| Ikona w menu barze | Menu: Settings (⚙️) i Quit |
| Overlay | Panel z szkła w prawym górnym rogu (350×55) |
| Onboarding (pierwszy start) | Prośba o uprawnienia: Accessibility, Microphone, Notifications — **wszystkie zaakceptuj** |

## 3. Skróty klawiszowe

| Skrót | Akcja |
|---|---|
| `Left Cmd + Left Opt` (przytrzymaj, mów, puść) | **STT → Agent**: głosowa komenda dla agenta z dowolnego miejsca w macOS. Nagranie → transkrypcja → zadanie w kolejce agenta |
| `Right Cmd + Right Opt` (przytrzymaj, mów, puść) | **STT → transkrypcja**: tekst wstawiany do aktywnej aplikacji (bez agenta) |
| `Ctrl + Opt` | Rozwiń / zwiń overlay |
| `Esc` | Zwiń overlay |

> Nie ma już pola tekstowego w overlayu — agenta wywołujesz **głosem** (Left Cmd+Left Opt) albo ręcznie dodając zadanie w **Settings → Queue**.

## 4. Jak przetestować agenta głosowo (krok po kroku)

1. Przytrzymaj **Left Cmd + Left Opt** (overlay rozwinie się sam)
2. Powiedz komendę, np. *"Open example.com"*
3. Puść klawisze
4. Obserwuj w overlayu: zadanie jako **Queued** (szare) → **Running** (zielone) → **Completed** (niebieskie)
5. Ticker w nagłówku pokazuje krótkie statusy: `💭 Agent 1: thinking…` → `🔧 Agent 1: open_url…` → `✅ Agent 1: done`
6. Powiadomienie z odpowiedzią agenta

## 5. Checklista testowa — czego się spodziewać

> Komendy głosowe wymawiasz podczas trzymania `Left Cmd + Left Opt`. Alternatywnie możesz dodać zadanie ręcznie w **Settings → Queue** (dokładnie ten sam prompt).

### A. Podstawy
- [ ] **T1 — Prosta odpowiedź:** powiedz `What is 2+2?` → odpowiedź "4", powiadomienie.
- [ ] **T2 — Streaming:** podczas T1 ticker pokazuje `💭 Agent 1: thinking…`, a wiersz agenta aktualizuje się treścią odpowiedzi.
- [ ] **T3 — Kolejkowanie:** wyślij komendę i od razu drugą → **obie się wykonują po kolei**; druga widoczna jako **"Queued"** (szara), potem "Running", potem "Completed".

### B. Narzędzia
- [ ] **T4 — open_url:** powiedz `Open https://example.com` → przeglądarka otwiera example.com.
- [ ] **T5 — frontmost_app:** powiedz `Which app is in front right now?` → odpowiedź z nazwą aktywnej aplikacji.
- [ ] **T6 — screen_capture:** powiedz `Take a screenshot` → agent informuje o zapisaniu. Sprawdź plik:
  ```bash
  ls -la /var/folders/*/T/sergey-screen-*.png
  ```
  ⚠️ Wymaga uprawnienia: **System Settings → Privacy & Security → Screen Recording** → zaznacz sergey. Bez tego screenshot będzie pusty.
  💡 **Wizja (opcjonalnie):** jeśli w **Settings → General → Vision model** ustawisz model wizyjny (np. `llama3.2-vision` po `ollama pull llama3.2-vision`), agent po zrobieniu screenshotu **opisze, co widzi na ekranie** — powiedz `What do you see on my screen?` i powinieneś dostać opis zawartości ekranu.
- [ ] **T7 — insert_text:** otwórz Notatki, powiedz `Type "Hello from Sergey" into the frontmost app` → tekst pojawia się w Notatkach (wymaga Accessibility).
- [ ] **T8 — notify:** powiedz `Send me a notification saying "Test OK"` → powiadomienie macOS na ekranie.
- [ ] **T7b — Bezpieczeństwo insert_text:** powiedz `What is the weather in Poznan?` (pytanie, bez prośby o wpisywanie) → agent **NIE powinien** wpisywać niczego do żadnej aplikacji; ma uczciwie odpowiedzieć, że nie może sprawdzić pogody (brak narzędzia web).

### C. Wieloetapowość i kolejka
- [ ] **T9 — Łańcuch narzędzi:** powiedz `Take a screenshot, then open https://example.com and notify me when done` → agent wykonuje **3 narzędzia po kolei** i podaje Final Answer.
- [ ] **T9b — Wielu agentów naraz:** wyślij 4–5 komend pod rząd (np. mieszanka open_url / frontmost_app / notify) → wykonują się **równolegle** (do 4 naraz), każdy ma własny wiersz w overlayu.
- [ ] **T9c — Priorytety:** w Settings → Queue dodaj zadanie z niskim priorytetem (np. 1) i wysokim (np. 10) → najpierw wykonuje się to z wyższym priorytetem.

### D. Obsługa błędów
- [ ] **T10 — Ollama offline:** zatrzymaj Ollama, wyślij komendę → zadanie czeka w kolejce jako "Pending" (nie ginie); po włączeniu Ollamy wykonuje się samo. Aplikacja nie zawiesza się.
- [ ] **T10b — Restart w trakcie zadania:** wyślij długą komendę, zabij aplikację (⌘Q) i uruchom ponownie → zadanie w kolejce wraca do "Pending" i wykonuje się zamiast blokować kolejkę.
- [ ] **T11 — Błąd w środku pętli:** zatrzymaj Ollama w trakcie T9 → zadanie dostaje status "Retrying (1/3)…", po przywróceniu Ollamy próbuje ponownie (max 3 razy, potem "Failed"). Brak zawieszenia.

### E. STT — transkrypcja (bez agenta)
- [ ] **T12 — Transkrypcja do aplikacji:** przytrzymaj `Right Cmd + Right Opt`, mów, puść → tekst wstawiony do aktywnej aplikacji, **zero interakcji z agentem** (nic nie trafia do kolejki).
- [ ] **T12b — Rozdzielność skrótów:** `Right Cmd + Right Opt` → tylko transkrypcja; `Left Cmd + Left Opt` → tylko agent. Sprawdź, że lewa para nie wstawia tekstu, a prawa nie tworzy zadań.
- [ ] **T12c — Korekta transkrypcji:** powiedz zdanie bez pauz/interpunkcji (np. "spotkanie o trzeciej jutro przenosimy na piątek") → wstawiony tekst powinien mieć **poprawną interpunkcję i wielkie litery** (korektor `gemma3:1b` — ustawienie w Settings → Records → Correction model; wymaga `ollama pull gemma3:1b`). Jeśli model niedostępny — tekst wstawia się surowy (fallback).

### F. Okno Settings
- [ ] **T17 — Normalne okno (nie zawsze na wierzchu):** otwórz Settings, kliknij w inną aplikację (np. przeglądarkę) → okno Settings chowa się **pod** nią; overlay **nadal zostaje na wierzchu**.
- [ ] **T18 — Resize:** złap róg okna Settings → pojawia się kursor zmiany rozmiaru, okno się rozciąga/skurcza (min. 720×480).
- [ ] **T19 — Pamiętanie pozycji/rozmiaru:** przesuń okno w róg i zmień rozmiar, ⌘Q, uruchom ponownie → Settings otwiera się w **tej samej pozycji i rozmiarze**.

### G. Regression (sprawdzić, że nic się nie zepsuło)
- [ ] **T13 — Kolejka z narzędziami:** Settings → Queue → dodaj zadanie `Open https://example.com` → zadanie wykonuje się **z narzędziami** (otwiera przeglądarkę), stan `running → completed`.
- [ ] **T14 — Persistence:** zmień model w Settings, zrestartuj aplikację → ustawienie zostaje (`~/.sergey_config.json`).
- [ ] **T15 — Historia:** po testach kliknij wiersz zadania w overlayu → panel z logami; Settings → History → rekordy istnieją.
- [ ] **T16 — Skróty:** `Ctrl+Opt` toggle, `Esc` zwija, oba pary dyktowania działają — bez crashy.

### H. Przeglądarka agenta (browser tool) — wymaga Chrome + zgody w ustawieniach

> Najpierw włącz: **Settings → General → Agent Tools → Enable browser automation**. Agent ma **własną, ukrytą instancję Chrome** (osobny profil, okno poza ekranem) — Twoja przeglądarka i myszka są nietykane. Screenshoty przeglądarki robi z renderera (bez zgody Screen Recording).

- [ ] **B1 — read:** powiedz `Open https://example.com and read the page title` → agent nawiguje (własna, ukryta przeglądarka) i podaje tytuł strony.
- [ ] **B2 — elements (drzewo DOM):** powiedz `Go to wykop.pl and list the main navigation links` → agent używa `browser elements` (struktura DOM, nie screenshot) i wypisuje linki. Sprawdź w logach (Settings → History), że nie wykonał screen_capture.
- [ ] **B3 — screenshot przeglądarki:** powiedz `Open example.com and take a screenshot of that page` → plik `sergey-browser-*.jpg` w temp:
  ```bash
  ls -la /var/folders/*/T/sergey-browser-*.jpg
  ```
  Obrazek pokazuje **stronę agenta**, nie Twój ekran.
- [ ] **B4 — izolacja:** miej otwartą własną przeglądarkę z Twoimi zakładkami; poproś agenta o `Open https://news.ycombinator.com and summarize the top stories` → Twoje zakładki/cookies nietknięte; agent pracuje w osobnej instancji (sprawdź `ps aux | grep sergey-chrome-profile`).
- [ ] **B5 — gate bezpieczeństwa:** wyłącz "Enable browser automation" w ustawieniach, poproś o `Open example.com and read it` → agent **uczciwie odpowiada**, że automatyzacja przeglądarki jest wyłączona; nie odpala Chrome.
- [ ] **B6 — żadnych zabranych klików:** podczas pracy agenta używaj myszki w innych aplikacjach → kursor nigdy nie jest przejmowany; kliknięcia agenta są wirtualne (w rendererze jego przeglądarki).

## 6. Znane ograniczenia (przed wypuszczeniem na produkcję)

1. **Screen Recording nie jest jeszcze w onboarding** — trzeba dodać ręcznie w ustawieniach systemu.
2. **Jakość modelu ma znaczenie** — jeśli LLM nie trzyma formatu `Action: tool(...)`, agent krąży 6 iteracji i kończy błędem. Zmień model na lepszy.
3. **Wizja wymaga modelu wizyjnego** — bez ustawienia go w Settings → General, screenshot jest tylko zapisywany (bez opisu).
4. **Lista zadań w overlayu rośnie bez limitu** — zakończone wiersze nie są automatycznie usuwane (max 50 widocznych). Planowane: auto-pruning.
5. **Agent nie czyta stron internetowych** — open_url tylko otwiera przeglądarkę; brak narzędzia web/webscrape (kolejny etap).

## 7. Sugerowana kolejność testów

Zacznij od: **T1 → T4 → T6 → T7b → T9 → T9b → T10 → T12b → T17 → T18**.
Jeśli te przechodzą — rdzeń agenta, kolejka, STT i okno Settings działają poprawnie, reszta to szczegóły.
