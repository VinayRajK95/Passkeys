/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The view where the user can sign in, or create an account.
*/

import AuthenticationServices
import UIKit
import os

class SignInViewController: UIViewController {
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userNameField: UITextField!

    @IBOutlet weak var containerStackView: UIStackView!
    @IBOutlet weak var buttonStackView: UIStackView!
    
    private var signInObserver: NSObjectProtocol?
    private var errorObserver: NSObjectProtocol?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        signInObserver = NotificationCenter.default.addObserver(forName: .UserSignedIn, object: nil, queue: nil) {_ in
            self.didFinishSignIn()
        }

        errorObserver = NotificationCenter.default.addObserver(forName: .Error, object: nil, queue: nil) { [weak self] notification in
            self?.presentAlert(withTitle: notification.userInfo?["title"] as? String,
                              message: notification.userInfo?["subTitle"] as? String)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if let signInObserver = signInObserver {
            NotificationCenter.default.removeObserver(signInObserver)
        }

        if let errorObserver = errorObserver {
            NotificationCenter.default.removeObserver(errorObserver)
        }
        
        super.viewDidDisappear(animated)
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }

    private func showPassKeysPopUp()
    {
        guard let window = self.view.window else { fatalError("The view was not in the app's view hierarchy!") }
        Task
        {
            await AccountManager.defaultAM.signInWith(anchor: window, preferImmediatelyAvailableCredentials: true)
        }
    }
    
    func showSignInForm() {
//        containerStackView.isHidden = false
//        guard let window = self.view.window else { fatalError("The view was not in the app's view hierarchy!") }
//        Task
//        {
//            await AccountManager.defaultAM.beginAutoFillAssistedPasskeySignIn(anchor: window)
//        }
    }

    func didFinishSignIn() {
        DispatchQueue.main.async
        {
            self.view.window?.rootViewController = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "UserHomeViewController")
        }
    }

    @IBAction func createAccount(_ sender: Any) {
        
        containerStackView.isHidden = false
        buttonStackView.isHidden = true
        userNameField.becomeFirstResponder()
    }

    @IBAction func loginTapped(_ sender: Any)
    {
        showPassKeysPopUp()
    }
    
    @IBAction func procced(_ sender: Any)
    {
        guard let userName = userNameField.text,
        !userName.isEmpty
        else {
            Logger().log("No user name provided")
            presentAlert(withTitle: "UserName is empty", message: "please enter a user name")
            return
        }

        guard let window = self.view.window else { fatalError("The view was not in the app's view hierarchy!") }
        Task
        {
            await AccountManager.defaultAM.signUpWith(userName: userName, anchor: window)
        }
    }
    
    @IBAction func tappedBackground(_ sender: Any)
    {
        self.view.endEditing(true)
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
    
    @IBAction func cancelAction(_ sender: UIButton)
    {
        containerStackView.isHidden = true
        buttonStackView.isHidden = false
        userNameField.text = nil
        userNameField.resignFirstResponder()
    }
}

