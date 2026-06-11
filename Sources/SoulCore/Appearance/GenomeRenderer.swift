import Foundation

public enum GenomeRenderer {
    public static func render(genome: AppearanceGenome, stage: Stage, state: String = "idle") -> String {
        let fur = "hsl(\(genome.furHue) \(genome.furSaturation)% 63%)"
        let furDeep = "hsl(\(max(0, genome.furHue - 6)) \(max(0, genome.furSaturation - 10))% 54%)"
        let earIn = "hsl(\(genome.furHue + 2) \(max(0, genome.furSaturation - 12))% 82%)"
        let cream = "#FFF4E3"
        let line = "#46322B"
        let blush = genome.blushEnabled ?
            "<ellipse cx=\"112\" cy=\"200\" rx=\"13\" ry=\"8\" fill=\"#FF9FAC\" opacity=\".5\"/><ellipse cx=\"228\" cy=\"200\" rx=\"13\" ry=\"8\" fill=\"#FF9FAC\" opacity=\".5\"/>" : ""
        let scale = stageScale(stage)
        let svg = "<svg class=\"pet state-\(state)\" id=\"pet\" viewBox=\"0 0 340 340\" style=\"transform:scale(\(scale))\">" +
            "<ellipse cx=\"170\" cy=\"305\" rx=\"80\" ry=\"11\" fill=\"#000000\" opacity=\".18\"/>" +
            "<g id=\"pet-root\">" +
            "<g id=\"tail\">\(tailSVG(genome.tailType, fur: fur, furDeep: furDeep, cream: cream))</g>" +
            "<ellipse cx=\"170\" cy=\"200\" rx=\"92\" ry=\"88\" fill=\"\(fur)\"/>" +
            "<ellipse cx=\"170\" cy=\"251\" rx=\"46\" ry=\"32\" fill=\"\(cream)\"/>" +
            "<ellipse cx=\"138\" cy=\"282\" rx=\"16\" ry=\"10\" fill=\"\(furDeep)\"/>" +
            "<ellipse cx=\"202\" cy=\"282\" rx=\"16\" ry=\"10\" fill=\"\(furDeep)\"/>" +
            "<g id=\"ears\">\(earsSVG(genome.earShape, fur: fur, earIn: earIn))</g>" +
            "<ellipse cx=\"170\" cy=\"208\" rx=\"32\" ry=\"21\" fill=\"\(cream)\"/>" +
            "<g id=\"eyes\">\(eyesSVG(genome.eyeStyle, line: line))</g>" +
            "<ellipse cx=\"170\" cy=\"198\" rx=\"5.5\" ry=\"4\" fill=\"#4A332B\"/>" +
            "<g id=\"mouth\">\(mouthSVG())</g>\(blush)" +
            "</g></svg>"
        return wrapInHTML(svg, state: state)
    }

    public static func stageScale(_ stage: Stage) -> Double {
        switch stage { case .egg: return 0.7; case .baby: return 0.9; case .juvenile: return 1.0; case .adult: return 1.1 }
    }

    static func tailSVG(_ type: AppearanceGenome.TailType, fur: String, furDeep: String, cream: String) -> String {
        switch type {
        case .fluffyComma: return "<circle cx=\"252\" cy=\"212\" r=\"33\" fill=\"\(furDeep)\"/><circle cx=\"277\" cy=\"177\" r=\"25\" fill=\"\(furDeep)\"/><circle cx=\"290\" cy=\"148\" r=\"18\" fill=\"\(cream)\"/>"
        case .bushy: return "<ellipse cx=\"260\" cy=\"190\" rx=\"40\" ry=\"55\" fill=\"\(furDeep)\" transform=\"rotate(-15 260 190)\"/>"
        case .short: return "<ellipse cx=\"240\" cy=\"220\" rx=\"20\" ry=\"15\" fill=\"\(furDeep)\"/>"
        case .curl: return "<path d=\"M250,220 Q280,180 260,150 Q240,130 260,110\" fill=\"none\" stroke=\"\(furDeep)\" stroke-width=\"18\" stroke-linecap=\"round\"/>"
        }
    }

    static func earsSVG(_ shape: AppearanceGenome.EarShape, fur: String, earIn: String) -> String {
        switch shape {
        case .roundTri: return "<path d=\"M104,138 C98,100 110,72 126,75 C144,79 150,104 145,130 Z\" fill=\"\(fur)\"/><path d=\"M236,138 C242,100 230,72 214,75 C196,79 190,104 195,130 Z\" fill=\"\(fur)\"/>"
        case .pointy: return "<path d=\"M108,140 L118,60 L148,128 Z\" fill=\"\(fur)\"/><path d=\"M232,140 L222,60 L192,128 Z\" fill=\"\(fur)\"/>"
        case .floppy: return "<ellipse cx=\"110\" cy=\"145\" rx=\"25\" ry=\"40\" fill=\"\(fur)\" transform=\"rotate(-20 110 145)\"/><ellipse cx=\"230\" cy=\"145\" rx=\"25\" ry=\"40\" fill=\"\(fur)\" transform=\"rotate(20 230 145)\"/>"
        case .catLike: return "<path d=\"M108,140 L100,65 L145,125 Z\" fill=\"\(fur)\"/><path d=\"M232,140 L240,65 L195,125 Z\" fill=\"\(fur)\"/>"
        }
    }

