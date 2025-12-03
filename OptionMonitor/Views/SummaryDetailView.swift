import SwiftUI

enum TransactionSortOption: String, CaseIterable {
    case premium = "Premium"
    case volume = "Volume"
}

struct SummaryDetailView: View {
    let summary: OptionSummary
    @Environment(\.dismiss) var dismiss
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sortOption: TransactionSortOption = .premium
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Time period section
                    sectionHeader("Time Period")
                    timePeriodSection
                    
                    Divider()
                    
                    // Premium section
                    sectionHeader("Premium")
                    premiumSection
                    
                    Divider()
                    
                    // Volume section
                    sectionHeader("Volume")
                    volumeSection
                    
                    Divider()
                    
                    // Ratio section
                    sectionHeader("Call/Put Ratio")
                    ratioSection
                    
                    Divider()
                    
                    // Transactions section
                    HStack {
                        sectionHeader("Transactions")
                        Spacer()
                        Menu {
                            ForEach(TransactionSortOption.allCases, id: \.self) { option in
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
                                .font(.caption)
                        }
                    }
                    transactionsSection
                }
                .padding()
            }
            .navigationTitle("Summary Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                fetchTransactions()
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.secondary)
    }
    
    private var timePeriodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow(label: "Start", value: formatDateTime(summary.periodStart))
            detailRow(label: "End", value: formatDateTime(summary.periodEnd))
            detailRow(label: "Duration", value: formatDuration(summary.periodStart, summary.periodEnd))
        }
    }
    
    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow(label: "Call Premium", value: formatCurrency(summary.callPremium))
            detailRow(label: "Put Premium", value: formatCurrency(summary.putPremium))
            detailRow(label: "Total Premium", value: formatCurrency(summary.totalPremium), isHighlighted: true)
        }
    }
    
    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow(label: "Call Volume", value: formatNumber(summary.callVolume))
            detailRow(label: "Put Volume", value: formatNumber(summary.putVolume))
            detailRow(label: "Total Volume", value: formatNumber(summary.callVolume + summary.putVolume), isHighlighted: true)
        }
    }
    
    private var ratioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow(label: "Call/Put Ratio", value: String(format: "%.4f", summary.callPutRatio))
            
            // Visual ratio indicator
            HStack {
                Text("Calls")
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
                Text("Puts")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: geometry.size.width * callPercentage)
                    Rectangle()
                        .fill(Color.red.opacity(0.6))
                        .frame(width: geometry.size.width * putPercentage)
                }
            }
            .frame(height: 20)
            .cornerRadius(4)
        }
    }
    
    private var callPercentage: CGFloat {
        let total = summary.callVolume + summary.putVolume
        guard total > 0 else { return 0 }
        return CGFloat(summary.callVolume) / CGFloat(total)
    }
    
    private var putPercentage: CGFloat {
        let total = summary.callVolume + summary.putVolume
        guard total > 0 else { return 0 }
        return CGFloat(summary.putVolume) / CGFloat(total)
    }
    
    private func detailRow(label: String, value: String, isHighlighted: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(isHighlighted ? .semibold : .regular)
        }
        .font(.body)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ start: Date, _ end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "0"
    }
    
    private var sortedTransactions: [Transaction] {
        switch sortOption {
        case .premium:
            return transactions.sorted { 
                ($0.volumeWeightedPrice * Double($0.volume) * 100.0) > 
                ($1.volumeWeightedPrice * Double($1.volume) * 100.0) 
            }
        case .volume:
            return transactions.sorted { $0.volume > $1.volume }
        }
    }
    
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            } else if transactions.isEmpty {
                Text("No transactions found")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(sortedTransactions) { transaction in
                    TransactionRowView(transaction: transaction)
                        .padding(.vertical, 4)
                    Divider()
                }
            }
        }
    }
    
    private func fetchTransactions() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Use the period start date and time
                let date = summary.periodStart
                let time = summary.periodStart
                
                let fetchedTransactions = try await TransactionService.shared.fetchTransactions(date: date, time: time)
                
                await MainActor.run {
                    self.transactions = fetchedTransactions
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    
    private var premium: Double {
        // Premium = VWAP * Volume * 100 (options contracts are typically 100 shares)
        transaction.volumeWeightedPrice * Double(transaction.volume) * 100.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Symbol display: P/C Date Strike
            if let details = transaction.optionDetails {
                HStack {
                    Text(details.optionType == "CALL" ? "C" : "P")
                        .font(.headline)
                        .foregroundColor(details.optionType == "CALL" ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(details.optionType == "CALL" ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text(details.expiration)
                        .font(.headline)
                    
                    Text(formatCurrency(details.strike))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
            } else {
                Text(transaction.symbol)
                    .font(.headline)
            }
            
            Divider()
            
            // Premium and key metrics
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Premium")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(premium))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("VWAP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(transaction.volumeWeightedPrice))
                        .font(.subheadline)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Volume")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatNumber(transaction.volume))
                        .font(.subheadline)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "0"
    }
}

struct SummaryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSummary = OptionSummary(
            id: UUID(),
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(60),
            callPremium: 1158667.03,
            putPremium: 72771,
            totalPremium: 1231438.03,
            callPutRatio: 15.922098500776409,
            callVolume: 2156,
            putVolume: 363
        )
        SummaryDetailView(summary: sampleSummary)
    }
}

