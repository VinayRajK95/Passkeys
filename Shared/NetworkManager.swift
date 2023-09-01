//
//  NetworkManager.swift
//  PassKeys_POC
//
//  Created by Vinay Raj K on 06/02/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation

enum HTTPMethod: String
{
    case get = "GET"
    case post = "POST"
}

protocol NetworkRequestProtocol
{
    associatedtype SuccessResponse: Decodable
    associatedtype ErrorResponse: Decodable
    associatedtype BodyType: Encodable
    
    var url: URL { get }
    var body: BodyType? { get }
    var httpMethod: HTTPMethod { get }
    var needsCookieSetup: Bool { get }

}
extension NetworkRequestProtocol
{
    var request: URLRequest
    {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        if let body = body,
           let requestBody = try? JSONEncoder().encode(body)
        {
            request.httpBody = requestBody
        }
        
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        return request
    }
}

struct DummyStruct : Codable { }

struct GenericError: Decodable, Error
{
    let error: String?
}

struct LoginChallengeRequest: NetworkRequestProtocol
{
    typealias SuccessResponse = Challenge
    typealias ErrorResponse = GenericError
    typealias BodyType = DummyStruct
    
    var body: BodyType?
    
    var httpMethod: HTTPMethod = .post
    
    var needsCookieSetup: Bool = false
    
    var url: URL
    {
        return URL(string: "https://frbpasskey.ymedia.in/login/public-key/challenge")!
    }
}

struct SignUpChallengeRequest: NetworkRequestProtocol
{
    typealias SuccessResponse = Challenge
    typealias ErrorResponse = GenericError
    typealias BodyType = SignupChallengeParam
    
    var body: BodyType?
    
    var httpMethod: HTTPMethod = .post
    
    var needsCookieSetup: Bool = false
    
    var url: URL
    {
        return URL(string: "https://frbpasskey.ymedia.in/signup/public-key/challenge")!
    }
    
    init(body: BodyType? = nil) {
        self.body = body
    }
}

struct LoginRequest<BodyType: Encodable>: NetworkRequestProtocol
{
    typealias SuccessResponse = LoginResponse
    typealias ErrorResponse = GenericError
    
    var body: BodyType?
    
    var httpMethod: HTTPMethod = .post
    
    var needsCookieSetup: Bool = false
    
    var url: URL
    {
        return URL(string: "https://frbpasskey.ymedia.in/login/public-key")!
    }
    
    init(body: BodyType? = nil) {
        self.body = body
    }
}

struct LogOutRequest: NetworkRequestProtocol
{
    typealias SuccessResponse = LogOutResponse
    typealias ErrorResponse = GenericError
    typealias BodyType = DummyStruct
    
    var body: BodyType?
    
    var httpMethod: HTTPMethod = .post
    
    var needsCookieSetup: Bool = false
    
    var url: URL
    {
        return URL(string: "https://frbpasskey.ymedia.in/logout")!
    }
}

class NetworkManager
{
    func make<T: NetworkRequestProtocol>(urlRequest: T) async -> Result<T.SuccessResponse, T.ErrorResponse>
    {
        do
        {
            let (data,response) = try await URLSession.shared.data(for: urlRequest.request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else
            {
                let errorResponse: T.ErrorResponse = try decodeData(data: data)
                return .failure(errorResponse)
                
            }
            
            if urlRequest.needsCookieSetup
            {
                setUpCookie(url: urlRequest.url, response: response)
            }
            else
            {
                // Do nothing
            }
            
            let object: T.SuccessResponse = try decodeData(data: data)
            return .success(object)
        }
        catch
        {
            debugPrint("failed with error \(error)")
            let errorResponse = GenericError.init(error: error.localizedDescription) as! T.ErrorResponse
            return .failure(errorResponse)
        }
    }
    
    private func decodeData<T: Decodable>(data: Data) throws -> T
    {
        let decoder = JSONDecoder()
        let obj = try decoder.decode(T.self, from: data)
        return obj
    }
    
    private func setUpCookie(url: URL, response: URLResponse?)
    {
        if let httpResponse = response as? HTTPURLResponse,
           let fields = httpResponse.allHeaderFields as? [String: String]
        {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
            HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: url)
            for cookie in cookies {
                var cookieProperties = [HTTPCookiePropertyKey: Any]()
                cookieProperties[.name] = cookie.name
                cookieProperties[.value] = cookie.value
                cookieProperties[.domain] = cookie.domain
                cookieProperties[.path] = cookie.path
                cookieProperties[.version] = cookie.version
                cookieProperties[.expires] = Date().addingTimeInterval(31536000)
                
                let newCookie = HTTPCookie(properties: cookieProperties)
                HTTPCookieStorage.shared.setCookie(newCookie!)
                
                debugPrint("name: \(cookie.name) value: \(cookie.value)")
            }
        }
        
    }
}
