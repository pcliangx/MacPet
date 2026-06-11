import SwiftUI

struct ChatPanel: View {
    @ObservedObject var viewModel: PetViewModel
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.chatMessages) { msg in
                            HStack(alignment: .top) {
                                if msg.role == "user" {
                                    Spacer()
                                    Text(msg.text).padding(10)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.2)))
                                } else {
                                    Text(msg.text).padding(10)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
                                    Spacer()
                                }
                            }.id(msg.id)
                        }
                    }.padding()
                }
                .onChange(of: viewModel.chatMessages.count) { _ in
                    if let last = viewModel.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            Divider()
            HStack {
                TextField("跟它说点什么…", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { send() }
                Button("发送") { send() }.keyboardShortcut(.return, modifiers: [])
            }.padding()
        }
    }
    private func send() { viewModel.sendChat(inputText); inputText = "" }
}
