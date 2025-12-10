import Foundation

class NotificationThresholdService {
    static let shared = NotificationThresholdService()
    
    private let configService = ConfigService.shared
    private let authService = AuthenticationService.shared
    
    private init() {}
    
    func fetchThresholds(ticker: String) async throws -> ThresholdConfig? {
        guard let url = configService.getNotificationsURL(ticker: ticker) else {
            print("🔔 [Thresholds] Invalid notifications URL")
            return nil
        }
        
        // Check authentication
        guard authService.isAuthenticated, let sessionID = authService.sessionID else {
            print("🔔 [Thresholds] Not authenticated, skipping server fetch")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(sessionID)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🔔 [Thresholds] Invalid response type")
                return nil
            }
            
            if httpResponse.statusCode == 200 {
                // Check if response is empty JSON
                if let jsonString = String(data: data, encoding: .utf8),
                   jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "{}" {
                    return nil
                }
                
                // Parse JSON response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Navigate nested structure: notifications -> ticker -> thresholds
                    guard let notifications = json["notifications"] as? [String: Any],
                          let tickerData = notifications[ticker.uppercased()] as? [String: Any] else {
                        return nil
                    }
                    
                    // Helper function to extract Double from various types
                    func extractDouble(from value: Any?) -> Double? {
                        if let doubleValue = value as? Double {
                            return doubleValue
                        } else if let intValue = value as? Int {
                            return Double(intValue)
                        } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                            return doubleValue
                        }
                        return nil
                    }
                    
                    // Map snake_case server fields to ThresholdConfig
                    guard let ratioPremiumThreshold = extractDouble(from: tickerData["ratio_premium_threshold"]),
                          let callRatioThreshold = extractDouble(from: tickerData["call_ratio_threshold"]),
                          let putRatioThreshold = extractDouble(from: tickerData["put_ratio_threshold"]),
                          let callPremiumThreshold = extractDouble(from: tickerData["call_premium_threshold"]),
                          let putPremiumThreshold = extractDouble(from: tickerData["put_premium_threshold"]) else {
                        return nil
                    }
                    
                    // Extract disabled field (defaults to false if not present)
                    let disabled: Bool
                    if let disabledValue = tickerData["disabled"] as? Bool {
                        disabled = disabledValue
                    } else if let disabledValue = tickerData["disabled"] as? Int {
                        disabled = disabledValue != 0
                    } else {
                        disabled = false // Default to enabled
                    }
                    
                    let config = ThresholdConfig(
                        callRatioThreshold: callRatioThreshold,
                        putRatioThreshold: putRatioThreshold,
                        callPremiumThreshold: callPremiumThreshold,
                        putPremiumThreshold: putPremiumThreshold,
                        totalPremiumThreshold: ratioPremiumThreshold,
                        disabled: disabled
                    )
                    
                    return config
                } else {
                    return nil
                }
            } else if httpResponse.statusCode == 401 {
                print("🔔 [Thresholds] Authentication failed (401)")
                // Clear invalid session
                await MainActor.run {
                    authService.handleAuthenticationFailure()
                }
                return nil
            } else {
                print("🔔 [Thresholds] Server error (code: \(httpResponse.statusCode))")
                return nil
            }
        } catch {
            print("🔔 [Thresholds] Network error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveThresholds(ticker: String, config: ThresholdConfig, disabled: Bool? = nil) async {
        guard let url = configService.getNotificationsURL() else {
            print("🔔 [Thresholds] Invalid notifications URL for save")
            return
        }
        
        // Check authentication
        guard authService.isAuthenticated, let sessionID = authService.sessionID else {
            print("🔔 [Thresholds] Not authenticated, skipping server save")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(sessionID)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request body with snake_case field names
        // Use disabled parameter if provided, otherwise use config.disabled, default to false
        let disabledValue = disabled ?? config.disabled ?? false
        
        var requestBody: [String: Any] = [
            "ticker": ticker.uppercased(),
            "ratio_premium_threshold": config.totalPremiumThreshold,
            "call_ratio_threshold": config.callRatioThreshold,
            "put_ratio_threshold": config.putRatioThreshold,
            "call_premium_threshold": config.callPremiumThreshold,
            "put_premium_threshold": config.putPremiumThreshold,
            "disabled": disabledValue
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🔔 [Thresholds] Invalid response type on save")
                return
            }
            
            if httpResponse.statusCode == 200 {
                print("🔔 [Thresholds] Successfully saved thresholds to server for \(ticker)")
            } else if httpResponse.statusCode == 401 {
                print("🔔 [Thresholds] Authentication failed (401) on save")
                await MainActor.run {
                    authService.handleAuthenticationFailure()
                }
            } else {
                print("🔔 [Thresholds] Server error (code: \(httpResponse.statusCode)) on save")
            }
        } catch {
            // Silently handle errors - don't interrupt user workflow
            print("🔔 [Thresholds] Network error on save: \(error.localizedDescription)")
        }
    }
}

