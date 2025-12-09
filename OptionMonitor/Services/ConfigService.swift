import Foundation

class ConfigService: ObservableObject {
    static let shared = ConfigService()
    
    private let hostKey = "websocket_host"
    private let portKey = "websocket_port"
    private let notificationsEnabledKey = "notifications_enabled"
    private let selectedDateKey = "selected_date"
    private let tickerKey = "ticker"
    private let useHttpKey = "use_http"
    private let thresholdsPrefix = "thresholds_"
    
    private let defaultHost = "localhost"
    private let defaultPort = "8080"
    private let defaultNotificationsEnabled: Bool = true
    private let defaultTicker = "AAPL"
    private let defaultUseHttp: Bool = false
    
    // Current ticker for threshold access
    @Published var ticker: String {
        didSet {
            let uppercased = ticker.uppercased()
            UserDefaults.standard.set(uppercased, forKey: tickerKey)
            // Load thresholds for new ticker
            loadThresholdsForCurrentTicker()
        }
    }
    
    // Computed properties that read from current ticker's thresholds
    @Published private(set) var callRatioThreshold: Double = ThresholdConfig.defaults.callRatioThreshold
    @Published private(set) var putRatioThreshold: Double = ThresholdConfig.defaults.putRatioThreshold
    @Published private(set) var callPremiumThreshold: Double = ThresholdConfig.defaults.callPremiumThreshold
    @Published private(set) var putPremiumThreshold: Double = ThresholdConfig.defaults.putPremiumThreshold
    @Published private(set) var totalPremiumThreshold: Double = ThresholdConfig.defaults.totalPremiumThreshold
    
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
    
    @Published var useHttp: Bool {
        didSet {
            UserDefaults.standard.set(useHttp, forKey: useHttpKey)
        }
    }
    
    var isDevBundle: Bool {
        Bundle.main.bundleIdentifier == "io.chaossignal.optionmonitor.dev"
    }
    
    private init() {
        self.host = UserDefaults.standard.string(forKey: hostKey) ?? defaultHost
        self.port = UserDefaults.standard.string(forKey: portKey) ?? defaultPort
        self.notificationsEnabled = UserDefaults.standard.object(forKey: notificationsEnabledKey) as? Bool ?? defaultNotificationsEnabled
        self.useHttp = UserDefaults.standard.object(forKey: useHttpKey) as? Bool ?? defaultUseHttp
        
        // Load selected date, defaulting to today if not set
        if let savedDate = UserDefaults.standard.object(forKey: selectedDateKey) as? Date {
            self.selectedDate = savedDate
        } else {
            self.selectedDate = Date()
        }
        
        // Load ticker, defaulting to AAPL if not set
        if let savedTicker = UserDefaults.standard.string(forKey: tickerKey), !savedTicker.isEmpty {
            self.ticker = savedTicker.uppercased()
        } else {
            self.ticker = defaultTicker
        }
        
        // Load thresholds for current ticker
        loadThresholdsForCurrentTicker()
    }
    
    private func loadThresholdsForCurrentTicker() {
        let config = getThresholds(for: ticker)
        callRatioThreshold = config.callRatioThreshold
        putRatioThreshold = config.putRatioThreshold
        callPremiumThreshold = config.callPremiumThreshold
        putPremiumThreshold = config.putPremiumThreshold
        totalPremiumThreshold = config.totalPremiumThreshold
    }
    
    func getThresholds(for ticker: String) -> ThresholdConfig {
        let key = "\(thresholdsPrefix)\(ticker.uppercased())"
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(ThresholdConfig.self, from: data) else {
            return ThresholdConfig.defaults
        }
        return config
    }
    
    func saveThresholds(for ticker: String, config: ThresholdConfig) {
        let uppercasedTicker = ticker.uppercased()
        let key = "\(thresholdsPrefix)\(uppercasedTicker)"
        
        // Only save if different from defaults
        if config.isEqualToDefaults() {
            // Remove saved thresholds if they match defaults
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            // Save custom thresholds
            if let data = try? JSONEncoder().encode(config) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
        
        // If this is the current ticker, update published properties
        if uppercasedTicker == self.ticker {
            loadThresholdsForCurrentTicker()
        }
    }
    
    func hasCustomThresholds(for ticker: String) -> Bool {
        let key = "\(thresholdsPrefix)\(ticker.uppercased())"
        return UserDefaults.standard.data(forKey: key) != nil
    }
    
    func clearThresholds(for ticker: String) {
        let key = "\(thresholdsPrefix)\(ticker.uppercased())"
        UserDefaults.standard.removeObject(forKey: key)
        
        // If this is the current ticker, reload defaults
        if ticker.uppercased() == self.ticker {
            loadThresholdsForCurrentTicker()
        }
    }
    
    func getWebSocketURL() -> URL? {
        var components = URLComponents()
        
        // Determine scheme based on useHttp setting or localhost
        if host.contains("localhost") || host.contains("127.0.0.1") {
            components.scheme = "ws"
        } else if useHttp {
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
        
        // Add date and ticker query parameters
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: selectedDate)
        components.queryItems = [
            URLQueryItem(name: "date", value: dateString),
            URLQueryItem(name: "ticker", value: ticker.uppercased())
        ]
        
        return components.url
    }
    
    func getAuthURL() -> URL? {
        var components = URLComponents()
        
        // Determine scheme based on useHttp setting or localhost
        if host.contains("localhost") || host.contains("127.0.0.1") {
            components.scheme = "http"
        } else if useHttp {
            components.scheme = "http"
        } else {
            components.scheme = "https"
        }
        
        components.host = host
        // Only set port if it's not the default for the scheme
        if let portInt = Int(port) {
            let defaultPort = components.scheme == "https" ? 443 : 80
            if portInt != defaultPort {
                components.port = portInt
            }
        }
        components.path = "/auth/login"
        
        return components.url
    }
    
    func getNotificationsURL() -> URL? {
        var components = URLComponents()
        
        // Determine scheme based on useHttp setting or localhost
        if host.contains("localhost") || host.contains("127.0.0.1") {
            components.scheme = "http"
        } else if useHttp {
            components.scheme = "http"
        } else {
            components.scheme = "https"
        }
        
        components.host = host
        // Only set port if it's not the default for the scheme
        if let portInt = Int(port) {
            let defaultPort = components.scheme == "https" ? 443 : 80
            if portInt != defaultPort {
                components.port = portInt
            }
        }
        components.path = "/notifications"
        
        return components.url
    }
    
    func getNotificationsURL(ticker: String) -> URL? {
        var components = URLComponents()
        
        // Determine scheme based on useHttp setting or localhost
        if host.contains("localhost") || host.contains("127.0.0.1") {
            components.scheme = "http"
        } else if useHttp {
            components.scheme = "http"
        } else {
            components.scheme = "https"
        }
        
        components.host = host
        // Only set port if it's not the default for the scheme
        if let portInt = Int(port) {
            let defaultPort = components.scheme == "https" ? 443 : 80
            if portInt != defaultPort {
                components.port = portInt
            }
        }
        components.path = "/notifications"
        
        // Add ticker query parameter for GET requests
        components.queryItems = [
            URLQueryItem(name: "ticker", value: ticker.uppercased())
        ]
        
        return components.url
    }
    
    func resetToDefaults() {
        host = defaultHost
        port = defaultPort
        ticker = defaultTicker
        useHttp = defaultUseHttp
        // Thresholds will be reloaded automatically via loadThresholdsForCurrentTicker()
    }
}

