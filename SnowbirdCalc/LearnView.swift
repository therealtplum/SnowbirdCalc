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

        var icon: String {
            switch self {
            case .glossary: return "book.closed"
            case .guide:    return "lightbulb"
            case .link:     return "link"
            }
        }
    }

    let id: UUID
    var title: String
    var subtitle: String?
    var kind: Kind
    var content: String?
    var url: URL?
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

    // Make JSON 'id' optional; auto-generate if missing.
    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, kind, content, url, tags
    }

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

// MARK: - Sample Data (edit freely)
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

        var id: String { rawValue }
    }

    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var entries: [LearnEntry] = .loadFromBundle()
    @AppStorage("LearnView.favorites") private var favoriteIDsData: Data = Data()

    /// Single, correct declaration (with nonmutating setter).
    private var favoriteIDs: Set<UUID> {
        get {
            (try? JSONDecoder().decode(Set<UUID>.self, from: favoriteIDsData)) ?? []
        }
        nonmutating set {
            favoriteIDsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter
                Picker("Category", selection: $filter) {
                    ForEach(Filter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                // List
                List {
                    // Optional Favorites section
                    let favs = filteredEntries.filter { favoriteIDs.contains($0.id) }
                    if !favs.isEmpty && searchText.isEmpty && filter == .all {
                        Section("Favorites") {
                            ForEach(favs) { entry in
                                row(entry)
                            }
                        }
                    }

                    // Group by kind
                    ForEach(LearnEntry.Kind.allCases, id: \.self) { kind in
                        let items = filteredEntries.filter { $0.kind == kind && !favoriteIDs.contains($0.id) }
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
                            addYourOwnTemplate()
                        } label: {
                            Label("Add your own note", systemImage: "plus")
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
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(_ entry: LearnEntry) -> some View {
        NavigationLink {
            LearnDetailView(entry: entry,
                            isFavorite: favoriteBinding(for: entry.id))
        } label: {
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
    }

    // MARK: - Filtering

    private var filteredEntries: [LearnEntry] {
        var result = entries

        switch filter {
        case .all: break
        case .glossary:
            result = result.filter { $0.kind == .glossary }
        case .guides:
            result = result.filter { $0.kind == .guide }
        case .links:
            result = result.filter { $0.kind == .link }
        }

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = searchText.lowercased()
            result = result.filter { entry in
                entry.title.lowercased().contains(q) ||
                (entry.subtitle?.lowercased().contains(q) ?? false) ||
                entry.tags.joined(separator: " ").lowercased().contains(q) ||
                (entry.content?.lowercased().contains(q) ?? false)
            }
        }

        return result
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
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

    // MARK: - “Add your own” stub (basic for now)

    private func addYourOwnTemplate() {
        withAnimation {
            entries.insert(
                LearnEntry(
                    title: "My Note",
                    subtitle: "Tap to edit",
                    kind: .guide,
                    content: """
                    # My Note

                    Replace this with your own text. You can use **bold**, _italics_, lists, and headings.
                    """,
                    tags: ["personal", "note"]
                ),
                at: 0
            )
        }
    }
}

// MARK: - Detail View

private struct LearnDetailView: View {
    let entry: LearnEntry
    @Binding var isFavorite: Bool
    @State private var showShareSheet = false

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

                // Content or Link
                Group {
                    if let md = entry.content, !md.isEmpty {
                        Text(.init(md)) // Markdown-rendered
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
                Button {
                    isFavorite.toggle()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                }
                if let url = entry.url {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
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

// MARK: - Preview

#Preview {
    LearnView()
}
