import Foundation
import CoreGraphics
import AppKit
import SwiftUI

final class TaskExecutor {
    private let ollama = OllamaClient()
    private let statusOverlay = StatusOverlayManager.shared

    private var isProcessing = false
    private var currentLivePrompt: String = "" 

    func resetProcessing() {
        isProcessing = false
    }

    func startListening() {
        guard !isProcessing else { return }
        // Audio recording functionality removed. Use other input methods.
    }

    func executeRequest() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        // TODO: Integration
        do { isProcessing = false }
    }
}
