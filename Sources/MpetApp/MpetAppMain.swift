import SwiftUI
import AppKit

@main
struct MpetAppMain: App {
    @StateObject private var viewModel = PetViewModel()
    @State private var firstLaunch = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if firstLaunch {
                    OnboardingView { firstLaunch = false }
                } else {
                    PetWindowContent(viewModel: viewModel)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 200, height: 250)

        Window("聊天", id: "chat") {
            ChatPanel(viewModel: viewModel)
                .frame(minWidth: 350, minHeight: 400)
        }

        Settings {
            SettingsPanel(viewModel: viewModel)
        }

        MenuBarExtra("🦊 mpet", systemImage: "pawprint.fill") {
            StatusMenuContent(viewModel: viewModel)
        }
    }
}

struct PetWindowContent: View {
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        ZStack {
            SVGRenderer(state: viewModel.moodToSVGState, emote: viewModel.currentEmote)
                .frame(width: 180, height: 180)
            if let bubble = viewModel.bubbleText {
                BubbleView(text: bubble).offset(y: -110)
            }
        }
        .frame(width: 200, height: 250)
        .background(Color.clear)
        .onAppear {
            let sockPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/mpet/soul.sock").path
            viewModel.connect(socketPath: sockPath)
        }
        .onTapGesture { viewModel.sendEvent("click") }
        .contextMenu {
            Button("打开聊天") { viewModel.showChat = true }
            Divider()
            Text("心情：\(moodCN(viewModel.mood))")
            Text("注意力：\(attentionCN(viewModel.attention))")
            Divider()
            Button("退出") { NSApplication.shared.terminate(nil) }
        }
    }
    private func moodCN(_ m: String) -> String {
        ["calm": "平静", "happy": "开心", "sleepy": "犯困", "missing": "想你"][m] ?? m
    }
    private func attentionCN(_ a: String) -> String {
        ["attending": "专注", "elsewhere": "别处", "away": "离开"][a] ?? a
    }
}

struct StatusMenuContent: View {
    @ObservedObject var viewModel: PetViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("🦊 泡沫").font(.headline); Spacer()
                Text(viewModel.isConnected ? "● 已连接" : "○ 未连接").font(.caption)
                    .foregroundStyle(viewModel.isConnected ? .green : .red) }
            Divider()
            Text("心情：\(moodCN(viewModel.mood))")
            Text("注意力：\(attentionCN(viewModel.attention))")
            Text("阶段：\(stageCN(viewModel.stage))")
            Divider()
            Text("总 XP：\(viewModel.totalXP)")
            Text("今日 XP：\(viewModel.todayXP)")
            Text("连续活跃：\(viewModel.streakDays) 天")
            Text("羁绊：\(viewModel.bond)")
            ProgressView(value: viewModel.progress).frame(width: 150)
            Divider()
            Text("版本：\(viewModel.soulVersion)").font(.caption).foregroundStyle(.secondary)
        }.padding().frame(width: 200)
    }
    private func moodCN(_ m: String) -> String {
        ["calm": "平静", "happy": "开心", "sleepy": "犯困", "missing": "想你"][m] ?? m
    }
    private func attentionCN(_ a: String) -> String {
        ["attending": "专注", "elsewhere": "别处", "away": "离开"][a] ?? a
    }
    private func stageCN(_ s: String) -> String {
        ["egg": "蛋", "baby": "幼崽", "juvenile": "少年", "adult": "成年"][s] ?? s
    }
}
