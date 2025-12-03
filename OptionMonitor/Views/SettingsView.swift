import SwiftUI

struct SettingsView: View {
    @ObservedObject private var configService = ConfigService.shared
    @State private var hostText: String = ""
    @State private var portText: String = ""
    @State private var callRatioThresholdText: String = ""
    @State private var putRatioThresholdText: String = ""
    @State private var callPremiumThresholdText: String = ""
    @State private var putPremiumThresholdText: String = ""
    @State private var showSaveConfirmation = false
    
    var body: some View {
        Form {
            Section(header: Text("WebSocket Configuration")) {
                HStack {
                    Text("Host")
                    TextField("localhost", text: $hostText)
                        .keyboardType(.default)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                HStack {
                    Text("Port")
                    TextField("8080", text: $portText)
                        .keyboardType(.numberPad)
                }
            }
            
            Section(header: Text("Ratio Thresholds")) {
                HStack {
                    Text("Call Ratio Threshold")
                    TextField("1.5", text: $callRatioThresholdText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Put Ratio Threshold")
                    TextField("0.5", text: $putRatioThresholdText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                Toggle("Enable Notifications", isOn: $configService.notificationsEnabled)
                
                Text("Call ratio thresholds take precedence. Rows with call ratio ≥ threshold will be highlighted green. Rows with call ratio ≤ put threshold will be highlighted red. Notifications will be sent when thresholds are crossed.")
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
                    TextField("50000", text: $putPremiumThresholdText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                
                Text("If call ratio thresholds are not met, rows with both call premium ≥ threshold AND put premium ≥ threshold will be highlighted yellow. Notifications will be sent when thresholds are crossed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Actions")) {
                Button("Save") {
                    saveSettings()
                }
                .disabled(!isValidInput)
                
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .foregroundColor(.red)
            }
            
            Section(header: Text("Current Configuration")) {
                HStack {
                    Text("WebSocket URL")
                    Spacer()
                    Text(configService.getWebSocketURL()?.absoluteString ?? "Invalid")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hostText = configService.host
            portText = configService.port
            callRatioThresholdText = String(format: "%.2f", configService.callRatioThreshold)
            putRatioThresholdText = String(format: "%.2f", configService.putRatioThreshold)
            callPremiumThresholdText = String(format: "%.0f", configService.callPremiumThreshold)
            putPremiumThresholdText = String(format: "%.0f", configService.putPremiumThreshold)
        }
        .alert("Settings Saved", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("WebSocket configuration has been updated. The connection will be re-established with the new settings.")
        }
    }
    
    private var isValidInput: Bool {
        let hostValid = !hostText.trimmingCharacters(in: .whitespaces).isEmpty
        let portValid = !portText.trimmingCharacters(in: .whitespaces).isEmpty &&
                       Int(portText) != nil &&
                       Int(portText)! > 0 &&
                       Int(portText)! <= 65535
        let callRatioValid = Double(callRatioThresholdText.trimmingCharacters(in: .whitespaces)) != nil
        let putRatioValid = Double(putRatioThresholdText.trimmingCharacters(in: .whitespaces)) != nil
        let callPremiumValid = Double(callPremiumThresholdText.trimmingCharacters(in: .whitespaces)) != nil
        let putPremiumValid = Double(putPremiumThresholdText.trimmingCharacters(in: .whitespaces)) != nil
        
        return hostValid && portValid && callRatioValid && putRatioValid && callPremiumValid && putPremiumValid
    }
    
    private func saveSettings() {
        guard isValidInput else { return }
        
        configService.host = hostText.trimmingCharacters(in: .whitespaces)
        configService.port = portText.trimmingCharacters(in: .whitespaces)
        
        if let callRatio = Double(callRatioThresholdText.trimmingCharacters(in: .whitespaces)) {
            configService.callRatioThreshold = callRatio
        }
        
        if let putRatio = Double(putRatioThresholdText.trimmingCharacters(in: .whitespaces)) {
            configService.putRatioThreshold = putRatio
        }
        
        if let callPremium = Double(callPremiumThresholdText.trimmingCharacters(in: .whitespaces)) {
            configService.callPremiumThreshold = callPremium
        }
        
        if let putPremium = Double(putPremiumThresholdText.trimmingCharacters(in: .whitespaces)) {
            configService.putPremiumThreshold = putPremium
        }
        
        showSaveConfirmation = true
    }
    
    private func resetToDefaults() {
        configService.resetToDefaults()
        hostText = configService.host
        portText = configService.port
        callRatioThresholdText = String(format: "%.2f", configService.callRatioThreshold)
        putRatioThresholdText = String(format: "%.2f", configService.putRatioThreshold)
        callPremiumThresholdText = String(format: "%.0f", configService.callPremiumThreshold)
        putPremiumThresholdText = String(format: "%.0f", configService.putPremiumThreshold)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}

