import SwiftUI

struct SettingsView: View {
    @ObservedObject private var configService = ConfigService.shared
    @State private var hostText: String = ""
    @State private var portText: String = ""
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
        }
        .alert("Settings Saved", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("WebSocket configuration has been updated. The connection will be re-established with the new settings.")
        }
    }
    
    private var isValidInput: Bool {
        !hostText.trimmingCharacters(in: .whitespaces).isEmpty &&
        !portText.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(portText) != nil &&
        Int(portText)! > 0 &&
        Int(portText)! <= 65535
    }
    
    private func saveSettings() {
        guard isValidInput else { return }
        
        configService.host = hostText.trimmingCharacters(in: .whitespaces)
        configService.port = portText.trimmingCharacters(in: .whitespaces)
        
        showSaveConfirmation = true
    }
    
    private func resetToDefaults() {
        configService.resetToDefaults()
        hostText = configService.host
        portText = configService.port
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}

