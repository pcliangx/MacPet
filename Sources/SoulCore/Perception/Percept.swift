// Sources/SoulCore/Perception/Percept.swift
import Foundation

public struct PerceptAction: Codable, Equatable, Sendable {
    public let id: String, label: String
    public init(id: String, label: String) { self.id = id; self.label = label }
}

public enum PerceptPriority: String, Codable, Sendable { case ambient, nudge, alert }

public struct Percept: Codable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let priority: PerceptPriority
    public let payload: [String: JSONValue]
    public let actions: [PerceptAction]
    public let at: Date
    public init(id: String = UUID().uuidString, kind: String, priority: PerceptPriority,
                payload: [String: JSONValue] = [:], actions: [PerceptAction] = [], at: Date) {
        self.id = id; self.kind = kind; self.priority = priority
        self.payload = payload; self.actions = actions; self.at = at
    }
}
