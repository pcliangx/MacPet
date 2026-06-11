import SwiftUI

struct BubbleView: View {
    let text: String
    @State private var visible = true

    var body: some View {
        Text(text)
            .font(.system(size: 13, design: .rounded))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.95)))
            .shadow(radius: 4)
            .opacity(visible ? 1 : 0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation(.easeOut(duration: 0.3)) { visible = false }
                }
            }
    }
}
