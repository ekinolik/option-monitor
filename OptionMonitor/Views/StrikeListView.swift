import SwiftUI

enum StrikeCountFilter: String, CaseIterable {
    case top10
    case top20
    case top50
    case all

    var limit: Int? {
        switch self {
        case .top10: return 10
        case .top20: return 20
        case .top50: return 50
        case .all: return nil
        }
    }

    var label: String {
        switch self {
        case .top10: return "10"
        case .top20: return "20"
        case .top50: return "50"
        case .all: return "All"
        }
    }
}

enum StrikeExpirationFilter: String, CaseIterable {
    case days5
    case days30
    case days90
    case days180
    case all

    var days: Int? {
        switch self {
        case .days5: return 5
        case .days30: return 30
        case .days90: return 90
        case .days180: return 180
        case .all: return nil
        }
    }

    var label: String {
        switch self {
        case .days5: return "5"
        case .days30: return "30"
        case .days90: return "90"
        case .days180: return "180"
        case .all: return "All"
        }
    }
}

enum StrikeSortOption: String, CaseIterable {
    case totalPremium = "Total Premium"
    case expiration = "Expiration"
    case strike = "Strike"
}

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
                List {
                    ForEach(sortedStrikeRows, id: \.strike.id) { row in
                        StrikeRowView(
                            strike: row.strike,
                            maxTotalPremium: row.maxTotalPremium,
                            expirationText: configService.strikeAggregateByStrike ? nil : formatExpiration(row.strike.expiration)
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    }
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
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 12) {
                    Menu {
                        ForEach(StrikeCountFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                configService.strikeCountFilter = filter
                            }) {
                                HStack {
                                    Text(filter == .all ? "All" : "Top \(filter.label)")
                                    if configService.strikeCountFilter == filter {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Top \(configService.strikeCountFilter.label)", systemImage: "line.3.horizontal.decrease.circle")
                    }

                    Menu {
                        ForEach(availableSortOptions, id: \.self) { option in
                            Button(action: {
                                configService.strikeSortOption = option
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    if configService.strikeSortOption == option {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }

                    Menu {
                        ForEach(StrikeExpirationFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                configService.strikeExpirationFilter = filter
                            }) {
                                HStack {
                                    Text(filter == .all ? "All" : "\(filter.label) days")
                                    if configService.strikeExpirationFilter == filter {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label(
                            configService.strikeExpirationFilter == .all ? "Exp" : "\(configService.strikeExpirationFilter.label)d",
                            systemImage: "calendar"
                        )
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        configService.strikeAggregateByStrike.toggle()
                        if configService.strikeAggregateByStrike && configService.strikeSortOption == .expiration {
                            configService.strikeSortOption = .totalPremium
                        }
                    }) {
                        Image(systemName: configService.strikeAggregateByStrike ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                            .foregroundColor(configService.strikeAggregateByStrike ? .blue : .primary)
                    }

                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            fetchStrikes()
        }
    }

    private var availableSortOptions: [StrikeSortOption] {
        configService.strikeAggregateByStrike
            ? StrikeSortOption.allCases.filter { $0 != .expiration }
            : StrikeSortOption.allCases
    }

    private var expirationFilteredStrikes: [StrikeSummary] {
        strikes.filter { passesExpirationFilter($0) }
    }

    private var processedStrikes: [StrikeSummary] {
        let filtered = expirationFilteredStrikes
        guard configService.strikeAggregateByStrike else { return filtered }
        return aggregateStrikes(filtered)
    }

    private var filteredStrikes: [StrikeSummary] {
        let ranked = processedStrikes.sorted { $0.totalPremium > $1.totalPremium }
        let limited: [StrikeSummary]
        if let limit = configService.strikeCountFilter.limit {
            limited = Array(ranked.prefix(limit))
        } else {
            limited = processedStrikes
        }
        return sortStrikes(limited)
    }

    private func aggregateStrikes(_ strikes: [StrikeSummary]) -> [StrikeSummary] {
        let grouped = Dictionary(grouping: strikes, by: \.strike)
        return grouped.map { strikePrice, items in
            StrikeSummary(
                expiration: "",
                strike: strikePrice,
                callPremium: items.reduce(0) { $0 + $1.callPremium },
                putPremium: items.reduce(0) { $0 + $1.putPremium },
                totalPremium: items.reduce(0) { $0 + $1.totalPremium },
                callVolume: items.reduce(0) { $0 + $1.callVolume },
                putVolume: items.reduce(0) { $0 + $1.putVolume }
            )
        }
    }

    private func passesExpirationFilter(_ strike: StrikeSummary) -> Bool {
        guard let days = configService.strikeExpirationFilter.days else { return true }
        guard let expirationDate = parseExpirationDate(strike.expiration) else { return true }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: days, to: today) else { return true }

        let expirationDay = calendar.startOfDay(for: expirationDate)
        return expirationDay >= today && expirationDay <= endDate
    }

    private func parseExpirationDate(_ expiration: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: expiration)
    }

    private func sortStrikes(_ strikes: [StrikeSummary]) -> [StrikeSummary] {
        strikes.sorted { lhs, rhs in
            if configService.strikeAggregateByStrike {
                switch configService.strikeSortOption {
                case .totalPremium:
                    if lhs.totalPremium != rhs.totalPremium { return lhs.totalPremium > rhs.totalPremium }
                    return lhs.strike < rhs.strike
                case .strike:
                    if lhs.strike != rhs.strike { return lhs.strike < rhs.strike }
                    return lhs.totalPremium > rhs.totalPremium
                case .expiration:
                    if lhs.totalPremium != rhs.totalPremium { return lhs.totalPremium > rhs.totalPremium }
                    return lhs.strike < rhs.strike
                }
            }

            switch configService.strikeSortOption {
            case .totalPremium:
                if lhs.totalPremium != rhs.totalPremium { return lhs.totalPremium > rhs.totalPremium }
                if lhs.expiration != rhs.expiration { return lhs.expiration < rhs.expiration }
                return lhs.strike < rhs.strike
            case .expiration:
                if lhs.expiration != rhs.expiration { return lhs.expiration < rhs.expiration }
                if lhs.totalPremium != rhs.totalPremium { return lhs.totalPremium > rhs.totalPremium }
                return lhs.strike < rhs.strike
            case .strike:
                if lhs.strike != rhs.strike { return lhs.strike < rhs.strike }
                if lhs.totalPremium != rhs.totalPremium { return lhs.totalPremium > rhs.totalPremium }
                return lhs.expiration < rhs.expiration
            }
        }
    }

    private var sortedStrikeRows: [(strike: StrikeSummary, maxTotalPremium: Double)] {
        let maxTotal = filteredStrikes.map(\.totalPremium).max() ?? 1
        return filteredStrikes.map { (strike: $0, maxTotalPremium: maxTotal) }
    }

    private func formatExpiration(_ expiration: String) -> String {
        guard let date = parseExpirationDate(expiration) else { return expiration }
        let output = DateFormatter()
        output.dateFormat = "MMM d, yyyy"
        return output.string(from: date)
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
    let maxTotalPremium: Double
    let expirationText: String?

    private let callPremiumColor = Color(red: 0.0, green: 0.48, blue: 0.14)
    private let putPremiumColor = Color(red: 0.78, green: 0.12, blue: 0.12)
    private let callBarColor = Color.green.opacity(0.095)
    private let putBarColor = Color.red.opacity(0.095)

    private var barScale: CGFloat {
        guard maxTotalPremium > 0 else { return 0 }
        return CGFloat(min(strike.totalPremium / maxTotalPremium, 1))
    }

    private var dominantPremium: Double {
        max(strike.callPremium, strike.putPremium, 1)
    }

    var body: some View {
        VStack(spacing: 2) {
            if let expirationText = expirationText {
                Text(expirationText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(formatAbbreviatedCurrency(strike.callPremium))
                        .fontWeight(.semibold)
                        .foregroundColor(callPremiumColor)
                    Text("/")
                        .foregroundColor(.secondary)
                    Text(formatNumber(strike.callVolume))
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(formatStrikePrice(strike.strike))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(minWidth: 56)

                HStack(spacing: 4) {
                    Text(formatAbbreviatedCurrency(strike.putPremium))
                        .fontWeight(.semibold)
                        .foregroundColor(putPremiumColor)
                    Text("/")
                        .foregroundColor(.secondary)
                    Text(formatNumber(strike.putVolume))
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
        .background {
            GeometryReader { geometry in
                let centerX = geometry.size.width / 2
                let halfWidth = geometry.size.width / 2
                let callBarWidth = halfWidth * barScale * CGFloat(strike.callPremium / dominantPremium)
                let putBarWidth = halfWidth * barScale * CGFloat(strike.putPremium / dominantPremium)

                ZStack {
                    if callBarWidth > 0 {
                        Rectangle()
                            .fill(callBarColor)
                            .frame(width: callBarWidth, height: geometry.size.height)
                            .position(x: centerX - callBarWidth / 2, y: geometry.size.height / 2)
                    }
                    if putBarWidth > 0 {
                        Rectangle()
                            .fill(putBarColor)
                            .frame(width: putBarWidth, height: geometry.size.height)
                            .position(x: centerX + putBarWidth / 2, y: geometry.size.height / 2)
                    }
                }
            }
        }
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
