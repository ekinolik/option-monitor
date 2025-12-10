import SwiftUI

enum SortOption: String, CaseIterable {
    case time = "Time"
    case callRatio = "Call Ratio"
    case totalPremium = "Total Premium"
    case callPremium = "Call Premium"
    case putPremium = "Put Premium"
}

struct SummaryListView: View {
    @StateObject private var webSocketService = WebSocketService()
    @ObservedObject private var configService = ConfigService.shared
    @ObservedObject private var authService = AuthenticationService.shared
    @ObservedObject private var deviceRegistrationService = DeviceRegistrationService.shared
    @Environment(\.scenePhase) var scenePhase
    @State private var selectedSummary: OptionSummary?
    @State private var sortOption: SortOption = .time
    @State private var showDatePicker = false
    @State private var showTickerPicker = false
    @State private var showThresholdSettings = false
    @State private var filterByThreshold = false
    @State private var showRegistrationError = false
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                NavigationView {
            VStack(spacing: 0) {
                // Header row 2: Ticker and date
                tickerAndDateHeader
                
                // Header row 3: Connection status bar
                connectionStatusBar
                
                // List of summaries
                if webSocketService.summaries.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if !webSocketService.summaries.isEmpty {
                        ratiosHeader
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button(action: {
                            filterByThreshold.toggle()
                        }) {
                            Image(systemName: filterByThreshold ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .foregroundColor(filterByThreshold ? .blue : .primary)
                        }
                        
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    sortOption = option
                                }) {
                                    HStack {
                                        Text(option.rawValue)
                                        if sortOption == option {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            webSocketService.reconnect()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Button(action: {
                            showDatePicker = true
                        }) {
                            Image(systemName: "calendar")
                        }
                        
                        NavigationLink(destination: ServerSettingsView()) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(item: $selectedSummary) { summary in
                SummaryDetailView(summary: summary)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $configService.selectedDate, isPresented: $showDatePicker)
            }
            .sheet(isPresented: $showTickerPicker) {
                TickerPickerSheet(ticker: $configService.ticker, isPresented: $showTickerPicker)
            }
            .sheet(isPresented: $showThresholdSettings) {
                NavigationView {
                    ThresholdSettingsView()
                }
            }
            .alert("Device Registration Error", isPresented: $showRegistrationError) {
                Button("OK") {
                    deviceRegistrationService.registrationError = nil
                }
            } message: {
                if let error = deviceRegistrationService.registrationError {
                    Text(error)
                }
            }
            .onChange(of: deviceRegistrationService.registrationError) { error in
                showRegistrationError = error != nil
            }
            .onAppear {
                webSocketService.connect()
            }
            .onDisappear {
                // Don't disconnect on disappear - let it stay connected in background
            }
            .onChange(of: scenePhase) { newPhase in
                handleScenePhaseChange(newPhase)
            }
            .onChange(of: authService.isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    webSocketService.connect()
                }
            }
                }
            } else {
                SignInView()
            }
        }
        .onAppear {
            authService.checkAuthenticationStatus()
        }
    }
    
    private var tickerAndDateHeader: some View {
        HStack {
            Button(action: {
                showTickerPicker = true
            }) {
                HStack(spacing: 4) {
                    Text(configService.ticker)
                        .font(.title2)
                        .fontWeight(.bold)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            Button(action: {
                showThresholdSettings = true
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Text(" - ")
                .foregroundColor(.secondary)
            
            Text(formatDate(configService.selectedDate))
                .font(.title2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private var connectionStatusBar: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var ratiosHeader: some View {
        HStack(spacing: 16) {
            ratioItem(label: "15m", ratio: fifteenMinuteRatio)
            ratioItem(label: "1h", ratio: oneHourRatio)
            ratioItem(label: "Day", ratio: allDayRatio)
        }
    }
    
    private func ratioItem(label: String, ratio: Double?) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            if let ratio = ratio {
                Text(String(format: "%.2f", ratio))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ratioColor(for: ratio))
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func ratioColor(for ratio: Double) -> Color {
        if ratio < 2.0 {
            return .red
        } else if ratio < 4.0 {
            return .orange
        } else if ratio < 6.0 {
            return Color(red: 0.0, green: 0.5, blue: 0.0) // Dark green
        } else {
            return .green // Bright green
        }
    }
    
    private var fifteenMinuteRatio: Double? {
        calculateRatio(for: 15 * 60) // 15 minutes in seconds
    }
    
    private var oneHourRatio: Double? {
        calculateRatio(for: 60 * 60) // 1 hour in seconds
    }
    
    private var allDayRatio: Double? {
        calculateRatio(for: nil) // nil means all day
    }
    
    private func calculateRatio(for timeWindowSeconds: Int?) -> Double? {
        let now = Date()
        let cutoffDate: Date?
        
        if let seconds = timeWindowSeconds {
            cutoffDate = now.addingTimeInterval(-Double(seconds))
        } else {
            cutoffDate = nil // All day
        }
        
        let relevantSummaries: [OptionSummary]
        if let cutoff = cutoffDate {
            relevantSummaries = webSocketService.summaries.filter { $0.periodStart >= cutoff }
        } else {
            relevantSummaries = webSocketService.summaries
        }
        
        guard !relevantSummaries.isEmpty else { return nil }
        
        let totalCallVolume = relevantSummaries.reduce(0) { $0 + $1.callVolume }
        let totalPutVolume = relevantSummaries.reduce(0) { $0 + $1.putVolume }
        
        guard totalPutVolume > 0 else { return nil }
        
        return Double(totalCallVolume) / Double(totalPutVolume)
    }
    
    private var statusColor: Color {
        switch webSocketService.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch webSocketService.connectionStatus {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active - check if we need to reconnect
            if case .disconnected = webSocketService.connectionStatus {
                webSocketService.connect()
            } else if case .error = webSocketService.connectionStatus {
                // If there was an error, try to reconnect
                webSocketService.reconnect()
            }
        case .background, .inactive:
            // App went to background - keep connection but don't disconnect
            break
        @unknown default:
            break
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No data yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Waiting for option summaries...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func meetsThreshold(_ summary: OptionSummary) -> Bool {
        // Check if summary meets any threshold (same logic as backgroundColor)
        if summary.callPremium >= configService.callPremiumThreshold {
            return true
        } else if summary.callPutRatio >= configService.callRatioThreshold &&
                  summary.totalPremium >= configService.totalPremiumThreshold {
            return true
        } else if summary.putPremium >= configService.putPremiumThreshold {
            return true
        } else if summary.callPutRatio <= configService.putRatioThreshold &&
                  summary.totalPremium >= configService.totalPremiumThreshold {
            return true
        }
        
        return false
    }
    
    private var sortedSummaries: [OptionSummary] {
        let summaries = filterByThreshold 
            ? webSocketService.summaries.filter { meetsThreshold($0) }
            : webSocketService.summaries
        
        switch sortOption {
        case .time:
            return summaries.sorted { $0.periodStart > $1.periodStart }
        case .callRatio:
            return summaries.sorted { $0.callPutRatio > $1.callPutRatio }
        case .totalPremium:
            return summaries.sorted { $0.totalPremium > $1.totalPremium }
        case .callPremium:
            return summaries.sorted { $0.callPremium > $1.callPremium }
        case .putPremium:
            return summaries.sorted { $0.putPremium > $1.putPremium }
        }
    }
    
    private var listView: some View {
        List {
            ForEach(sortedSummaries) { summary in
                SummaryRowView(summary: summary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSummary = summary
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct SummaryRowView: View {
    let summary: OptionSummary
    @ObservedObject private var configService = ConfigService.shared
    
    private var backgroundColor: Color {
        // Check thresholds in priority order
        if summary.callPremium >= configService.callPremiumThreshold {
            return Color.green.opacity(0.15)
        } else if summary.callPutRatio >= configService.callRatioThreshold &&
                  summary.totalPremium >= configService.totalPremiumThreshold {
            return Color.green.opacity(0.15)
        } else if summary.putPremium >= configService.putPremiumThreshold {
            return Color.red.opacity(0.15)
        } else if summary.callPutRatio <= configService.putRatioThreshold &&
                  summary.totalPremium >= configService.totalPremiumThreshold {
            return Color.red.opacity(0.15)
        }
        
        return Color.clear
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // First line: time, total premium, call ratio
            HStack(spacing: 12) {
                Text(formatTime(summary.periodStart))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(formatCurrency(summary.totalPremium))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("C/P: \(String(format: "%.2f", summary.callPutRatio))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Second line: call premium, call volume, put premium, put volume
            HStack(spacing: 12) {
                Text(formatCurrency(summary.callPremium))
                    .font(.caption)
                    .foregroundColor(.green)
                
                Text("\(formatNumber(summary.callVolume))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatCurrency(summary.putPremium))
                    .font(.caption)
                    .foregroundColor(.red)
                
                Text("\(formatNumber(summary.putVolume))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(.vertical, 6)
        .background(backgroundColor)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "0"
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct TickerPickerSheet: View {
    @Binding var ticker: String
    @Binding var isPresented: Bool
    @State private var tickerText: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ticker Symbol")) {
                    TextField("AAPL", text: $tickerText)
                        .keyboardType(.default)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                }
            }
            .navigationTitle("Change Ticker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmed = tickerText.trimmingCharacters(in: .whitespaces).uppercased()
                        if !trimmed.isEmpty {
                            ticker = trimmed
                        }
                        isPresented = false
                    }
                    .disabled(tickerText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                tickerText = ticker
            }
        }
    }
}

struct SummaryListView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryListView()
    }
}

