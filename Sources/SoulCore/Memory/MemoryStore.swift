import Foundation

public final class MemoryStore: @unchecked Sendable {
    private let dir: URL
    private let lock = NSLock()
    private var memories: [Memory] = []
    private var fileURL: URL { dir.appendingPathComponent("memories.json") }

    public init(directory: URL) {
        self.dir = directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        loadFromDisk()
    }

    public func add(_ memory: Memory) {
        lock.lock(); defer { lock.unlock() }
        memories.append(memory); saveToDisk()
    }
    public func getAll() -> [Memory] { lock.lock(); defer { lock.unlock() }; return memories }
    public func get(id: String) -> Memory? { lock.lock(); defer { lock.unlock() }; return memories.first { $0.id == id } }
    public func update(_ memory: Memory) {
        lock.lock(); defer { lock.unlock() }
        memories = memories.map { $0.id == memory.id ? memory : $0 }; saveToDisk()
    }
    public func delete(id: String) {
        lock.lock(); defer { lock.unlock() }
        memories.removeAll { $0.id == id }; saveToDisk()
    }
    public func count(kind: MemoryKind? = nil) -> Int {
        lock.lock(); defer { lock.unlock() }
        return kind.map { k in memories.filter { $0.kind == k }.count } ?? memories.count
    }
    public func recordAccess(id: String) {
        lock.lock(); defer { lock.unlock() }
        guard let idx = memories.firstIndex(where: { $0.id == id }) else { return }
        memories[idx].accessCount += 1; memories[idx].lastAccessedAt = Date(); saveToDisk()
    }
    public func correct(id: String, newContent: String) {
        lock.lock(); defer { lock.unlock() }
        guard let idx = memories.firstIndex(where: { $0.id == id }) else { return }
        memories[idx].content = newContent
        memories[idx].confidence = max(0.3, memories[idx].confidence - 0.2); saveToDisk()
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        memories = (try? JSONDecoder().decode([Memory].self, from: data)) ?? []
    }
    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(memories) else { return }
        let tmp = dir.appendingPathComponent(".memories.tmp")
        try? data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }
}
