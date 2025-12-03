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
    @State private var selectedSummary: OptionSummary?
    @State private var sortOption: SortOption = .time
    @State private var showDatePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection status bar
                connectionStatusBar
                
                // List of summaries
                if webSocketService.summaries.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showDatePicker = true
                        }) {
                            Image(systemName: "calendar")
                        }
                        
                        NavigationLink(destination: SettingsView()) {
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
            .onAppear {
                webSocketService.connect()
            }
            .onDisappear {
                webSocketService.disconnect()
            }
        }
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
    
    private var navigationTitle: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: configService.selectedDate)
        
        // Check if selected date is today
        let calendar = Calendar.current
        if calendar.isDateInToday(configService.selectedDate) {
            return "AAPL Options"
        } else {
            return "AAPL Options - \(dateString)"
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
    
    private var sortedSummaries: [OptionSummary] {
        switch sortOption {
        case .time:
            return webSocketService.summaries.sorted { $0.periodStart > $1.periodStart }
        case .callRatio:
            return webSocketService.summaries.sorted { $0.callPutRatio > $1.callPutRatio }
        case .totalPremium:
            return webSocketService.summaries.sorted { $0.totalPremium > $1.totalPremium }
        case .callPremium:
            return webSocketService.summaries.sorted { $0.callPremium > $1.callPremium }
        case .putPremium:
            return webSocketService.summaries.sorted { $0.putPremium > $1.putPremium }
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
        // Call ratio takes precedence - check if it should be green or red
        if summary.callPutRatio >= configService.callRatioThreshold {
            return Color.green.opacity(0.15)
        }
        
        if summary.callPutRatio <= configService.putRatioThreshold {
            return Color.red.opacity(0.15)
        }
        
        // If call ratio is between thresholds (not highlighted by ratio), check premium thresholds
        let callPremiumExceeded = summary.callPremium >= configService.callPremiumThreshold
        let putPremiumExceeded = summary.putPremium >= configService.putPremiumThreshold
        
        // If both premiums exceeded, highlight yellow
        if callPremiumExceeded && putPremiumExceeded {
            return Color.yellow.opacity(0.15)
        }
        
        // If put premium exceeded (alone), highlight red
        if putPremiumExceeded {
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

struct SummaryListView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryListView()
    }
}

