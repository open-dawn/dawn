import Foundation

enum CLIJSON {
    static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)

        guard let text = String(data: data, encoding: .utf8) else {
            throw CLIError.invalidJSON("The reply could not be encoded.")
        }

        return text
    }

    static func decode<T: Decodable>(_ type: T.Type, from path: String) throws -> T {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw CLIError.unreadableFile(path)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CLIError.invalidJSON(path)
        }
    }
}
