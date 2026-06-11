# M5 它是你创造的 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** SVG 形象系统（基因组+阶段骨架+表情变体+部件级动画）+ 共创仪式 + 初见孵化 onboarding——你创造了它。

**Architecture:** `AppearanceGenome`（体色/耳形/眼型/尾巴/斑纹 JSON 参数）+ `GenomeRenderer`（基因组×阶段×心情→SVG HTML）+ `CoCreationCeremony`（升阶蜕变仪式）+ `HatchingOnboarding`（蛋→创造→孵化）+ MpetApp 集成。

**对应 spec：** §8 形象与动画（SVG-first）· §11 初见孵化 onboarding · §6.1 外观维度成长。

---

## 文件结构

```
Sources/SoulCore/
  Appearance/AppearanceGenome.swift   # NEW: 外观基因组
  Appearance/GenomeRenderer.swift     # NEW: 基因组→SVG HTML
  Appearance/CoCreationCeremony.swift # NEW: 共创仪式
Sources/SoulCore/Brain/PersonaSynth.swift  # MODIFY: 用 AppearanceGenome 替代简化 Genome
Sources/MpetApp/
  OnboardingView.swift                # MODIFY: 完整孵化仪式
  SVGRenderer.swift                   # MODIFY: 数据驱动（基因组+状态+阶段）
  PetViewModel.swift                  # MODIFY: 基因组集成
  MpetAppMain.swift                   # MODIFY: 首次启动引导
Tests/SoulCoreTests/
  AppearanceGenomeTests.swift         # NEW
  GenomeRendererTests.swift           # NEW
  CoCreationCeremonyTests.swift       # NEW
```

---

### Task 0: AppearanceGenome（外观基因组）

```swift
// Sources/SoulCore/Appearance/AppearanceGenome.swift
import Foundation

public struct AppearanceGenome: Codable, Equatable, Sendable {
    public var furHue: Int           // 体色色相 0-360
    public var furSaturation: Int    // 饱和度 0-100
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
        case roundXL = "round-XL", roundSmall = "round-small", anime = "anime", sleepy = "sleepy"
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

    /// 生成随机基因组
    public static func random(name: String = "小生命", species: String = "神秘小动物") -> AppearanceGenome {
        AppearanceGenome(
            furHue: Int.random(in: 0...360),
            furSaturation: Int.random(in: 60...95),
            earShape: EarShape.allCases.randomElement()!,
            eyeStyle: EyeStyle.allCases.randomElement()!,
            tailType: TailType.allCases.randomElement()!,
            pattern: Pattern.allCases.randomElement()!,
            blushEnabled: Bool.random(),
            petName: name, species: species
        )
    }
}
```

### Task 1: GenomeRenderer（基因组→SVG）

