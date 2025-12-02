import Foundation

class ConfigService: ObservableObject {
    static let shared = ConfigService()
    
    private let hostKey = "websocket_host"
    private let portKey = "websocket_port"
    private let callRatioThresholdKey = "call_ratio_threshold"
    private let putRatioThresholdKey = "put_ratio_threshold"
    
    private let defaultHost = "localhost"
    private let defaultPort = "8080"
    private let defaultCallRatioThreshold: Double = 1.5
    private let defaultPutRatioThreshold: Double = 0.5
    
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
    }
    
    func getWebSocketURL() -> URL? {
        var components = URLComponents()
        components.scheme = "ws"
        components.host = host
        components.port = Int(port)
        components.path = "/analyze"
        return components.url
    }
    
    func resetToDefaults() {
        host = defaultHost
        port = defaultPort
        callRatioThreshold = defaultCallRatioThreshold
        putRatioThreshold = defaultPutRatioThreshold
    }
}