    static func eyesSVG(_ style: AppearanceGenome.EyeStyle, line: String) -> String {
        let r: Int = style == .roundSmall ? 7 : (style == .anime ? 12 : 10)
        return "<g class=\"eyes-open\"><g class=\"blinker\"><circle cx=\"132\" cy=\"178\" r=\"\(r)\" fill=\"\(line)\"/><circle cx=\"128.5\" cy=\"174.5\" r=\"3.2\" fill=\"#fff\"/></g><g class=\"blinker\"><circle cx=\"208\" cy=\"178\" r=\"\(r)\" fill=\"\(line)\"/><circle cx=\"204.5\" cy=\"174.5\" r=\"3.2\" fill=\"#fff\"/></g></g>" +
        "<g class=\"eyes-happy\" fill=\"none\" stroke=\"\(line)\" stroke-width=\"5.5\" stroke-linecap=\"round\"><path d=\"M120,179 Q132,165 144,179\"/><path d=\"M196,179 Q208,165 220,179\"/></g>" +
        "<g class=\"eyes-sleepy\"><path d=\"M121,177 A11,11 0 0 0 143,177 Z\" fill=\"\(line)\"/><path d=\"M197,177 A11,11 0 0 0 219,177 Z\" fill=\"\(line)\"/></g>" +
        "<g class=\"eyes-closed\" fill=\"none\" stroke=\"\(line)\" stroke-width=\"5\" stroke-linecap=\"round\"><path d=\"M121,179 Q132,188 143,179\"/><path d=\"M197,179 Q208,188 219,179\"/></g>" +
        "<g class=\"eyes-up\"><circle cx=\"129\" cy=\"174\" r=\"\(r)\" fill=\"\(line)\"/><circle cx=\"205\" cy=\"174\" r=\"\(r)\" fill=\"\(line)\"/></g>" +
        "<g class=\"eyes-wide\"><circle cx=\"132\" cy=\"178\" r=\"\(r + 1)\" fill=\"\(line)\"/><circle cx=\"208\" cy=\"178\" r=\"\(r + 1)\" fill=\"\(line)\"/></g>"
    }

    static func mouthSVG() -> String {
        "<path class=\"m-idle\" d=\"M156,209 q7,7 14,0 q7,7 14,0\" fill=\"none\" stroke=\"#4A332B\" stroke-width=\"3.2\" stroke-linecap=\"round\"/>" +
        "<g class=\"m-happy\"><path d=\"M157,207 Q170,226 183,207 Z\" fill=\"#5C3A30\"/></g>" +
        "<ellipse class=\"m-o\" cx=\"170\" cy=\"210\" rx=\"4.5\" ry=\"5.5\" fill=\"#5C3A30\"/>" +
        "<path class=\"m-sleep\" d=\"M162,210 Q170,214 178,210\" fill=\"none\" stroke=\"#4A332B\" stroke-width=\"3\" stroke-linecap=\"round\"/>"
    }

    static func wrapInHTML(_ svg: String, state: String) -> String {
        "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><style>" +
        "*{margin:0;padding:0}body{background:transparent;overflow:hidden;display:flex;align-items:center;justify-content:center;height:100vh}" +
        ".pet{width:180px;height:auto}.pet *{transform-box:fill-box}" +
        "#pet-root{transform-origin:50% 100%;animation:breathe 3.4s ease-in-out infinite}" +
        "@keyframes breathe{0%,100%{transform:scale(1,1)}50%{transform:scale(.996,1.028)}}" +
        "#tail{transform-origin:24% 92%;animation:wag 2.8s ease-in-out infinite}" +
        "@keyframes wag{0%,100%{transform:rotate(-6deg)}50%{transform:rotate(9deg)}}" +
        ".blinker{transform-origin:50% 50%;animation:blink 4.6s infinite}" +
        "@keyframes blink{0%,90.5%,96%,100%{transform:scaleY(1)}93%{transform:scaleY(.06)}}" +
        ".eyes-open,.eyes-happy,.eyes-sleepy,.eyes-closed,.eyes-up,.eyes-wide,.m-idle,.m-happy,.m-o,.m-sleep,.m-sleeping{display:none}" +
        ".state-idle .eyes-open,.state-idle .m-idle{display:block}" +
        ".state-happy .eyes-happy,.state-happy .m-happy{display:block}" +
        ".state-happy #pet-root{animation:bounce .58s ease-in-out infinite}" +
        "@keyframes bounce{0%,100%{transform:translateY(0)}45%{transform:translateY(-9px)}}" +
        ".state-sleepy .eyes-sleepy,.state-sleepy .m-o{display:block}" +
        ".state-missyou .eyes-up,.state-missyou .m-idle{display:block}" +
        ".state-sleeping .eyes-closed,.state-sleeping .m-sleep{display:block}" +
        ".state-alert .eyes-wide,.state-alert .m-o{display:block}" +
        "</style></head><body>\(svg)</body></html>"
    }
}
