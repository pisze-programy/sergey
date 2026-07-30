import Foundation
import Combine

@MainActor
final class OllamaHealthService: ObservableObject {
    static let shared = OllamaHealthService()
    
    private var _isHealthy: Bool = false { didSet { objectWillChange.send() } }
    private var _lastCheckedAt: Date? { didSet { objectWillChange.send() } }
    private var _consecutiveFailures: Int = 0 { didSet { objectWillChange.send() } }
    
    var isHealthy: Bool { _isHealthy }
    var lastCheckedAt: Date? { _lastCheckedAt }
    var consecutiveFailures: Int { _consecutiveFailures }
    
    private let client = OllamaClient()
    private var checkTimer: Timer?
    private var isCheckingHealth = false
    
    private init() {}
    
    func startMonitoring(interval: TimeInterval = 10) {
        stopMonitoring()
        
        Task { @MainActor in
            await self.performInitialHealthCheck()
        }
        
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.performHealthCheck()
            }
        }
    }
    
    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    func performInitialHealthCheck() async {
        _ = await performHealthCheck()
    }
    
    func performHealthCheck() async -> Bool {
        guard !isCheckingHealth else { return _isHealthy }
        isCheckingHealth = true
        
        let result = await client.isAvailable()
        
        if result {
            _isHealthy = true
            _consecutiveFailures = 0
        } else {
            _consecutiveFailures += 1
            if _consecutiveFailures >= 3 {
                _isHealthy = false
            }
        }
        _lastCheckedAt = Date()
        
        isCheckingHealth = false
        return result
    }
}
