// Sources/SoulCore/Plugin/CCSpoolMonitor.swift
import Foundation

/// 监听 cc-watcher spool 目录。hook 命令将事件写入此目录，monitor 解析并转发。
public actor CCSpoolMonitor {
    private let spoolDir: URL
    private var handler: (@Sendable (CCEvent) -> Void)?
    private var processedFiles: Set<String> = []
    private var scanTimer: Task<Void, Never>?
    private var isRunning = false

    public init(spoolDir: URL) {
        self.spoolDir = spoolDir
        try? FileManager.default.createDirectory(at: spoolDir, withIntermediateDirectories: true)
    }

    public func setHandler(_ handler: @escaping @Sendable (CCEvent) -> Void) {
        self.handler = handler
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        if let existing = try? FileManager.default.contentsOfDirectory(atPath: spoolDir.path) {
            processedFiles.formUnion(existing)
        }
        scanTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self?.scan()
            }
        }
    }

    public func stop() {
        isRunning = false
        scanTimer?.cancel()
        scanTimer = nil
    }

    private func scan() {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: spoolDir.path) else { return }
        for file in files.sorted() where !processedFiles.contains(file) && file.hasSuffix(".json") {
            processedFiles.insert(file)
            let path = spoolDir.appendingPathComponent(file)
            guard let data = try? Data(contentsOf: path),
                  let event = try? CCEventParser.parse(data) else { continue }
            handler?(event)
            try? FileManager.default.removeItem(at: path)
        }
    }
}
