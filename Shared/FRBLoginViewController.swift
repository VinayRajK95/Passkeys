//
//  FRBLoginViewController.swift
//  PassKeys_POC
//
//  Created by Vinay Raj K on 06/03/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import AuthenticationServices
import UIKit
import os

class FRBLoginViewController: UIViewController {

    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var switchPasskeysButton: UIButton!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var userNameView: UIView!
    @IBOutlet weak var containerView: UIView!
    
    private var signInObserver: NSObjectProtocol?
    private var errorObserver: NSObjectProtocol?

    var isRegistrationFlow = false
    
    enum AuthFlow
    {
        struct VariantDetail
        {
            let logoName: String
            let placeholder: String
            let actionButtonTitle: String
            let switchButtonTitle: String
        }
        
        case registration
        case login
        
        func getDetails() -> VariantDetail
        {
            switch self
            {
            case .login:
                return .init(logoName: "lock", placeholder: "Password", actionButtonTitle: "Sign In with Passkey", switchButtonTitle: "Not Registered with Passkeys? Register now")
            case .registration:
                return .init(logoName: "contact_email_icon", placeholder: "Email ID", actionButtonTitle: "Register", switchButtonTitle: "Back to Login")
            }
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        signInObserver = NotificationCenter.default.addObserver(forName: .UserSignedIn, object: nil, queue: nil) {_ in
            self.didFinishSignIn()
        }

        errorObserver = NotificationCenter.default.addObserver(forName: .Error, object: nil, queue: nil) { [weak self] notification in
            self?.presentAlert(withTitle: notification.userInfo?["title"] as? String,
                              message: notification.userInfo?["subTitle"] as? String)
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(resignTextFieldResponder))
        containerView.addGestureRecognizer(tapGesture)
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }
    
    func didFinishSignIn()
    {
        DispatchQueue.main.async
        {
            let viewController = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "HomeViewController")
            viewController.modalPresentationStyle = .fullScreen
            viewController.isModalInPresentation = true
            self.present(viewController, animated: true, completion:
                            { [weak self] in
                self?.userNameTextField.text = nil
            })
        }
    }
    
    @objc func resignTextFieldResponder()
    {
        view.endEditing(true)
    }
    
    private func presentAlert(withTitle title: String?, message: String?)
    {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okButton = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okButton)
        DispatchQueue.main.async {
            self.present(alert, animated: true)
        }
    }

    @IBAction func switchPasskeyAction(_ sender: Any)
    {
        let flow: AuthFlow = isRegistrationFlow ? .login : .registration
        let details = flow.getDetails()
        userNameView.isHidden = isRegistrationFlow
        signInButton.setTitle(details.actionButtonTitle, for: .normal)
        switchPasskeysButton.setTitle(details.switchButtonTitle, for: .normal)
        isRegistrationFlow.toggle()
        self.userNameTextField.text = nil
        resignTextFieldResponder()
    }
    
    @IBAction func signInAction(_ sender: Any)
    {
        defer
        {
            resignTextFieldResponder()
            self.userNameTextField.text = nil
        }
        if isRegistrationFlow
        {
            guard let userName = userNameTextField.text,
            !userName.isEmpty
            else {
                Logger().log("No email provided")
                presentAlert(withTitle: "Email cannot be empty", message: "please enter your mail id")
                return
            }

            guard let window = self.view.window else { fatalError("The view was not in the app's view hierarchy!") }
            Task
            {
                await AccountManager.defaultAM.signUpWith(userName: userName, anchor: window)
            }
        }
        else
        {
            guard let window = self.view.window else { fatalError("The view was not in the app's view hierarchy!") }
            Task
            {
                await AccountManager.defaultAM.signInWith(anchor: window, preferImmediatelyAvailableCredentials: true)
            }
        }
    }

    func signedOut()
    {
        DispatchQueue.main.async
        {
            self.showToast(message: "Sign out success")
        }
    }
}

extension UIViewController
{
    func showToast(message : String)
    {
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 75, y: self.view.frame.size.height-100, width: 150, height: 35))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.font = .systemFont(ofSize: 14)
        toastLabel.textAlignment = .center;
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        self.view.addSubview(toastLabel)
        UIView.animate(withDuration: 2.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    }
}


class CustomTextfield: UITextField
{
    var clearButton: UIButton?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if clearButton == nil
        {
            for view in subviews {
                clearButton = view as? UIButton
            }
        }
        clearButton?.setImage(clearButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
        clearButton?.tintColor = .white
    }
}
