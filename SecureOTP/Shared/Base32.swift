import Foundation

enum Base32 {
    private static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    static func decode(_ string: String) -> Data? {
        let str = string.uppercased().replacingOccurrences(of: " ", with: "")
        guard !str.isEmpty else { return nil }

        var bits = ""
        for char in str {
            guard char != "=" else { break }
            guard let index = alphabet.firstIndex(of: char) else { return nil }
            let value = alphabet.distance(from: alphabet.startIndex, to: index)
            bits += String(value, radix: 2).padLeft(toLength: 5, withPad: "0")
        }

        var bytes = [UInt8]()
        for i in stride(from: 0, to: bits.count - 7, by: 8) {
            let start = bits.index(bits.startIndex, offsetBy: i)
            let end = bits.index(start, offsetBy: 8)
            if let byte = UInt8(String(bits[start..<end]), radix: 2) {
                bytes.append(byte)
            }
        }

        return bytes.isEmpty ? nil : Data(bytes)
    }
}

extension String {
    func padLeft(toLength length: Int, withPad pad: Character) -> String {
        String(repeating: pad, count: max(0, length - count)) + self
    }
}
