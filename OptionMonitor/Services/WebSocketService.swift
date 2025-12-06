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
    
    init() {
        // Listen for config changes (host, port, date)
        Publishers.CombineLatest3(
            configService.$host,
            configService.$port,
            configService.$selectedDate
        )
        .sink { [weak self] _, _, _ in
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
        
        guard let url = configService.getWebSocketURL() else {
            connectionStatus = .error("Invalid WebSocket URL")
            lastError = "Invalid WebSocket URL. Please check host and port settings."
            return
        }
        
        connectionStatus = .connecting
        shouldReconnect = true
        // Mark that we should clear summaries when we receive the first message
        shouldClearOnFirstMessage = true
        
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        
        self.urlSession = session
        self.webSocketTask = task
        
        task.resume()
        receiveMessage()
        
        // Set up ping to keep connection alive
        schedulePing()
        
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
            print("Failed to decode message: \(error)")
            print("Message content: \(text)")
        }
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.connectionStatus = .error(error.localizedDescription)
            self.lastError = error.localizedDescription
            self.webSocketTask = nil
            self.urlSession = nil
            
            // Attempt reconnection if we should be connected
            if self.shouldReconnect {
                self.scheduleReconnect()
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
        if summary.callPutRatio >= configService.callRatioThreshold {
            notificationService.sendThresholdNotification(for: summary, thresholdType: .callRatioExceeded)
            return // Don't check premium thresholds if ratio threshold is met
        }
        
        if summary.callPutRatio <= configService.putRatioThreshold {
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

