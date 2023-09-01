//
//  HomeViewController.swift
//  PassKeys_POC
//
//  Created by Vinay Raj K on 07/03/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        self.showToast(message: "You are now signed in")
    }
    
    @IBAction func signOutAction(_ sender: Any)
    {
        Task
        {
            await AccountManager.defaultAM.signOut()
        }
        
        dismiss(animated: true) {
            let viewController = self.presentingViewController as? FRBLoginViewController
            viewController?.signedOut()
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
