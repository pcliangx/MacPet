import Foundation

/// M3 开发模式（spec §12.5）
public enum DevMode {
    public static func injectXP(_ amount: Int, into state: inout GrowthState) {
        state.totalXP += amount; state.todayXP += amount
    }
    public static func jumpToStage(_ target: Stage, state: inout GrowthState) {
        switch target {
        case .egg: state.totalXP = 0
        case .baby: state.totalXP = 0
        case .juvenile: state.totalXP = max(state.totalXP, 500)
        case .adult: state.totalXP = max(state.totalXP, 2500)
        }
        state.stage = target
    }
    public static func forceStreak(_ days: Int, state: inout GrowthState) { state.streakDays = days }
    public static func resetGrowth(_ state: inout GrowthState) { state = GrowthState() }
}
