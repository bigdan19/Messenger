//
//  LoginViewController.swift
//  Messenger
//
//  Created by Daniel on 20/06/2021.
//

import UIKit
import FirebaseAuth
import Firebase
import FBSDKLoginKit
import GoogleSignIn
import JGProgressHUD

class LoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "Logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email Adress..."
        field.leftView = UIView(
            frame: CGRect(x: 0,
                          y: 0,
                          width: 5,
                          height: 0)
        )
        field.leftViewMode = .always
        field.backgroundColor = .white
        return field
    }()
    
    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password..."
        field.leftView = UIView(
            frame: CGRect(x: 0,
                          y: 0,
                          width: 5,
                          height: 0)
        )
        field.leftViewMode = .always
        field.backgroundColor = .white
        field.isSecureTextEntry = true
        return field
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let facebookLoginButton: FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["public_profile", "email"]
        return button
    }()
    
    private let googleLoginButton: GIDSignInButton = {
        let button = GIDSignInButton()
        button.style = .wide
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Log In"
        view.backgroundColor = .white
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Register",
            style: .done,
            target: self,
            action: #selector(didTapRegister)
        )
        
        loginButton.addTarget(self,
                              action: #selector(loginButtonTapped),
                              for: .touchUpInside)
        googleLoginButton.addTarget(self,
                              action: #selector(signIn),
                              for: .touchUpInside)

        emailField.delegate = self
        passwordField.delegate = self
        facebookLoginButton.delegate = self
        
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(facebookLoginButton)
        scrollView.addSubview(googleLoginButton)
        
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width/3
        imageView.frame = CGRect(
            x: (scrollView.width-size)/2,
            y: 20,
            width: size,
            height: size
        )
        emailField.frame = CGRect(
            x: 30,
            y: imageView.bottom+10,
            width: scrollView.width-60,
            height: 50
        )
        passwordField.frame = CGRect(
            x: 30,
            y: emailField.bottom+10,
            width: scrollView.width-60,
            height: 50
        )
        loginButton.frame = CGRect(
            x: 30,
            y: passwordField.bottom+10,
            width: scrollView.width-60,
            height: 50
        )
        facebookLoginButton.frame = CGRect(
            x: 30,
            y: loginButton.bottom+10,
            width: scrollView.width-60,
            height: 50
        )
        facebookLoginButton.frame.origin.y = loginButton.bottom+60
        
        googleLoginButton.frame = CGRect(
            x: 30,
            y: facebookLoginButton.bottom+10,
            width: scrollView.width-60,
            height: 50
        )
    }
    
    @objc private func signIn(sender: Any) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        
        GIDSignIn.sharedInstance.signIn(with: config, presenting: self) { [unowned self] user, error in
            
            if let error = error {
                print("error occured \(error)")
                return
            }
            
            guard user != nil else {
                return
            }
            
            guard let autentication = user?.authentication, let idToken = autentication.idToken else {
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: autentication.accessToken)
            
            FirebaseAuth.Auth.auth().signIn(with: credential, completion: { [weak self] authResult, error in
                guard let strongSelf = self else {
                    return
                }
                guard authResult != nil, error == nil else {
                    if let error = error {
                        print("Google sign in failed. error - \(error)")
                    }
                    
                    return
                }
                print("Successfully logged user in using google")
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            })
        
            
            let emailAddress = user?.profile?.email
            guard let email = emailAddress else {
                print("not able to get email after google login")
                return
            }

            let fullName = user?.profile?.name.components(separatedBy: " ")
            guard let names = fullName, names.count == 2 else {
                return
            }
            let firstName = names[0]
            let secondName = names[1]

            UserDefaults.standard.set(email, forKey: "email")
            UserDefaults.standard.set(fullName, forKey: "name")

            DatabaseManager.shared.userExists(with: email) { exists in
                if !exists {
                    let chatUser = ChatAppUser(firstName: firstName, lastName: secondName, emailAdress: email)
                    DatabaseManager.shared.insertUser(with: chatUser) { success in
                        if success {
                            //upload image
                            
                            if ((user?.profile?.hasImage) != nil) {
                                guard let url = user?.profile?.imageURL(withDimension: 200) else {
                                    return
                                }
                                
                                URLSession.shared.dataTask(with: url) { data, _, _ in
                                    guard let data = data else {
                                        return
                                    }
                                    
                                    let fileName = chatUser.profilePictureFileName
                                    StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName) { result in
                                        switch result {
                                        case .success(let downloadUrl):
                                            UserDefaults.standard.setValue(downloadUrl, forKey: "profile_picrute_url")
                                            print(downloadUrl)
                                        case .failure(let error):
                                                print("Storage manager error \(error)")
                                        }
                                    }
                                }.resume()
                            }
                        }
                    }
                }
            }
            
            
            
            
            // User is succesfully logged in google sign in , database record is created
        }
    }
    
    @objc private func loginButtonTapped() {
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        guard let email = emailField.text, let password = passwordField.text,
              !email.isEmpty, !password.isEmpty, password.count >= 6 else {
            alertUserLoginError()
            return
        }
        
        spinner.show(in: view)
        
        // Firebase Log In
        
        FirebaseAuth.Auth.auth().signIn(
            withEmail: email,
            password: password,
            completion: { [weak self] AuthResult, error in
                guard let strongSelf = self else {
                    return
                }
                
                DispatchQueue.main.async {
                    strongSelf.spinner.dismiss()
                }
                
                guard let result = AuthResult, error == nil else {
                    print("Failed to log in user")
                    return
                }
                
                let user = result.user
                
                let safeEmail = DatabaseManager.safeEmail(emailAdress: email)
                DatabaseManager.shared.getDataFor(path: safeEmail, completion: { result in
                    switch result {
                    case .success(let data):
                        guard let userData = data as? [String : Any],
                        let firstName = userData["first_name"] as? String ,
                        let lastName = userData["last_name"] as? String else {
                            return
                        }
                        UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                    case .failure(let error):
                        print("Failed to read data with error \(error)")
                    }
                })
                
                UserDefaults.standard.set(email, forKey: "email")
                
                
                print("Logged in User: \(user)")
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            })
    }
    
    func alertUserLoginError() {
        let alert = UIAlertController(title: "Woops",
                                      message: "Please enter all information to login",
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Dismiss",
                                      style: .cancel,
                                      handler: nil))
        
        present(alert, animated: true)
    }
    
    @objc private func didTapRegister() {
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
}


