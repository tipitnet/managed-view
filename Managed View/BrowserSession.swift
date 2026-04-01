//
//  BrowserSession.swift
//  Managed View
//

import UIKit
import WebKit

class ThinProgressView: UIProgressView {

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: 1.5)
    }
}

final class BrowserSession: NSObject {

    let view: WKWebView
    private let progressBar = ThinProgressView(progressViewStyle: .bar)
    private let blankUrl = URL(string: "about:blank")!
    private var progressObservation: NSKeyValueObservation?

    private(set) var isBrowsing = false
    private(set) var sessionURL: URL?
    private(set) var historyBase: Int?

    var customUserAgent: String? {
        get { return view.customUserAgent }
        set { view.customUserAgent = newValue }
    }

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 13.0, *) {
            config.defaultWebpagePreferences.preferredContentMode = .mobile
        }

        view = WKWebView(frame: .zero, configuration: config)

        super.init()

        view.navigationDelegate = self
        view.uiDelegate = self
        view.isHidden = true
        if #available(macOS 13.3, iOS 16.4, tvOS 16.4, *) {
            view.isInspectable = true
        }

        progressBar.progressTintColor = .black
        progressBar.trackTintColor = .clear
        progressBar.alpha = 0
        view.addSubview(progressBar)

        progressObservation = view.observe(\.estimatedProgress) { [weak self] webView, _ in
            guard let self, self.isBrowsing else { return }
            let progress = Float(webView.estimatedProgress)
            self.progressBar.setProgress(progress, animated: true)
            if webView.estimatedProgress >= 1.0 {
                UIView.animate(withDuration: 0.3, delay: 0.3) {
                    self.progressBar.alpha = 0
                }
            }
        }
    }

    // MARK: - Session Control

    func open(frame: CGRect, url: URL?, userAgent: String?, contentMode: String?) {
        if let ua = userAgent { view.customUserAgent = ua }
        if let mode = contentMode?.lowercased() {
            if #available(iOS 13.0, *) {
                view.configuration.defaultWebpagePreferences.preferredContentMode =
                    (mode == "desktop") ? .desktop : .mobile
            }
        }

        sessionURL = url
        historyBase = view.backForwardList.backList.count + 1

        view.frame = frame
        view.autoresizingMask =
            [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        view.isHidden = false
        isBrowsing = true

        if let url = url {
            view.load(URLRequest(url: url))
        }
    }

    func close(clearCookiesAndCache: Bool = false) {
        isBrowsing = false
        sessionURL = nil
        historyBase = nil

        if clearCookiesAndCache {
            removeCookiesAndCache()
        }

        progressBar.alpha = 0
        progressBar.setProgress(0, animated: false)
        view.load(URLRequest(url: blankUrl))
        view.isHidden = true
    }

    func hide() {
        view.isHidden = true
    }

    func show() {
        view.isHidden = false
    }

    func setVisible(_ visible: Bool) {
        view.isHidden = !visible
    }

    func goBack() -> Bool {
        guard isBrowsing,
              let backItem = view.backForwardList.backItem,
              backItem.url != sessionURL,
              backItem.url != blankUrl,
              let base = historyBase,
              view.backForwardList.backList.count > base else {
            return false
        }
        view.goBack()
        return true
    }

    // MARK: - Private

    private func removeCookiesAndCache() {
        let websiteDataStore = view.configuration.websiteDataStore
        let cookieStore = websiteDataStore.httpCookieStore

        cookieStore.getAllCookies { cookies in
            for cookie in cookies {
                cookieStore.delete(cookie)
            }
        }

        websiteDataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records, completionHandler: {})
        }
    }

    private func fixBackground() {
        view.backgroundColor = .white
        view.scrollView.backgroundColor = .white
        for subview in view.scrollView.subviews {
            if String(describing: type(of: subview)) == "WKPDFView" {
                subview.backgroundColor = .white
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension BrowserSession: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard isBrowsing else { return }
        progressBar.frame = CGRect(x: 0, y: 0, width: webView.bounds.width, height: 2)
        webView.bringSubviewToFront(progressBar)
        progressBar.layer.removeAllAnimations()
        progressBar.setProgress(0, animated: false)
        progressBar.alpha = 1
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        fixBackground()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        progressBar.alpha = 0
    }
}

// MARK: - WKUIDelegate

extension BrowserSession: WKUIDelegate {

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame?.isMainFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
