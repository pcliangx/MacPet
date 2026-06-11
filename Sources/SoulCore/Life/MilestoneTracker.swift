import Foundation

public struct Milestone: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var date: Date
    public var description: String

    public init(id: String = UUID().uuidString, name: String, date: Date = Date(), description: String = "") {
        self.id = id
        self.name = name
        self.date = date
        self.description = description
    }
}

public enum MilestoneTracker {
    public static func checkAnniversary(milestones: [Milestone], today: Date = Date()) -> Milestone? {
        let cal = Calendar.current
        let todayMonth = cal.component(.month, from: today)
        let todayDay = cal.component(.day, from: today)
        return milestones.first { m in
            let mMonth = cal.component(.month, from: m.date)
            let mDay = cal.component(.day, from: m.date)
            return mMonth == todayMonth && mDay == todayDay && !cal.isDate(m.date, inSameDayAs: today)
        }
    }

    public static func anniversaryGreeting(milestone: Milestone, today: Date = Date()) -> String {
        let years = Calendar.current.dateComponents([.year], from: milestone.date, to: today).year ?? 0
        return years > 0
            ? "今天是「\(milestone.name)」的\(years)周年纪念！\(milestone.description)"
            : "今天是「\(milestone.name)」的纪念日！\(milestone.description)"
    }

    public static func detectNewMilestones(growth: GrowthState, bond: Int, existing: [Milestone]) -> [Milestone] {
        var new: [Milestone] = []
        let names = Set(existing.map(\.name))
        if growth.stage == .juvenile && !names.contains("长大成少年") {
            new.append(Milestone(name: "长大成少年", description: "从幼崽成长为少年"))
        }
        if growth.stage == .adult && !names.contains("成年了") {
            new.append(Milestone(name: "成年了", description: "从少年成长为成年体"))
        }
        if growth.streakDays >= 30 && !names.contains("连续陪伴 30 天") {
            new.append(Milestone(name: "连续陪伴 30 天", description: "连续 30 天的陪伴"))
        }
        if bond >= 100 && !names.contains("羁绊值 100") {
            new.append(Milestone(name: "羁绊值 100", description: "我们的关系更加亲密了"))
        }
        return new
    }
}
