import SwiftUI

struct StrikeListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var configService = ConfigService.shared
    @State private var strikes: [StrikeSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && strikes.isEmpty {
                ProgressView("Loading strikes...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, strikes.isEmpty {
                VStack(spacing: 16) {
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        fetchStrikes()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if strikes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No strike data")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(strikes) { strike in
                    StrikeRowView(strike: strike)
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await fetchStrikesAsync()
                }
            }
        }
        .navigationTitle("Strikes — \(configService.ticker)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            fetchStrikes()
        }
    }

    private func fetchStrikes() {
        Task {
            await fetchStrikesAsync()
        }
    }

    private func fetchStrikesAsync() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let fetched = try await StrikeService.shared.fetchStrikes(date: configService.selectedDate)
            await MainActor.run {
                strikes = fetched
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct StrikeRowView: View {
    let strike: StrikeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(strike.expiration)
                    .font(.headline)

                Text(formatStrikePrice(strike.strike))
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text(formatAbbreviatedCurrency(strike.totalPremium))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Call")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatAbbreviatedCurrency(strike.callPremium))
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(formatNumber(strike.callVolume))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Put")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatAbbreviatedCurrency(strike.putPremium))
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(formatNumber(strike.putVolume))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private func formatStrikePrice(_ amount: Double) -> String {
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
