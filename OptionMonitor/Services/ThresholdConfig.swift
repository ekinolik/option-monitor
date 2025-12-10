import Foundation

struct ThresholdConfig: Codable {
    let callRatioThreshold: Double
    let putRatioThreshold: Double
    let callPremiumThreshold: Double
    let putPremiumThreshold: Double
    let totalPremiumThreshold: Double
    let disabled: Bool? // Optional for backward compatibility, nil means enabled (disabled=false)
    
    static let defaults = ThresholdConfig(
        callRatioThreshold: 40.0,
        putRatioThreshold: 0.50,
        callPremiumThreshold: 1000000.0,
        putPremiumThreshold: 500000.0,
        totalPremiumThreshold: 1000000.0,
        disabled: false
    )
    
    init(callRatioThreshold: Double, putRatioThreshold: Double, callPremiumThreshold: Double, putPremiumThreshold: Double, totalPremiumThreshold: Double, disabled: Bool? = nil) {
        self.callRatioThreshold = callRatioThreshold
        self.putRatioThreshold = putRatioThreshold
        self.callPremiumThreshold = callPremiumThreshold
        self.putPremiumThreshold = putPremiumThreshold
        self.totalPremiumThreshold = totalPremiumThreshold
        self.disabled = disabled
    }
    
    func isEqualToDefaults() -> Bool {
        return callRatioThreshold == ThresholdConfig.defaults.callRatioThreshold &&
               putRatioThreshold == ThresholdConfig.defaults.putRatioThreshold &&
               callPremiumThreshold == ThresholdConfig.defaults.callPremiumThreshold &&
               putPremiumThreshold == ThresholdConfig.defaults.putPremiumThreshold &&
               totalPremiumThreshold == ThresholdConfig.defaults.totalPremiumThreshold
    }
}