```swift
// Sources/SoulCore/Appearance/GenomeRenderer.swift
import Foundation

public enum GenomeRenderer {
    /// 渲染完整 SVG HTML（基因组 × 阶段 × 心情状态）
    public static func render(genome: AppearanceGenome, stage: Stage, state: String = "idle") -> String {
        let fur = "hsl(\(genome.furHue) \(genome.furSaturation)% 63%)"
        let furDeep = "hsl(\(genome.furHue - 6) \(genome.furSaturation - 10)% 54%)"
        let earIn = "hsl(\(genome.furHue + 2) \(genome.furSaturation - 12)% 82%)"
        let cream = "#FFF4E3"
        let line = "#46322B"
        let blush = genome.blushEnabled ?
            """
            <ellipse cx="112" cy="200" rx="13" ry="8" fill="#FF9FAC" opacity=".5"/>
            <ellipse cx="228" cy="200" rx="13" ry="8" fill="#FF9FAC" opacity=".5"/>
            """ : ""

        let scale = stageScale(stage)
        let svg = """
        <svg class="pet state-\(state)" id="pet" viewBox="0 0 340 340" style="transform:scale(\(scale))">
        <ellipse cx="170" cy="305" rx="80" ry="11" fill="#000000" opacity=".18"/>
        <g id="pet-root">
          <g id="tail">\(tailSVG(genome.tailType, fur: fur, furDeep: furDeep, cream: cream))</g>
          <ellipse cx="170" cy="200" rx="92" ry="88" fill="\(fur)"/>
          <ellipse cx="148" cy="148" rx="56" ry="38" fill="#FFFFFF" opacity=".08"/>
          <ellipse cx="170" cy="251" rx="46" ry="32" fill="\(cream)"/>
          <ellipse cx="138" cy="282" rx="16" ry="10" fill="\(furDeep)"/>
          <ellipse cx="202" cy="282" rx="16" ry="10" fill="\(furDeep)"/>
          <g id="ears">\(earsSVG(genome.earShape, fur: fur, earIn: earIn, furDeep: furDeep))</g>
          <ellipse cx="170" cy="208" rx="32" ry="21" fill="\(cream)"/>
          <g id="eyes">\(eyesSVG(genome.eyeStyle, line: line))</g>
          <ellipse cx="170" cy="198" rx="5.5" ry="4" fill="#4A332B"/>
          <g id="mouth">\(mouthSVG())</g>
          \(blush)
        </g>
        </svg>
        """
        return wrapInHTML(svg, state: state)
    }

    static func stageScale(_ stage: Stage) -> Double {
        switch stage {
        case .egg: return 0.7
        case .baby: return 0.9
        case .juvenile: return 1.0
        case .adult: return 1.1
        }
    }

    static func tailSVG(_ type: AppearanceGenome.TailType, fur: String, furDeep: String, cream: String) -> String {
        switch type {
        case .fluffyComma:
            return """
            <circle cx="252" cy="212" r="33" fill="\(furDeep)"/>
            <circle cx="277" cy="177" r="25" fill="\(furDeep)"/>
            <circle cx="290" cy="148" r="18" fill="\(cream)"/>
            """
        case .bushy:
            return """
            <ellipse cx="260" cy="190" rx="40" ry="55" fill="\(furDeep)" transform="rotate(-15 260 190)"/>
            """
        case .short:
            return """
            <ellipse cx="240" cy="220" rx="20" ry="15" fill="\(furDeep)"/>
            """
        case .curl:
            return """
            <path d="M250,220 Q280,180 260,150 Q240,130 260,110" fill="none" stroke="\(furDeep)" stroke-width="18" stroke-linecap="round"/>
            """
        }
    }

    static func earsSVG(_ shape: AppearanceGenome.EarShape, fur: String, earIn: String, furDeep: String) -> String {
        switch shape {
        case .roundTri:
            return """
            <path d="M104,138 C98,100 110,72 126,75 C144,79 150,104 145,130 Q124,142 104,138 Z" fill="\(fur)"/>
            <path d="M114,131 C111,104 119,86 128,88 C138,91 141,108 138,126 Q126,134 114,131 Z" fill="\(earIn)"/>
            <path d="M236,138 C242,100 230,72 214,75 C196,79 190,104 195,130 Q216,142 236,138 Z" fill="\(fur)"/>
            <path d="M226,131 C229,104 221,86 212,88 C202,91 199,108 202,126 Q214,134 226,131 Z" fill="\(earIn)"/>
            """
        case .pointy:
            return """
            <path d="M108,140 L118,60 L148,128 Z" fill="\(fur)"/>
            <path d="M116,130 L122,75 L140,122 Z" fill="\(earIn)"/>
            <path d="M232,140 L222,60 L192,128 Z" fill="\(fur)"/>
            <path d="M224,130 L218,75 L200,122 Z" fill="\(earIn)"/>
            """
        case .floppy:
            return """
            <ellipse cx="110" cy="145" rx="25" ry="40" fill="\(fur)" transform="rotate(-20 110 145)"/>
            <ellipse cx="230" cy="145" rx="25" ry="40" fill="\(fur)" transform="rotate(20 230 145)"/>
            """
        case .catLike:
            return """
            <path d="M108,140 L100,65 L145,125 Z" fill="\(fur)"/>
            <path d="M115,132 L108,78 L138,120 Z" fill="\(earIn)"/>
            <path d="M232,140 L240,65 L195,125 Z" fill="\(fur)"/>
            <path d="M225,132 L232,78 L202,120 Z" fill="\(earIn)"/>
            """
        }
    }

    static func eyesSVG(_ style: AppearanceGenome.EyeStyle, line: String) -> String {
        let r: Double = style == .roundSmall ? 7 : (style == .anime ? 12 : 10)
        return """
        <g class="eyes-open">
          <g class="blinker"><circle cx="132" cy="178" r="\(r)" fill="\(line)"/><circle cx="128.5" cy="174.5" r="3.2" fill="#fff"/></g>
          <g class="blinker"><circle cx="208" cy="178" r="\(r)" fill="\(line)"/><circle cx="204.5" cy="174.5" r="3.2" fill="#fff"/></g>
        </g>
        <g class="eyes-happy" fill="none" stroke="\(line)" stroke-width="5.5" stroke-linecap="round">
          <path d="M120,179 Q132,165 144,179"/><path d="M196,179 Q208,165 220,179"/>
        </g>
        <g class="eyes-sleepy">
          <path d="M121,177 A11,11 0 0 0 143,177 Z" fill="\(line)"/>
          <path d="M197,177 A11,11 0 0 0 219,177 Z" fill="\(line)"/>
        </g>
        <g class="eyes-closed" fill="none" stroke="\(line)" stroke-width="5" stroke-linecap="round">
          <path d="M121,179 Q132,188 143,179"/><path d="M197,179 Q208,188 219,179"/>
        </g>
        <g class="eyes-up">
          <circle cx="129" cy="174" r="\(r)" fill="\(line)"/>
          <circle cx="205" cy="174" r="\(r)" fill="\(line)"/>
        </g>
        <g class="eyes-wide">
          <circle cx="132" cy="178" r="\(r + 1.5)" fill="\(line)"/>
          <circle cx="208" cy="178" r="\(r + 1.5)" fill="\(line)"/>
        </g>
        """
    }

    static func mouthSVG() -> String {
        """
        <path class="m-idle" d="M156,209 q7,7 14,0 q7,7 14,0" fill="none" stroke="#4A332B" stroke-width="3.2" stroke-linecap="round"/>
        <g class="m-happy"><path d="M157,207 Q170,226 183,207 Z" fill="#5C3A30"/><ellipse cx="170" cy="213" rx="5" ry="3" fill="#FF8E9E"/></g>
        <ellipse class="m-o" cx="170" cy="210" rx="4.5" ry="5.5" fill="#5C3A30"/>
        <path class="m-sleep" d="M162,210 Q170,214 178,210" fill="none" stroke="#4A332B" stroke-width="3" stroke-linecap="round"/>
        """
    }

    static func wrapInHTML(_ svg: String, state: String) -> String {
        """
        <!DOCTYPE html><html><head><meta charset="UTF-8">
        <style>
        *{margin:0;padding:0}
        body{background:transparent;overflow:hidden;display:flex;align-items:center;justify-content:center;height:100vh}
        .pet{width:180px;height:auto}
        .pet *{transform-box:fill-box}
        #pet-root{transform-origin:50% 100%;animation:breathe 3.4s ease-in-out infinite}
        @keyframes breathe{0%,100%{transform:scale(1,1)}50%{transform:scale(.996,1.028)}}
        #tail{transform-origin:24% 92%;animation:wag 2.8s ease-in-out infinite}
        @keyframes wag{0%,100%{transform:rotate(-6deg)}50%{transform:rotate(9deg)}}
        .blinker{transform-origin:50% 50%;animation:blink 4.6s infinite}
        @keyframes blink{0%,90.5%,96%,100%{transform:scaleY(1)}93%{transform:scaleY(.06)}}
        .eyes-open,.eyes-happy,.eyes-sleepy,.eyes-closed,.eyes-up,.eyes-wide,
        .m-idle,.m-happy,.m-o,.m-sleep,.m-sleeping{display:none}
        .state-idle .eyes-open,.state-idle .m-idle{display:block}
        .state-happy .eyes-happy,.state-happy .m-happy{display:block}
        .state-happy #pet-root{animation:bounce .58s ease-in-out infinite}
        @keyframes bounce{0%,100%{transform:translateY(0)}45%{transform:translateY(-9px)}}
        .state-sleepy .eyes-sleepy,.state-sleepy .m-o{display:block}
        .state-missyou .eyes-up,.state-missyou .m-idle{display:block}
        .state-sleeping .eyes-closed,.state-sleeping .m-sleep,.state-sleeping .m-sleeping{display:block}
        .state-alert .eyes-wide,.state-alert .m-o{display:block}
        </style></head><body>\(svg)</body></html>
        """
    }
}
```

