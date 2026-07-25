import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

final class ScreenCaptureExecutor: SkillExecutor {
    
    func execute(params: [String: Any]) async throws -> Any {
        let mode = params["mode"] as? String ?? "primary"
        
        do {
            let image: CGImage
            if mode == "region", 
               let rectDict = params["rect"] as? [String: Double] {
                image = try await captureRegion(
                    x: rectDict["x"] ?? 0,
                    y: rectDict["y"] ?? 0,
                    w: rectDict["width"] ?? 0,
                    h: rectDict["height"] ?? 0
                )
            } else {
                image = try await capturePrimaryDisplay()
            }
            
            guard let pngData = imageToPNGData(image) else {
                return SkillResult(success: false, error: "Failed to convert image to PNG")
            }
            
            return SkillResult(success: true, data: pngData)
        } catch {
            return SkillResult(success: false, error: error.localizedDescription)
        }
    }

    @MainActor
    private func capturePrimaryDisplay() async throws -> CGImage {
        let displays = try await SCShareableContent.current.displays
        guard let display = displays.first else {
            throw NSError(domain: "ScreenCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "No displays found"])
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    @MainActor
    private func captureRegion(x: Double, y: Double, w: Double, h: Double) async throws -> CGImage {
        let rect = CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h))
        let displays = try await SCShareableContent.current.displays
        guard let display = displays.first else {
            throw NSError(domain: "ScreenCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "No displays found"])
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height

        let fullImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        guard let cropped = fullImage.cropping(to: rect) else {
            throw NSError(domain: "ScreenCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Crop failed"])
        }
        return cropped
    }

    private func imageToPNGData(_ image: CGImage) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
