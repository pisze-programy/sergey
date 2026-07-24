import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

final class ScreenCapture {

    enum CaptureError: Error {
        case noDisplays
        case cropFailed
    }

    func capturePrimaryDisplay() async throws -> CGImage {
        let displays = try await SCShareableContent.current.displays

        guard let display = displays.first else {
            throw CaptureError.noDisplays
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    func captureAllDisplays() async throws -> [CGImage] {
        let displays = try await SCShareableContent.current.displays

        guard !displays.isEmpty else {
            throw CaptureError.noDisplays
        }

        return try await withThrowingTaskGroup(of: CGImage.self) { group in
            for display in displays {
                group.addTask {
                    let filter = SCContentFilter(
                        display: display,
                        excludingApplications: [],
                        exceptingWindows: []
                    )

                    let configuration = SCStreamConfiguration()
                    configuration.width = display.width
                    configuration.height = display.height

                    return try await SCScreenshotManager.captureImage(
                        contentFilter: filter,
                        configuration: configuration
                    )
                }
            }

            var images: [CGImage] = []

            for try await image in group {
                images.append(image)
            }

            return images
        }
    }
    
    func captureRegion(_ rect: CGRect) async throws -> CGImage {
        let fullImage = try await capturePrimaryDisplay()
        guard let cropped = fullImage.cropping(to: rect) else {
            throw CaptureError.cropFailed
        }
        return cropped
    }
    
    func imageToPNGData(_ image: CGImage) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
