import Foundation

public final class SkillInitializer {
    public static let shared = SkillInitializer()
    private init() {}

    public func setup() {
        SkillRegistry.shared.loadAllSkills()
        
        bindMarkerOverlay()
        bindScreenCapture()
        
        print("[Skills] All skills initialized and bound.")
    }

    private func bindMarkerOverlay() {
        SkillRegistry.shared.setExecutor(for: "marker-overlay", executor: MarkerOverlayExecutor())
    }

    private func bindScreenCapture() {
        SkillRegistry.shared.setExecutor(for: "screen-capture", executor: ScreenCaptureExecutor())
    }
}
