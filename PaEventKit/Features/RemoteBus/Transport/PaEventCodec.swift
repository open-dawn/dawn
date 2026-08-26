import Foundation

enum PaEventCodec {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func encode(_ event: PaEvent) throws -> Data {
        try encoder.encode(event)
    }

    static func decode(_ data: Data) throws -> PaEvent {
        try decoder.decode(PaEvent.self, from: data)
    }
}
