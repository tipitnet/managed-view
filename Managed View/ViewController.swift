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
            
            self.loadWebView()
        }
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
    
    override var prefersStatusBarHidden : Bool {
        
        return true
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
            
            var request = URLRequest(url: self.url!)
            
            request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
            
            URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
                
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
    
    func loadWebView() {
        
        if url != lastUrl {
            
            hud.textLabel.text = "Loading"
            hud.show(in: self.view)
            
            retry(
                task: {
                    
                    self.loadURL()
                },
                after: 15,
                attempts: 240,
                success: { response, data in
                    
                    self.lastUrl = self.url
                    
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
                    
                    let action = UIAlertAction(title: "Retry", style: .default, handler: retryWebViewLoad)
                    
                    let alert = UIAlertController(title: "", message: "Can't connect to the network.", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(action)
                    
                    self.present(alert, animated: true, completion: nil)
                }
            )
        }
        
        func retryWebViewLoad(alert: UIAlertAction) {
            
            self.loadWebView()
        }
    }
}
