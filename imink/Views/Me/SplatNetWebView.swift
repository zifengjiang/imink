import SwiftUI
import UIKit
import WebKit

struct SplatNetWebViewScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL

    @State private var loadState: LoadState = .loading
    @State private var retryID = UUID()
    @State private var webViewID = UUID()
    @State private var isPageLoading = true
    @State private var pageError: String?
    @State private var sharePayload: SplatNetSharePayload?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            content
        }
        .task(id: retryID) {
            await loadSession()
        }
        .sheet(item: $sharePayload) { payload in
            SplatNetActivityView(items: payload.activityItems) {
                sharePayload = nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            loadingView

        case .failed(let message):
            errorView(message: message) {
                retryID = UUID()
            }

        case .ready(let session):
            ZStack {
                SplatNetWebView(
                    session: session,
                    interfaceLanguage: interfaceLanguage,
                    colorScheme: colorScheme,
                    onClose: {
                        dismiss()
                    },
                    onLoadingChanged: { isLoading in
                        isPageLoading = isLoading
                        if isLoading {
                            pageError = nil
                        }
                    },
                    onError: { message in
                        isPageLoading = false
                        pageError = message
                    },
                    onShare: { payload in
                        sharePayload = payload
                    },
                    onCopy: { text in
                        UIPasteboard.general.string = text
                    },
                    onOpenExternal: { url in
                        openURL(url)
                    }
                )
                .id("\(webViewID.uuidString)-\(interfaceLanguage)-\(colorScheme)")
                .ignoresSafeArea(.container, edges: .bottom)

                if isPageLoading {
                    loadingView
                        .background(Color.black.opacity(0.94))
                }

                if let pageError {
                    errorView(message: pageError) {
                        isPageLoading = true
                        self.pageError = nil
                        webViewID = UUID()
                    }
                    .background(Color.black)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.white)
                .controlSize(.large)

            Text("正在打开鱿鱼圈 3…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(
        message: String,
        retry: @escaping () -> Void
    ) -> some View {
        ContentUnavailableView {
            Label("无法打开鱿鱼圈 3", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("重试", action: retry)
                .buttonStyle(.borderedProminent)

            Button("关闭", role: .cancel) {
                dismiss()
            }
        }
        .foregroundStyle(.white)
    }

    private var interfaceLanguage: String {
        let localization = Bundle.main.preferredLocalizations.first
            ?? AppUserDefaults.shared.currentLanguage
            ?? locale.identifier
        return SplatNetWebLanguage.identifier(for: localization)
    }

    @MainActor
    private func loadSession() async {
        loadState = .loading
        pageError = nil
        isPageLoading = true

        do {
            let session = try await SplatNetWebSessionProvider.load()
            try Task.checkCancellation()
            loadState = .ready(session)
        } catch is CancellationError {
            return
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}

private extension SplatNetWebViewScreen {
    enum LoadState {
        case loading
        case ready(SplatNetWebSession)
        case failed(String)
    }
}

struct SplatNetWebView: UIViewRepresentable {
    let session: SplatNetWebSession
    let interfaceLanguage: String
    let colorScheme: ColorScheme
    let onClose: () -> Void
    let onLoadingChanged: (Bool) -> Void
    let onError: (String) -> Void
    let onShare: (SplatNetSharePayload) -> Void
    let onCopy: (String) -> Void
    let onOpenExternal: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(
            context.coordinator,
            name: SplatNetBridgeScript.messageHandlerName
        )
        userContentController.addUserScript(
            WKUserScript(
                source: SplatNetBridgeScript.source(gameWebToken: session.gameWebToken),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController = userContentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = SplatNetWebRequestBuilder.androidWebViewUserAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        context.coordinator.webView = webView

        do {
            let request = try SplatNetWebRequestBuilder.request(
                for: session,
                interfaceLanguage: interfaceLanguage,
                colorScheme: colorScheme
            )
            webView.load(request)
        } catch {
            DispatchQueue.main.async {
                onError(error.localizedDescription)
            }
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: SplatNetBridgeScript.messageHandlerName
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: SplatNetWebView
        weak var webView: WKWebView?

        init(parent: SplatNetWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            parent.onLoadingChanged(true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            parent.onLoadingChanged(false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: Error
        ) {
            handleNavigationError(error)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation?,
            withError error: Error
        ) {
            handleNavigationError(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if isAllowedInternalURL(url) {
                decisionHandler(.allow)
                return
            }

            let isUserActivatedLink = navigationAction.navigationType == .linkActivated
            let targetsVisiblePage = navigationAction.targetFrame?.isMainFrame == true
                || navigationAction.targetFrame == nil

            if isExternalWebURL(url), isUserActivatedLink, targetsVisiblePage {
                parent.onOpenExternal(url)
            }

            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil,
                  let url = navigationAction.request.url else {
                return nil
            }

            if isAllowedInternalURL(url) {
                webView.load(navigationAction.request)
            } else if navigationAction.navigationType == .linkActivated,
                      isExternalWebURL(url) {
                parent.onOpenExternal(url)
            }

            return nil
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == SplatNetBridgeScript.messageHandlerName,
                  message.frameInfo.isMainFrame,
                  isAllowedMessageSource(message.frameInfo.securityOrigin),
                  let object = message.body as? [String: Any],
                  let type = object["type"] as? String else {
                return
            }

            let payload = object["payload"]

            switch type {
            case "close":
                parent.onClose()

            case "share":
                guard let value = decode(payload, as: ShareImageMessage.self),
                      let url = URL(string: value.imageURL),
                      isExternalWebURL(url) else {
                    return
                }
                parent.onShare(.url(url, text: value.text))

            case "shareURL":
                guard let value = decode(payload, as: ShareURLMessage.self),
                      let url = URL(string: value.url),
                      isExternalWebURL(url) else {
                    return
                }
                parent.onShare(.url(url, text: value.text))

            case "copy":
                guard let text = payload as? String else {
                    return
                }
                parent.onCopy(text)

            case "images":
                guard let value = decode(payload, as: ShareImagesMessage.self) else {
                    return
                }
                let urls = value.imageURLs
                    .compactMap(URL.init(string:))
                    .filter(isExternalWebURL)
                guard !urls.isEmpty else {
                    return
                }
                parent.onShare(.images(urls))

            default:
                return
            }
        }

        private func handleNavigationError(_ error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else {
                return
            }

            parent.onLoadingChanged(false)
            parent.onError(error.localizedDescription)
        }

        private func isAllowedInternalURL(_ url: URL) -> Bool {
            SplatNetWebNavigationPolicy.isAllowedInternalURL(url)
        }

        private func isAllowedMessageSource(_ origin: WKSecurityOrigin) -> Bool {
            origin.protocol.lowercased() == "https"
                && origin.host.lowercased() == SplatNetWebRequestBuilder.allowedHost
        }

        private func isExternalWebURL(_ url: URL) -> Bool {
            SplatNetWebNavigationPolicy.isExternalWebURL(url)
        }

        private func decode<Value: Decodable>(_ payload: Any?, as type: Value.Type) -> Value? {
            let data: Data

            if let payload = payload as? String {
                guard let stringData = payload.data(using: .utf8) else {
                    return nil
                }
                data = stringData
            } else if let payload, JSONSerialization.isValidJSONObject(payload) {
                guard let objectData = try? JSONSerialization.data(withJSONObject: payload) else {
                    return nil
                }
                data = objectData
            } else {
                return nil
            }

            return try? JSONDecoder().decode(type, from: data)
        }
    }
}

enum SplatNetWebNavigationPolicy {
    static func isAllowedInternalURL(_ url: URL) -> Bool {
        if url.absoluteString == "about:blank" {
            return true
        }

        return url.scheme?.lowercased() == "https"
            && url.host?.lowercased() == SplatNetWebRequestBuilder.allowedHost
    }

    static func isExternalWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "https" || scheme == "http"
    }
}

enum SplatNetBridgeScript {
    static let messageHandlerName = "splatNetBridge"

    static func source(gameWebToken: String) -> String {
        let token = javascriptStringLiteral(gameWebToken)

        return """
        (() => {
          const nativeBridge = window.webkit?.messageHandlers?.\(messageHandlerName);
          const post = (type, payload = null) => nativeBridge?.postMessage({ type, payload });

          window.closeWebView = () => post("close");
          window.invokeNativeShare = value => post("share", value);
          window.invokeNativeShareUrl = value => post("shareURL", value);
          window.copyToClipboard = value => post("copy", value);
          window.downloadImages = value => post("images", value);
          window.requestGameWebToken = () => Promise.resolve().then(() => {
            window.onGameWebTokenReceive?.call(null, \(token));
          });
        })();
        """
    }

    static func javascriptStringLiteral(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let literal = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return literal
    }
}

struct SplatNetSharePayload: Identifiable {
    let id = UUID()
    let activityItems: [Any]

    static func url(_ url: URL, text: String?) -> Self {
        let items: [Any]
        if let text, !text.isEmpty {
            items = [text, url]
        } else {
            items = [url]
        }
        return Self(activityItems: items)
    }

    static func images(_ urls: [URL]) -> Self {
        Self(activityItems: urls)
    }
}

private struct ShareImageMessage: Decodable {
    let imageURL: String
    let text: String?

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case text
    }
}

private struct ShareURLMessage: Decodable {
    let url: String
    let text: String?
}

private struct ShareImagesMessage: Decodable {
    let imageURLs: [String]

    enum CodingKeys: String, CodingKey {
        case imageURLs = "image_urls"
    }
}

private struct SplatNetActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in
                onComplete()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
