import SwiftUI
import WebKit
import AppKit
import SoulCore

struct SVGRenderer: NSViewRepresentable {
    let genome: AppearanceGenome
    let stage: Stage
    let state: String
    let emote: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        let html = GenomeRenderer.render(genome: genome, stage: stage, state: state)
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = GenomeRenderer.render(genome: genome, stage: stage, state: state)
        webView.loadHTMLString(html, baseURL: nil)
    }
}
