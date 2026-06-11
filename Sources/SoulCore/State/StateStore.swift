// Sources/SoulCore/State/StateStore.swift
import Foundation

/// 生命档案的最小内核（硬约束 §12.2）：原子写（tmp+rename）、损坏自愈留证、每日备份轮转。
public final class StateStore: @unchecked Sendable {
    private let dir: URL
    private let clock: SoulClock
    private let fm = FileManager.default
    private var fileURL: URL { dir.appendingPathComponent("soul-state.json") }
    private var backupDir: URL { dir.appendingPathComponent("backups") }

    public init(directory: URL, clock: SoulClock) {
        self.dir = directory; self.clock = clock
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
    }

    public func load() -> SoulState {
        guard let data = try? Data(contentsOf: fileURL) else { return SoulState() }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        if let s = try? dec.decode(SoulState.self, from: data) { return s }
        let stamp = Int(clock.now.timeIntervalSince1970)
        try? fm.moveItem(at: fileURL, to: dir.appendingPathComponent("soul-state.corrupt.\(stamp)"))
        return SoulState()
    }

    public func save(_ s: SoulState) throws {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(s)
        let tmp = dir.appendingPathComponent(".soul-state.tmp")
        try data.write(to: tmp, options: .atomic)
        // replaceItemAt requires the destination to already exist.
        // Fall back to moveItem on first save when fileURL is absent.
        if fm.fileExists(atPath: fileURL.path) {
            _ = try fm.replaceItemAt(fileURL, withItemAt: tmp)
        } else {
            try fm.moveItem(at: tmp, to: fileURL)
        }
        try backupIfNewDay(data)
    }

    private func backupIfNewDay(_ data: Data) throws {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        let name = "soul-state.\(f.string(from: clock.now)).json"
        let url = backupDir.appendingPathComponent(name)
        guard !fm.fileExists(atPath: url.path) else { return }
        try data.write(to: url, options: .atomic)
        let all = (try fm.contentsOfDirectory(atPath: backupDir.path)).sorted()
        for old in all.dropLast(7) {
            try? fm.removeItem(at: backupDir.appendingPathComponent(old))
        }
    }
}
