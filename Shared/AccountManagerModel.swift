//
//  AccountManagerModel.swift
//  PassKeys_POC
//
//  Created by Vinay Raj K on 19/01/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation

struct Challenge: Codable
{
    let user: User?
    let challenge: String
    
    struct User: Codable
    {
        let id: String
    }
}

struct SignupChallengeParam: Codable
{
    init(_csrf: String = UUID().uuidString, name: String, username: String) {
        self._csrf = _csrf
        self.name = name
        self.username = username
    }
    
    let _csrf: String
    let name: String
    let username: String
}

struct SignUpParam : Codable {
    let response: ResponseParam
}

struct LoginParam: Codable {
    let id: String
    let authenticatorAttachment: String?
    let response: ResponseParam
}

struct ResponseParam: Codable {
    let clientDataJSON : String?
    let attestationObject : String?
    let authenticatorData : String?
    let userHandle: String?
    let signature : String?
    let transports: [String]?
}

struct LoginResponse: Codable {
    let ok: Bool
    let location: String
}

struct LogOutResponse: Codable {
    let status: Bool
    
    enum CodingKeys: String, CodingKey
    {
        case status = "ok"
    }
}
