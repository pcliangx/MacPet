import SwiftUI
import WebKit
import AppKit

struct SVGRenderer: NSViewRepresentable {
    let state: String
    let emote: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadHTMLString(Self.htmlContent, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let js = "document.getElementById('pet')?.setAttribute('class', 'pet state-\(state)');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    static let htmlContent: String = """
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
    .m-idle,.m-happy,.m-o,.m-sleep{display:none}
    .state-idle .eyes-open,.state-idle .m-idle{display:block}
    .state-happy .eyes-happy,.state-happy .m-happy{display:block}
    .state-happy #pet-root{animation:bounce .58s ease-in-out infinite}
    @keyframes bounce{0%,100%{transform:translateY(0)}45%{transform:translateY(-9px)}}
    .state-sleepy .eyes-sleepy,.state-sleepy .m-o{display:block}
    .state-sleepy #pet-root{animation-duration:4.6s}
    .state-missyou .eyes-up,.state-missyou .m-idle{display:block}
    .state-sleeping .eyes-closed,.state-sleeping .m-sleep{display:block}
    .state-sleeping #pet-root{animation-duration:5.8s}
    .state-sleeping #tail{animation:none;transform:rotate(-5deg)}
    .state-alert .eyes-wide,.state-alert .m-o{display:block}
    </style></head>
    <body>
    <svg class="pet state-idle" id="pet" viewBox="0 0 340 340">
    <ellipse cx="170" cy="305" rx="80" ry="11" fill="#000000" opacity=".18"/>
    <g id="pet-root">
      <g id="tail">
        <circle cx="252" cy="212" r="33" fill="hsl(22 80% 54%)"/>
        <circle cx="277" cy="177" r="25" fill="hsl(22 80% 54%)"/>
        <circle cx="290" cy="148" r="18" fill="#FFF4E3"/>
      </g>
      <ellipse cx="170" cy="200" rx="92" ry="88" fill="hsl(28 90% 63%)"/>
      <ellipse cx="148" cy="148" rx="56" ry="38" fill="#FFFFFF" opacity=".08"/>
      <ellipse cx="170" cy="251" rx="46" ry="32" fill="#FFF4E3"/>
      <ellipse cx="138" cy="282" rx="16" ry="10" fill="hsl(22 80% 54%)"/>
      <ellipse cx="202" cy="282" rx="16" ry="10" fill="hsl(22 80% 54%)"/>
      <g id="ears">
        <path d="M104,138 C98,100 110,72 126,75 C144,79 150,104 145,130 Q124,142 104,138 Z" fill="hsl(28 90% 63%)"/>
        <path d="M114,131 C111,104 119,86 128,88 C138,91 141,108 138,126 Q126,134 114,131 Z" fill="hsl(30 78% 82%)"/>
        <path d="M236,138 C242,100 230,72 214,75 C196,79 190,104 195,130 Q216,142 236,138 Z" fill="hsl(28 90% 63%)"/>
        <path d="M226,131 C229,104 221,86 212,88 C202,91 199,108 202,126 Q214,134 226,131 Z" fill="hsl(30 78% 82%)"/>
      </g>
      <ellipse cx="170" cy="208" rx="32" ry="21" fill="#FFF4E3"/>
      <g id="eyes">
        <g class="eyes-open">
          <g class="blinker"><circle cx="132" cy="178" r="10" fill="#46322B"/><circle cx="128.5" cy="174.5" r="3.2" fill="#fff"/></g>
          <g class="blinker"><circle cx="208" cy="178" r="10" fill="#46322B"/><circle cx="204.5" cy="174.5" r="3.2" fill="#fff"/></g>
        </g>
        <g class="eyes-happy" fill="none" stroke="#46322B" stroke-width="5.5" stroke-linecap="round">
          <path d="M120,179 Q132,165 144,179"/><path d="M196,179 Q208,165 220,179"/>
        </g>
        <g class="eyes-sleepy">
          <path d="M121,177 A11,11 0 0 0 143,177 Z" fill="#46322B"/>
          <path d="M119,176 L145,176" stroke="#46322B" stroke-width="4" stroke-linecap="round"/>
          <path d="M197,177 A11,11 0 0 0 219,177 Z" fill="#46322B"/>
          <path d="M195,176 L221,176" stroke="#46322B" stroke-width="4" stroke-linecap="round"/>
        </g>
        <g class="eyes-closed" fill="none" stroke="#46322B" stroke-width="5" stroke-linecap="round">
          <path d="M121,179 Q132,188 143,179"/><path d="M197,179 Q208,188 219,179"/>
        </g>
        <g class="eyes-up">
          <g class="blinker"><circle cx="129" cy="174" r="10" fill="#46322B"/><circle cx="125.5" cy="170.5" r="3" fill="#fff"/></g>
          <g class="blinker"><circle cx="205" cy="174" r="10" fill="#46322B"/><circle cx="201.5" cy="170.5" r="3" fill="#fff"/></g>
        </g>
        <g class="eyes-wide">
          <circle cx="132" cy="178" r="11.5" fill="#46322B"/><circle cx="128" cy="173.5" r="2.4" fill="#fff"/>
          <circle cx="208" cy="178" r="11.5" fill="#46322B"/><circle cx="204" cy="173.5" r="2.4" fill="#fff"/>
        </g>
      </g>
      <ellipse cx="170" cy="198" rx="5.5" ry="4" fill="#4A332B"/>
      <g id="mouth">
        <path class="m-idle" d="M156,209 q7,7 14,0 q7,7 14,0" fill="none" stroke="#4A332B" stroke-width="3.2" stroke-linecap="round"/>
        <g class="m-happy">
          <path d="M157,207 Q170,226 183,207 Z" fill="#5C3A30"/>
          <ellipse cx="170" cy="213" rx="5" ry="3" fill="#FF8E9E"/>
        </g>
        <ellipse class="m-o" cx="170" cy="210" rx="4.5" ry="5.5" fill="#5C3A30"/>
        <path class="m-sleep" d="M162,210 Q170,214 178,210" fill="none" stroke="#4A332B" stroke-width="3" stroke-linecap="round"/>
      </g>
      <ellipse cx="112" cy="200" rx="13" ry="8" fill="#FF9FAC" opacity=".5"/>
      <ellipse cx="228" cy="200" rx="13" ry="8" fill="#FF9FAC" opacity=".5"/>
    </g>
    </svg>
    </body></html>
    """
}
