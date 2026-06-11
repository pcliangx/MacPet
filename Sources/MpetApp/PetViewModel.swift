import Foundation
import SwiftUI
import Combine
import SoulCore

@MainActor
final class PetViewModel: ObservableObject {
    @Published var genome: AppearanceGenome = .default
    @Published var mood: String = "calm"
    @Published var attention: String = "elsewhere"
    @Published var stage: String = "baby"
    @Published var soulVersion: String = "?"
    @Published var isConnected: Bool = false
    @Published var bubbleText: String? = nil
    @Published var chatMessages: [ChatEntry] = []
    @Published var currentEmote: String = "idle"
    @Published var showChat: Bool = false
    @Published var showOnboarding: Bool = false
    @Published var totalXP: Int = 0
    @Published var todayXP: Int = 0
    @Published var streakDays: Int = 0
    @Published var bond: Int = 0
    @Published var progress: Double = 0.0

    struct ChatEntry: Identifiable {
        let id = UUID()
        let role: String
        var text: String
    }

    private var client: SoulClient?
    private var currentAssistantText = ""

    var moodToSVGState: String {
        switch mood {
        case "happy": return "happy"
        case "sleepy": return "sleepy"
        case "missing": return "missyou"
        case "sleeping": return "sleeping"
        default: return "idle"
        }
    }

    func connect(socketPath: String) {
        let c = SoulClient(socketPath: socketPath)
        Task {
            await c.setMessageHandler { [weak self] msg in
                Task { @MainActor in self?.handleMessage(msg) }
            }
            await c.connect()
            await c.performHandshake()
            await MainActor.run { self.startStatusPolling() }
        }
        client = c
    }

    func disconnect() { Task { await client?.disconnect() }; client = nil }

    func sendChat(_ text: String) {
        guard !text.isEmpty else { return }
        chatMessages.append(ChatEntry(role: "user", text: text))
        currentAssistantText = ""
        Task { await client?.send(.chatUser(text: text)) }
    }

    func sendEvent(_ kind: String) {
        Task { await client?.send(.event(kind: kind, payload: [:])) }
    }

    func requestStatus() {
        Task { await client?.send(.status) }
    }

    func startStatusPolling() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.requestStatus()
        }
    }

    private func handleMessage(_ msg: PeripheralMessage) {
        switch msg {
        case .helloOK(_, let v):
            isConnected = true; soulVersion = v; requestStatus()
        case .statusOK(let f):
            mood = f["mood"]?.stringValue ?? "calm"
            attention = f["attention"]?.stringValue ?? "elsewhere"
            stage = f["stage"]?.stringValue ?? "baby"
            if case .number(let v) = f["totalXP"] { totalXP = Int(v) }
            if case .number(let v) = f["todayXP"] { todayXP = Int(v) }
            if case .number(let v) = f["streakDays"] { streakDays = Int(v) }
            if case .number(let v) = f["bond"] { bond = Int(v) }
            if case .number(let v) = f["progress"] { progress = v }
        case .chatDelta(let text):
            currentAssistantText += text
            if let last = chatMessages.last, last.role == "assistant" {
                chatMessages[chatMessages.count - 1].text = currentAssistantText
            } else {
                chatMessages.append(ChatEntry(role: "assistant", text: currentAssistantText))
            }
        case .chatDone: currentAssistantText = ""
        case .directive(let kind, let payload):
            switch kind {
            case "speak": bubbleText = payload["text"]?.stringValue
            case "emote": currentEmote = payload["animation"]?.stringValue ?? "idle"
            case "notify": bubbleText = payload["title"]?.stringValue
            default: break
            }
        default: break
        }
    }
}
