//
//  Reachability.swift
//  Managed View
//
//  Created by Gabriel Horacio Cutrini on 03/04/2018.
//  Copyright © 2018 Tipit. All rights reserved.
//

import SystemConfiguration

public final class Reachability {
    
    public enum NetworkReachabilityStatus {
        case unknown
        case reachable
        case notReachable
    }
    
    public typealias Listener = (NetworkReachabilityStatus) -> Void
    
    // MARK: - Properties
    
    public var listener: Listener?
    
    public var isReachable: Bool { return networkReachabilityStatus == .reachable }
    
    public var networkReachabilityStatus: NetworkReachabilityStatus {
        
        guard let flags = self.flags else { return .unknown }
        
        return networkReachabilityStatusForFlags(flags)
    }
    
    private var previousFlags: SCNetworkReachabilityFlags?
    
    private var flags: SCNetworkReachabilityFlags? {
        
        var flags = SCNetworkReachabilityFlags()
        
        if SCNetworkReachabilityGetFlags(reachability, &flags) { return flags }
        
        return nil
    }
    
    private let listenerQueue: DispatchQueue = DispatchQueue.main
    
    private var reachability: SCNetworkReachability
    
    // MARK: - Initialization
    
    public convenience init?() {
        
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        
        guard let reachability = withUnsafePointer(to: &address, { pointer in
            return pointer.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
                return SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else { return nil }
        
        self.init(reachability: reachability)
    }
    
    private init(reachability: SCNetworkReachability) {
        
        self.reachability = reachability
        
        self.startListening()
    }
    
    deinit {
        
        stopListening()
    }
    
    // MARK: - Methods
    
    @discardableResult
    private func startListening() -> Bool {
        
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        let callbackSet = SCNetworkReachabilitySetCallback(reachability, { (_, flags, info) in
            
            let reachability = Unmanaged<Reachability>.fromOpaque(info!).takeUnretainedValue()
            
            reachability.notifyListener(flags)
            
        }, &context)
        
        let queueSet = SCNetworkReachabilitySetDispatchQueue(reachability, listenerQueue)
        
        listenerQueue.async {
            
            self.notifyListener(self.flags ?? SCNetworkReachabilityFlags())
        }
        
        return callbackSet && queueSet
    }
    
    private func stopListening() {
        
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
    }
    
    private func notifyListener(_ flags: SCNetworkReachabilityFlags) {
        
        guard previousFlags != flags else { return }
        
        previousFlags = flags
        
        listener?(networkReachabilityStatusForFlags(flags))
    }
    
    private func networkReachabilityStatusForFlags(_ flags: SCNetworkReachabilityFlags) -> NetworkReachabilityStatus {
        
        guard flags.contains(.reachable) else { return .notReachable }
        
        return .reachable
    }
}
