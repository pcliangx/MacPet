import SwiftUI
import SoulCore

struct OnboardingView: View {
    @State private var step = 0
    @State private var petName = "泡沫"
    var onComplete: (AppearanceGenome) -> Void

    var body: some View {
        VStack(spacing: 24) {
            switch step {
            case 0:
                Text("🥚").font(.system(size: 64))
                Text("一颗蛋出现在你的桌面上").font(.title2)
                Button("开始孵化") { withAnimation { step = 1 } }
            case 1:
                TextField("给它起个名字", text: $petName)
                    .textFieldStyle(.roundedBorder).frame(width: 200)
                Button("就用这个名字！") {
                    let genome = AppearanceGenome.random(name: petName)
                    onComplete(genome)
                }
            default: EmptyView()
            }
        }.padding(40).frame(width: 400, height: 300)
    }
}
