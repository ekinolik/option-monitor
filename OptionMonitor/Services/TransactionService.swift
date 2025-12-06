import Foundation

class TransactionService {
    static let shared = TransactionService()
    private let configService = ConfigService.shared
    
    private init() {}
    
    func fetchTransactions(date: Date, time: Date) async throws -> [Transaction] {
        guard let url = buildTransactionsURL(date: date, time: time) else {
            throw TransactionError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TransactionError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let transactions = try decoder.decode([Transaction].self, from: data)
        
        return transactions
    }
    
    private func buildTransactionsURL(date: Date, time: Date) -> URL? {
        var components = URLComponents()
        
        // Determine scheme and host based on config
        let host = configService.host
        if host.contains("localhost") || host.contains("127.0.0.1") {
            components.scheme = "http"
        } else {
            // Use https for remote hosts
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
            URLQueryItem(name: "time", value: timeString)
        ]
        
        return components.url
    }
}

enum TransactionError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
}

