//
//  LearnView.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/2/25.
//

import SwiftUI

// MARK: - Model

struct LearnEntry: Identifiable, Hashable, Codable {
    enum Kind: String, CaseIterable, Codable {
        case glossary = "Glossary"
        case guide = "Guides"
        case link = "Helpful Links"
        case note = "My Notes"
        case opportunity = "Opportunities"

        var icon: String {
            switch self {
            case .glossary:    return "book.closed"
            case .guide:       return "lightbulb"
            case .link:        return "link"
            case .note:        return "note.text"
            case .opportunity: return "briefcase"
            }
        }
    }

    let id: UUID
    var title: String
    var subtitle: String?
    var kind: Kind
    var content: String?     // Markdown for glossary/guide/note
    var url: URL?            // For external links (Helpful Links / Opportunities)
    var tags: [String] = []

    init(id: UUID = UUID(),
         title: String,
         subtitle: String? = nil,
         kind: Kind,
         content: String? = nil,
         url: URL? = nil,
         tags: [String] = []) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.content = content
        self.url = url
        self.tags = tags
    }

    // Make JSON 'id' optional when decoding
    enum CodingKeys: String, CodingKey { case id, title, subtitle, kind, content, url, tags }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id       = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title    = try c.decode(String.self, forKey: .title)
        self.subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        self.kind     = try c.decode(Kind.self, forKey: .kind)
        self.content  = try c.decodeIfPresent(String.self, forKey: .content)
        self.url      = try c.decodeIfPresent(URL.self, forKey: .url)
        self.tags     = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

// MARK: - Bundle Loader

extension Array where Element == LearnEntry {
    static func loadFromBundle() -> [LearnEntry] {
        guard let url = Bundle.main.url(forResource: "LearnEntries", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([LearnEntry].self, from: data)
        else {
            return []
        }
        return decoded
    }
}

// MARK: - View

struct LearnView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case glossary = "Glossary"
        case guides = "Guides"
        case links = "Helpful Links"
        case notes = "My Notes"
        case opportunities = "Opportunities"

