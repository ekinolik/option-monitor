import Foundation
import Combine
import UserNotifications

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error(String)
}

class WebSocketService: ObservableObject {
    @Published var summaries: [OptionSummary] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var reconnectTimer: Timer?
    private var shouldReconnect = false
    private var shouldClearOnFirstMessage = false
    private let configService = ConfigService.shared
    private let notificationService = NotificationService.shared
    private let authService = AuthenticationService.shared
    
    init() {
        // Listen for config changes (host, port, date, ticker)
        Publishers.CombineLatest4(
            configService.$host,
            configService.$port,
            configService.$selectedDate,
            configService.$ticker
        )
        .sink { [weak self] _, _, _, _ in
            // Always reconnect when config changes, regardless of current state
            guard let self = self else { return }
            
            // Clear summaries when config changes
            DispatchQueue.main.async {
                self.summaries = []
            }
            
            // Disconnect and reconnect
            self.disconnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.reconnect()
            }
        }
        .store(in: &cancellables)
        
        // Listen for authentication state changes
        authService.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                if isAuthenticated {
                    // Auto-connect when authenticated
                    DispatchQueue.main.async {
                        if case .disconnected = self.connectionStatus {
                            self.connect()
                        }
                    }
                } else {
                    // Disconnect when not authenticated
                    self.disconnect()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func connect() {
        // If already connected or connecting, don't reconnect unless forced
        guard case .disconnected = connectionStatus else {
            return
        }
        
        performConnection()
    }
    
    func reconnect() {
        // Force reconnection by disconnecting first, then connecting
        disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.performConnection()
        }
    }
    
    private func performConnection() {
        // Disconnect existing connection first if any
        if webSocketTask != nil {
            disconnect()
        }
        
        // Check authentication first
        guard authService.isAuthenticated, let sessionID = authService.sessionID else {
            connectionStatus = .error("Not authenticated")
            lastError = "Please sign in to connect"
            // Trigger sign-in
            DispatchQueue.main.async {
                self.authService.signInWithApple()
            }
            return
        }
        
        guard let url = configService.getWebSocketURL() else {
            connectionStatus = .error("Invalid WebSocket URL")
            lastError = "Invalid WebSocket URL. Please check host and port settings."
            return
        }
        
        connectionStatus = .connecting
        shouldReconnect = true
        // Mark that we should clear summaries when we receive the first message
        shouldClearOnFirstMessage = true
        
        // Create URLRequest with authentication header
        var request = URLRequest(url: url)
        request.setValue("Bearer \(sessionID)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        
        self.urlSession = session
        self.webSocketTask = task
        
        // Set up message receiver before resuming to catch immediate errors
        receiveMessage()
        
        task.resume()
        
        // Set up ping to keep connection alive
        schedulePing()
        
        // Note: We set connected status optimistically, but handleError will update it if connection fails
        connectionStatus = .connected
        lastError = nil
    }
    
    func disconnect() {
        shouldReconnect = false
        shouldClearOnFirstMessage = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        connectionStatus = .disconnected
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                if case .connected = self.connectionStatus {
                    self.receiveMessage()
                }
                
            case .failure(let error):
                self.handleError(error)
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        // Check if the message is an error response indicating authentication failure
        // Only check for specific error patterns, not just any occurrence of these words
        let lowerText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let isErrorResponse = lowerText.hasPrefix("{") && 
                             (lowerText.contains("\"error\"") || 
                              lowerText.contains("\"status\":401") ||
                              lowerText.contains("\"code\":401") ||
                              lowerText.contains("unauthorized") ||
                              (lowerText.contains("401") && lowerText.contains("authentication")))
        
        if isErrorResponse {
            print("🔌 [WebSocket] Received authentication error message: \(text)")
            DispatchQueue.main.async {
                self.connectionStatus = .error("Authentication required")
                self.lastError = "Session expired. Please sign in again."
                self.webSocketTask = nil
                self.urlSession = nil
                self.authService.handleAuthenticationFailure()
            }
            return
        }
        
        guard let data = text.data(using: .utf8) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let summary = try decoder.decode(OptionSummary.self, from: data)
            
            DispatchQueue.main.async {
                // If this is the first message after a new connection, clear existing summaries
                if self.shouldClearOnFirstMessage {
                    self.summaries = []
                    self.shouldClearOnFirstMessage = false
                }
                
                // Check thresholds and send notifications if needed
                self.checkThresholdsAndNotify(for: summary)
                
                // Insert at the beginning to show newest first
                self.summaries.insert(summary, at: 0)
            }
        } catch {
            // If decoding fails, check if it might be an error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (json["error"] != nil || json["status"] as? Int == 401 || json["code"] as? Int == 401) {
                print("🔌 [WebSocket] Received error response: \(text)")
                DispatchQueue.main.async {
                    self.connectionStatus = .error("Authentication required")
                    self.lastError = "Session expired. Please sign in again."
                    self.webSocketTask = nil
                    self.urlSession = nil
                    self.authService.handleAuthenticationFailure()
                }
                return
            }
            
            print("Failed to decode message: \(error)")
            print("Message content: \(text)")
        }
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            let errorDescription = error.localizedDescription
            let nsError = error as NSError
            
