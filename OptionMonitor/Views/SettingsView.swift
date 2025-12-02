import SwiftUI

struct SettingsView: View {
    @ObservedObject private var configService = ConfigService.shared
    @State private var hostText: String = ""
    @State private var portText: String = ""
    @State private var callRatioThresholdText: String = ""
    @State private var putRatioThresholdText: String = ""
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
                
                Text("Rows with call ratio ≥ threshold will be highlighted green. Rows with call ratio ≤ put threshold will be highlighted red.")
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
        
        return hostValid && portValid && callRatioValid && putRatioValid
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
        
        showSaveConfirmation = true
    }
    
    private func resetToDefaults() {
        configService.resetToDefaults()
        hostText = configService.host
        portText = configService.port
        callRatioThresholdText = String(format: "%.2f", configService.callRatioThreshold)
        putRatioThresholdText = String(format: "%.2f", configService.putRatioThreshold)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}

