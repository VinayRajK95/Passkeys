/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The authentication manager object.
*/

import AuthenticationServices
import Foundation
import os

extension NSNotification.Name {
    static let UserSignedIn = Notification.Name("UserSignedInNotification")
    static let Error = Notification.Name("ErrorNotification")
}

class AccountManager: NSObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate
{
    private override init(){}
    static let defaultAM = AccountManager()
    
    let domain = "frbpasskey.ymedia.in"
    let networkManager: NetworkManager = .init()
    var authenticationAnchor: ASPresentationAnchor?
    var isPerformingModalReqest = false
    
    func signInWith(anchor: ASPresentationAnchor, preferImmediatelyAvailableCredentials: Bool) async {
        self.authenticationAnchor = anchor
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
        
        // Fetch the challenge from the server. The challenge needs to be unique for each request.
        guard let challenge = await fetchChallenge()?.challenge.base64urlToBase64,
              let challengeData = Data(base64Encoded: challenge)
        else { return }
        
        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challengeData)
        
        // Also allow the user to use a saved password, if they have one.
        let passwordCredentialProvider = ASAuthorizationPasswordProvider()
        let passwordRequest = passwordCredentialProvider.createRequest()
        
        // Pass in any mix of supported sign-in request types.
        let authController = ASAuthorizationController(authorizationRequests: [ assertionRequest, passwordRequest ] )
        authController.delegate = self
        authController.presentationContextProvider = self
        
        if preferImmediatelyAvailableCredentials {
            // If credentials are available, presents a modal sign-in sheet.
            // If there are no locally saved credentials, no UI appears and
            // the system passes ASAuthorizationError.Code.canceled to call
            // `AccountManager.authorizationController(controller:didCompleteWithError:)`.
            authController.performRequests(options: .preferImmediatelyAvailableCredentials)
        } else {
            // If credentials are available, presents a modal sign-in sheet.
            // If there are no locally saved credentials, the system presents a QR code to allow signing in with a
            // passkey from a nearby device.
            authController.performRequests()
        }
        