        var id: String { rawValue }
    }

    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var staticEntries: [LearnEntry] = .loadFromBundle() // from JSON
    @State private var opps: [LearnEntry] = [] // seeded once from code
    @AppStorage("LearnView.favorites") private var favoriteIDsData: Data = Data()
    @AppStorage("LearnView.notes") private var notesData: Data = Data()
    @AppStorage("LearnView.oppsSeeded") private var oppsSeeded: Bool = false

    // Favorites persistence
    private var favoriteIDs: Set<UUID> {
        get { (try? JSONDecoder().decode(Set<UUID>.self, from: favoriteIDsData)) ?? [] }
        nonmutating set { favoriteIDsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    // Notes persistence (array of LearnEntry with kind == .note)
    private var notes: [LearnEntry] {
        get { (try? JSONDecoder().decode([LearnEntry].self, from: notesData)) ?? [] }
        nonmutating set { notesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    // Combined source for filtering
    private var allEntries: [LearnEntry] {
        staticEntries + notes + opps
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FilterBar(selection: $filter)

                // List
                List {
                    // Optional Favorites section (for All only, exclude notes edit context)
                    let favs = filteredEntries.filter { favoriteIDs.contains($0.id) }
                    if !favs.isEmpty && searchText.isEmpty && filter == .all {
                        Section("Favorites") {
                            ForEach(favs) { entry in
                                row(entry)
                            }
                        }
                    }

                    // Notes section (with swipe-to-delete and reordering if desired)
                    if filter == .notes {
                        Section("My Notes") {
                            ForEach(notes, id: \.id) { entry in
                                row(entry) // routes to editor
                            }
                            .onDelete(perform: deleteNotes)
                        }
                    }

                    // Group by kind for other sections
                    ForEach(sectionKindsToShow, id: \.self) { kind in
                        let items = filteredEntries.filter { $0.kind == kind && !(filter == .notes && kind == .note) }
                        if !items.isEmpty {
                            Section(kind.rawValue) {
                                ForEach(items) { entry in
                                    row(entry)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Learn")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search terms, guides, links")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            addNote()
                        } label: {
                            Label("New note", systemImage: "square.and.pencil")
                        }

                        ShareLink(item: URL(string: "https://github.com/")!,
                                  subject: Text("Snowbird Learn Resources"),
                                  message: Text("Quick reference links and notes.")) {
                            Label("Share…", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More actions")
                }
            }
            .onAppear {
                seedOpportunitiesIfNeeded()
            }
        }
    }

    // MARK: - Computed: filter + sections

    private var sectionKindsToShow: [LearnEntry.Kind] {
        switch filter {
        case .all:            return [.glossary, .guide, .link, .note, .opportunity]
        case .glossary:       return [.glossary]
        case .guides:         return [.guide]
        case .links:          return [.link]
        case .notes:          return [.note]
        case .opportunities:  return [.opportunity]
        }
    }

    private var filteredEntries: [LearnEntry] {
        var result: [LearnEntry]
        switch filter {
        case .all:           result = allEntries
        case .glossary:      result = allEntries.filter { $0.kind == .glossary }
        case .guides:        result = allEntries.filter { $0.kind == .guide }
        case .links:         result = allEntries.filter { $0.kind == .link }
        case .notes:         result = notes // use notes array directly to enable delete
        case .opportunities: result = allEntries.filter { $0.kind == .opportunity }
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { entry in
                entry.title.lowercased().contains(q) ||
                (entry.subtitle?.lowercased().contains(q) ?? false) ||
                entry.tags.joined(separator: " ").lowercased().contains(q) ||
                (entry.content?.lowercased().contains(q) ?? false) ||
                (entry.url?.absoluteString.lowercased().contains(q) ?? false)
            }
        }

        // Sort: favorites first (in All), then title A→Z
        if filter == .all {
            result.sort {
                let f0 = favoriteIDs.contains($0.id), f1 = favoriteIDs.contains($1.id)
                return f0 == f1
                    ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    : f0 && !f1
            }
            return result
        }

        return result.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(_ entry: LearnEntry) -> some View {
        // Notes route to editor; others use detail/link view
        if entry.kind == .note {
            NavigationLink {
                LearnNoteEditor(
                    entry: bindingForNote(id: entry.id),
                    onDelete: { deleteNote(id: entry.id) }
                )
            } label: {
                listRowLabel(entry)
            }
            .swipeActions {
                Button(role: .destructive) { deleteNote(id: entry.id) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            NavigationLink {
                LearnDetailView(entry: entry,
                                isFavorite: favoriteBinding(for: entry.id))
            } label: {
                listRowLabel(entry)
            }
        }
    }

    private func listRowLabel(_ entry: LearnEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.kind.icon)
                .foregroundStyle(.secondary)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                if let subtitle = entry.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if !entry.tags.isEmpty {
                    TagsView(tags: entry.tags)
                }
            }

            Spacer()

            if favoriteIDs.contains(entry.id) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Favorites

    private func favoriteBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { favoriteIDs.contains(id) },
            set: { isFav in
                var set = favoriteIDs
                if isFav { set.insert(id) } else { set.remove(id) }
                favoriteIDs = set
            }
        )
    }

    // MARK: - Notes: add / delete / binding

    private func addNote() {
        var current = notes
        current.insert(
            LearnEntry(
                title: "Untitled Note",
                // subtitle: "Tap to edit",   // ← remove this line
                kind: .note,
                content: """
                # Untitled Note

                Start typing here. You can use **bold**, _italics_, lists, and headings.
                """,
                tags: ["personal", "note"]
            ),
            at: 0
        )
        notes = current
        filter = .notes
    }

    private func deleteNotes(at offsets: IndexSet) {
        var current = notes
        current.remove(atOffsets: offsets)
        notes = current
    }

    private func deleteNote(id: UUID) {
        var current = notes
        current.removeAll { $0.id == id }
        notes = current
    }

    private func bindingForNote(id: UUID) -> Binding<LearnEntry> {
        Binding<LearnEntry>(
            get: {
                notes.first(where: { $0.id == id })!
            },
            set: { updated in
                var current = notes
                if let idx = current.firstIndex(where: { $0.id == id }) {
                    current[idx] = updated
                    notes = current
                }
            }
        )
    }

    // MARK: - Opportunities: seed once

    private func seedOpportunitiesIfNeeded() {
        guard !oppsSeeded else { return }
        opps = seededOpportunities()
        oppsSeeded = true
    }

    private func reseedOpportunities() {
        opps = seededOpportunities()
    }

    private func seededOpportunities() -> [LearnEntry] {
        [
            LearnEntry(
                title: "AcreTrader",
                subtitle: "Farmland investing platform",
                kind: .opportunity,
                content: "Invest in U.S. farmland through curated offerings; long-term, income + appreciation potential.",
                url: URL(string: "https://acretrader.com/"),
                tags: ["real assets", "farmland", "income"]
            ),
            LearnEntry(
                title: "Royalty Exchange (Auctions)",
                subtitle: "Music royalty auctions",
                kind: .opportunity,
                content: "Bid on music royalty streams; returns tied to catalog performance.",
                url: URL(string: "https://auctions.royaltyexchange.com/overview"),
                tags: ["royalties", "music", "cash flow"]
            ),
            LearnEntry(
                title: "CrowdStreet",
                subtitle: "Commercial real estate marketplace",
                kind: .opportunity,
                content: "Access CRE deals across sponsors, strategies, and geographies.",
                url: URL(string: "https://crowdstreet.com/"),
                tags: ["real estate", "CRE", "marketplace"]
            ),
            LearnEntry(
                title: "EnergyNet",
                subtitle: "Oil & gas asset auctions",
                kind: .opportunity,
                content: "Online marketplace for upstream oil & gas interests and related assets.",
                url: URL(string: "https://www.energynet.com/"),
                tags: ["energy", "oil & gas", "auctions"]
            ),
            LearnEntry(
                title: "LandGate",
                subtitle: "Land & resource valuations and listings",
                kind: .opportunity,
                content: "Data platform and marketplace for land, minerals, and renewables siting.",
                url: URL(string: "https://www.landgate.com/"),
                tags: ["land", "data", "renewables"]
            ),
            LearnEntry(
                title: "U.S. Mineral Exchange",
                subtitle: "Mineral rights marketplace",
                kind: .opportunity,
                content: "Buy/sell mineral rights and royalties with education resources.",
                url: URL(string: "https://www.usmineralexchange.com/"),
                tags: ["minerals", "royalties", "energy"]
            ),
            LearnEntry(
                title: "Pecan Estimate",
                subtitle: "Orchard valuation & yield tools",
                kind: .opportunity,
                content: "Niche tool for pecan orchards—useful in ag investing due diligence.",
                url: URL(string: "https://pecanestimate.com/"),
                tags: ["agriculture", "tools", "valuation"]
            )
        ]
    }
}

// MARK: - Detail View (read-only for non-note types)

private struct LearnDetailView: View {
    let entry: LearnEntry
    @Binding var isFavorite: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: entry.kind.icon)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(entry.title)
                            .font(.title3).fontWeight(.semibold)
                        if let subtitle = entry.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                if !entry.tags.isEmpty {
                    TagsView(tags: entry.tags)
                }

                Group {
                    if let md = entry.content, !md.isEmpty {
                        Text(.init(md))
                            .font(.body)
                            .textSelection(.enabled)
                    } else if let url = entry.url {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Open Website")
                                .font(.headline)
                            Link(destination: url) {
                                Label(url.absoluteString, systemImage: "safari")
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    } else {
                        Text("No content yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 12)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { isFavorite.toggle() } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                }
                if let url = entry.url {
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                } else if let content = entry.content {
                    ShareLink(item: content.data(using: .utf8) ?? Data(),
                              preview: SharePreview(entry.title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - Note Editor (editable)

private struct LearnNoteEditor: View {
    @Binding var entry: LearnEntry
    var onDelete: () -> Void

    @FocusState private var focused: Field?
    enum Field { case title, subtitle, content }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $entry.title)
                    .focused($focused, equals: .title)
            }

            Section("Content") {
                TextEditor(text: Binding($entry.content, replacingNilWith: """
                # Note

                Start typing here. Use **bold**, _italics_, lists, and headings.
                """))
                .frame(minHeight: 200)
                .font(.body.monospaced())
            }

            if !entry.tags.isEmpty {
                Section("Tags") {
                    TagsView(tags: entry.tags)
                }
            }
        }
        .navigationTitle("Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
            }
        }
        .onAppear {
            // Focus title on first open if empty
            if entry.title.trimmingCharacters(in: .whitespaces).isEmpty {
                focused = .title
            }
        }
    }
}

// MARK: - Small Tag Chips

private struct TagsView: View {
    var tags: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.15), in: Capsule())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Tag \(tag)")
                }
            }
        }
    }
}

private struct FilterBar: View {
    @Binding var selection: LearnView.Filter
    let allCases = LearnView.Filter.allCases

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allCases) { f in
                    Button {
                        selection = f
                    } label: {
                        Text(f.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selection == f ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12), in: Capsule())
                            .overlay(
                                Capsule().stroke(selection == f ? Color.accentColor : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}

// MARK: - Helpers

private extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith fallback: String) {
        self.init(
            get: { source.wrappedValue ?? fallback },
            set: { newValue in
                source.wrappedValue = newValue.isEmpty ? nil : newValue
            }
        )
    }
}
// MARK: - Preview

#Preview {
    LearnView()
}
