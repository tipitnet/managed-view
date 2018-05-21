//
//  ViewController.swift
//  Managed View
//


import UIKit
import JGProgressHUD

class ViewController: UIViewController {
    
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
            
            hud.textLabel.text = "Loading"
            hud.show(in: self.view)
            
            retry(
                task: {
                    
                    self.loadURL()
                },
                after: 15,
                attempts: 240,
                success: { response, data in
                    
                    DispatchQueue.main.async {
                        
                        self.hud.dismiss()
                        self.webView.load(data, mimeType: "text/html", textEncodingName: "UTF-8", baseURL: self.url!)
                    }
                },
                failure: { response, err in
                    
                    print("Failed: \(String(describing: err))")
                    
                    DispatchQueue.main.async {
                        
                        self.hud.dismiss()
                    }
                    
                    let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                    
                    let alert = UIAlertController(title: "Unable to load", message: "Contact Volo! representative.", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(action)
                    
                    self.present(alert, animated: true, completion: nil)
                }
            )
        }
    }
    
    // Autonomous Single App Mode (Mode)
    var asamStatus:Bool = true
    var asamStatusString:String = ""

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
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
    
    typealias Async = (_ success: @escaping (URLResponse?, Data) -> (), _ failure: @escaping (URLResponse?, Error?) -> ()) -> ()
    
    func loadURL() -> Async {
        
        return { success, failure in
            
            URLSession.shared.dataTask(with: self.url!, completionHandler: { data, response, error in
                
                guard error == nil, let data = data else {
                    
                    failure(response, error)
                    
                    return
                }
                
                success(response, data)
                
            }).resume()
        }
    }
    
    func retry(task: @escaping () -> Async, after seconds: Int, attempts attempt: Int, success: @escaping (URLResponse?, Data) -> (), failure: @escaping (URLResponse?, Error?) -> ()) {
        
        unowned let unownedSelf = self
        
        task() (success, { response, error in
            
            if attempt <= 0 {
                
                failure(response, error)
                
                return
            }
            
            print("Retry for attempt: \(attempt)")
            
            let deadlineTime = DispatchTime.now() + .seconds(seconds)
            
            DispatchQueue.main.asyncAfter(deadline: deadlineTime, execute: {
                
                unownedSelf.retry(task: task, after: seconds, attempts: attempt - 1, success: success, failure: failure)
            })
        })
    }
}
