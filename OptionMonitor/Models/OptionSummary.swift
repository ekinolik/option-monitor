import Foundation

struct OptionSummary: Codable, Identifiable {
    let id: UUID
    let periodStart: Date
    let periodEnd: Date
    let callPremium: Double
    let putPremium: Double
    let totalPremium: Double
    let callPutRatio: Double
    let callVolume: Int
    let putVolume: Int
    
    enum CodingKeys: String, CodingKey {
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case callPremium = "call_premium"
        case putPremium = "put_premium"
        case totalPremium = "total_premium"
        case callPutRatio = "call_put_ratio"
        case callVolume = "call_volume"
        case putVolume = "put_volume"
    }
    
    // Memberwise initializer for previews and testing
    init(id: UUID = UUID(), periodStart: Date, periodEnd: Date, callPremium: Double, putPremium: Double, totalPremium: Double, callPutRatio: Double, callVolume: Int, putVolume: Int) {
        self.id = id
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.callPremium = callPremium
        self.putPremium = putPremium
        self.totalPremium = totalPremium
        self.callPutRatio = callPutRatio
        self.callVolume = callVolume
        self.putVolume = putVolume
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Generate unique ID for each summary
        self.id = UUID()
        
        // Parse ISO 8601 dates with timezone (try with and without fractional seconds)
        let periodStartString = try container.decode(String.self, forKey: .periodStart)
        let periodEndString = try container.decode(String.self, forKey: .periodEnd)
        
        let startDate: Date
        let endDate: Date
        
        // Try parsing with fractional seconds first, then without
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let formatterWithoutFractional = ISO8601DateFormatter()
        formatterWithoutFractional.formatOptions = [.withInternetDateTime]
        
        if let date = formatterWithFractional.date(from: periodStartString) {
            startDate = date
        } else if let date = formatterWithoutFractional.date(from: periodStartString) {
            startDate = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .periodStart,
                                                  in: container,
                                                  debugDescription: "Invalid date format: \(periodStartString)")
        }
        
        if let date = formatterWithFractional.date(from: periodEndString) {
            endDate = date
        } else if let date = formatterWithoutFractional.date(from: periodEndString) {
            endDate = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .periodEnd,
                                                  in: container,
                                                  debugDescription: "Invalid date format: \(periodEndString)")
        }
        
        self.periodStart = startDate
        self.periodEnd = endDate
        self.callPremium = try container.decode(Double.self, forKey: .callPremium)
        self.putPremium = try container.decode(Double.self, forKey: .putPremium)
        self.totalPremium = try container.decode(Double.self, forKey: .totalPremium)
        self.callPutRatio = try container.decode(Double.self, forKey: .callPutRatio)
        self.callVolume = try container.decode(Int.self, forKey: .callVolume)
        self.putVolume = try container.decode(Int.self, forKey: .putVolume)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        try container.encode(dateFormatter.string(from: periodStart), forKey: .periodStart)
        try container.encode(dateFormatter.string(from: periodEnd), forKey: .periodEnd)
        try container.encode(callPremium, forKey: .callPremium)
        try container.encode(putPremium, forKey: .putPremium)
        try container.encode(totalPremium, forKey: .totalPremium)
        try container.encode(callPutRatio, forKey: .callPutRatio)
        try container.encode(callVolume, forKey: .callVolume)
        try container.encode(putVolume, forKey: .putVolume)
    }
}

