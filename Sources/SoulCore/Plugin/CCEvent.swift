// Sources/SoulCore/Plugin/CCEvent.swift
import Foundation

public struct CCEvent: Sendable {
    public let sessionID: String
    public let cwd: String
    public let hookEventName: String
    public let transcriptPath: String
    public let toolName: String?
    public let notificationType: String?
    public let message: String?
    public let toolInputJSON: [String: JSONValue]

    public init(sessionID: String, cwd: String, hookEventName: String, transcriptPath: String,
                toolName: String? = nil, toolInput: [String: Any]? = nil,
                notificationType: String? = nil, message: String? = nil) {
        self.sessionID = sessionID; self.cwd = cwd
        self.hookEventName = hookEventName; self.transcriptPath = transcriptPath
        self.toolName = toolName; self.notificationType = notificationType; self.message = message
        var jv: [String: JSONValue] = [:]
        if let ti = toolInput {
            for (k, v) in ti {
                if let s = v as? String { jv[k] = .string(s) }
                else if let n = v as? Double { jv[k] = .number(n) }
                else if let b = v as? Bool { jv[k] = .bool(b) }
                else { jv[k] = .string("\(v)") }
            }
        }
        self.toolInputJSON = jv
    }

    public func toPercept() -> Percept {
        switch hookEventName {
        case "Notification":
            return Percept(kind: "cc.needs_you", priority: .alert,
                payload: ["title": .string(message ?? "CC 需要你"), "session": .string(sessionID),
                          "notificationType": .string(notificationType ?? "")],
                actions: [PerceptAction(id: "return-to-cc", label: "带我回那个终端")], at: Date())
        case "PreToolUse", "PostToolUse":
            return Percept(kind: "cc.working", priority: .ambient,
                payload: ["tool": .string(toolName ?? ""), "session": .string(sessionID)], at: Date())
        case "Stop":
            return Percept(kind: "cc.done", priority: .nudge, payload: ["session": .string(sessionID)], at: Date())
        case "UserPromptSubmit":
            return Percept(kind: "cc.user_talking", priority: .ambient, payload: ["session": .string(sessionID)], at: Date())
        default:
            return Percept(kind: "cc.unknown.\(hookEventName)", priority: .ambient, payload: ["session": .string(sessionID)], at: Date())
        }
    }
}

public enum CCEventParser {
    public enum CCParserError: Error { case notAnObject }
    public static func parse(_ data: Data) throws -> CCEvent {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CCParserError.notAnObject }
        return CCEvent(
            sessionID: json["session_id"] as? String ?? "",
            cwd: json["cwd"] as? String ?? "",
            hookEventName: json["hook_event_name"] as? String ?? "unknown",
            transcriptPath: json["transcript_path"] as? String ?? "",
            toolName: json["tool_name"] as? String,
            toolInput: json["tool_input"] as? [String: Any],
            notificationType: json["notification_type"] as? String,
            message: json["message"] as? String
        )
    }
}
