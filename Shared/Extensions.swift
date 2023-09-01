//
//  Extensions.swift
//  PassKeys_POC
//
//  Created by Vinay Raj K on 06/02/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation

extension Data
{
    func stringValue() -> String?
    {
        String(data: self, encoding: .utf8)
    }
}

extension String {
    var base64StringToBase64url: String
    {
        let base64url = self
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64url
    }
    
    var base64urlToBase64: String
    {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if base64.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.count % 4))
        }
        return base64
    }
}
