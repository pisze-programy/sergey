import Foundation

/// Minimal Chrome DevTools Protocol (CDP) client backed by a WebSocket.
///
/// Responsibilities:
///   - HTTP endpoint discovery: `GET http://127.0.0.1:9222/json` returns the
///     `webSocketDebuggerUrl` of a page target.
///   - WebSocket connection to that URL via `URLSessionWebSocketTask`.
///   - JSON-RPC command layer (`sendCommand`) with per-command timeouts and
///     routing of responses back to the waiting caller.
///   - Ready-made page helpers (`navigate`, `evaluate`, `currentPageText`,
///     `pageElements`, `screenshotJPEG`, `pageTitle`) used by the future
///     BrowserTool.
///
/// Threading: the app builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
/// so every type defaults to `@MainActor`. This type opts out explicitly with
/// `nonisolated`: URLSession's WebSocket machinery must never run on the main
/// actor. The session delegate callbacks arrive on a private background
/// `OperationQueue` and the async `receive()` loop runs inside a detached task.
/// All mutable state is guarded by `lock`, which makes the type safe to share
/// across executors (`@unchecked Sendable`).
nonisolated final class CDPClient: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {

    static let shared = CDPClient()

    private static let errorDomain = "sergey.tools.browser.cdp"

    /// How long to wait for the WebSocket handshake (`didOpen`) before giving up.
    private static let connectTimeout: TimeInterval = 10

    // MARK: - State (all access guarded by `lock`)

    private let lock = NSLock()
    /// Serial background queue that receives the URLSession delegate callbacks.
    private let delegateQueue: OperationQueue

    private var session: URLSession?
    private var socketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var isConnected = false
    /// The URL of the currently open WebSocket (nil while not connected or
    /// mid-handshake). Lets `performConnect` distinguish a no-op reconnect to
    /// the same endpoint from a genuine reconnect to a NEW endpoint (e.g. after
    /// Chrome restarted and handed out a fresh `webSocketDebuggerUrl`).
    private var connectedURL: URL?
    private var nextCommandID = 1

    /// Continuations for `connect(to:)` callers still waiting on the handshake.
    private var openWaiters: [CheckedContinuation<Void, Error>] = []
    /// Continuations for in-flight commands, keyed by their JSON-RPC id.
    private var pendingCommands: [Int: CheckedContinuation<[String: Any], Error>] = [:]

    private override init() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "sergey.cdp.delegate"
        queue.qualityOfService = .utility
        delegateQueue = queue
        super.init()
    }

    // MARK: - Endpoint discovery

    /// Discovers the WebSocket URL of a page target from Chrome's DevTools
    /// HTTP endpoint (defaults to `http://127.0.0.1:9222`). Prefers a dedicated
    /// disposable tab (empty url or `about:blank`) so that attaching to a
    /// running Chrome never hijacks a page the user is actively viewing; falls
    /// back to the first page with a non-empty URL. Throws if no page target
    /// exists.
    func discoverPageWebSocketURL(endpoint: URL = URL(string: "http://127.0.0.1:9222")!) async throws -> URL {
        let discoveryURL = endpoint.appendingPathComponent("json")
        var request = URLRequest(url: discoveryURL)
        request.timeoutInterval = 5
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        // Keep the HTTP fetch off the main actor.
        let (data, response) = try await Task.detached {
            try await URLSession.shared.data(for: request)
        }.value

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: Self.errorDomain, code: 11,
                          userInfo: [NSLocalizedDescriptionKey: "Chrome DevTools endpoint returned HTTP \(status)"])
        }

        guard let targets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(domain: Self.errorDomain, code: 12,
                          userInfo: [NSLocalizedDescriptionKey: "Chrome DevTools endpoint returned unreadable JSON"])
        }

        var fallback: URL?
        for target in targets {
            guard (target["type"] as? String) == "page",
                  let wsString = target["webSocketDebuggerUrl"] as? String,
                  let wsURL = URL(string: wsString) else { continue }
            let targetURL = target["url"] as? String ?? ""
            // In attach mode we attach to an already-running Chrome, so prefer
            // a tab that is empty or `about:blank` — a dedicated/disposable
            // tab that we may navigate without disturbing the user. Only if no
            // such tab exists do we fall back to a page with a real URL.
            if targetURL.isEmpty || targetURL == "about:blank" {
                return wsURL
            }
            if fallback == nil {
                fallback = wsURL
            }
        }
        if let fallback {
            return fallback
        }

        throw NSError(domain: Self.errorDomain, code: 13,
                      userInfo: [NSLocalizedDescriptionKey: "No 'page' target found on the Chrome DevTools endpoint (\(endpoint.absoluteString))"])
    }

    // MARK: - Connection

    /// Opens a WebSocket connection to the given Chrome DevTools endpoint.
    /// Idempotent while a connection to the *same* URL is already open; a
    /// connection to a different URL is considered stale and replaced. Throws
    /// if the handshake fails or does not complete within `connectTimeout`
    /// seconds.
    func connect(to url: URL) async throws {
        // Run the whole handshake off the main actor.
        try await Task.detached {
            try await self.performConnect(to: url)
        }.value
    }

    private func performConnect(to url: URL) async throws {
        guard let scheme = url.scheme?.lowercased(), scheme == "ws" || scheme == "wss" else {
            throw NSError(domain: Self.errorDomain, code: 14,
                          userInfo: [NSLocalizedDescriptionKey: "Unsupported WebSocket URL scheme '\(url.scheme ?? "(none)")' (expected ws:// or wss://)"])
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Loop so a racing connect() that installs a socket (or completes a
            // handshake) while we tear down a stale one is re-evaluated instead
            // of being shared with a mismatched connection.
            while true {
                lock.lock()
                if isConnected {
                    if connectedURL == url {
                        // Already connected to the exact URL we were asked for
                        // — nothing to do.
                        lock.unlock()
                        continuation.resume()
                        return
                    }
                    // Connected to a STALE endpoint (e.g. Chrome restarted and
                    // the caller discovered a NEW ws URL). Tear the old
                    // connection down via the shared disconnection path so any
                    // pending waiters/commands get proper errors, then loop
                    // around and establish a fresh connection.
                    if let staleTask = socketTask {
                        lock.unlock()
                        handleDisconnection(of: staleTask, error: NSError(
                            domain: Self.errorDomain, code: 47,
                            userInfo: [NSLocalizedDescriptionKey: "Reconnecting to a new Chrome DevTools endpoint (previous socket went stale)"]
                        ))
                        continue
                    }
                    // Defensive: `isConnected` without a socket is an
                    // inconsistent state — clear the flag and fall through to a
                    // fresh connect.
                    isConnected = false
                }
                if socketTask != nil {
                    // A handshake is already in flight — share it.
                    openWaiters.append(continuation)
                    lock.unlock()
                    return
                }

                // No live connection and no handshake in flight: start one.
                let newSession = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: delegateQueue)
                let newTask = newSession.webSocketTask(with: url)
                session = newSession
                socketTask = newTask
                openWaiters = [continuation]
                isConnected = false
                connectedURL = nil
                // Assign the receive loop atomically with installing the socket
                // (both under `lock`) so a teardown can never read a
                // half-installed loop for this socket.
                receiveTask = startReceiveLoop(for: newTask)
                lock.unlock()

                newTask.resume()

                // Handshake watchdog: if didOpen never arrives, tear the attempt down
                // so connect(to:) doesn't hang forever.
                Task.detached { [weak self] in
                    try? await Task.sleep(for: .seconds(Self.connectTimeout))
                    self?.failStaleConnectAttempt(task: newTask)
                }
                return
            }
        }
    }

    /// Fails a connect attempt whose handshake never completed.
    private func failStaleConnectAttempt(task: URLSessionWebSocketTask) {
        lock.lock()
        let stale = socketTask !== task || isConnected
        lock.unlock()
        guard !stale else { return }
        handleDisconnection(of: task, error: NSError(
            domain: Self.errorDomain, code: 15,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for the WebSocket handshake"]
        ))
    }

    // MARK: - JSON-RPC command layer

    /// Sends a CDP command and awaits its response. The response is routed from
    /// the background receive loop to this caller via the id-keyed continuation.
    /// Enforces `timeout`; on timeout (or any failure) the pending continuation
    /// is removed and an error thrown.
    func sendCommand(_ method: String, params: [String: Any] = [:], timeout: TimeInterval = 15) async throws -> [String: Any] {
        let (id, task) = try reserveCommand()
        let effectiveTimeout = max(timeout, 0.1)

        let payload: [String: Any] = ["id": id, "method": method, "params": params]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let message = String(data: data, encoding: .utf8) else {
            throw NSError(domain: Self.errorDomain, code: 20,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to serialize command '\(method)'"])
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Any], Error>) in
            registerPending(continuation, id: id)

            // Send the frame off the main actor.
            Task.detached {
                do {
                    try await task.send(.string(message))
                } catch {
                    self.failCommand(id: id, error: NSError(
                        domain: Self.errorDomain, code: 21,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to send command '\(method)': \(error.localizedDescription)"]
                    ))
                }
            }

            // Per-command timeout. The response normally beats this; if not, the
            // continuation is removed and resumed with a timeout error.
            Task.detached {
                try? await Task.sleep(for: .seconds(effectiveTimeout))
                self.failCommand(id: id, error: NSError(
                    domain: Self.errorDomain, code: 22,
                    userInfo: [NSLocalizedDescriptionKey: "CDP command '\(method)' timed out after \(Int(effectiveTimeout))s"]
                ))
            }
        }
    }

    // MARK: - Convenience helpers (used by the future BrowserTool)

    /// Navigates the current page to `urlString` (Page.navigate). Throws when
    /// Chrome reports a navigation error (e.g. `net::ERR_NAME_NOT_RESOLVED`).
    func navigate(to urlString: String) async throws {
        let result = try await sendCommand("Page.navigate", params: ["url": urlString])
        if let errorText = result["errorText"] as? String, !errorText.isEmpty {
            throw NSError(domain: Self.errorDomain, code: 46,
                          userInfo: [NSLocalizedDescriptionKey: "Navigation failed: \(errorText)"])
        }
    }

    /// Evaluates an arbitrary JavaScript expression in the current page context
    /// (Runtime.evaluate with `returnByValue`) and returns its value. The value
    /// is nil when the expression evaluated to `undefined`/`null` or the CDP
    /// response carried no `result.value` payload.
    func evaluate(_ expression: String) async throws -> Any? {
        let result = try await sendCommand("Runtime.evaluate", params: [
            "expression": expression,
            "returnByValue": true
        ])
        return (result["result"] as? [String: Any])?["value"]
    }

    /// Returns the visible text of the current page (Runtime.evaluate with
    /// `returnByValue`). An empty string when the page has no body.
    func currentPageText() async throws -> String {
        let value = try await evaluate("document.body ? document.body.innerText : \"\"")
        return value as? String ?? ""
    }

    /// Captures a JPEG screenshot of the current page (Page.captureScreenshot).
    func screenshotJPEG(quality: Int = 75) async throws -> Data {
        let result = try await sendCommand("Page.captureScreenshot", params: [
            "format": "jpeg",
            "quality": quality
        ])
        guard let base64 = result["data"] as? String, let data = Data(base64Encoded: base64) else {
            throw NSError(domain: Self.errorDomain, code: 44,
                          userInfo: [NSLocalizedDescriptionKey: "Screenshot response did not contain valid base64 image data"])
        }
        return data
    }

    /// Returns the current page title (Runtime.evaluate `document.title`).
    func pageTitle() async throws -> String {
        let value = try await evaluate("document.title")
        return value as? String ?? ""
    }

    /// Single-expression IIFE that walks the page's DOM and returns up to 60
    /// unique interactive elements (links, buttons, inputs, selects, headings,
    /// role-based buttons/links and `aria-label`ed nodes) as a JSON array of
    /// `[tag, text, href, placeholder, type]` rows. Returns a JSON string, or
    /// `"ERR: <message>"` when the document is unavailable or extraction throws.
    private static let domElementsScript = """
    (() => {
      try {
        if (!document || !document.querySelectorAll) return "ERR: no document";
        const MAX = 60;
        const seen = new Set();
        const out = [];
        const els = document.querySelectorAll('a,button,input,textarea,select,h1,h2,h3,h4,h5,h6,[role="button"],[role="link"],[aria-label]');
        for (const el of els) {
          if (out.length >= MAX) break;
          const tag = el.tagName.toLowerCase();
          const text = (el.getAttribute('aria-label') || el.innerText || el.textContent || '').trim().replace(/\\s+/g, ' ').slice(0, 60);
          const key = tag + '|' + text;
          if (seen.has(key)) continue;   // dedupe identical entries to save tokens
          seen.add(key);
          const href = el.getAttribute('href') || '';
          const placeholder = el.getAttribute('placeholder') || '';
          const type = el.getAttribute('type') || '';
          out.push([tag, text, href, placeholder, type]);
        }
        return JSON.stringify(out);
      } catch (e) {
        return "ERR: " + (e && e.message ? e.message : String(e));
      }
    })()
    """

    /// Returns the current page's DOM structure: rows of
    /// `[tag, text, href, placeholder, type]` for up to 60 unique interactive
    /// elements (links, buttons, inputs, headings…). Much cheaper than a
    /// screenshot for locating content. Throws when the embedded JS reports an
    /// error or its JSON payload cannot be decoded.
    func pageElements() async throws -> [[String]] {
        let jsonString = try await evaluate(Self.domElementsScript) as? String ?? ""
        if jsonString.hasPrefix("ERR:") {
            let message = String(jsonString.dropFirst("ERR:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: Self.errorDomain, code: 47,
                          userInfo: [NSLocalizedDescriptionKey: "DOM element extraction failed: \(message)"])
        }
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let rows = object as? [[String]] else {
            throw NSError(domain: Self.errorDomain, code: 47,
                          userInfo: [NSLocalizedDescriptionKey: "DOM element extraction failed: unparseable result"])
        }
        return rows
    }

    /// Gracefully closes the WebSocket and fails any in-flight commands.
    func close() async {
        let state = captureAndClose()
        state.receiveTask?.cancel()

        let closeError = NSError(domain: Self.errorDomain, code: 42,
                                 userInfo: [NSLocalizedDescriptionKey: "CDP connection closed by client"])
        for waiter in state.waiters { waiter.resume(throwing: closeError) }
        for (_, continuation) in state.pending { continuation.resume(throwing: closeError) }

        state.task?.cancel(with: .goingAway, reason: nil)
        if let session = state.session {
            // Hop off the calling thread; invalidating a session mid-delegate-
            // callback can deadlock, so let the delegate queue do it.
            delegateQueue.addOperation { session.invalidateAndCancel() }
        }
    }

    deinit {
        let state = captureAndClose()
        state.receiveTask?.cancel()

        let error = NSError(domain: Self.errorDomain, code: 43,
                            userInfo: [NSLocalizedDescriptionKey: "CDPClient deallocated"])
        for waiter in state.waiters { waiter.resume(throwing: error) }
        for (_, continuation) in state.pending { continuation.resume(throwing: error) }

        state.task?.cancel()
        state.session?.invalidateAndCancel()
    }

    // MARK: - Lock helpers (synchronous — never touch NSLock from async bodies)

    private struct TearDownState {
        let task: URLSessionWebSocketTask?
        let session: URLSession?
        let receiveTask: Task<Void, Never>?
        let waiters: [CheckedContinuation<Void, Error>]
        let pending: [Int: CheckedContinuation<[String: Any], Error>]
    }

    /// Reserves the next JSON-RPC id for a command, requiring an open socket.
    private func reserveCommand() throws -> (Int, URLSessionWebSocketTask) {
        lock.lock(); defer { lock.unlock() }
        guard let task = socketTask, isConnected else {
            throw NSError(domain: Self.errorDomain, code: 30,
                          userInfo: [NSLocalizedDescriptionKey: "Not connected to a Chrome DevTools WebSocket endpoint. Call connect(to:) first."])
        }
        let id = nextCommandID
        nextCommandID += 1
        return (id, task)
    }

    private func registerPending(_ continuation: CheckedContinuation<[String: Any], Error>, id: Int) {
        lock.lock(); defer { lock.unlock() }
        pendingCommands[id] = continuation
    }

    /// Removes and returns the continuation for `id` if it is still pending.
    private func takePending(id: Int) -> CheckedContinuation<[String: Any], Error>? {
        lock.lock(); defer { lock.unlock() }
        return pendingCommands.removeValue(forKey: id)
    }

    /// Fails the command with the given id if it has not been answered yet.
    private func failCommand(id: Int, error: Error) {
        takePending(id: id)?.resume(throwing: error)
    }

    /// Atomically drains all connection state. Used by `close()` and `deinit`.
    private func captureAndClose() -> TearDownState {
        lock.lock(); defer { lock.unlock() }
        let state = TearDownState(
            task: socketTask,
            session: session,
            receiveTask: receiveTask,
            waiters: openWaiters,
            pending: pendingCommands
        )
        socketTask = nil
        session = nil
        receiveTask = nil
        openWaiters = []
        pendingCommands = [:]
        isConnected = false
        connectedURL = nil
        return state
    }

    // MARK: - Receive loop

    /// Creates and returns the receive loop for `task`. The caller assigns the
    /// returned task to `receiveTask` *while holding `lock`* (in
    /// `performConnect`, atomically with installing `socketTask`). Invariant:
    /// `receiveTask` is only ever read/nilled inside the same lock that guards
    /// `socketTask`, and teardown always cancels the *captured* reference — so
    /// a loop belonging to a replaced socket can never cancel (or be confused
    /// with) a newer socket's loop.
    private func startReceiveLoop(for task: URLSessionWebSocketTask) -> Task<Void, Never> {
        Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                do {
                    switch try await task.receive() {
                    case .string(let text):
                        self?.handleIncomingMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self?.handleIncomingMessage(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    self?.handleDisconnection(of: task, error: error)
                    break
                }
            }
        }
    }

    /// Parses an incoming JSON-RPC message and resumes the matching caller.
    /// Events (no `id`) and responses for already-failed commands are ignored.
    private func handleIncomingMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? Int,
              let continuation = takePending(id: id) else {
            return
        }

        if let errorObject = json["error"] as? [String: Any] {
            let errorMessage = errorObject["message"] as? String ?? "Unknown CDP error"
            continuation.resume(throwing: NSError(
                domain: Self.errorDomain, code: 40,
                userInfo: [NSLocalizedDescriptionKey: "CDP error: \(errorMessage)"]
            ))
        } else if let result = json["result"] as? [String: Any] {
            continuation.resume(returning: result)
        } else {
            continuation.resume(returning: [:])
        }
    }

    // MARK: - Connection teardown

    /// Tears down the connection. Safe to call more than once: events from a
    /// previous socket are ignored and a fully torn-down connection is a no-op.
    private func handleDisconnection(of task: URLSessionWebSocketTask, error: Error?) {
        lock.lock()
        // Stale event from a socket that has already been replaced — ignore.
        guard socketTask === task else {
            lock.unlock()
            return
        }
        let staleSession = session
        socketTask = nil
        session = nil
        isConnected = false
        connectedURL = nil
        // Capture the receive loop together with the socket (under the same
        // lock) so we never cancel a loop installed by a *replacement* socket
        // that connected after we released the lock.
        let receiveLoop = receiveTask
        receiveTask = nil
        let waiters = openWaiters
        openWaiters = []
        let pending = pendingCommands
        pendingCommands = [:]
        lock.unlock()

        receiveLoop?.cancel()

        let disconnectError = NSError(
            domain: Self.errorDomain, code: 41,
            userInfo: [NSLocalizedDescriptionKey: "CDP connection closed: \(error?.localizedDescription ?? "socket closed")"]
        )
        for waiter in waiters { waiter.resume(throwing: disconnectError) }
        for (_, continuation) in pending { continuation.resume(throwing: disconnectError) }

        task.cancel()
        if let staleSession {
            // This can run from within a delegate callback; invalidating the
            // session synchronously there can deadlock, so hop to the queue.
            delegateQueue.addOperation { staleSession.invalidateAndCancel() }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        lock.lock()
        // Ignore handshake results from a replaced socket.
        guard socketTask === webSocketTask else {
            lock.unlock()
            return
        }
        isConnected = true
        connectedURL = webSocketTask.originalRequest?.url
        let waiters = openWaiters
        openWaiters = []
        lock.unlock()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        handleDisconnection(of: webSocketTask, error: nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let webSocketTask = task as? URLSessionWebSocketTask else { return }
        handleDisconnection(of: webSocketTask, error: error)
    }

}
