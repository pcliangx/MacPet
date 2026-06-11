import Foundation
import SoulCore

struct SoulConfig: Codable {
    var llm: LLMConfig
    var watchedBundleIDs: [String] = ["com.apple.Terminal", "com.googlecode.iterm2", "com.microsoft.VSCode"]
    var nudgeBudgetPerHour: Int = 4

    static var path: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mpet/soul.json")
    }
    static func load() throws -> SoulConfig {
        if let base = ProcessInfo.processInfo.environment["MPET_BASE_URL"],
           let url = URL(string: base) {
            return SoulConfig(llm: LLMConfig(
                baseURL: url,
                apiKey: ProcessInfo.processInfo.environment["MPET_API_KEY"] ?? "",
                model: ProcessInfo.processInfo.environment["MPET_MODEL"] ?? "gpt-4o-mini"))
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(SoulConfig.self, from: data)
    }
}
