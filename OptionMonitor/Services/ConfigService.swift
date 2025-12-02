import Foundation

class ConfigService: ObservableObject {
    static let shared = ConfigService()
    
    private let hostKey = "websocket_host"
    private let portKey = "websocket_port"
    
    private let defaultHost = "localhost"
    private let defaultPort = "8080"
    
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
    
    private init() {
        self.host = UserDefaults.standard.string(forKey: hostKey) ?? defaultHost
        self.port = UserDefaults.standard.string(forKey: portKey) ?? defaultPort
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
    }
}

