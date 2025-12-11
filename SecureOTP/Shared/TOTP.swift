import Foundation
import CommonCrypto

enum OTPAlgorithm {
    case sha1, sha256, sha512

    var ccAlgorithm: CCHmacAlgorithm {
        switch self {
        case .sha1: return CCHmacAlgorithm(kCCHmacAlgSHA1)
        case .sha256: return CCHmacAlgorithm(kCCHmacAlgSHA256)
        case .sha512: return CCHmacAlgorithm(kCCHmacAlgSHA512)
        }
    }

    var digestLength: Int {
        switch self {
        case .sha1: return Int(CC_SHA1_DIGEST_LENGTH)
        case .sha256: return Int(CC_SHA256_DIGEST_LENGTH)
        case .sha512: return Int(CC_SHA512_DIGEST_LENGTH)
        }
    }
}

struct TOTP {
    let secret: Data
    let digits: Int
    let timeInterval: Int
    let algorithm: OTPAlgorithm

    init?(secret: Data, digits: Int = 6, timeInterval: Int = 30, algorithm: OTPAlgorithm = .sha1) {
        guard !secret.isEmpty else { return nil }
        self.secret = secret
        self.digits = digits
        self.timeInterval = timeInterval
        self.algorithm = algorithm
    }

    func generate(time: Date = Date()) -> String? {
        let counter = UInt64(time.timeIntervalSince1970) / UInt64(timeInterval)
        return generateOTP(counter: counter)
    }

    private func generateOTP(counter: UInt64) -> String? {
        var bigCounter = counter.bigEndian
        let counterData = Data(bytes: &bigCounter, count: 8)

        var hmac = [UInt8](repeating: 0, count: algorithm.digestLength)
        counterData.withUnsafeBytes { counterBytes in
            secret.withUnsafeBytes { secretBytes in
                CCHmac(algorithm.ccAlgorithm, secretBytes.baseAddress, secret.count, counterBytes.baseAddress, counterData.count, &hmac)
            }
        }

        let offset = Int(hmac[algorithm.digestLength - 1] & 0x0f)
        let truncated = (UInt32(hmac[offset]) & 0x7f) << 24
            | (UInt32(hmac[offset + 1]) & 0xff) << 16
            | (UInt32(hmac[offset + 2]) & 0xff) << 8
            | (UInt32(hmac[offset + 3]) & 0xff)

        let otp = truncated % UInt32(pow(10, Double(digits)))
        return String(format: "%0\(digits)d", otp)
    }
}
