import Foundation

public struct PetProject: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var description: String
    public var progress: Double
    public var status: Status
    public var createdAt: Date
    public var updatedAt: Date

    public enum Status: String, Codable, Sendable {
        case active, completed, abandoned
    }

    public init(id: String = UUID().uuidString, name: String, description: String, progress: Double = 0.0) {
        self.id = id
        self.name = name
        self.description = description
        self.progress = progress
        self.status = .active
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

public final class PetProjectStore: @unchecked Sendable {
    private let dir: URL
    private let lock = NSLock()
    private var projects: [PetProject] = []

    private var fileURL: URL { dir.appendingPathComponent("pet-projects.json") }

    public init(directory: URL) {
        self.dir = directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: fileURL),
           let p = try? JSONDecoder().decode([PetProject].self, from: data) {
            projects = p
        }
    }

    public func add(_ project: PetProject) {
        lock.lock(); defer { lock.unlock() }
        projects.append(project)
        save()
    }

    public func updateProgress(id: String, progress: Double) {
        lock.lock(); defer { lock.unlock() }
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].progress = min(1.0, max(0.0, progress))
        projects[idx].updatedAt = Date()
        if projects[idx].progress >= 1.0 {
            projects[idx].status = .completed
        }
        save()
    }

    public func getAll() -> [PetProject] {
        lock.lock(); defer { lock.unlock() }
        return projects
    }

    public func activeCount() -> Int { getAll().filter { $0.status == .active }.count }
    public func completedCount() -> Int { getAll().filter { $0.status == .completed }.count }

    private func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        let tmp = dir.appendingPathComponent(".pet-projects.tmp")
        try? data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }
}
