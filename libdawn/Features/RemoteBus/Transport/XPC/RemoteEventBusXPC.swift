import Foundation

@objc(RemoteEventBusXPCProtocol)
protocol RemoteEventBusXPC: NSObjectProtocol {
    func deliver(_ data: Data)
}
