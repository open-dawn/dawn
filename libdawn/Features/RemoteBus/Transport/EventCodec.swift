import Foundation

enum EventCodec {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func encode(_ event: Event) throws -> Data {
        try encoder.encode(event)
    }

    static func decode(_ data: Data) throws -> Event {
        try decoder.decode(Event.self, from: data)
    }
}
