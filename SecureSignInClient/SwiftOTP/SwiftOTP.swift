/*
 * Copyright (c) 2017-2020, Leondias.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND

 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import CommonCrypto

public struct OTP {
    
    public enum Algorithm {
        case sha1, sha256, sha512
        
        var toCCHmacAlgorithm: CCHmacAlgorithm {
            switch self {
            case .sha1:
                return CCHmacAlgorithm(kCCHmacAlgSHA1)
            case .sha256:
                return CCHmacAlgorithm(kCCHmacAlgSHA256)
            case .sha512:
                return CCHmacAlgorithm(kCCHmacAlgSHA512)
            }
        }
        
        var toDigestLength: Int32 {
            switch self {
            case .sha1:
                return CC_SHA1_DIGEST_LENGTH
            case .sha256:
                return CC_SHA256_DIGEST_LENGTH
            case .sha512:
                return CC_SHA512_DIGEST_LENGTH
            }
        }
    }
}

public struct TOTP {
    
    /// The secret key
    public let secret: Data
    
    /// The number of digits
    public let digits: Int
    
    /// The time interval
    public let timeInterval: Int
    
    /// The algorithm
    public let algorithm: OTP.Algorithm
    
    /**
     Init
     
     - parameter secret: The secret key
     - parameter digits: The number of digits
     - parameter timeInterval: The time interval
     - parameter algorithm: The algorithm
     */
    public init?(secret: Data, digits: Int = 6, timeInterval: Int = 30, algorithm: OTP.Algorithm = .sha1) {
        
        guard digits > 0 && timeInterval > 0 else {
            return nil
        }
        
        self.secret = secret
        self.digits = digits
        self.timeInterval = timeInterval
        self.algorithm = algorithm
    }
    
    /**
     Generates the password
     
     - parameter time: The time to generate the password for
     - returns: The password
     */
    public func generate(time: Date) -> String? {
        
        let counter = UInt64(time.timeIntervalSince1970) / UInt64(timeInterval)
        
        return generate(counter: counter)
    }
    
    /**
     Generates the password
     
     - parameter counter: The counter to generate the password for
     - returns: The password
     */
    public func generate(counter: UInt64) -> String? {

        var counter = counter.bigEndian
        let counterData = Data(bytes: &counter, count: MemoryLayout<UInt64>.size)

        let hmac = HMAC.final(key: secret, data: counterData, algorithm: algorithm)
        
        var truncatedHmac = hmac.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> UInt32 in
            let bytes = buffer.bindMemory(to: UInt8.self)
            
            let offset = bytes[bytes.count - 1] & 0x0f
            
            let truncatedHmac = bytes[Int(offset)...Int(offset)+3]
            
            return truncatedHmac.withUnsafeBytes { (truncatedBuffer: UnsafeRawBufferPointer) -> UInt32 in
                let value = truncatedBuffer.bindMemory(to: UInt32.self).baseAddress!.pointee
                return UInt32(bigEndian: value)
            }
        }
        
        truncatedHmac &= 0x7fffffff
        truncatedHmac = truncatedHmac % UInt32(pow(10, Float(digits)))
        
        return String(format: "%0*u", digits, truncatedHmac)
    }
}

internal struct HMAC {
    
    /**
     Generates a HMAC
     
     - parameter key: The key
     - parameter data: The data to authenticate
     - parameter algorithm: The algorithm
     - returns: The generated HMAC
     */
    static func final(key: Data, data: Data, algorithm: OTP.Algorithm) -> Data {
        let (keyBytes, keyLength) = key.bytes
        let (dataBytes, dataLength) = data.bytes
        
        var hmac = [UInt8](repeating: 0, count: Int(algorithm.toDigestLength))
        
        CCHmac(algorithm.toCCHmacAlgorithm, keyBytes, keyLength, dataBytes, dataLength, &hmac)
        
        return Data(hmac)
    }
}
