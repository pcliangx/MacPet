import Foundation

public enum DiaryWriter {
    public static func writeEntry(date: Date, events: [Memory], mood: Mood, stage: Stage) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "zh_CN")
        let dateStr = f.string(from: date)
        var lines = ["# \(dateStr) 的日记\n"]
        switch stage {
        case .egg: lines.append("……")
        case .baby: lines.append("今天…嗯…发生了…什么呢…")
        case .juvenile: lines.append("今天过得挺有意思的！")
        case .adult: lines.append("今天的一天，值得记一下。")
        }
        if !events.isEmpty {
            lines.append("\n## 今天发生的事\n")
            for e in events.prefix(5) { lines.append("- \(e.content)") }
        }
        let moodCN = ["calm": "平静", "happy": "开心", "sleepy": "犯困",
                       "missing": "想你", "sleeping": "睡着"][mood.rawValue] ?? "平静"
        lines.append("\n心情：\(moodCN)")
        return lines.joined(separator: "\n")
    }

    public static func save(entry: String, date: Date, to directory: URL) throws {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let path = directory.appendingPathComponent("\(f.string(from: date)).md")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try entry.write(to: path, atomically: true, encoding: .utf8)
    }
}
