import Foundation

class StrikeService {
    static let shared = StrikeService()
    private let configService = ConfigService.shared
    private let authService = AuthenticationService.shared

    private init() {}

    func fetchStrikes(date: Date) async throws -> [StrikeSummary] {
        guard let url = buildStrikesURL(date: date) else {
            throw StrikeError.invalidURL
        }

        guard authService.isAuthenticated, let sessionID = authService.sessionID else {
            throw StrikeError.authenticationRequired
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(sessionID)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StrikeError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            print("🔐 [Strike] 401 error - clearing invalid session")
            await MainActor.run {
                authService.handleAuthenticationFailure()
            }

            await MainActor.run {
                authService.signInWithApple()
            }

            var retryCount = 0
            while !authService.isAuthenticated && retryCount < 30 {
                try await Task.sleep(nanoseconds: 100_000_000)
                retryCount += 1
            }

            if authService.isAuthenticated, let newSessionID = authService.sessionID {
                var retryRequest = URLRequest(url: url)
                retryRequest.setValue("Bearer \(newSessionID)", forHTTPHeaderField: "Authorization")

                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)

                guard let retryHttpResponse = retryResponse as? HTTPURLResponse,
                      retryHttpResponse.statusCode == 200 else {
                    throw StrikeError.invalidResponse
                }

                let decoder = JSONDecoder()
                return try decoder.decode([StrikeSummary].self, from: retryData)
            } else {
                throw StrikeError.authenticationRequired
            }
        }

        guard httpResponse.statusCode == 200 else {
            throw StrikeError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode([StrikeSummary].self, from: data)
    }

    private func buildStrikesURL(date: Date) -> URL? {
        var components = URLComponents()

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
        components.path = "/strikes"

        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = dateComponents.year,
              let month = dateComponents.month,
              let day = dateComponents.day else {
            return nil
        }
        let dateString = String(format: "%04d-%02d-%02d", year, month, day)

        components.queryItems = [
            URLQueryItem(name: "date", value: dateString),
            URLQueryItem(name: "ticker", value: configService.ticker.uppercased())
        ]

        return components.url
    }
}

enum StrikeError: Error {
    case invalidURL
    case invalidResponse
    case authenticationRequired
}
