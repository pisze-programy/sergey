import Foundation
import CoreGraphics

// MARK: - UI Action / Element Location Entity (Unintegrated for future use)

struct UIElementLocation: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let label: String
    
    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct VisionUIResponse: Codable {
    let answer: String
    let targetElement: UIElementLocation?
}
