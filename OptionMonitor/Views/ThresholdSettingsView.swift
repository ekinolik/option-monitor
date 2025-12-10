import SwiftUI

struct ThresholdSettingsView: View {
    @ObservedObject private var configService = ConfigService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Notification threshold state
    @State private var notificationSectionExpanded: Bool = false
    @State private var notificationCallRatioText: String = ""
    @State private var notificationPutRatioText: String = ""
    @State private var notificationCallPremiumText: String = ""
    @State private var notificationPutPremiumText: String = ""
    @State private var notificationTotalPremiumText: String = ""
    @State private var notificationEnabled: Bool = true
    @State private var showNotificationFields: Bool = false
    @State private var checkingServerForNotificationThresholds: Bool = false
    
    // Highlight threshold state
    @State private var highlightSectionExpanded: Bool = false
    @State private var highlightCallRatioText: String = ""
    @State private var highlightPutRatioText: String = ""
    @State private var highlightCallPremiumText: String = ""
    @State private var highlightPutPremiumText: String = ""
    @State private var highlightTotalPremiumText: String = ""
    
    private var currentTicker: String {
        configService.ticker
    }
    
    @State private var hasNotificationThresholds: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("Current Ticker")) {
                Text("\(currentTicker)")
                    .font(.headline)
            }
            
            // Notification Thresholds Section
            DisclosureGroup(isExpanded: $notificationSectionExpanded) {
                if checkingServerForNotificationThresholds {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking server...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if showNotificationFields {
                    notificationThresholdFields
                } else {
                    Button("Create Notification Thresholds") {
                        showNotificationFields = true
                        loadNotificationThresholds()
                    }
                    .foregroundColor(.blue)
                }
            } label: {
                HStack {
                    Text("Notification Thresholds")
                        .font(.headline)
                    Spacer()
                    if hasNotificationThresholds {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Highlight Thresholds Section
            DisclosureGroup(isExpanded: $highlightSectionExpanded) {
                highlightThresholdFields
            } label: {
                Text("Highlight Thresholds")
                    .font(.headline)
            }
        }
        .navigationTitle("Threshold Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save All") {
                    saveAllSettings()
                }
                .disabled(!isValidInput)
            }
        }
        .onAppear {
            loadCurrentThresholds()
            checkNotificationThresholds()
        }
        .onChange(of: configService.ticker) { _ in
            loadCurrentThresholds()
            checkNotificationThresholds()
        }
    }
    
    private var notificationThresholdFields: some View {
        VStack(spacing: 16) {
            Group {
                Text("Ratio Thresholds")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text("Call Ratio Threshold")
                        .frame(minWidth: 220, alignment: .leading)
                    TextField("40", text: $notificationCallRatioText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Put Ratio Threshold")
                    TextField("0.50", text: $notificationPutRatioText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Ratio Premium Threshold")
                        .frame(minWidth: 220, alignment: .leading)
                    TextField("1000000", text: $notificationTotalPremiumText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Group {
                Text("Premium Thresholds")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                
                HStack {
                    Text("Call Premium Threshold")
                    TextField("1000000", text: $notificationCallPremiumText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Put Premium Threshold")
                    TextField("500000", text: $notificationPutPremiumText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Toggle("Enabled", isOn: $notificationEnabled)
                .padding(.top, 8)
            
            Button("Use Highlight Thresholds") {
                copyHighlightToNotification()
            }
            .foregroundColor(.blue)
            .padding(.top, 8)
            
            Button("Save Notifications") {
                saveNotificationThresholds()
            }
            .foregroundColor(.blue)
            .padding(.top, 8)
            .disabled(!isNotificationInputValid)
        }
        .padding(.vertical, 8)
    }
    
    private var highlightThresholdFields: some View {
        VStack(spacing: 16) {
            Group {
                Text("Ratio Thresholds")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text("Call Ratio Threshold")
                        .frame(minWidth: 220, alignment: .leading)
                    TextField("40", text: $highlightCallRatioText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Put Ratio Threshold")
                    TextField("0.50", text: $highlightPutRatioText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Ratio Premium Threshold")
                        .frame(minWidth: 220, alignment: .leading)
                    TextField("1000000", text: $highlightTotalPremiumText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                Text("Ratio threshold highlighting only applies if total premium ≥ ratio premium threshold.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Group {
                Text("Premium Thresholds")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                
                HStack {
                    Text("Call Premium Threshold")
                    TextField("1000000", text: $highlightCallPremiumText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Put Premium Threshold")
                    TextField("500000", text: $highlightPutPremiumText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                Text("If call ratio thresholds are not met, rows with both call premium ≥ threshold AND put premium ≥ threshold will be highlighted yellow.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if hasNotificationThresholds {
                Button("Use Notification Thresholds") {
                    copyNotificationToHighlight()
                }
                .foregroundColor(.blue)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func loadCurrentThresholds() {
        // Load notification thresholds if they exist
        if hasNotificationThresholds {
            showNotificationFields = true
            loadNotificationThresholds()
        } else {
            showNotificationFields = false
        }
        
        // Always load highlight thresholds (with defaults)
        loadHighlightThresholds()
    }
    
    private func checkNotificationThresholds() {
        // First check local storage
        let localHasThresholds = configService.hasNotificationThresholds(for: currentTicker)
        
        if localHasThresholds {
            hasNotificationThresholds = true
            showNotificationFields = true
            loadNotificationThresholds()
            return
        }
        
        // If not found locally, check server
        checkingServerForNotificationThresholds = true
        Task {
            let thresholdService = NotificationThresholdService.shared
            do {
                if let serverConfig = try await thresholdService.fetchThresholds(ticker: currentTicker) {
                    // Found on server - save locally and update UI
                    await MainActor.run {
                        configService.saveNotificationThresholds(for: currentTicker, config: serverConfig)
                        hasNotificationThresholds = true
                        showNotificationFields = true
                        checkingServerForNotificationThresholds = false
                        // Load the thresholds into the fields
                        loadNotificationThresholds()
                    }
                } else {
                    // Not found on server either
                    await MainActor.run {
                        hasNotificationThresholds = false
                        showNotificationFields = false
                        checkingServerForNotificationThresholds = false
                    }
                }
            } catch {
                // Error checking server - assume no thresholds
                await MainActor.run {
                    hasNotificationThresholds = false
                    showNotificationFields = false
                    checkingServerForNotificationThresholds = false
                }
            }
        }
    }
    
    private func loadNotificationThresholds() {
        let config = configService.getNotificationThresholds(for: currentTicker)
        notificationCallRatioText = String(format: "%.2f", config.callRatioThreshold)
        notificationPutRatioText = String(format: "%.2f", config.putRatioThreshold)
        notificationCallPremiumText = String(format: "%.0f", config.callPremiumThreshold)
        notificationPutPremiumText = String(format: "%.0f", config.putPremiumThreshold)
        notificationTotalPremiumText = String(format: "%.0f", config.totalPremiumThreshold)
        notificationEnabled = !(config.disabled ?? false) // enabled = !disabled, default to enabled if nil
    }
    
    private func loadHighlightThresholds() {
        let config = configService.getHighlightThresholds(for: currentTicker)
        highlightCallRatioText = String(format: "%.2f", config.callRatioThreshold)
        highlightPutRatioText = String(format: "%.2f", config.putRatioThreshold)
        highlightCallPremiumText = String(format: "%.0f", config.callPremiumThreshold)
        highlightPutPremiumText = String(format: "%.0f", config.putPremiumThreshold)
        highlightTotalPremiumText = String(format: "%.0f", config.totalPremiumThreshold)
    }
    
    private func copyHighlightToNotification() {
        notificationCallRatioText = highlightCallRatioText
        notificationPutRatioText = highlightPutRatioText
        notificationCallPremiumText = highlightCallPremiumText
        notificationPutPremiumText = highlightPutPremiumText
        notificationTotalPremiumText = highlightTotalPremiumText
    }
    
    private func copyNotificationToHighlight() {
        highlightCallRatioText = notificationCallRatioText
        highlightPutRatioText = notificationPutRatioText
        highlightCallPremiumText = notificationCallPremiumText
        highlightPutPremiumText = notificationPutPremiumText
        highlightTotalPremiumText = notificationTotalPremiumText
    }
    
    private var isValidInput: Bool {
        // Check notification thresholds if fields are shown
        let notificationValid = !showNotificationFields || (
            Double(notificationCallRatioText.trimmingCharacters(in: .whitespaces)) != nil &&
            Double(notificationPutRatioText.trimmingCharacters(in: .whitespaces)) != nil &&
            Double(notificationCallPremiumText.trimmingCharacters(in: .whitespaces)) != nil &&
            Double(notificationPutPremiumText.trimmingCharacters(in: .whitespaces)) != nil &&
            Double(notificationTotalPremiumText.trimmingCharacters(in: .whitespaces)) != nil
        )
        
        // Check highlight thresholds (always required)
        let highlightValid = 
            Double(highlightCallRatioText.trimmingCharacters(in: .whitespaces)) != nil &&
            Double(highlightPutRatioText.trimmingCharacters(in: .whitespaces)) != nil &&
            Double(highlightCallPremiumText.trimmingCharacters(in: .whitespaces)) != nil &&
            Double(highlightPutPremiumText.trimmingCharacters(in: .whitespaces)) != nil &&
            Double(highlightTotalPremiumText.trimmingCharacters(in: .whitespaces)) != nil
        
        return notificationValid && highlightValid
    }
    
    private var isNotificationInputValid: Bool {
        guard showNotificationFields else { return false }
        return Double(notificationCallRatioText.trimmingCharacters(in: .whitespaces)) != nil &&
               Double(notificationPutRatioText.trimmingCharacters(in: .whitespaces)) != nil &&
               Double(notificationCallPremiumText.trimmingCharacters(in: .whitespaces)) != nil &&
               Double(notificationPutPremiumText.trimmingCharacters(in: .whitespaces)) != nil &&
               Double(notificationTotalPremiumText.trimmingCharacters(in: .whitespaces)) != nil
    }
    
    private func saveNotificationThresholds() {
        guard isNotificationInputValid else { return }
        
        guard let callRatio = Double(notificationCallRatioText.trimmingCharacters(in: .whitespaces)),
              let putRatio = Double(notificationPutRatioText.trimmingCharacters(in: .whitespaces)),
              let callPremium = Double(notificationCallPremiumText.trimmingCharacters(in: .whitespaces)),
              let putPremium = Double(notificationPutPremiumText.trimmingCharacters(in: .whitespaces)),
              let totalPremium = Double(notificationTotalPremiumText.trimmingCharacters(in: .whitespaces)) else {
            return
        }
        
        let notificationConfig = ThresholdConfig(
            callRatioThreshold: callRatio,
            putRatioThreshold: putRatio,
            callPremiumThreshold: callPremium,
            putPremiumThreshold: putPremium,
            totalPremiumThreshold: totalPremium,
            disabled: !notificationEnabled
        )
        
        // Save locally
        configService.saveNotificationThresholds(for: currentTicker, config: notificationConfig)
        
        // Save to server in background
        Task {
            await NotificationThresholdService.shared.saveThresholds(ticker: currentTicker, config: notificationConfig, disabled: !notificationEnabled)
        }
    }
    
    private func saveAllSettings() {
        guard isValidInput else { return }
        
        // Save notification thresholds if fields are shown
        if showNotificationFields {
            guard let callRatio = Double(notificationCallRatioText.trimmingCharacters(in: .whitespaces)),
                  let putRatio = Double(notificationPutRatioText.trimmingCharacters(in: .whitespaces)),
                  let callPremium = Double(notificationCallPremiumText.trimmingCharacters(in: .whitespaces)),
                  let putPremium = Double(notificationPutPremiumText.trimmingCharacters(in: .whitespaces)),
                  let totalPremium = Double(notificationTotalPremiumText.trimmingCharacters(in: .whitespaces)) else {
                return
            }
            
            let notificationConfig = ThresholdConfig(
                callRatioThreshold: callRatio,
                putRatioThreshold: putRatio,
                callPremiumThreshold: callPremium,
                putPremiumThreshold: putPremium,
                totalPremiumThreshold: totalPremium,
                disabled: !notificationEnabled
            )
            
            // Save locally
            configService.saveNotificationThresholds(for: currentTicker, config: notificationConfig)
            
            // Save to server in background
            Task {
                await NotificationThresholdService.shared.saveThresholds(ticker: currentTicker, config: notificationConfig, disabled: !notificationEnabled)
            }
        }
        
        // Save highlight thresholds (always)
        guard let callRatio = Double(highlightCallRatioText.trimmingCharacters(in: .whitespaces)),
              let putRatio = Double(highlightPutRatioText.trimmingCharacters(in: .whitespaces)),
              let callPremium = Double(highlightCallPremiumText.trimmingCharacters(in: .whitespaces)),
              let putPremium = Double(highlightPutPremiumText.trimmingCharacters(in: .whitespaces)),
              let totalPremium = Double(highlightTotalPremiumText.trimmingCharacters(in: .whitespaces)) else {
            return
        }
        
        let highlightConfig = ThresholdConfig(
            callRatioThreshold: callRatio,
            putRatioThreshold: putRatio,
            callPremiumThreshold: callPremium,
            putPremiumThreshold: putPremium,
            totalPremiumThreshold: totalPremium
        )
        
        // Save locally only
        configService.saveHighlightThresholds(for: currentTicker, config: highlightConfig)
        
        dismiss()
    }
}

struct ThresholdSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ThresholdSettingsView()
        }
    }
}
