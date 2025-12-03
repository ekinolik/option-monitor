import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            } else if granted {
                print("Notification authorization granted")
            } else {
                print("Notification authorization denied")
            }
        }
    }
    
    func sendThresholdNotification(for summary: OptionSummary, thresholdType: ThresholdType) {
        let content = UNMutableNotificationContent()
        
        switch thresholdType {
        case .callRatioExceeded:
            content.title = "Call Ratio Alert"
            content.body = String(format: "Call/Put ratio %.2f exceeded threshold (%.2f). Total premium: %@",
                                summary.callPutRatio,
                                ConfigService.shared.callRatioThreshold,
                                formatCurrency(summary.totalPremium))
            content.sound = .default
            content.badge = 1
            
        case .putRatioBelow:
            content.title = "Put Ratio Alert"
            content.body = String(format: "Call/Put ratio %.2f below threshold (%.2f). Total premium: %@",
                                summary.callPutRatio,
                                ConfigService.shared.putRatioThreshold,
                                formatCurrency(summary.totalPremium))
            content.sound = .default
            content.badge = 1
            
        case .callPremiumExceeded:
            content.title = "Call Premium Alert"
            content.body = String(format: "Call premium %@ exceeded threshold (%@). Ratio: %.2f",
                                formatCurrency(summary.callPremium),
                                formatCurrency(ConfigService.shared.callPremiumThreshold),
                                summary.callPutRatio)
            content.sound = .default
            content.badge = 1
            
        case .putPremiumExceeded:
            content.title = "Put Premium Alert"
            content.body = String(format: "Put premium %@ exceeded threshold (%@). Ratio: %.2f",
                                formatCurrency(summary.putPremium),
                                formatCurrency(ConfigService.shared.putPremiumThreshold),
                                summary.callPutRatio)
            content.sound = .default
            content.badge = 1
            
        case .bothPremiumsExceeded:
            content.title = "Premium Alert"
            content.body = String(format: "Both premiums exceeded thresholds. Call: %@, Put: %@. Ratio: %.2f",
                                formatCurrency(summary.callPremium),
                                formatCurrency(summary.putPremium),
                                summary.callPutRatio)
            content.sound = .default
            content.badge = 1
        }
        
        // Add user info for potential deep linking
        content.userInfo = [
            "summary_id": summary.id.uuidString,
            "threshold_type": thresholdType.rawValue
        ]
        
        // Create trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "\(summary.id.uuidString)-\(thresholdType.rawValue)",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

enum ThresholdType: String {
    case callRatioExceeded = "call_ratio_exceeded"
    case putRatioBelow = "put_ratio_below"
    case callPremiumExceeded = "call_premium_exceeded"
    case putPremiumExceeded = "put_premium_exceeded"
    case bothPremiumsExceeded = "both_premiums_exceeded"
}

