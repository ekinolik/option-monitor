import Foundation

class TransactionService {
    static let shared = TransactionService()
    private let configService = ConfigService.shared
    private let authService = AuthenticationService.shared
    
    private init() {}
    
    func fetchTransactions(date: Date, time: Date) async throws -> [Transaction] {
        guard let url = buildTransactionsURL(date: date, time: time) else {
            throw TransactionError.invalidURL
        }
        
        // Check authentication
        guard authService.isAuthenticated, let sessionID = authService.sessionID else {
            throw TransactionError.authenticationRequired
        }
        
        // Create request with authentication header
        var request = URLRequest(url: url)
        request.setValue("Bearer \(sessionID)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransactionError.invalidResponse
        }
        
        // Handle 401 - authentication required
        if httpResponse.statusCode == 401 {
            print("🔐 [Transaction] 401 error - clearing invalid session")
            // Clear invalid session first
            await MainActor.run {
                authService.handleAuthenticationFailure()
            }
            
            // Trigger re-authentication
            await MainActor.run {
                authService.signInWithApple()
            }
            
            // Wait for authentication to complete (with timeout)
            var retryCount = 0
            while !authService.isAuthenticated && retryCount < 30 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                retryCount += 1
            }
            
            // If authenticated, retry the request
            if authService.isAuthenticated, let newSessionID = authService.sessionID {
                var retryRequest = URLRequest(url: url)
                retryRequest.setValue("Bearer \(newSessionID)", forHTTPHeaderField: "Authorization")
                
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse,
                      retryHttpResponse.statusCode == 200 else {
                    throw TransactionError.invalidResponse
                }
                
                let decoder = JSONDecoder()
                let transactions = try decoder.decode([Transaction].self, from: retryData)
                return transactions
            } else {
                throw TransactionError.authenticationRequired
            }
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TransactionError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let transactions = try decoder.decode([Transaction].self, from: data)
        
        return transactions
    }
    
    private func buildTransactionsURL(date: Date, time: Date) -> URL? {
        var components = URLComponents()
        
        // Determine scheme based on useHttp setting or localhost
        let host = configService.host
        if host.contains("localhost") || host.contains("127.0.0.1") {
            components.scheme = "http"
        } else if configService.useHttp {
            components.scheme = "http"
        } else {
            components.scheme = "https"
        }
        
        components.host = host
        if let port = Int(configService.port), port != 80 && port != 443 {
            components.port = port
        }
        components.path = "/transactions"
        
        // Format date as YYYY-MM-DD (use calendar to get the date component)
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = dateComponents.year,
              let month = dateComponents.month,
              let day = dateComponents.day else {
            return nil
        }
        let dateString = String(format: "%04d-%02d-%02d", year, month, day)
        
        // Format time as HH:MM (use calendar to get the time component)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = timeComponents.hour,
              let minute = timeComponents.minute else {
            return nil
        }
        let timeString = String(format: "%02d:%02d", hour, minute)
        
        components.queryItems = [
            URLQueryItem(name: "date", value: dateString),
            URLQueryItem(name: "time", value: timeString),
            URLQueryItem(name: "ticker", value: configService.ticker.uppercased())
        ]
        
        return components.url
    }
}

enum TransactionError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
    case authenticationRequired
}

