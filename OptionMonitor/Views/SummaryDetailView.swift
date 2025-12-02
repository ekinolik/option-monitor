import SwiftUI

struct SummaryDetailView: View {
    let summary: OptionSummary
    @Environment(\.dismiss) var dismiss
    
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

