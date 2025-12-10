import Foundation
import AuthenticationServices
import Combine
import UIKit

class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var isAuthenticated: Bool = false
    @Published var sessionID: String?
    @Published var isSigningIn: Bool = false
    @Published var authError: String?
    
    private let keychainService = KeychainService.shared
    private let configService = ConfigService.shared
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        if let sessionID = keychainService.getSessionID(), !sessionID.isEmpty {
            self.sessionID = sessionID
            self.isAuthenticated = true
        } else {
            self.sessionID = nil
            self.isAuthenticated = false
        }
    }
    
    func signInWithApple() {
        guard !isSigningIn else {
            print("🔐 [Auth] Sign-in already in progress")
            return
        }
        
        print("🔐 [Auth] Starting Sign in with Apple flow")
        isSigningIn = true
        authError = nil
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        print("🔐 [Auth] Created Apple ID authorization request")
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    private func exchangeTokenForSession(identityToken: String, authorizationCode: String?) async {
        guard let url = configService.getAuthURL() else {
            DispatchQueue.main.async {
                self.authError = "Invalid authentication URL"
                self.isSigningIn = false
            }
            return
        }
        
        print("🔐 [Auth] Starting authentication exchange")
        print("🔐 [Auth] URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestBody: [String: Any] = [
            "identity_token": identityToken
        ]
        
        // Add authorization code if available
        if let authCode = authorizationCode {
            requestBody["authorization_code"] = authCode
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Log request details (mask token for security)
            if let bodyData = request.httpBody,
               let bodyString = String(data: bodyData, encoding: .utf8) {
                let maskedBody = bodyString.replacingOccurrences(of: identityToken, with: "[TOKEN_MASKED]")
                print("🔐 [Auth] Request body: \(maskedBody)")
            }
            
            print("🔐 [Auth] Sending request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🔐 [Auth] ❌ Invalid response type")
                throw AuthError.invalidResponse
            }
            
            print("🔐 [Auth] Response status code: \(httpResponse.statusCode)")
            
            // Log response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔐 [Auth] Response body: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                // Parse JSON response - flexible parsing for different field names
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let sessionID: String?
                    
                    // Try different possible field names
                    if let id = json["sessionId"] as? String {
                        sessionID = id
                    } else if let id = json["session_id"] as? String {
                        sessionID = id
                    } else if let id = json["token"] as? String {
                        sessionID = id
                    } else if let id = json["jwt"] as? String {
                        sessionID = id
                    } else {
                        throw AuthError.invalidResponse
                    }
                    
                    if let sessionID = sessionID {
                        print("🔐 [Auth] ✅ Successfully received session ID")
                        // Save to Keychain
                        if keychainService.saveSessionID(sessionID) {
                            print("🔐 [Auth] ✅ Session ID saved to Keychain")
                            DispatchQueue.main.async {
                                self.sessionID = sessionID
                                self.isAuthenticated = true
                                self.isSigningIn = false
                                self.authError = nil
                                
                                // Register device for push notifications if token is available
                                let notificationService = NotificationService.shared
                                if let deviceToken = notificationService.deviceToken {
                                    DeviceRegistrationService.shared.registerDeviceWithRetry(deviceToken: deviceToken)
                                }
                            }
                        } else {
                            print("🔐 [Auth] ❌ Failed to save session ID to Keychain")
                            throw AuthError.keychainError
                        }
                    } else {
                        print("🔐 [Auth] ❌ No session ID found in response")
                        throw AuthError.invalidResponse
                    }
                } else {
                    print("🔐 [Auth] ❌ Failed to parse JSON response")
                    throw AuthError.invalidResponse
                }
            } else if httpResponse.statusCode == 401 {
                print("🔐 [Auth] ❌ Authentication failed (401)")
                throw AuthError.authenticationFailed
            } else {
                // For 400 and other errors, try to extract error message from response
                var errorMessage = "Server error (code: \(httpResponse.statusCode))"
                if let responseString = String(data: data, encoding: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let message = json["error"] as? String {
                        errorMessage = "\(errorMessage): \(message)"
                    } else if let message = json["message"] as? String {
                        errorMessage = "\(errorMessage): \(message)"
                    } else {
                        errorMessage = "\(errorMessage). Response: \(responseString)"
                    }
                }
                print("🔐 [Auth] ❌ \(errorMessage)")
                throw AuthError.serverError(httpResponse.statusCode, message: errorMessage)
            }
        } catch {
            print("🔐 [Auth] ❌ Exception: \(error.localizedDescription)")
            DispatchQueue.main.async {
                if let authError = error as? AuthError {
                    switch authError {
                    case .authenticationFailed:
                        self.authError = "Authentication failed. Please try again."
                    case .invalidResponse:
                        self.authError = "Invalid server response. Check console for details."
                    case .keychainError:
                        self.authError = "Failed to save session. Please try again."
                    case .serverError(let code, let message):
                        self.authError = message
                    }
                } else {
                    self.authError = "Network error: \(error.localizedDescription)"
                }
                self.isSigningIn = false
            }
        }
    }
    
    func signOut() {
        keychainService.deleteSessionID()
        sessionID = nil
        isAuthenticated = false
        authError = nil
    }
    
    func handleAuthenticationFailure() {
        print("🔐 [Auth] Handling authentication failure - clearing session")
        keychainService.deleteSessionID()
        DispatchQueue.main.async {
            self.sessionID = nil
            self.isAuthenticated = false
            // Don't clear authError here - let the caller set it if needed
        }
    }
}

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("🔐 [Auth] Apple authorization completed successfully")
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                print("🔐 [Auth] ❌ Failed to get identity token from Apple credential")
                DispatchQueue.main.async {
                    self.authError = "Failed to get identity token"
                    self.isSigningIn = false
                }
                return
            }
            
            // Get authorization code if available
            var authorizationCode: String? = nil
            if let authCodeData = appleIDCredential.authorizationCode,
               let authCode = String(data: authCodeData, encoding: .utf8) {
                authorizationCode = authCode
                print("🔐 [Auth] ✅ Received authorization code from Apple")
            } else {
                print("🔐 [Auth] ⚠️ No authorization code available")
            }
            
            print("🔐 [Auth] ✅ Received identity token from Apple (length: \(identityToken.count))")
            Task {
                await exchangeTokenForSession(identityToken: identityToken, authorizationCode: authorizationCode)
            }
        } else {
            print("🔐 [Auth] ❌ Authorization credential is not ASAuthorizationAppleIDCredential")
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    self.authError = nil // User canceled - don't show error
                case .failed:
                    self.authError = "Authentication failed. Please try again."
                case .invalidResponse:
                    self.authError = "Invalid response from Apple. Please try again."
                case .notHandled:
                    self.authError = "Authentication not handled. Please try again."
                case .unknown:
                    self.authError = "Unknown authentication error. Please try again."
                @unknown default:
                    self.authError = "Authentication error. Please try again."
                }
            } else {
                self.authError = "Authentication error: \(error.localizedDescription)"
            }
            self.isSigningIn = false
        }
    }
}

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the key window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window
        }
        // Fallback - this shouldn't happen
        return UIApplication.shared.windows.first ?? UIWindow()
    }
}

enum AuthError: Error {
    case authenticationFailed
    case invalidResponse
    case keychainError
    case serverError(Int, message: String)
}

