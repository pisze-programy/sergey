import Foundation

public final class SkillInitializer {
    public static let shared = SkillInitializer()
    private init() {}

    public func setup() {
        SkillRegistry.shared.loadAllSkills()
        
        bindScreenCapture()
        
        print("[Skills] All skills initialized and bound.")
    }

    private func bindScreenCapture() {
        SkillRegistry.shared.setExecutor(for: "screen-capture", executor: ScreenCaptureExecutor())
    }
}
