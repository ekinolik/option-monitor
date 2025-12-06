import Foundation

class ConfigService: ObservableObject {
    static let shared = ConfigService()
    
    private let hostKey = "websocket_host"
    private let portKey = "websocket_port"
    private let callRatioThresholdKey = "call_ratio_threshold"
    private let putRatioThresholdKey = "put_ratio_threshold"
    private let callPremiumThresholdKey = "call_premium_threshold"
    private let putPremiumThresholdKey = "put_premium_threshold"
    private let totalPremiumThresholdKey = "total_premium_threshold"
    private let notificationsEnabledKey = "notifications_enabled"
    private let selectedDateKey = "selected_date"
    
    private let defaultHost = "localhost"
    private let defaultPort = "8080"
    private let defaultCallRatioThreshold: Double = 1.5
    private let defaultPutRatioThreshold: Double = 0.5
    private let defaultCallPremiumThreshold: Double = 1000000.0
    private let defaultPutPremiumThreshold: Double = 50000.0
    private let defaultTotalPremiumThreshold: Double = 1000000.0
    private let defaultNotificationsEnabled: Bool = true
    
    @Published var host: String {
        didSet {
            UserDefaults.standard.set(host, forKey: hostKey)
        }
    }
    
    @Published var port: String {
        didSet {
            UserDefaults.standard.set(port, forKey: portKey)
        }
    }
    
    @Published var callRatioThreshold: Double {
        didSet {
            UserDefaults.standard.set(callRatioThreshold, forKey: callRatioThresholdKey)
        }
    }
    
    @Published var putRatioThreshold: Double {
        didSet {
            UserDefaults.standard.set(putRatioThreshold, forKey: putRatioThresholdKey)
        }
    }
    
    @Published var callPremiumThreshold: Double {
        didSet {
            UserDefaults.standard.set(callPremiumThreshold, forKey: callPremiumThresholdKey)
        }
    }
    
    @Published var putPremiumThreshold: Double {
        didSet {
            UserDefaults.standard.set(putPremiumThreshold, forKey: putPremiumThresholdKey)
        }
    }
    
    @Published var totalPremiumThreshold: Double {
        didSet {
            UserDefaults.standard.set(totalPremiumThreshold, forKey: totalPremiumThresholdKey)
        }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: notificationsEnabledKey)
        }
    }
    
    @Published var selectedDate: Date {
        didSet {
            UserDefaults.standard.set(selectedDate, forKey: selectedDateKey)
        }
    }
    
    private init() {
        self.host = UserDefaults.standard.string(forKey: hostKey) ?? defaultHost
        self.port = UserDefaults.standard.string(forKey: portKey) ?? defaultPort
        
        // Load thresholds, defaulting if not set or invalid
        if UserDefaults.standard.object(forKey: callRatioThresholdKey) != nil {
            self.callRatioThreshold = UserDefaults.standard.double(forKey: callRatioThresholdKey)
        } else {
            self.callRatioThreshold = defaultCallRatioThreshold
        }
        
        if UserDefaults.standard.object(forKey: putRatioThresholdKey) != nil {
            self.putRatioThreshold = UserDefaults.standard.double(forKey: putRatioThresholdKey)
        } else {
            self.putRatioThreshold = defaultPutRatioThreshold
        }
        
        if UserDefaults.standard.object(forKey: callPremiumThresholdKey) != nil {
            self.callPremiumThreshold = UserDefaults.standard.double(forKey: callPremiumThresholdKey)
        } else {
            self.callPremiumThreshold = defaultCallPremiumThreshold
        }
        
        if UserDefaults.standard.object(forKey: putPremiumThresholdKey) != nil {
            self.putPremiumThreshold = UserDefaults.standard.double(forKey: putPremiumThresholdKey)
        } else {
            self.putPremiumThreshold = defaultPutPremiumThreshold
        }
        
        if UserDefaults.standard.object(forKey: totalPremiumThresholdKey) != nil {
            self.totalPremiumThreshold = UserDefaults.standard.double(forKey: totalPremiumThresholdKey)
        } else {
            self.totalPremiumThreshold = defaultTotalPremiumThreshold
        }
        
        self.notificationsEnabled = UserDefaults.standard.object(forKey: notificationsEnabledKey) as? Bool ?? defaultNotificationsEnabled
        
        // Load selected date, defaulting to today if not set
        if let savedDate = UserDefaults.standard.object(forKey: selectedDateKey) as? Date {
            self.selectedDate = savedDate
        } else {
            self.selectedDate = Date()
        }
    }
    
    func getWebSocketURL() -> URL? {
        var components = URLComponents()
        
        // Use wss (WebSocket Secure) for HTTPS, ws for localhost
        if host.contains("localhost") || host.contains("127.0.0.1") {
            components.scheme = "ws"
        } else {
            components.scheme = "wss"
        }
        
        components.host = host
        // Only set port if it's not the default for the scheme
        if let portInt = Int(port) {
            let defaultPort = components.scheme == "wss" ? 443 : 80
            if portInt != defaultPort {
                components.port = portInt
            }
        }
        components.path = "/analyze"
        
        // Add date query parameter in YYYY-MM-DD format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: selectedDate)
        components.queryItems = [URLQueryItem(name: "date", value: dateString)]
        
        return components.url
    }
    
    func resetToDefaults() {
        host = defaultHost
        port = defaultPort
        callRatioThreshold = defaultCallRatioThreshold
        putRatioThreshold = defaultPutRatioThreshold
        callPremiumThreshold = defaultCallPremiumThreshold
        putPremiumThreshold = defaultPutPremiumThreshold
        totalPremiumThreshold = defaultTotalPremiumThreshold
    }
}

