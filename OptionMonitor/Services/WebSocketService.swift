import Foundation
import Combine

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
    private let configService = ConfigService.shared
    
    init() {
        // Listen for config changes
        Publishers.CombineLatest(configService.$host, configService.$port)
            .sink { [weak self] _, _ in
                // If connected, reconnect with new config
                if case .connected = self?.connectionStatus {
                    self?.disconnect()
                    self?.connect()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func connect() {
        guard case .disconnected = connectionStatus else {
            return // Already connecting or connected
        }
        
        guard let url = configService.getWebSocketURL() else {
            connectionStatus = .error("Invalid WebSocket URL")
            lastError = "Invalid WebSocket URL. Please check host and port settings."
            return
        }
        
        connectionStatus = .connecting
        shouldReconnect = true
        
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
}

