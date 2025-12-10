import Foundation

class DeviceRegistrationService: ObservableObject {
    static let shared = DeviceRegistrationService()
    
    @Published var registrationError: String?
    
    private let configService = ConfigService.shared
    private let authService = AuthenticationService.shared
    
    private init() {}
    
    func registerDevice(deviceToken: String) async throws {
        guard let url = configService.getRegisterDeviceURL() else {
            throw DeviceRegistrationError.invalidURL
        }
        
        // Check authentication
        guard authService.isAuthenticated, let sessionID = authService.sessionID else {
            throw DeviceRegistrationError.notAuthenticated
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(sessionID)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "device_token": deviceToken
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeviceRegistrationError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            print("📱 [Device] Successfully registered device with server")
            await MainActor.run {
                self.registrationError = nil
            }
        } else if httpResponse.statusCode == 401 {
            print("📱 [Device] Authentication failed (401) during registration")
            await MainActor.run {
                authService.handleAuthenticationFailure()
            }
            throw DeviceRegistrationError.authenticationFailed
        } else {
            let errorMessage = "Server error (code: \(httpResponse.statusCode))"
            if let responseString = String(data: data, encoding: .utf8) {
                print("📱 [Device] Registration failed: \(responseString)")
            }
            throw DeviceRegistrationError.serverError(httpResponse.statusCode, message: errorMessage)
        }
    }
    
    func registerDeviceWithRetry(deviceToken: String) {
        Task {
            do {
                try await registerDevice(deviceToken: deviceToken)
            } catch {
                print("📱 [Device] First registration attempt failed: \(error.localizedDescription)")
                
                // Retry once
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                    try await registerDevice(deviceToken: deviceToken)
                    print("📱 [Device] Retry successful")
                } catch {
                    // Retry also failed - show error
                    print("📱 [Device] Retry also failed: \(error.localizedDescription)")
                    await MainActor.run {
                        if let regError = error as? DeviceRegistrationError {
                            switch regError {
                            case .notAuthenticated:
                                self.registrationError = "Not authenticated. Please sign in again."
                            case .serverError(_, let message):
                                self.registrationError = "Failed to register device: \(message)"
                            default:
                                self.registrationError = "Failed to register device for push notifications."
                            }
                        } else {
                            self.registrationError = "Failed to register device: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
}

enum DeviceRegistrationError: Error {
    case invalidURL
    case notAuthenticated
    case invalidResponse
    case authenticationFailed
    case serverError(Int, message: String)
}

