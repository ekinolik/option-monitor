import Foundation
import UserNotifications
import Combine
import UIKit

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var deviceToken: String?
    
    private let deviceRegistrationService = DeviceRegistrationService.shared
    
    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            } else if granted {
                print("Notification authorization granted")
                // Request device token after authorization
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("Notification authorization denied")
            }
        }
    }
    
    func handleDeviceToken(_ deviceToken: Data) {
        // Convert device token to hex string
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        print("📱 [Notifications] Received device token: \(token)")
        
        // Check if token changed
        let previousToken = self.deviceToken
        
        // Store token
        DispatchQueue.main.async {
            self.deviceToken = token
        }
        
        // Register device with server if authenticated
        let authService = AuthenticationService.shared
        if authService.isAuthenticated {
            // If token changed, re-register
            if previousToken != token {
                print("📱 [Notifications] Device token changed, re-registering")
            }
            deviceRegistrationService.registerDeviceWithRetry(deviceToken: token)
        }
    }
    
}

extension NotificationService: UNUserNotificationCenterDelegate {
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

