//
//  ViewController.swift
//  Managed View
//


import UIKit
import JGProgressHUD

class ViewController: UIViewController, UIWebViewDelegate {
    
    // let UserDefaults: Foundation.UserDefaults = Foundation.UserDefaults.standard
    
    @IBOutlet var webView: UIWebView!
    
    let hud = JGProgressHUD(style: .dark)
    
    // Default URL to display in web view
    var defaultURL = URL(string: "http://maximlink.com/readme")

    // Maintenance mode status
    var MAINTENANCE_MODE = "OFF"
    
    // Last URL loaded in web view
    var lastUrl: URL?
    
    // Pending URL to load
    var url: URL? {
        
        didSet {
            
            loadURL()
        }
    }
    
    // Autonomous Single App Mode (Mode)
    var asamStatus:Bool = true
    var asamStatusString:String = ""

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        webView.delegate = self
        
        setUrl()
        
        // observe if App Config pushed from MDM
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: OperationQueue.main) { _ in
            
            self.setUrl()
            
            print("reload")
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
    
    func loadURL() {
        
        if lastUrl != url {
        
            hud.textLabel.text = "Loading"
            
            hud.show(in: self.view)
            
            checkInternet { internet in
                
                if internet {
                    
                    let request = URLRequest(url: self.url!)
                    
                    self.webView.loadRequest(request)
                    
                } else {
                    
                    DispatchQueue.main.async {
                        
                        self.hud.dismiss()
                    }
                    
                    self.retry()
                }
            }
        }
    }
    
    func retry() {
        
        let action = UIAlertAction(title: "Retry", style: .default, handler: { action in
            
            self.loadURL()
        })
        
        let alert = UIAlertController(title: "", message: "There is no internet connection", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(action)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func checkInternet(completionHandler: @escaping (Bool) -> Void) {
        
        let url = URL(string: "http://www.appleiphonecell.com/")
        
        var request = URLRequest(url: url!)
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 3.0
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error -> Void in
            
            let httpResponse = response as? HTTPURLResponse
            completionHandler(httpResponse?.statusCode == 200)
        })
        
        task.resume()
    }
    
    // MARK: - UIWebViewDelegate
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        
        hud.dismiss()
        
        retry()
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        
        lastUrl = url
        
        hud.dismiss()
    }
}
