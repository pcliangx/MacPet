import Foundation

public enum ClawAuthManager {
    public static func authorize(tool: ToolSpec, currentStage: Stage, requestTier: ToolTier) -> Bool {
        guard currentStage >= tool.minStage else { return false }
        switch requestTier {
        case .freeHome, .freeRead, .ask: return true
        case .never: return false
        }
    }

    public static func authorizePlugin(toolTier: ToolTier) -> Bool {
        switch toolTier {
        case .freeRead, .ask: return true
        case .freeHome, .never: return false
        }
    }

    public static func canAccess(path: String, tier: ToolTier, petHomeDir: String) -> Bool {
        if path.hasPrefix(petHomeDir) { return true }
        switch tier {
        case .freeHome: return path.hasPrefix(petHomeDir)
        case .freeRead, .ask: return true
        case .never: return false
        }
    }
}
