import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    
    private let service = "com.optionmonitor.session"
    private let account = "sessionID"
    
    private init() {}
    
    func saveSessionID(_ sessionID: String) -> Bool {
        guard let data = sessionID.data(using: .utf8) else {
            return false
        }
        
        // Delete existing item first
        deleteSessionID()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func getSessionID() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let sessionID = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return sessionID
    }
    
    func deleteSessionID() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