        isPerformingModalReqest = true
    }
    
    func beginAutoFillAssistedPasskeySignIn(anchor: ASPresentationAnchor) async {
        self.authenticationAnchor = anchor
        
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
        
        // Fetch the challenge from the server. The challenge needs to be unique for each request.

        guard let challenge = await fetchChallenge()?.challenge.base64urlToBase64,
              let challengeData = Data(base64Encoded: challenge)
        else { return }
        
        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challengeData)
        
        // AutoFill-assisted requests only support ASAuthorizationPlatformPublicKeyCredentialAssertionRequest.
        let authController = ASAuthorizationController(authorizationRequests: [ assertionRequest ] )
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performAutoFillAssistedRequests()
    }
    
    func signUpWith(userName: String, anchor: ASPresentationAnchor) async {
        self.authenticationAnchor = anchor
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
        
        // Fetch the challenge from the server. The challenge needs to be unique for each request.
        // The userID is the identifier for the user's account.
        guard let challenge = await fetchChallenge(for: userName),
              let user = challenge.user,
              let challenge = Data(base64Encoded: challenge.challenge.base64urlToBase64)
        else { return }
        
        let userId = Data(user.id.utf8)
        
        let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: userName, userID: userId)
        
        // Use only ASAuthorizationPlatformPublicKeyCredentialRegistrationRequests or
        // ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequests here.
        let authController = ASAuthorizationController(authorizationRequests: [ registrationRequest ] )
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
        isPerformingModalReqest = true
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization)
    {
        let logger = Logger()
        switch authorization.credential {
        case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            logger.log("A new passkey was registered: \(credentialRegistration)")
            // Verify the attestationObject and clientDataJSON with your service.
            // The attestationObject contains the user's new public key to store and use for subsequent sign-ins.
            //             let attestationObject = credentialRegistration.rawAttestationObject
            //             let clientDataJSON = credentialRegistration.rawClientDataJSON
            
            // After the server verifies the registration and creates the user account, sign in the user with the new account.
            Task
            {
                await didFinishSignUp(data: credentialRegistration)
            }
        case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            logger.log("A passkey was used to sign in: \(credentialAssertion)")
            // Verify the below signature and clientDataJSON with your service for the given userID.
            //             let signature = credentialAssertion.signature
            //             let clientDataJSON = credentialAssertion.rawClientDataJSON
            //             let userID = credentialAssertion.userID
            //             let authData = credentialAssertion.rawAuthenticatorData
            //            let userHandle = credentialAssertion.
            
            // After the server verifies the assertion, sign in the user.
            Task
            {
                await didFinishSignIn(data: credentialAssertion)
            }
        case let passwordCredential as ASPasswordCredential:
            logger.log("A password was provided: \(passwordCredential)")
            // Verify the userName and password with your service.
            // let userName = passwordCredential.user
            // let password = passwordCredential.password
            
            // After the server verifies the userName and password, sign in the user.
            // await didFinishSignIn(data: credentialAssertion)
        default:
            fatalError("Received unknown authorization type.")
        }
        
        isPerformingModalReqest = false
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let logger = Logger()
        guard let authorizationError = error as? ASAuthorizationError else {
            isPerformingModalReqest = false
            logger.error("Unexpected authorization error: \(error.localizedDescription)")
            return
        }
        
        if authorizationError.code == .canceled
        {
            // Either the system doesn't find any credentials and the request ends silently, or the user cancels the request.
            // This is a good time to show a traditional login form, or ask the user to create an account.
            logger.log("Request canceled.")
            
            if isPerformingModalReqest {
                didCancelModalSheet()
            }
        }
        else
        {
            // Another ASAuthorization error.
            // Note: The userInfo dictionary contains useful information.
            logger.error("Error: \((error as NSError).userInfo)")
        }
        
        handleError(message: error.localizedDescription)
        isPerformingModalReqest = false
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor
    {
        return authenticationAnchor!
    }
    
    func didFinishSignUp(data: ASAuthorizationPlatformPublicKeyCredentialRegistration) async
    {
        let requestBody = SignUpParam(response: .init(clientDataJSON: data.rawClientDataJSON.base64EncodedString(),
                                                      attestationObject: data.rawAttestationObject?.base64EncodedString(),
                                                      authenticatorData: nil,
                                                      userHandle: nil,
                                                      signature: nil,
                                                      transports: ["internal"]))
        
        let response: Result<LoginRequest.SuccessResponse, LoginRequest.ErrorResponse> = await networkManager.make(urlRequest: LoginRequest(body: requestBody))
        handleResponse(response)
    }
    
    private func fetchChallenge(for userName: String? = nil) async -> Challenge?
    {
        let response: Result<SignUpChallengeRequest.SuccessResponse, SignUpChallengeRequest.ErrorResponse>
        if let userName = userName
        {
            response = await networkManager.make(urlRequest: SignUpChallengeRequest(body: .init(name: userName, username: userName)))
        }
        else
        {
            response = await networkManager.make(urlRequest: LoginChallengeRequest())
        }
        
        switch response
        {
            case let .success(result):
                return result
            case let .failure(error):
            print("failed to fetch challenge with error \(error.localizedDescription)")
                return nil
        }
    }
    
    private func didFinishSignIn(data: ASAuthorizationPlatformPublicKeyCredentialAssertion) async {
        let requestBody = LoginParam(id: data.credentialID.base64EncodedString().base64StringToBase64url,
                                     authenticatorAttachment: "platform",
                                     response: .init(clientDataJSON: data.rawClientDataJSON.base64EncodedString().base64StringToBase64url,
                                                     attestationObject: nil,
                                                     authenticatorData: data.rawAuthenticatorData.base64EncodedString().base64StringToBase64url,
                                                     userHandle: data.userID.stringValue(),
                                                     signature: data.signature.base64EncodedString().base64StringToBase64url,
                                                     transports: nil))
        let response = await networkManager.make(urlRequest: LoginRequest(body: requestBody))
        handleResponse(response)
    }
    
    private func processLoginSuccessResponse(_ response: LoginResponse)
    {
        if response.ok {
            NotificationCenter.default.post(name: .UserSignedIn, object: nil)
        }
        else{
            print("Login failed")
        }
    }
    
    private func handleResponse(_ response: Result<LoginRequest.SuccessResponse, LoginRequest.ErrorResponse>)
    {
        switch response
        {
            case let .success(value):
                processLoginSuccessResponse(value)
                break
            case let .failure(value):
                processFailureResponse(value)
                handleError(message: value.error)
                break
        }
    }
    
    private func processFailureResponse(_ response: GenericError)
    {
        print("Login failed")
    }
    
    func signOut() async
    {
        let response = await networkManager.make(urlRequest: LogOutRequest())
        switch response
        {
            case let .success(result):
                if result.status {
                    print("logout success")
                }
                else
                {
                    print("logout failed")
                }
                break
            case let .failure(error):
                handleError(message: error.localizedDescription)
                print("logout failed", error.error as Any)
                break
        }
    }
    
    private func handleError(message: String?)
    {
        let userInfo: [AnyHashable: Any] = ["title": "Something went wrong", "subTitle": message ?? ""]
        NotificationCenter.default.post(name: .Error, object: nil, userInfo: userInfo)
    }
    
    private func didCancelModalSheet() {
        // Do nothing
//        NotificationCenter.default.post(name: .ModalSignInSheetCanceled, object: nil)
    }
}
