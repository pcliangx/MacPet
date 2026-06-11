import Foundation

public struct GrowthState: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var totalXP: Int = 0
    public var todayXP: Int = 0
    public var bond: Int = 0
    public var stage: Stage = .baby
    public var streakDays: Int = 0
    public var lastActiveDay: String = ""
    public var todayDate: String = ""
    public var hatchDate: Date? = nil

    public static func stageForXP(_ xp: Int) -> Stage {
        if xp >= 2500 { return .adult }
        if xp >= 500 { return .juvenile }
        return .baby
    }
    public var progressToNext: Double {
        switch stage {
        case .egg, .baby: return min(1.0, Double(totalXP) / 500.0)
        case .juvenile: return min(1.0, Double(totalXP - 500) / 2000.0)
        case .adult: return 1.0
        }
    }
    public var shouldEvolve: Bool { Self.stageForXP(totalXP) > stage }
}