### Task 2: CoCreationCeremony（共创仪式）

```swift
// Sources/SoulCore/Appearance/CoCreationCeremony.swift
import Foundation

public enum CoCreationCeremony {
    public struct CeremonyPrompt: Sendable {
        public let announcement: String
        public let question: String
    }

    /// 升阶前的蜕变宣告
    public static func evolutionAnnouncement(from: Stage, to: Stage, name: String) -> CeremonyPrompt {
        let fromCN = stageCN(from); let toCN = stageCN(to)
        return CeremonyPrompt(
            announcement: "「\(name)」感觉到身体在发生变化…它要从\(fromCN)变成\(toCN)了！",
            question: "请描述一下你想象中它蜕变后的样子（或输入「随机」让我来挑选）："
        )
    }

    /// 根据用户描述生成候选基因组（简化版：M5 用随机+微调，M6+ 可接 LLM）
    public static func generateCandidates(from current: AppearanceGenome, count: Int = 3) -> [AppearanceGenome] {
        var candidates: [AppearanceGenome] = []
        for _ in 0..<count {
            var c = current
            // 微调：随机改变 1-2 个参数
            switch Int.random(in: 0...3) {
            case 0: c.furHue = (c.furHue + Int.random(in: -30...30) + 360) % 360
            case 1: c.earShape = AppearanceGenome.EarShape.allCases.randomElement()!
            case 2: c.eyeStyle = AppearanceGenome.EyeStyle.allCases.randomElement()!
            case 3: c.tailType = AppearanceGenome.TailType.allCases.randomElement()!
            default: break
            }
            candidates.append(c)
        }
        return candidates
    }

    static func stageCN(_ s: Stage) -> String {
        switch s {
        case .egg: return "蛋"; case .baby: return "幼崽"
        case .juvenile: return "少年"; case .adult: return "成年"
        }
    }
}
```

### Task 3-4: MpetApp 集成

- Update SVGRenderer to accept AppearanceGenome + use GenomeRenderer
- Update OnboardingView with full creation ceremony (describe → pick genome → hatch)
- Update PetViewModel to carry genome
- Update MpetAppMain to show onboarding on first launch

### Task 5: M5 验收 + 打标 v0.6.0-m5
