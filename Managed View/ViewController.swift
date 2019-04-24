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
    
    let blankUrl = URL(string: "about:blank")
    
    // Default URL to display in web view
    var defaultURL = URL(string: "http://maximlink.com/readme")
    
    // Last URL loaded in web view
    var lastUrl: URL?
    
    // Pending URL to load
    var url: URL? {
        
        didSet {
            
            loadWebView()
            closeBrowser()
        }
    }
    
    var browsing = false
    
    // Maintenance mode status
    var MAINTENANCE_MODE = "OFF"
    
    // Autonomous Single App Mode (Mode)
    var asamStatus:Bool = true
    var asamStatusString:String = ""

    override func loadView() {
        
        super.loadView()
        
        webView = WKWebView(frame: view.frame, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        view.addSubview(webView)
        
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = false
        
        browser = WKWebView(frame: .zero, configuration: configuration)
        browser.navigationDelegate = self
        browser.uiDelegate = self
        browser.isHidden = true
        browser.translatesAutoresizingMaskIntoConstraints = true
        
        view.addSubview(browser)
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        setUrl()
        
        // observe if App Config pushed from MDM
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: OperationQueue.main) { _ in
            
            self.setUrl()
            
            print("reload")
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        super.viewWillTransition(to: size, with: coordinator)
        
        if browsing {
            
            browser.isHidden = !UIDevice.current.orientation.isLandscape
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
    
    func closeBrowser() {
        
        browser.load(URLRequest(url: blankUrl!))
        
        browser.isHidden = true
        
        browser.removeCookiesAndCache()
        
        browsing = false
    }
}

extension ViewController: WKNavigationDelegate {
    
    func open(url: URL) -> Bool {
        
        if url.host == "open",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems {
            
            var frame = CGRect(x: 0, y: 0, width: 0, height: 0)
            
            for queryItem in queryItems {
                
                if queryItem.name == "x",
                    let x = Float(queryItem.value!) {
                    
                    frame.origin.x = CGFloat(x)
                }
                
                if queryItem.name == "y",
                    let y = Float(queryItem.value!) {
                    
                    frame.origin.y = CGFloat(y)
                }
                
                if queryItem.name == "width",
                    let width = Float(queryItem.value!) {
                    
                    frame.size.width = CGFloat(width)
                }
                
                if queryItem.name == "height",
                    let height = Float(queryItem.value!) {
                    
                    frame.size.height = CGFloat(height)
                }
                
                if queryItem.name == "url",
                    let url = URL(string: queryItem.value!) {
                    
                    if let first = browser.backForwardList.backList.first {
                        
                        browser.go(to: first)
                    }
                    
                    let request = URLRequest(url: url)
                    browser.load(request)
                }
            }
            
            browser.frame = frame
            
            browser.autoresizingMask =
                [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
            
            browser.isHidden = false
            
            browsing = true
            
            return true
        }
        
        if url.host == "back" {
            
            if let blank = browser.backForwardList.backList.first,
                browser.backForwardList.backItem != blank {
                
                browser.goBack()
            }
            else {
                
                webView.evaluateJavaScript("window.history.back();", completionHandler: nil)
            }
            
            return true
        }
        
        if url.host == "hide" {
            
            browser.isHidden = true
            
            return true
        }
        
        if url.host == "show" {
            
            browser.isHidden = false
            
            return true
        }
        
        if url.host == "close" {
            
            closeBrowser()
            
            return true
        }
        
        return false
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        if webView == self.webView {
            
            lastUrl = url
            
            hud.dismiss()
        }
        
        if webView == browser {
            
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
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        
        let url = navigationAction.request.url
        
        if let url = url,
            url.scheme == "com.getvolo" {
            
            _ = open(url: url)
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
