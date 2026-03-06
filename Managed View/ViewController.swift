//
//  ViewController.swift
//  Managed View
//


import UIKit
import WebKit
import JGProgressHUD

class ViewController: UIViewController {

    var webView: WKWebView!

    var browser: WKWebView!
    
    let hud = JGProgressHUD(style: .dark)
    
    let blankUrl = URL(string: "about:blank")!

    let userAgentTextField = UITextField()

    private let browserProgressBar = ThinProgressView(progressViewStyle: .bar)

    // Default URL to display in web view
    var defaultURL = URL(string: "https://demo.getvolo.com/app/")
    
    // Last URL loaded in web view
    var lastUrl: URL?
    
    // Pending URL to load
    var url: URL? {
        
        didSet {
            
            loadWebView()
            closeBrowser(clearCookiesAndCache: true)
        }
    }
    
    var browsing = false

    private var browserSessionURL: URL?
    private var browserHistoryBase: Int?

    // Maintenance mode status
    var MAINTENANCE_MODE = "OFF"
    
    // Autonomous Single App Mode (Mode)
    var asamStatus:Bool = true
    var asamStatusString:String = ""

    override func loadView() {

        super.loadView()

        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: view.frame, configuration: configuration)
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if #available(macOS 13.3, iOS 16.4, tvOS 16.4, *) {
            webView.isInspectable = true
        }
        view.addSubview(webView)

        createBrowser()
        view.addSubview(browser)
        setupBrowserProgressBar()

        userAgentTextField.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 36)
        userAgentTextField.placeholder = "Enter User-Agent"
        userAgentTextField.textColor = .black
        userAgentTextField.backgroundColor = .white
        userAgentTextField.returnKeyType = .done
        userAgentTextField.autocorrectionType = .no
        userAgentTextField.autocapitalizationType = .none
        userAgentTextField.isHidden = true
        userAgentTextField.addTarget(self, action: #selector(userAgentEntered), for: .editingDidEndOnExit)
        view.addSubview(userAgentTextField)

        let fourFingerQuadTap = UITapGestureRecognizer(target: self, action: #selector(toggleUserAgentField))
        fourFingerQuadTap.numberOfTouchesRequired = 4
        fourFingerQuadTap.numberOfTapsRequired = 4
        view.addGestureRecognizer(fourFingerQuadTap)
    }

    @objc func toggleUserAgentField() {
        userAgentTextField.isHidden = !userAgentTextField.isHidden
        if userAgentTextField.isHidden {
            userAgentTextField.resignFirstResponder()
        } else {
            userAgentTextField.text = browser.customUserAgent
        }
    }

    @objc func userAgentEntered() {
        if let customUA = userAgentTextField.text, !customUA.isEmpty {
            browser.customUserAgent = customUA
            print("Custom User-Agent set: \(customUA)")
        }
    }

    override func viewDidLoad() {
        
        super.viewDidLoad()

        // keyboard warmup
        // browser webview crashing on iOS 18 when the keyboard opens for the first time
        preloadKeyboard()

        setUrl()
        
        // observe if App Config pushed from MDM
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in

            guard let self else { return }
            self.setUrl()

            print("reload")
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        super.viewWillTransition(to: size, with: coordinator)
        
        if browsing {

            let landscape = size.width > size.height
            browser.isHidden = !landscape
            browserProgressBar.isHidden = !landscape
        }
    }
    
    override var prefersStatusBarHidden : Bool {
        
        return true
    }
    
    // Tap Gesture Recognizer (triple tap defined in storyboard)
    // Gesture used as interactive method to enable or disable Autonomous Single App Mode
    
    @IBAction func tripleTap(_ sender: AnyObject) {
        
        // If ASAM is enabled
        if (UIAccessibilityIsGuidedAccessEnabled() == true ) {
            
            asamStatus = true
            asamStatusString = "ENABLED"
        }
        
        // if ASAM is not enabled
        else {
            
            asamStatus = false
            asamStatusString = "DISABLED"
        }
        
        print (asamStatus)
        
        // define dialog to user
        let actionSheetController: UIAlertController = UIAlertController(title: "Autonomous Single App Mode is currently\n \(asamStatusString)", message: "Select action", preferredStyle: .actionSheet)
        
       
        // Customize user dialog based on current state of ASAM and reguest ASAM state change
        var message:String = "Disabled"
        
        if (asamStatus) {
            message = "Enabled"
        }
        
        setupASAM(enabled: asamStatus, actionSheetController: actionSheetController, message: message)
        
        // Create and add the Cancel action
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .destructive) { action -> Void in
            //Just dismiss the action sheet
        }
        
        actionSheetController.addAction(cancelAction)
        
        // for iPad
        actionSheetController.popoverPresentationController?.sourceView = view

        // Present dialog to user
        self.present(actionSheetController, animated: true, completion: nil)
    }
    
    func setupASAM(enabled:Bool, actionSheetController: UIAlertController, message:String) {
        
        let asam: UIAlertAction = UIAlertAction(title: message, style: .default) { action -> Void in
            UIAccessibilityRequestGuidedAccessSession(true) { success in
                
                print("INFO: ASAM request to set \(message)")
                
                if success {
                    
                    print ("ASAM is \(message)")
                    let asamAlert = UIAlertController(title: "Success", message: "Autonomous Single App Mode is\n\n \(message).", preferredStyle: UIAlertControllerStyle.alert)
                    asamAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    
                    self.present(asamAlert, animated: true, completion: nil)
                    
                } else {
                    
                    print ("INFO: ASAM is not capable.")
                    let asamAlert = UIAlertController(title: "Autonomous Single App Mode is not supported", message: "This device does not currently support Automonous Single App Mode (ASAM).  ASAM requires the following:\n\n (1) Device is in supervised state.\n\n(2) Configuration profile supporting ASAM for this specific app installed on device.", preferredStyle: UIAlertControllerStyle.alert)
                    asamAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    
                    self.present(asamAlert, animated: true, completion: nil)
                }
            }
        }
        
        actionSheetController.addAction(asam)
    }
    
    func setUrl() {

        print ("INFO: setupView")
        
        // Check for Manged App Config
        if let ManAppConfig = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed") {
            
            // Check if MAINTENANCE_MODE key is set
            if (ManAppConfig["MAINTENANCE_MODE"] != nil) {
                
                MAINTENANCE_MODE = String(describing: ManAppConfig["MAINTENANCE_MODE"]!)
                
            } else {
                
                MAINTENANCE_MODE = "OFF"
            }
            
            // Check if MAINTENANCE_MODE key is set to "ON"
            if (MAINTENANCE_MODE == "ON") {
                
                url = URL.init(fileURLWithPath: Bundle.main.path(forResource: "curtain", ofType: "png")!)
                
                // If URL changed since last web view load then load new URL
                print ("STATUS: loading maintenacne URL \(url!)")
                
            } else {
                
                // Check if URL key is set
                if (ManAppConfig["URL"] != nil) {
                    
                    url = URL(string: String(describing: ManAppConfig["URL"]!))
                    
                    // If URL changed since last web view load then load new URL
                    print ("STATUS: loading updated AppConfig URL \(url!)")
                }

                // If no Manged App Config URL key set then use default URL
                else {
                    
                    url = defaultURL
                    
                    // If URL changed since last web view load then load new URL
                    print ("STATUS: loading default URL \(url!)")
                }
            }
        }
            
        // If no Manged App Config then use default URL

        else {
            
            url = defaultURL
            
            // If URL changed since last web view load then load new URL
            print ("INFO: Refreshing to \(url!)")
        }
    }
    
    func loadWebView() {
        
        if var url = self.url,
            url != lastUrl {
            
            if !hud.isVisible {
                
                hud.textLabel.text = "Loading"
                hud.show(in: self.view)
            }
            
            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                
                let version = URLQueryItem(name: "appversion", value: build)
                
                if var queryItems = components.queryItems {
                    
                    queryItems.append(version)
                    
                    components.queryItems = queryItems
                }
                else {
                    
                    components.queryItems = [version]
                }
                
                if let newUrl = components.url {
                    
                    url = newUrl
                }
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            
            webView.load(request)
        }
    }
    
    func closeBrowser(clearCookiesAndCache: Bool = false) {

        browsing = false
        browserSessionURL = nil
        browserHistoryBase = nil

        if clearCookiesAndCache {
            browser.removeCookiesAndCache()
        }

        browserProgressBar.alpha = 0
        browserProgressBar.progress = 0

        browser.load(URLRequest(url: blankUrl))
        browser.isHidden = true
    }
    
    func createBrowser() {

        let browserConfiguration = WKWebViewConfiguration()
        browserConfiguration.allowsInlineMediaPlayback = true
        if #available(iOS 13.0, *) {
            browserConfiguration.defaultWebpagePreferences.preferredContentMode = .mobile
        }

        browser = WKWebView(frame: .zero, configuration: browserConfiguration)
        browser.navigationDelegate = self
        browser.uiDelegate = self
        browser.isHidden = true
        if #available(macOS 13.3, iOS 16.4, tvOS 16.4, *) {
            browser.isInspectable = true
        }
    }

    func preloadKeyboard() {
        // Create a hidden text field to trigger keyboard loading.
        let hiddenTextField = UITextField(frame: CGRect.zero)
        hiddenTextField.isHidden = true
        view.addSubview(hiddenTextField)

        // Force the text field to become first responder to load the keyboard.
        hiddenTextField.becomeFirstResponder()

        // Resign first responder shortly after so it doesn't interfere with your UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            hiddenTextField.resignFirstResponder()
            hiddenTextField.removeFromSuperview()
        }
    }

    // MARK: - Browser Progress Bar

    private func setupBrowserProgressBar() {
        browserProgressBar.progressTintColor = .black
        browserProgressBar.trackTintColor = .clear
        browserProgressBar.alpha = 0
        view.addSubview(browserProgressBar)
    }

    private func startBrowserProgress() {
        browserProgressBar.frame = CGRect(
            x: browser.frame.origin.x,
            y: browser.frame.origin.y,
            width: browser.frame.width,
            height: 2
        )
        view.bringSubview(toFront: browserProgressBar)
        browserProgressBar.layer.removeAllAnimations()
        browserProgressBar.setProgress(0, animated: false)
        browserProgressBar.layoutIfNeeded()
        browserProgressBar.alpha = 1
        browserProgressBar.setProgress(0.7, animated: true)
    }

    private func finishBrowserProgress() {
        browserProgressBar.setProgress(1.0, animated: true)
        UIView.animate(withDuration: 0.3, delay: 0.5) {
            self.browserProgressBar.alpha = 0
        }
    }
}

