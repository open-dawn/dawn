import Foundation

@objc(PaEventHostXPCProtocol)
protocol PaEventHostXPC: NSObjectProtocol {
    func handshake(withReply reply: @escaping (Bool) -> Void)
    func publish(_ data: Data)
    func subscribe(_ kindNames: [String], includeAll: Bool)
    func ask(_ data: Data, withReply reply: @escaping (Data?, Error?) -> Void)
}