            // Check for WebSocket handshake failure (error -1011) which often indicates 401
            // Also check error descriptions for authentication-related errors
            let isHandshakeFailure = nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorBadServerResponse
            let isAuthError = errorDescription.contains("401") || 
                             errorDescription.contains("Unauthorized") || 
                             errorDescription.contains("authentication") ||
                             errorDescription.contains("bad response from the server")
            
            if isHandshakeFailure || isAuthError {
                // Likely authentication error - clear session and show sign-in
                print("🔌 [WebSocket] Authentication/handshake error detected: \(errorDescription)")
                print("🔌 [WebSocket] Error code: \(nsError.code), domain: \(nsError.domain)")
                self.connectionStatus = .error("Authentication required")
                self.lastError = "Session expired or invalid. Please sign in again."
                self.webSocketTask = nil
                self.urlSession = nil
                self.shouldReconnect = false // Don't try to reconnect with invalid session
                
                // Clear invalid session - this will trigger UI to show sign-in screen
                self.authService.handleAuthenticationFailure()
            } else {
                self.connectionStatus = .error(errorDescription)
                self.lastError = errorDescription
                self.webSocketTask = nil
                self.urlSession = nil
                
                // Attempt reconnection if we should be connected
                if self.shouldReconnect {
                    self.scheduleReconnect()
                }
            }
        }
    }
    
    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            guard let self = self, self.shouldReconnect else { return }
            self.connect()
        }
    }
    
    private func schedulePing() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] timer in
            guard let self = self,
                  let task = self.webSocketTask,
                  case .connected = self.connectionStatus else {
                timer.invalidate()
                return
            }
            
            task.sendPing { error in
                if let error = error {
                    self.handleError(error)
                }
            }
        }
    }
    
    private func checkThresholdsAndNotify(for summary: OptionSummary) {
        // Only send notifications if enabled
        guard configService.notificationsEnabled else { return }
        
        // Call ratio takes precedence for notifications too
        // But only if total premium meets the ratio premium threshold
        if summary.callPutRatio >= configService.callRatioThreshold &&
           summary.totalPremium >= configService.totalPremiumThreshold {
            notificationService.sendThresholdNotification(for: summary, thresholdType: .callRatioExceeded)
            return // Don't check premium thresholds if ratio threshold is met
        }
        
        if summary.callPutRatio <= configService.putRatioThreshold &&
           summary.totalPremium >= configService.totalPremiumThreshold {
            notificationService.sendThresholdNotification(for: summary, thresholdType: .putRatioBelow)
            return // Don't check premium thresholds if ratio threshold is met
        }
        
        // If call ratio thresholds not met, check premium thresholds
        let callPremiumExceeded = summary.callPremium >= configService.callPremiumThreshold
        let putPremiumExceeded = summary.putPremium >= configService.putPremiumThreshold
        
        if callPremiumExceeded && putPremiumExceeded {
            notificationService.sendThresholdNotification(for: summary, thresholdType: .bothPremiumsExceeded)
        } else if callPremiumExceeded {
            notificationService.sendThresholdNotification(for: summary, thresholdType: .callPremiumExceeded)
        } else if putPremiumExceeded {
            notificationService.sendThresholdNotification(for: summary, thresholdType: .putPremiumExceeded)
        }
    }
}

