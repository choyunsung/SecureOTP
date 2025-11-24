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

internal struct Base32 {
    
    private static let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
    
    /**
     Decodes a base32 string
     
     - parameter string: The string to decode
     - returns: The decoded data
     */
    static func decode(_ string: String) -> Data? {
        
        let string = string.uppercased()
        
        guard string.range(of: "^[A-Z2-7]+=*$", options: .regularExpression) != nil else {
            return nil
        }
        
        let s = string.padding(toLength: string.count + (string.count % 8), withPad: "=", startingAt: 0)
        
        var bits = ""
        
        for char in s.utf8 {
            
            if let index = characters.firstIndex(of: char) {
                bits.append(String(index, radix: 2).padding(toLength: 5, withPad: "0", startingAt: 0))
            }
        }
        
        var data = Data()
        
        for i in 0..<(bits.count / 8) {
            
            let start = bits.index(bits.startIndex, offsetBy: i * 8)
            let end = bits.index(start, offsetBy: 8)
            
            guard let byte = UInt8(bits[start..<end], radix: 2) else {
                return nil
            }
            
            data.append(byte)
        }
        
        return data
    }
}