extension ViewController: WKNavigationDelegate {

    enum OpenURLAction: String {

        case open
        case back
        case hide
        case show
        case close
    }

    enum OpenQueryItemKey: String {

        case x
        case y
        case width
        case height
        case url
        case ua
        case contentMode
    }

    func open(url: URL) -> Bool {

        guard let host = url.host,
              let action = OpenURLAction(rawValue: host) else {

            return false
        }

        switch action {

        case .open:

            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {

                return false
            }

            var frame = CGRect.zero
            var requestURL: URL?
            var customUserAgent: String?

            for item in queryItems {

                guard let value = item.value,
                      let key = OpenQueryItemKey(rawValue: item.name) else {

                    continue
                }

                switch key {

                case .x:
                    frame.origin.x = CGFloat(Float(value) ?? 0)

                case .y:
                    frame.origin.y = CGFloat(Float(value) ?? 0)

                case .width:
                    frame.size.width = CGFloat(Float(value) ?? 0)

                case .height:
                    frame.size.height = CGFloat(Float(value) ?? 0)

                case .url:
                    requestURL = URL(string: value)

                case .ua:
                    customUserAgent = value

                case .contentMode:
                    if #available(iOS 13.0, *) {

                        let mode = value.lowercased()

                        browser.configuration.defaultWebpagePreferences.preferredContentMode =
                            (mode == "desktop") ? .desktop : .mobile
                    }
                }
            }

            if let ua = customUserAgent {

                browser.customUserAgent = ua
            }

            browserSessionURL = requestURL
            // +1 accounts for the current page (about:blank) that gets pushed onto
            // backList when browser.load() starts — the real boundary is after that entry
            browserHistoryBase = browser.backForwardList.backList.count + 1

            browser.frame = frame
            browser.autoresizingMask =
                [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
            browser.isHidden = false
            browsing = true

            if let url = requestURL {
                browser.load(URLRequest(url: url))
            }

        case .back:

            if browsing,
               let backItem = browser.backForwardList.backItem,
               backItem.url != browserSessionURL,
               backItem.url != blankUrl,
               let base = browserHistoryBase,
               browser.backForwardList.backList.count > base {
                browser.goBack()
            } else {
                webView.evaluateJavaScript("window.history.back();", completionHandler: nil)
            }

        case .hide:

            browser.isHidden = true
            browserProgressBar.isHidden = true

        case .show:

            browser.isHidden = false
            browserProgressBar.isHidden = false

        case .close:

            closeBrowser()
        }

        return true
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {

        if webView == browser, browsing {
            startBrowserProgress()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        if webView == self.webView {
            
            lastUrl = url
            
            hud.dismiss()
        }
        
        if webView == browser {

            finishBrowserProgress()

            browser.backgroundColor = .white
            browser.scrollView.backgroundColor = .white
            
            for subview in browser.scrollView.subviews {
                
                if String(describing: type(of: subview)) == "WKPDFView" {
                    
                    subview.backgroundColor = .white
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {

        if webView == self.webView {

            if lastUrl == nil {

                loadWebView()
            }
        }

        if webView == browser {
            finishBrowserProgress()
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {

        let url = navigationAction.request.url

        if let url = url,
            url.scheme == "com.getvolo" {

            _ = open(url: url)
            decisionHandler(.cancel)
            return
        }

        if navigationAction.targetFrame?.isMainFrame == nil {

            webView.load(navigationAction.request)
        }

        decisionHandler(.allow)
    }
}

extension ViewController: WKUIDelegate {
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        if navigationAction.targetFrame?.isMainFrame == nil {
            
            webView.load(navigationAction.request)
        }
        
        return nil
    }
}

class ThinProgressView: UIProgressView {

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: 1.5)
    }
}

extension WKWebView {
    
    func removeCookiesAndCache() {
        
        let websiteDataStore = self.configuration.websiteDataStore
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
}
