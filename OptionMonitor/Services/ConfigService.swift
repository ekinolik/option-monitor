import Foundation

class ConfigService: ObservableObject {
    static let shared = ConfigService()
    
    private let hostKey = "websocket_host"
    private let portKey = "websocket_port"
    private let notificationsEnabledKey = "notifications_enabled"
    private let selectedDateKey = "selected_date"
    private let tickerKey = "ticker"
    private let useHttpKey = "use_http"
    private let recentTickersKey = "recent_tickers"
    private let notificationThresholdsPrefix = "notification_thresholds_"
    private let highlightThresholdsPrefix = "highlight_thresholds_"
    
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
            // Add to recent tickers
            addToRecentTickers(uppercased)
            // Load thresholds for new ticker
            loadThresholdsForCurrentTicker()
        }
    }
    
    // Notification thresholds (for push notifications) - stored on server and locally
    @Published private(set) var notificationCallRatioThreshold: Double = ThresholdConfig.defaults.callRatioThreshold
    @Published private(set) var notificationPutRatioThreshold: Double = ThresholdConfig.defaults.putRatioThreshold
    @Published private(set) var notificationCallPremiumThreshold: Double = ThresholdConfig.defaults.callPremiumThreshold
    @Published private(set) var notificationPutPremiumThreshold: Double = ThresholdConfig.defaults.putPremiumThreshold
    @Published private(set) var notificationTotalPremiumThreshold: Double = ThresholdConfig.defaults.totalPremiumThreshold
    
    // Highlight thresholds (for row colors) - stored locally only
    @Published private(set) var highlightCallRatioThreshold: Double = ThresholdConfig.defaults.callRatioThreshold
    @Published private(set) var highlightPutRatioThreshold: Double = ThresholdConfig.defaults.putRatioThreshold
    @Published private(set) var highlightCallPremiumThreshold: Double = ThresholdConfig.defaults.callPremiumThreshold
    @Published private(set) var highlightPutPremiumThreshold: Double = ThresholdConfig.defaults.putPremiumThreshold
    @Published private(set) var highlightTotalPremiumThreshold: Double = ThresholdConfig.defaults.totalPremiumThreshold
    
    // Legacy properties for backward compatibility (now map to highlight thresholds)
    var callRatioThreshold: Double { highlightCallRatioThreshold }
    var putRatioThreshold: Double { highlightPutRatioThreshold }
    var callPremiumThreshold: Double { highlightCallPremiumThreshold }
    var putPremiumThreshold: Double { highlightPutPremiumThreshold }
    var totalPremiumThreshold: Double { highlightTotalPremiumThreshold }
    
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
        // Load notification thresholds
        let notificationConfig = getNotificationThresholds(for: ticker)
        notificationCallRatioThreshold = notificationConfig.callRatioThreshold
        notificationPutRatioThreshold = notificationConfig.putRatioThreshold
        notificationCallPremiumThreshold = notificationConfig.callPremiumThreshold
        notificationPutPremiumThreshold = notificationConfig.putPremiumThreshold
        notificationTotalPremiumThreshold = notificationConfig.totalPremiumThreshold
        
        // Load highlight thresholds (always has defaults)
        let highlightConfig = getHighlightThresholds(for: ticker)
        highlightCallRatioThreshold = highlightConfig.callRatioThreshold
        highlightPutRatioThreshold = highlightConfig.putRatioThreshold
        highlightCallPremiumThreshold = highlightConfig.callPremiumThreshold
        highlightPutPremiumThreshold = highlightConfig.putPremiumThreshold
        highlightTotalPremiumThreshold = highlightConfig.totalPremiumThreshold
    }
    
    // MARK: - Notification Thresholds (Server + Local)
    
    func getNotificationThresholds(for ticker: String) -> ThresholdConfig {
        let key = "\(notificationThresholdsPrefix)\(ticker.uppercased())"
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(ThresholdConfig.self, from: data) else {
            return ThresholdConfig.defaults
        }
        return config
    }
    
    func saveNotificationThresholds(for ticker: String, config: ThresholdConfig) {
        let uppercasedTicker = ticker.uppercased()
        let key = "\(notificationThresholdsPrefix)\(uppercasedTicker)"
        
        // Save to local storage
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
        
        // If this is the current ticker, update published properties
        if uppercasedTicker == self.ticker {
            loadThresholdsForCurrentTicker()
        }
    }
    
    func hasNotificationThresholds(for ticker: String) -> Bool {
        let key = "\(notificationThresholdsPrefix)\(ticker.uppercased())"
        return UserDefaults.standard.data(forKey: key) != nil
    }
    
    func clearNotificationThresholds(for ticker: String) {
        let key = "\(notificationThresholdsPrefix)\(ticker.uppercased())"
        UserDefaults.standard.removeObject(forKey: key)
        
        // If this is the current ticker, reload defaults
        if ticker.uppercased() == self.ticker {
            loadThresholdsForCurrentTicker()
        }
    }
    
    // MARK: - Highlight Thresholds (Local Only)
    
    func getHighlightThresholds(for ticker: String) -> ThresholdConfig {
        let key = "\(highlightThresholdsPrefix)\(ticker.uppercased())"
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(ThresholdConfig.self, from: data) else {
            // Always return defaults if not set
            return ThresholdConfig.defaults
        }
        return config
    }
    
    func saveHighlightThresholds(for ticker: String, config: ThresholdConfig) {
        let uppercasedTicker = ticker.uppercased()
        let key = "\(highlightThresholdsPrefix)\(uppercasedTicker)"
        
        // Save to local storage
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
        
        // If this is the current ticker, update published properties
        if uppercasedTicker == self.ticker {
            loadThresholdsForCurrentTicker()
        }
    }
    
    func hasHighlightThresholds(for ticker: String) -> Bool {
        let key = "\(highlightThresholdsPrefix)\(ticker.uppercased())"
        return UserDefaults.standard.data(forKey: key) != nil
    }
    
    func clearHighlightThresholds(for ticker: String) {
        let key = "\(highlightThresholdsPrefix)\(ticker.uppercased())"
        UserDefaults.standard.removeObject(forKey: key)
        
        // If this is the current ticker, reload defaults
        if ticker.uppercased() == self.ticker {
            loadThresholdsForCurrentTicker()
        }
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    
    func getThresholds(for ticker: String) -> ThresholdConfig {
        return getHighlightThresholds(for: ticker)
    }
    
    func saveThresholds(for ticker: String, config: ThresholdConfig) {
        saveHighlightThresholds(for: ticker, config: config)
    }
    
    func hasCustomThresholds(for ticker: String) -> Bool {
        return hasHighlightThresholds(for: ticker)
    }
    
    func clearThresholds(for ticker: String) {
        clearHighlightThresholds(for: ticker)
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
    
    func getRegisterDeviceURL() -> URL? {
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
        components.path = "/auth/register"
        
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
    
    // MARK: - Recent Tickers
    
    func getRecentTickers() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: recentTickersKey),
              let tickers = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tickers
    }
    
    private func addToRecentTickers(_ ticker: String) {
        var recentTickers = getRecentTickers()
        
        // Remove if already exists (to avoid duplicates)
        recentTickers.removeAll { $0.uppercased() == ticker.uppercased() }
        
        // Add to front (most recent first)
        recentTickers.insert(ticker.uppercased(), at: 0)
        
        // Keep only last 5
        if recentTickers.count > 5 {
            recentTickers = Array(recentTickers.prefix(5))
        }
        
        // Save back to UserDefaults
        if let data = try? JSONEncoder().encode(recentTickers) {
            UserDefaults.standard.set(data, forKey: recentTickersKey)
        }
    }
}

