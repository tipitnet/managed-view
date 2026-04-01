//
//  VoloCommandHandler.swift
//  Managed View
//
//  Parses com.getvolo:// URL commands from the webapp
//  and dispatches them to a delegate.
//

import UIKit

protocol VoloCommandHandlerDelegate: AnyObject {
    func didReceiveOpen(frame: CGRect, url: URL?, userAgent: String?, contentMode: String?)
    func didReceiveBack()
    func didReceiveHide()
    func didReceiveShow()
    func didReceiveClose()
}

class VoloCommandHandler {

    static let scheme = "com.getvolo"

    weak var delegate: VoloCommandHandlerDelegate?

    private enum Action: String {
        case open
        case back
        case hide
        case show
        case close
    }

    private enum QueryKey: String {
        case x
        case y
        case width
        case height
        case url
        case ua
        case contentMode
    }

    func handle(_ url: URL) -> Bool {

        guard url.scheme == VoloCommandHandler.scheme,
              let host = url.host,
              let action = Action(rawValue: host) else {
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
            var contentMode: String?

            for item in queryItems {

                guard let value = item.value,
                      let key = QueryKey(rawValue: item.name) else {
                    continue
                }

                switch key {
                case .x:           frame.origin.x = CGFloat(Float(value) ?? 0)
                case .y:           frame.origin.y = CGFloat(Float(value) ?? 0)
                case .width:       frame.size.width = CGFloat(Float(value) ?? 0)
                case .height:      frame.size.height = CGFloat(Float(value) ?? 0)
                case .url:         requestURL = URL(string: value)
                case .ua:          customUserAgent = value
                case .contentMode: contentMode = value
                }
            }

            delegate?.didReceiveOpen(frame: frame, url: requestURL, userAgent: customUserAgent, contentMode: contentMode)

        case .back:  delegate?.didReceiveBack()
        case .hide:  delegate?.didReceiveHide()
        case .show:  delegate?.didReceiveShow()
        case .close: delegate?.didReceiveClose()
        }

        return true
    }
}