extension LoginViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == emailField {
            passwordField.becomeFirstResponder()
        }
        else if textField == passwordField {
            loginButtonTapped()
        }
        
        return true
    }
    
}

extension LoginViewController: LoginButtonDelegate {
    func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        // no operation
    }
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        guard let token = result?.token?.tokenString else {
            print("User failed to log in with facebook")
            return
        }
        
        let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me", parameters: ["fields": "email, first_name, last_name, picture.type(large)"], tokenString: token, version: nil, httpMethod: .get)
        facebookRequest.start(completion: { _, result, error in
            guard let result = result as? [String: Any], error == nil else {
                print("Failed to make facebook graph request")
                return
            }
            
            print(result)
            guard let first_name = result["first_name"] as? String,
                  let last_name = result["last_name"] as? String,
                  let email = result["email"] as? String,
                  let picture = result["picture"] as? [String: Any],
                  let data = picture["data"] as? [String: Any],
                  let pictureUrl = data["url"] as? String else {
                print("failed to get email and name from fb result")
                return
            }
            
            UserDefaults.standard.set(email, forKey: "email")
            UserDefaults.standard.set("\(first_name) \(last_name)", forKey: "name")
            
            DatabaseManager.shared.userExists(with: email, completion: { exists in
                if !exists {
                    let chatUser = ChatAppUser(
                        firstName: first_name,
                        lastName: last_name,
                        emailAdress: email)
                    DatabaseManager.shared.insertUser(with: chatUser) { success in
                        if success {
                            
                            guard let url = URL(string: pictureUrl) else {
                                return
                            }
                            
                            print("Dowloading data from facebook image")
                            
                            URLSession.shared.dataTask(with: url) { data, _, _ in
                                guard let data = data else {
                                    print("failed to get data from facebook")
                                    return
                                }
                                
                                print("got data from facebook, uploading...")
                                
                                //upload image
                                
                                let fileName = chatUser.profilePictureFileName
                                StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName) { result in
                                    switch result {
                                    case .success(let downloadUrl):
                                        UserDefaults.standard.setValue(downloadUrl, forKey: "profile_picrute_url")
                                        print(downloadUrl)
                                    case .failure(let error):
                                        print("Storage manager error \(error)")
                                    }
                                }
                                
                            }.resume()
                        }
                    }
                }
            })
            
            
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            
            FirebaseAuth.Auth.auth().signIn(with: credential, completion: { [weak self] authResult, error in
                guard let strongSelf = self else {
                    return
                }
                guard authResult != nil, error == nil else {
                    if let error = error {
                        print("Facebook credential login failed, MFA may be needed \(error)")
                    }
                    
                    return
                }
                print("Successfully logged user in")
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            })
        })
    }
    
    
}
