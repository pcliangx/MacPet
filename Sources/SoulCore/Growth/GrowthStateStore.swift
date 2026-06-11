import Foundation

/// M3 成长档案持久化
public final class GrowthStateStore: @unchecked Sendable {
    private let dir: URL
    private let clock: SoulClock
    private let fm = FileManager.default
    private var fileURL: URL { dir.appendingPathComponent("growth-state.json") }

    public init(directory: URL, clock: SoulClock) { self.dir = directory; self.clock = clock }

    public func load() -> GrowthState {
        guard let data = try? Data(contentsOf: fileURL) else { return GrowthState() }
        return (try? JSONDecoder().decode(GrowthState.self, from: data)) ?? GrowthState()
    }

    public func save(_ s: GrowthState) throws {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(s)
        let tmp = dir.appendingPathComponent(".growth-state.tmp")
        try data.write(to: tmp, options: .atomic)
        _ = try? fm.replaceItemAt(fileURL, withItemAt: tmp)
        if !fm.fileExists(atPath: fileURL.path) { try? fm.moveItem(at: tmp, to: fileURL) }
    }
}
