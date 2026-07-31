import AppKit
import Foundation

/// Owns the single shared Chrome/Chromium instance that Sergey drives through
/// the Chrome DevTools Protocol (CDP).
///
/// Strategy is "attach first": if anything already answers on the CDP port
/// (`http://127.0.0.1:9222`) we adopt it — it may be the user's own Chrome or a
/// leftover from a previous run — and we never terminate it. Only when the port
/// is silent do we spawn our own browser with a dedicated temporary profile, so
/// the `--remote-debugging-port` flag is guaranteed to be honoured: launching a
/// binary that is already running without a separate `--user-data-dir` would
/// just focus the existing instance and ignore the flag.
///
/// Threading: the app defaults every type to `@MainActor`; this class opts out
/// explicitly with `nonisolated` so `Process` spawning, `URLSession` probing and
/// the launch poll loop never block the main actor. Shared state is guarded by
/// an `NSLock`, which makes the type safe to share across executors
/// (`@unchecked Sendable`), mirroring `CDPClient`.
nonisolated final class BrowserSession: @unchecked Sendable {

    static let shared = BrowserSession()

    // MARK: - Constants

    /// CDP HTTP port. Tab/discovery endpoints (`/json`) hang off this port.
    private let port = 9222
    /// Time budget for probing an already-running browser before deciding to
    /// launch our own.
    private let probeTimeout: TimeInterval = 1.5
    /// Poll interval while waiting for a freshly launched browser to open its port.
    private let launchPollInterval: TimeInterval = 0.5
    /// Overall budget for the browser to open the CDP port after launch.
    private let launchTimeout: TimeInterval = 15

    /// Browser binaries we can drive through CDP, in order of preference.
    private static let candidateBrowserPaths = [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
    ]

    // MARK: - Shared state (guarded by `lock`)

    private let lock = NSLock()
    /// True when a browser is confirmed to be answering on the CDP port.
    private var running = false
    /// True only when the running browser was spawned by this session and is
    /// therefore safe to terminate on shutdown.
    private var launchedByUs = false
    /// The spawned browser process (nil in attach mode).
    private var chromeProcess: Process?
    /// The temp profile directory of the spawned browser (for cleanup).
    private var profileDirectory: URL?
    /// Single-flight gate: at most one launch sequence runs at a time.
    private var launchTask: Task<Void, Error>?

    private init() {}

    // MARK: - Public API

    /// Thread-safe read of whether a debuggable browser is available.
    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return running
    }

    /// Base URL of the CDP HTTP endpoint, e.g. `http://127.0.0.1:9222`.
    /// CDPClient uses this for `/json` tab discovery.
    func cdpEndpointURL() -> URL {
        // 127.0.0.1 (not "localhost") — avoids IPv6 (::1) resolution surprises.
        URL(string: "http://127.0.0.1:\(port)")!
    }

    /// Ensures a browser with CDP on the configured port is available.
    ///
    /// Idempotent: if the endpoint already answers it is reused (attach mode);
    /// otherwise Chrome/Chromium/Brave is launched with a dedicated temp profile
    /// and we poll until the endpoint responds or `launchTimeout` elapses.
    func ensureRunning() async throws {
        // Reclaim leftover `sergey-chrome-profile-*` temp dirs from crashed or
        // force-quit runs before anything else, so a fresh launch always starts
        // from a clean slate.
        sweepStaleProfiles()

        // Attach-first: reuse any browser that already exposes CDP.
        if await probeCDP() {
            adoptAttachedBrowser()
            return
        }

        // A browser we previously tracked has gone away — forget it so the
        // launch below starts from a clean slate.
        forgetStaleBrowser()

        // Single-flight: concurrent callers must not spawn two browsers that
        // would fight over port 9222. `takeLaunchSlot()` atomically returns the
        // in-flight task (the caller just waits on it) or creates and stores a
        // fresh one, reporting the caller as its owner.
        let slot = takeLaunchSlot()
        if !slot.ownsSlot {
            try await slot.task.value
            return
        }

        // Only the launch owner releases the slot; a waiter must never clear a
        // slot that a later caller may already have claimed.
        defer { clearLaunchSlot() }

        do {
            try await slot.task.value
        } catch {
            // Launch failed (spawn error or timeout). Kill anything we started
            // so we never leak a half-dead Chrome holding the port.
            terminateOwnedProcess()
            throw error
        }
    }

    /// Terminates the browser process — but ONLY if this session spawned it.
    /// A pre-existing external Chrome (attach mode) is never touched.
    ///
    /// Hook: the app should call `BrowserSession.shared.shutdown()` from its
    /// termination handler (e.g. `AppDelegate.applicationWillTerminate`).
    /// Wiring that up is intentionally left to the app layer.
    func shutdown() {
        terminateOwnedProcess()
    }

    deinit {
        // Singleton, so this practically never runs, but keep it crash-free.
        shutdown()
    }

    // MARK: - Probing / attaching

    /// Probes the CDP version endpoint. `true` means a debuggable browser is
    /// already listening; any error (connection refused, timeout, non-200) is
    /// treated as "not available" so callers fall through to launching.
    private func probeCDP() async -> Bool {
        let url = cdpEndpointURL().appendingPathComponent("json/version")
        var request = URLRequest(url: url)
        request.timeoutInterval = probeTimeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func adoptAttachedBrowser() {
        lock.lock(); defer { lock.unlock() }
        if !running {
            // First time we see a responder it is not ours (we never launched),
            // so it must never be terminated by shutdown().
            launchedByUs = false
        }
        // If we already own a running browser, keep launchedByUs = true so
        // shutdown() still cleans it up.
        running = true
    }

    private func forgetStaleBrowser() {
        lock.lock()
        let staleProfile = launchedByUs ? profileDirectory : nil
        running = false
        if launchedByUs {
            chromeProcess = nil
            profileDirectory = nil
            launchedByUs = false
        }
        lock.unlock()

        // A self-launched browser died while we weren't looking; reclaim its
        // temp profile directory so we don't accumulate garbage on repeated
        // runs. Best-effort: a directory still in use is not removable and
        // `sweepStaleProfiles()` will catch it on the next run.
        if let staleProfile {
            try? FileManager.default.removeItem(at: staleProfile)
        }
    }

    // MARK: - Launching

    /// Resolves the browser binary, spawns it with the CDP flag and a dedicated
    /// temp profile, then polls until the CDP endpoint responds.
    private static func launchAndWaitForEndpoint(_ session: BrowserSession) async throws {
        let browserURL = try resolveBrowserBinary()
        let profileURL = try makeProfileDirectory()

        let process = Process()
        process.executableURL = browserURL
        process.arguments = session.chromeArguments(profilePath: profileURL.path)
        // Null device: if Chrome ever writes to stdout/stderr we must not let a
        // full pipe buffer deadlock the child.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        // Record ownership BEFORE run() so shutdown() can terminate the process
        // even if the launch fails midway.
        session.setOwnedProcess(process, profileDirectory: profileURL)

        do {
            try process.run()
        } catch {
            throw NSError(
                domain: "sergey.browser",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to launch browser at \(browserURL.path): \(error.localizedDescription)"]
            )
        }

        // The browser has just materialised its first window (the "about:blank"
        // tab). Hide the whole app so it never appears over the user's work;
        // CDP drives the renderer independently of window visibility, so
        // navigation and screenshots are unaffected. Best-effort: if the lookup
        // fails the window just stays put (it is already offscreen).
        session.hideWindowOf(process)

        // Poll until the CDP port answers or we exhaust the budget.
        let deadline = Date().addingTimeInterval(session.launchTimeout)
        while Date() < deadline {
            if await session.probeCDP() {
                session.setRunning(true)
                return
            }
            try await Task.sleep(for: .seconds(session.launchPollInterval))
        }

        throw NSError(
            domain: "sergey.browser",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for Chrome DevTools on port \(session.port) (started \(browserURL.path))"]
        )
    }

    private func chromeArguments(profilePath: String) -> [String] {
        [
            "--remote-debugging-port=\(port)",
            "--user-data-dir=\(profilePath)",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-background-networking",
            // Keep the agent's browser off the user's screen: the window is
            // placed far offscreen so it never steals focus or appears over the
            // user's work.
            "--window-position=-32000,-32000",
            // Offscreen/hidden tabs must keep executing. Without this, Chrome
            // throttles timers in non-visible tabs and CDP navigation/evaluate
            // calls can stall.
            "--disable-background-timer-throttling",
            "about:blank",
        ]
    }

    /// Hides the freshly launched browser app so its window never appears over
    /// the user's work. The renderer keeps running fully in the background —
    /// CDP navigation, evaluation and screenshots are unaffected by window
    /// visibility. Best-effort: failure to look up or hide the app is ignored.
    private func hideWindowOf(_ process: Process) {
        guard let app = NSRunningApplication(processIdentifier: process.processIdentifier) else { return }
        app.hide()
    }

    private static func resolveBrowserBinary() throws -> URL {
        for path in candidateBrowserPaths where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        throw NSError(
            domain: "sergey.browser",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No supported browser found. Install Google Chrome (or Chromium/Brave) to enable browser automation."]
        )
    }

    private static func makeProfileDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sergey-chrome-profile-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        } catch {
            throw NSError(
                domain: "sergey.browser",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create temporary Chrome profile at \(url.path): \(error.localizedDescription)"]
            )
        }
    }

    // MARK: - State mutation (under lock)

    private func setOwnedProcess(_ process: Process, profileDirectory: URL) {
        lock.lock(); defer { lock.unlock() }
        chromeProcess = process
        self.profileDirectory = profileDirectory
        launchedByUs = true
    }

    private func setRunning(_ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        running = value
    }

    /// Result of claiming the single-flight launch slot.
    private struct LaunchSlot {
        /// The task to await: either the pre-existing in-flight launch or the
        /// freshly created one.
        let task: Task<Void, Error>
        /// `true` only for the caller that created the task and therefore owns
        /// the slot (it must release it with `clearLaunchSlot()` once done).
        let ownsSlot: Bool
    }

    /// Atomically claims the single-flight launch slot.
    ///
    /// If a launch is already in flight, the existing task is returned with
    /// `ownsSlot == false` and the caller simply waits on it. Otherwise a fresh
    /// launch task is created, stored and returned with `ownsSlot == true`. The
    /// task is created here, under the lock, so a losing caller never spawns a
    /// duplicate browser behind the winner's back.
    private func takeLaunchSlot() -> LaunchSlot {
        lock.lock(); defer { lock.unlock() }
        if let inFlight = launchTask {
            return LaunchSlot(task: inFlight, ownsSlot: false)
        }
        let newTask = Task { [self] in
            try await Self.launchAndWaitForEndpoint(self)
        }
        launchTask = newTask
        return LaunchSlot(task: newTask, ownsSlot: true)
    }

    /// Atomically releases the single-flight launch slot. Called (via `defer`)
    /// by the launch owner once its launch sequence has finished.
    private func clearLaunchSlot() {
        lock.lock(); defer { lock.unlock() }
        launchTask = nil
    }

    // MARK: - Cleanup

    /// Best-effort sweep of leftover `sergey-chrome-profile-*` temp directories.
    ///
    /// The profile directory is only removed on a clean `shutdown()`; if Sergey
    /// crashes or is force-quit, the last temp profile leaks into
    /// `temporaryDirectory`. Calling this at the top of `ensureRunning()`
    /// reclaims that space before a new launch. Directories still in use by a
    /// live Chrome make `removeItem` throw, which we deliberately ignore — those
    /// are not stale.
    private func sweepStaleProfiles() {
        let tmp = FileManager.default.temporaryDirectory
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: tmp, includingPropertiesForKeys: nil
        ) else { return }
        for entry in entries where entry.lastPathComponent.hasPrefix("sergey-chrome-profile-") {
            try? FileManager.default.removeItem(at: entry)
        }
    }

    /// Terminates and forgets the browser process if — and only if — this
    /// session spawned it. Attached (pre-existing) browsers are left alone; the
    /// temp profile directory is removed best-effort.
    private func terminateOwnedProcess() {
        lock.lock()
        let process = chromeProcess
        let ownsIt = launchedByUs
        let profile = profileDirectory
        chromeProcess = nil
        profileDirectory = nil
        launchedByUs = false
        running = false
        lock.unlock()

        guard ownsIt, let process else { return }

        waitForProcessExit(process, timeout: 2)

        if let profile {
            try? FileManager.default.removeItem(at: profile)
        }
    }

    /// SIGTERMs the process and waits briefly, escalating to SIGKILL if it is
    /// still alive after the timeout.
    private func waitForProcessExit(_ process: Process, timeout: TimeInterval) {
        guard process.isRunning else { return }
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }
        process.terminate()
        if semaphore.wait(timeout: .now() + timeout) == .timedOut, process.isRunning {
            // Chrome can ignore SIGTERM (e.g. while flushing its profile); escalate.
            kill(process.processIdentifier, SIGKILL)
        }
    }
}
