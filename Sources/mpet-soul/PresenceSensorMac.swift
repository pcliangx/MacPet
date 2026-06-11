import AppKit
import CoreGraphics
import SoulCore

enum PresenceSensorMac {
    static func snapshot(watched: Set<String>) -> PresenceSnapshot {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                           eventType: CGEventType(rawValue: ~0)!)
        return PresenceSnapshot(frontmostBundleID: front, idleSeconds: idle, watchedBundleIDs: watched)
    }
}
