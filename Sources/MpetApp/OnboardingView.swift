import SwiftUI

struct OnboardingView: View {
    @State private var step = 0
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            switch step {
            case 0:
                Text("🥚").font(.system(size: 64))
                Text("一颗蛋出现在你的桌面上").font(.title2)
                Text("它即将孵化成你的专属电子生命").foregroundStyle(.secondary)
                Button("开始孵化") { withAnimation { step = 1 } }
            case 1:
                Text("✨").font(.system(size: 64))
                Text("孵化完成！").font(.title2)
                Text("「泡沫」睁开了眼睛，好奇地看着你").foregroundStyle(.secondary)
                Button("开始一起生活") { onComplete() }
            default: EmptyView()
            }
        }.padding(40).frame(width: 400, height: 300)
    }
}
