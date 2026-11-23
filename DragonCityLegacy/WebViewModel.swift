import Foundation
import SwiftUI
import UIKit
import WebKit

@MainActor
final class WebViewModel: NSObject, ObservableObject {
    private static let serverAddress = "http://132.145.159.218:8080"

    enum State {
        case loading
        case ready
        case failed
        case configurationError
    }

    @Published private(set) var state: State = .loading
    let webView: WKWebView

    private let serverURL: URL?
    private let origin: ServerOrigin?
    private let behaviorScriptAvailable: Bool
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private var lastImpactTime: TimeInterval = 0
    private var activeNavigation: WKNavigation?
    private var didStart = false

    override init() {
        let plistAddress = Bundle.main.object(forInfoDictionaryKey: "SERVER_URL") as? String
        let configuredURL = plistAddress == Self.serverAddress ? URL(string: Self.serverAddress) : nil
        let configuredOrigin = configuredURL.flatMap(ServerOrigin.init(url:))
        serverURL = configuredOrigin == nil ? nil : configuredURL
        origin = configuredOrigin

        let contentController = WKUserContentController()
        if let scriptURL = Bundle.main.url(forResource: "WebBehavior", withExtension: "js"),
           let source = try? String(contentsOf: scriptURL, encoding: .utf8) {
            contentController.addUserScript(WKUserScript(
                source: source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            ))
            behaviorScriptAvailable = true
        } else {
            behaviorScriptAvailable = false
        }

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.ignoresViewportScaleLimits = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        // The controller retains message handlers. A weak proxy prevents a retain cycle.
        contentController.add(WeakTapHandler(target: self), name: "nativeTap")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 1
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        impact.prepare()
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        guard serverURL != nil, origin != nil, behaviorScriptAvailable else {
            state = .configurationError
            return
        }
        loadHome()
    }

    func retry() {
        tapFeedback()
        loadHome()
    }

    private func loadHome() {
        guard let serverURL else {
            state = .configurationError
            return
        }
        webView.stopLoading()
        activeNavigation = nil
        state = .loading
        let request = URLRequest(url: serverURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
        activeNavigation = webView.load(request)
        if activeNavigation == nil {
            state = .failed
        }
    }

    fileprivate func tapFeedback() {
        // Keep a page from driving the Taptic Engine continuously.
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastImpactTime >= 0.08 else { return }
        lastImpactTime = now
        impact.impactOccurred()
        impact.prepare()
    }

    private func failCurrentNavigation() {
        activeNavigation = nil
        state = .failed
    }
}

extension WebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, origin?.allows(url) == true else {
            // Also terminate the loading overlay if a provisional main navigation is blocked.
            if navigationAction.targetFrame?.isMainFrame == true, case .loading = state {
                failCurrentNavigation()
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let response = navigationResponse.response
        guard let url = response.url, origin?.allows(url) == true else {
            if navigationResponse.isForMainFrame { failCurrentNavigation() }
            decisionHandler(.cancel)
            return
        }
        if navigationResponse.isForMainFrame {
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                failCurrentNavigation()
                decisionHandler(.cancel)
                return
            }
            if !navigationResponse.canShowMIMEType {
                failCurrentNavigation()
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activeNavigation = navigation
        state = .loading
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let navigation, navigation === activeNavigation else { return }
        activeNavigation = nil
        state = .ready
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationFailed(navigation)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationFailed(navigation)
    }

    private func navigationFailed(_ navigation: WKNavigation?) {
        // Ignore a stale cancellation from an earlier navigation or retry.
        guard let navigation, navigation === activeNavigation else { return }
        failCurrentNavigation()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        failCurrentNavigation()
    }
}

extension WebViewModel: WKUIDelegate {
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Reuse the existing view for same-origin target=_blank/window.open links.
        if navigationAction.targetFrame == nil,
           let url = navigationAction.request.url,
           origin?.allows(url) == true {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

private final class WeakTapHandler: NSObject, WKScriptMessageHandler {
    weak var target: WebViewModel?

    init(target: WebViewModel) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "nativeTap" else { return }
        let target = target
        Task { @MainActor [weak target] in
            target?.tapFeedback()
        }
    }
}
