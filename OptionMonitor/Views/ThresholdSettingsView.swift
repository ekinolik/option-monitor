import SwiftUI

struct ThresholdSettingsView: View {
    @ObservedObject private var configService = ConfigService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var callRatioThresholdText: String = ""
    @State private var putRatioThresholdText: String = ""
    @State private var callPremiumThresholdText: String = ""
    @State private var putPremiumThresholdText: String = ""
    @State private var totalPremiumThresholdText: String = ""
    
    private var currentTicker: String {
        configService.ticker
    }
    
    private var hasCustomThresholds: Bool {
        configService.hasCustomThresholds(for: currentTicker)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Ratio Thresholds")) {
                HStack {
                    Text("Call Ratio Threshold")
                        .frame(minWidth: 220, alignment: .leading)
                    TextField("40", text: $callRatioThresholdText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Put Ratio Threshold")
                    TextField("0.50", text: $putRatioThresholdText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Ratio Premium Threshold")
                        .frame(minWidth: 220, alignment: .leading)
                    TextField("1000000", text: $totalPremiumThresholdText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                Text("Ratio threshold highlighting only applies if total premium ≥ ratio premium threshold.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Premium Thresholds")) {
                HStack {
                    Text("Call Premium Threshold")
                    TextField("1000000", text: $callPremiumThresholdText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Put Premium Threshold")
                    TextField("500000", text: $putPremiumThresholdText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                Text("If call ratio thresholds are not met, rows with both call premium ≥ threshold AND put premium ≥ threshold will be highlighted yellow. Notifications will be sent when thresholds are crossed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Current Ticker")) {
                Text("\(currentTicker)")
                    .font(.headline)
            }
            
            if hasCustomThresholds {
                Section(header: Text("Actions")) {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
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
                Button("Save") {
                    saveSettings()
                }
                .disabled(!isValidInput)
            }
        }
        .onAppear {
            loadCurrentThresholds()
        }
        .onChange(of: configService.ticker) { _ in
            loadCurrentThresholds()
        }
    }
    
    private func loadCurrentThresholds() {
        let config = configService.getThresholds(for: currentTicker)
        callRatioThresholdText = String(format: "%.2f", config.callRatioThreshold)
        putRatioThresholdText = String(format: "%.2f", config.putRatioThreshold)
        callPremiumThresholdText = String(format: "%.0f", config.callPremiumThreshold)
        putPremiumThresholdText = String(format: "%.0f", config.putPremiumThreshold)
        totalPremiumThresholdText = String(format: "%.0f", config.totalPremiumThreshold)
    }
    
    private var isValidInput: Bool {
        let callRatioValid = Double(callRatioThresholdText.trimmingCharacters(in: .whitespaces)) != nil
        let putRatioValid = Double(putRatioThresholdText.trimmingCharacters(in: .whitespaces)) != nil
        let callPremiumValid = Double(callPremiumThresholdText.trimmingCharacters(in: .whitespaces)) != nil
        let putPremiumValid = Double(putPremiumThresholdText.trimmingCharacters(in: .whitespaces)) != nil
        let totalPremiumValid = Double(totalPremiumThresholdText.trimmingCharacters(in: .whitespaces)) != nil
        
        return callRatioValid && putRatioValid && callPremiumValid && putPremiumValid && totalPremiumValid
    }
    
    private func saveSettings() {
        guard isValidInput else { return }
        
        guard let callRatio = Double(callRatioThresholdText.trimmingCharacters(in: .whitespaces)),
              let putRatio = Double(putRatioThresholdText.trimmingCharacters(in: .whitespaces)),
              let callPremium = Double(callPremiumThresholdText.trimmingCharacters(in: .whitespaces)),
              let putPremium = Double(putPremiumThresholdText.trimmingCharacters(in: .whitespaces)),
              let totalPremium = Double(totalPremiumThresholdText.trimmingCharacters(in: .whitespaces)) else {
            return
        }
        
        let config = ThresholdConfig(
            callRatioThreshold: callRatio,
            putRatioThreshold: putRatio,
            callPremiumThreshold: callPremium,
            putPremiumThreshold: putPremium,
            totalPremiumThreshold: totalPremium
        )
        
        // Save locally first
        configService.saveThresholds(for: currentTicker, config: config)
        
        // Save to server in background (errors handled silently)
        Task {
            await NotificationThresholdService.shared.saveThresholds(ticker: currentTicker, config: config)
        }
        
        dismiss()
    }
    
    private func resetToDefaults() {
        configService.clearThresholds(for: currentTicker)
        loadCurrentThresholds()
    }
}

struct ThresholdSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ThresholdSettingsView()
        }
    }
}

