import Foundation

public enum EconomyEngine {
    public static let dailyXPCap = 150
    public static let fuelXPCap = 80
    public static let interactionBonusCap = 20
    public static let chatBonusCap = 20
    public static let basePresenceXP = 10

    public static func calcXPGain(
        basePresence: Int = basePresenceXP, fuelRaw: Double = 0,
        interactionBonuses: Int = 0, chatBonuses: Int = 0,
        streakMultiplier: Double = 1.0, todayXPSoFar: Int = 0
    ) -> Int {
        let fuelXP = min(FuelProcessor.process(raw: fuelRaw), fuelXPCap)
        let interactionXP = min(interactionBonuses, interactionBonusCap)
        let chatXP = min(chatBonuses, chatBonusCap)
        let raw = Double(basePresence + fuelXP + interactionXP + chatXP) * min(streakMultiplier, 1.5)
        return max(0, min(Int(raw), dailyXPCap - todayXPSoFar))
    }

    public static func streakMultiplier(days: Int) -> Double {
        switch days {
        case ...1: return 1.0; case 2...3: return 1.1; case 4...7: return 1.2
        case 8...14: return 1.3; case 15...30: return 1.4; default: return 1.5
        }
    }

    public static func bondGain(for interaction: BondInteraction) -> Int {
        switch interaction {
        case .chat: return 2; case .respondToCall: return 5
        case .respondToAttentionSeek: return 3; case .milestone: return 10
        }
    }
    public enum BondInteraction { case chat, respondToCall, respondToAttentionSeek, milestone }
}
