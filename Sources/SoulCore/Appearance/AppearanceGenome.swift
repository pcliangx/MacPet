import Foundation

public struct AppearanceGenome: Codable, Equatable, Sendable {
    public var furHue: Int
    public var furSaturation: Int
    public var earShape: EarShape
    public var eyeStyle: EyeStyle
    public var tailType: TailType
    public var pattern: Pattern
    public var blushEnabled: Bool
    public var petName: String
    public var species: String

    public enum EarShape: String, Codable, Sendable, CaseIterable {
        case roundTri = "round-tri", pointy = "pointy", floppy = "floppy", catLike = "cat-like"
    }
    public enum EyeStyle: String, Codable, Sendable, CaseIterable {
        case roundXL = "round-XL", roundSmall = "round-small", anime = "anime", sleepyEyes = "sleepy"
    }
    public enum TailType: String, Codable, Sendable, CaseIterable {
        case fluffyComma = "fluffy-comma", bushy = "bushy", short = "short", curl = "curl"
    }
    public enum Pattern: String, Codable, Sendable, CaseIterable {
        case none, stripes = "stripes", spots = "spots", gradient = "gradient"
    }

    public static let `default` = AppearanceGenome(
        furHue: 28, furSaturation: 90, earShape: .roundTri, eyeStyle: .roundXL,
        tailType: .fluffyComma, pattern: .none, blushEnabled: true,
        petName: "泡沫", species: "圆滚滚的橘色小狐狸"
    )

    public static func random(name: String = "小生命", species: String = "神秘小动物") -> AppearanceGenome {
        AppearanceGenome(
            furHue: Int.random(in: 0...360), furSaturation: Int.random(in: 60...95),
            earShape: EarShape.allCases.randomElement()!, eyeStyle: EyeStyle.allCases.randomElement()!,
            tailType: TailType.allCases.randomElement()!, pattern: Pattern.allCases.randomElement()!,
            blushEnabled: Bool.random(), petName: name, species: species
        )
    }
}
