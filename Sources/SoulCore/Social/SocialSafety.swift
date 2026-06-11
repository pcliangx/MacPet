import Foundation

/// M8 社交礼仪与安全（spec §9.5）：拉黑/举报/过滤/仅好友模式
public final class SocialSafety: @unchecked Sendable {
    private let dir: URL
    private let lock = NSLock()
    private var state: SafetyState
    private var fileURL: URL { dir.appendingPathComponent("social-safety.json") }

    public struct SafetyState: Codable, Equatable, Sendable {
        public var blockedNodeIds: Set<String> = []
        public var reports: [Report] = []
        public var friendsOnlyMode: Bool = false
        public var socialEnabled: Bool = true   // 社交总开关（spec §9.6）
        public init() {}
    }

    public struct Report: Codable, Equatable, Sendable {
        public let nodeId: String
        public let reason: String
        public let reportedAt: Date
    }

    public init(directory: URL) {
        self.dir = directory
        self.state = SafetyState()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: fileURL),
           let s = try? JSONDecoder().decode(SafetyState.self, from: data) { state = s }
    }

    // ── 拉黑 ──
    public func block(nodeId: String) {
        lock.lock(); defer { lock.unlock() }
        state.blockedNodeIds.insert(nodeId); save()
    }
    public func unblock(nodeId: String) {
        lock.lock(); defer { lock.unlock() }
        state.blockedNodeIds.remove(nodeId); save()
    }
    public func isBlocked(nodeId: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return state.blockedNodeIds.contains(nodeId)
    }

    // ── 举报 ──
    public func report(nodeId: String, reason: String) {
        lock.lock(); defer { lock.unlock() }
        state.reports.append(Report(nodeId: nodeId, reason: reason, reportedAt: Date()))
        save()
    }
    public var reportCount: Int { lock.lock(); defer { lock.unlock() }; return state.reports.count }

    // ── 模式开关 ──
    public var friendsOnlyMode: Bool {
        get { lock.lock(); defer { lock.unlock() }; return state.friendsOnlyMode }
        set { lock.lock(); defer { lock.unlock() }; state.friendsOnlyMode = newValue; save() }
    }
    public var socialEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return state.socialEnabled }
        set { lock.lock(); defer { lock.unlock() }; state.socialEnabled = newValue; save() }
    }

    /// 是否允许与该节点互动（综合检查）
    public func allowsInteraction(nodeId: String, isFriend: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard state.socialEnabled else { return false }
        guard !state.blockedNodeIds.contains(nodeId) else { return false }
        if state.friendsOnlyMode && !isFriend { return false }
        return true
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        let tmp = dir.appendingPathComponent(".social-safety.tmp")
        try? data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }
}
