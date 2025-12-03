import Foundation

struct Transaction: Codable, Identifiable {
    let id: UUID
    let eventType: String
    let symbol: String
    let volume: Int
    let accumulatedVolume: Int
    let officialOpenPrice: Double
    let volumeWeightedPrice: Double
    let openPrice: Double
    let highPrice: Double
    let lowPrice: Double
    let closePrice: Double
    let todayVWAP: Double
    let averageTradeSize: Int
    let startTimestamp: Int64
    let endTimestamp: Int64
    
    enum CodingKeys: String, CodingKey {
        case eventType = "ev"
        case symbol = "sym"
        case volume = "v"
        case accumulatedVolume = "av"
        case officialOpenPrice = "op"
        case volumeWeightedPrice = "vw"
        case openPrice = "o"
        case highPrice = "h"
        case lowPrice = "l"
        case closePrice = "c"
        case todayVWAP = "a"
        case averageTradeSize = "z"
        case startTimestamp = "s"
        case endTimestamp = "e"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = UUID()
        self.eventType = try container.decode(String.self, forKey: .eventType)
        self.symbol = try container.decode(String.self, forKey: .symbol)
        self.volume = try container.decode(Int.self, forKey: .volume)
        self.accumulatedVolume = try container.decode(Int.self, forKey: .accumulatedVolume)
        self.officialOpenPrice = try container.decode(Double.self, forKey: .officialOpenPrice)
        self.volumeWeightedPrice = try container.decode(Double.self, forKey: .volumeWeightedPrice)
        self.openPrice = try container.decode(Double.self, forKey: .openPrice)
        self.highPrice = try container.decode(Double.self, forKey: .highPrice)
        self.lowPrice = try container.decode(Double.self, forKey: .lowPrice)
        self.closePrice = try container.decode(Double.self, forKey: .closePrice)
        self.todayVWAP = try container.decode(Double.self, forKey: .todayVWAP)
        self.averageTradeSize = try container.decode(Int.self, forKey: .averageTradeSize)
        self.startTimestamp = try container.decode(Int64.self, forKey: .startTimestamp)
        self.endTimestamp = try container.decode(Int64.self, forKey: .endTimestamp)
    }
    
    // Computed properties for dates
    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startTimestamp) / 1000.0)
    }
    
    var endDate: Date {
        Date(timeIntervalSince1970: TimeInterval(endTimestamp) / 1000.0)
    }
    
    // Parse option symbol to extract details
    var optionDetails: OptionSymbolDetails? {
        OptionSymbolDetails.parse(symbol)
    }
}

struct OptionSymbolDetails {
    let underlying: String
    let expiration: String
    let strike: Double
    let optionType: String // "CALL" or "PUT"
    
    static func parse(_ symbol: String) -> OptionSymbolDetails? {
        // Format: O:AAPL260116C00250000
        // O: prefix, then underlying, expiration (YYMMDD), type (C/P), strike (8 digits)
        // Strike is stored as integer (e.g., 250.00 = 00250000, which is 250000 / 1000)
        
        guard symbol.hasPrefix("O:") else { return nil }
        let withoutPrefix = String(symbol.dropFirst(2))
        
        // Find the C or P that comes after a 6-digit date pattern
        // We need to work backwards from the end since strike is always 8 digits
        guard withoutPrefix.count >= 15 else { return nil } // At least: ticker(4) + date(6) + type(1) + strike(8) = 19
        
        // Strike is always the last 8 digits
        // Format: strike stored as integer with 2 decimal places (e.g., 250.00 = 25000)
        // So divide by 100 to get actual strike price
        let strikePart = String(withoutPrefix.suffix(8))
        guard let strikeInt = Int(strikePart) else { return nil }
        let strikePrice = Double(strikeInt) / 1000.0
        
        // Type is the character before the strike (9th from end)
        let typeIndex = withoutPrefix.index(withoutPrefix.endIndex, offsetBy: -9)
        let typeChar = withoutPrefix[typeIndex]
        guard typeChar == "C" || typeChar == "P" else { return nil }
        
        // Everything before the type is ticker + date
        let beforeType = String(withoutPrefix[..<typeIndex])
        guard beforeType.count >= 6 else { return nil }
        
        // Last 6 characters of beforeType are the date
        let expirationPart = String(beforeType.suffix(6))
        let underlying = String(beforeType.dropLast(6))
        
        // Parse expiration date (YYMMDD)
        guard expirationPart.count == 6,
              let year = Int(expirationPart.prefix(2)),
              let month = Int(expirationPart.dropFirst(2).prefix(2)),
              let day = Int(expirationPart.suffix(2)) else {
            return nil
        }
        
        let fullYear = 2000 + year
        let expiration = String(format: "%04d-%02d-%02d", fullYear, month, day)
        let optionType = typeChar == "C" ? "CALL" : "PUT"
        
        return OptionSymbolDetails(
            underlying: underlying,
            expiration: expiration,
            strike: strikePrice,
            optionType: optionType
        )
    }
}

