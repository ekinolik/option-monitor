import Foundation

struct StrikeSummary: Codable, Identifiable {
    var id: String { "\(expiration)-\(strike)" }
    let expiration: String
    let strike: Double
    let callPremium: Double
    let putPremium: Double
    let totalPremium: Double
    let callVolume: Int
    let putVolume: Int

    enum CodingKeys: String, CodingKey {
        case expiration, strike
        case callPremium = "call_premium"
        case putPremium = "put_premium"
        case totalPremium = "total_premium"
        case callVolume = "call_volume"
        case putVolume = "put_volume"
    }
}
