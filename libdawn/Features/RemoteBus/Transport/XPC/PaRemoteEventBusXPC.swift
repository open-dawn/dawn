import Foundation

@objc(PaRemoteEventBusXPCProtocol)
protocol PaRemoteEventBusXPC: NSObjectProtocol {
    func deliver(_ data: Data)
}
