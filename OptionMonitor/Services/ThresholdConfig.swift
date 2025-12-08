import Foundation

struct ThresholdConfig: Codable {
    let callRatioThreshold: Double
    let putRatioThreshold: Double
    let callPremiumThreshold: Double
    let putPremiumThreshold: Double
    let totalPremiumThreshold: Double
    
    static let defaults = ThresholdConfig(
        callRatioThreshold: 40.0,
        putRatioThreshold: 0.50,
        callPremiumThreshold: 1000000.0,
        putPremiumThreshold: 500000.0,
        totalPremiumThreshold: 1000000.0
    )
    
    func isEqualToDefaults() -> Bool {
        return callRatioThreshold == ThresholdConfig.defaults.callRatioThreshold &&
               putRatioThreshold == ThresholdConfig.defaults.putRatioThreshold &&
               callPremiumThreshold == ThresholdConfig.defaults.callPremiumThreshold &&
               putPremiumThreshold == ThresholdConfig.defaults.putPremiumThreshold &&
               totalPremiumThreshold == ThresholdConfig.defaults.totalPremiumThreshold
    }
}

