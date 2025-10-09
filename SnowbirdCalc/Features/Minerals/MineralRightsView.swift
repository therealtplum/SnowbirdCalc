import SwiftUI

struct MineralRightsView: View {
    private let service: MineralRightsService = USMEScraper()

    @State private var listings: [MineralListing] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sort: MineralSortEx = .bestScore
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            controlBar

            Group {
                if isLoading {
                    ProgressView("Fetching listings…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding()
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Text("Couldn't load listings").font(.headline)
                        Text(err).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button { Task { await load() } } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if derived.isEmpty {
                    ContentUnavailableView(
                        "No results",
                        systemImage: "magnifyingglass",
                        description: Text(searchText.isEmpty
                                          ? "No listings were found on the marketplace."
                                          : "Try a different search term or clear the search.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            ForEach(derived) { item in
                                ListingCard(item: item)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(Color.black.opacity(0.06))
                                    )
                                    .padding(.horizontal, 16)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .animation(.default, value: derived)
        }
        .navigationTitle("Mineral Rights")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityLabel("Refresh")
            }
        }
        .task { await load() }
    }

    // MARK: - Controls

    private var controlBar: some View {
        VStack(spacing: 12) {
            // Search
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search by title, location, source, listing id…", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Sort
            HStack {
                Text("Sort").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Picker("Sort", selection: $sort) {
                    ForEach(MineralSortEx.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Derived

    private var derived: [MineralListing] {
        // Filter
        let filtered: [MineralListing]
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = listings
        } else {
            let needle = searchText.lowercased()
            filtered = listings.filter {
                $0.title.lowercased().contains(needle)
                || shortLoc(of: $0).lowercased().contains(needle)
                || $0.source.lowercased().contains(needle)
                || ($0.listingID ?? "").lowercased().contains(needle)
            }
        }

        // Sort
        switch sort {
        case .bestScore:
            return filtered.sorted(by: { $0.score > $1.score })
        case .lowestPricePerNMA:
            return filtered.sorted(by: {
                switch ($0.dollarsPerNMA, $1.dollarsPerNMA) {
                case let (a?, b?): return a < b
                case (_?, nil):    return true
                case (nil, _?):    return false
                default:           return $0.title < $1.title
                }
            })
        case .highestYield:
            return filtered.sorted(by: { (yield(of: $0) ?? -1) > (yield(of: $1) ?? -1) })
        case .newest:
            return filtered.sorted(by: { ($0.postedAt ?? .distantPast) > ($1.postedAt ?? .distantPast) })
        }
    }

    // Small helpers
    private func yield(of item: MineralListing) -> Double? {
        guard let cf = item.cashFlowUSD, let sb = item.priceUSD, sb > 0 else { return nil }
        return (cf * 12) / sb  // Annualize monthly cash flow
    }
    
    private func shortLoc(of item: MineralListing) -> String {
        let parts = item.location.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2 { return "\(parts[0]), \(parts[1])" }
        return item.location.isEmpty ? item.source : item.location
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let data = try await service.fetchListings(query: nil)
            await MainActor.run {
                self.listings = data
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

// MARK: - Sort enum (adds Highest Yield)

enum MineralSortEx: String, CaseIterable, Identifiable {
    case bestScore = "Best Score"
    case lowestPricePerNMA = "Lowest $/NMA"
    case highestYield = "Highest Yield"
    case newest = "Newest"
    var id: String { rawValue }
}

// MARK: - Listing Card (spacious, UI-friendly)

private struct ListingCard: View {
    let item: MineralListing

    private var nma: Double { item.netMineralAcres ?? item.acres ?? 0 }
    private var dollarsPerNMA: Double? {
        guard let p = item.priceUSD, nma > 0 else { return nil }
        return p / nma
    }
    private var annualCashFlow: Double? {
        guard let monthly = item.cashFlowUSD else { return nil }
        return monthly * 12
    }
    private var yieldFraction: Double? {
        guard let annual = annualCashFlow, let sb = item.priceUSD, sb > 0 else { return nil }
        return annual / sb
    }
    private var breakEvenYears: Double? {
        guard let annual = annualCashFlow, let sb = item.priceUSD, annual > 0 else { return nil }
        return sb / annual
    }
    private var shortLoc: String {
        let parts = item.location.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2 { return "\(parts[0]), \(parts[1])" }
        return item.location.isEmpty ? item.source : item.location
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerTitle)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    if !item.title.isEmpty && item.title != headerTitle {
                        Text(item.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(item.source)
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
                    .accessibilityHidden(true)
            }

            // Location
            Label(shortLoc, systemImage: "mappin.and.ellipse")
                .labelStyle(.titleAndIcon)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Big metrics
            VStack(spacing: 10) {
                MetricRow(leftLabel: "Starting Bid",
                          leftValue: item.priceUSD.map { $0.formatted(.currency(code: "USD")) } ?? "—",
                          rightLabel: "Monthly Cash Flow",
                          rightValue: item.cashFlowUSD.map { $0.formatted(.currency(code: "USD")) } ?? "—")

                MetricRow(leftLabel: "Annual Yield",
                          leftValue: yieldFraction.map { $0.formatted(.percent.precision(.fractionLength(1))) } ?? "—",
                          rightLabel: "Break Even",
                          rightValue: breakEvenYears.map { "\($0.formatted(.number.precision(.fractionLength(1)))) yrs" } ?? "—")
            }

            // Secondary metrics
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let id = item.listingID {
                        Pill(title: "ID", value: id)
                    }
                    Pill(title: "NMA", value: nma.formatted(.number.precision(.fractionLength(2))))
                    if let dpnma = dollarsPerNMA {
                        Pill(title: "$/NMA", value: dpnma.formatted(.currency(code: "USD")))
                    }
                    if let royalty = item.royaltyFraction {
                        Pill(title: "Royalty", value: royalty.formatted(.percent.precision(.fractionLength(2))))
                    }
                    Pill(title: "Score", value: item.score.formatted(.number.precision(.fractionLength(2))))
                }
            }
            
            // Additional info from notes
            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }

            // CTA
            HStack {
                Spacer()
                Link(destination: item.url) {
                    Label("View Offering", systemImage: "arrow.up.right.square")
                        .font(.headline)
                }
            }
        }
        .padding(16)
    }

    private var headerTitle: String {
        if let id = item.listingID { return "Listing #\(id)" }
        return item.title.isEmpty ? "Mineral Listing" : item.title
    }
}

// MARK: - UI helpers

private struct MetricRow: View {
    let leftLabel: String
    let leftValue: String
    let rightLabel: String
    let rightValue: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(leftLabel).font(.caption).foregroundStyle(.secondary)
                Text(leftValue).font(.title3.weight(.semibold)).monospacedDigit()
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 4) {
                Text(rightLabel).font(.caption).foregroundStyle(.secondary)
                Text(rightValue).font(.title3.weight(.semibold)).monospacedDigit()
            }
        }
    }
}

private struct Pill: View {
    let title: String
    let value: String
    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption).monospacedDigit()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemFill))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
