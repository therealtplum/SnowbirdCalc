import SwiftUI
import UniformTypeIdentifiers

struct UtilityItem: Identifiable, Hashable, Equatable, Transferable {
    enum Destination: Hashable {
        case scenarios
        case mineralRights
        case research
        case quickContact
        case none
    }

    let id: UUID
    var title: String
    var subtitle: String
    var systemImage: String
    var destination: Destination

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .json) { item in
            try JSONEncoder().encode(TransferProxy(from: item))
        } importing: { data in
            let proxy = try JSONDecoder().decode(TransferProxy.self, from: data)
            return proxy.toItem()
        }
    }

    private struct TransferProxy: Codable {
        let id: UUID
        let title: String
        let subtitle: String
        let systemImage: String
        let destination: DestinationProxy

        init(from item: UtilityItem) {
            self.id = item.id
            self.title = item.title
            self.subtitle = item.subtitle
            self.systemImage = item.systemImage
            self.destination = DestinationProxy(from: item.destination)
        }

        func toItem() -> UtilityItem {
            UtilityItem(
                id: id,
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                destination: destination.toDestination()
            )
        }
    }

    private enum DestinationProxy: String, Codable {
        case scenarios
        case mineralRights
        case research
        case quickContact
        case none

        init(from destination: Destination) {
            switch destination {
            case .scenarios: self = .scenarios
            case .mineralRights: self = .mineralRights
            case .research: self = .research
            case .quickContact: self = .quickContact
            case .none: self = .none
            }
        }

        func toDestination() -> UtilityItem.Destination {
            switch self {
            case .scenarios: return .scenarios
            case .mineralRights: return .mineralRights
            case .research: return .research
            case .quickContact: return .quickContact
            case .none: return .none
            }
        }
    }

    static func == (lhs: UtilityItem, rhs: UtilityItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct UtilitiesView: View {
    @EnvironmentObject var vm: AppViewModel

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 16)
    ]

    @State private var items: [UtilityItem] = []
    @State private var draggingItem: UtilityItem?

    var body: some View {
        ScrollView {
            grid
                .padding(16)
        }
        .navigationTitle("Utilities")
        .background(Color(.systemGroupedBackground))
        .onAppear(perform: buildInitialItemsIfNeeded)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(items) { item in
                tile(for: item)
            }
        }
    }

    private func buildInitialItemsIfNeeded() {
        if items.isEmpty {
            items = [
                UtilityItem(
                    id: UUID(),
                    title: "Scenarios",
                    subtitle: "Model outcomes",
                    systemImage: "list.bullet.rectangle",
                    destination: .scenarios
                ),
                UtilityItem(
                    id: UUID(),
                    title: "Mineral Rights",
                    subtitle: "Find and evaluate",
                    systemImage: "hammer",
                    destination: .mineralRights
                ),
                UtilityItem(
                    id: UUID(),
                    title: "Research",
                    subtitle: "Internal memos",
                    systemImage: "doc.text.magnifyingglass",
                    destination: .research
                ),
                UtilityItem(
                    id: UUID(),
                    title: "Quick Contact",
                    subtitle: "Share business card",
                    systemImage: "qrcode",
                    destination: .quickContact
                ),
                UtilityItem(
                    id: UUID(),
                    title: "Calculator",
                    subtitle: "Quick math",
                    systemImage: "function",
                    destination: .none
                ),
                UtilityItem(
                    id: UUID(),
                    title: "Exports",
                    subtitle: "PDF / DOCX",
                    systemImage: "square.and.arrow.up",
                    destination: .none
                ),
                UtilityItem(
                    id: UUID(),
                    title: "Logo & Theme",
                    subtitle: "App appearance",
                    systemImage: "paintpalette",
                    destination: .none
                )
            ]
        }
    }

    @ViewBuilder
    private func tile(for item: UtilityItem) -> some View {
        UtilityItemCell(item: item)
            .overlay(overlayFor(item))
            .onLongPressGesture(minimumDuration: 0.01) { draggingItem = item }
            .draggable(item) {
                UtilityTile(
                    title: item.title,
                    subtitle: item.subtitle,
                    systemImage: item.systemImage
                )
                .frame(width: 160, height: 140)
            }
            .dropDestination(for: UtilityItem.self) { droppedItems, _ in
                handleDrop(droppedItems: droppedItems, over: item)
            } isTargeted: { _ in }
            .onChange(of: items) { _, _ in
                draggingItem = nil
            }
    }

    @ViewBuilder
    private func overlayFor(_ item: UtilityItem) -> some View {
        if draggingItem == item {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.tint, lineWidth: 2)
        } else {
            EmptyView()
        }
    }

    @discardableResult
    private func handleDrop(droppedItems: [UtilityItem], over target: UtilityItem) -> Bool {
        guard let source = droppedItems.first,
              let fromIndex = items.firstIndex(of: source),
              let toIndex = items.firstIndex(of: target) else { return false }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            if fromIndex != toIndex {
                let moved = items.remove(at: fromIndex)
                items.insert(moved, at: toIndex)
            }
        }
        return true
    }
}

// MARK: - Tile View

struct UtilityTile: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.15))
                )
                .accessibilityHidden(true)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minHeight: 120, maxHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .overlay(
            // Subtle border for both light/dark
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.separator.opacity(0.5))
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

struct UtilityItemCell: View {
    @EnvironmentObject var vm: AppViewModel
    let item: UtilityItem

    var body: some View {
        Group {
            switch item.destination {
            case .scenarios:
                NavigationLink {
                    ScenarioListView().environmentObject(vm)
                } label: {
                    UtilityTile(
                        title: item.title,
                        subtitle: item.subtitle,
                        systemImage: item.systemImage
                    )
                }
                .buttonStyle(.plain)
            case .mineralRights:
                NavigationLink { MineralRightsView() } label: {
                    UtilityTile(
                        title: item.title,
                        subtitle: item.subtitle,
                        systemImage: item.systemImage
                    )
                }
                .buttonStyle(.plain)
            case .research:
                NavigationLink { ResearchListView() } label: {
                    UtilityTile(
                        title: item.title,
                        subtitle: item.subtitle,
                        systemImage: item.systemImage
                    )
                }
                .buttonStyle(.plain)
            case .quickContact:
                NavigationLink { QuickContactView() } label: {
                    UtilityTile(
                        title: item.title,
                        subtitle: item.subtitle,
                        systemImage: item.systemImage
                    )
                }
                .buttonStyle(.plain)
            case .none:
                UtilityTile(
                    title: item.title,
                    subtitle: item.subtitle,
                    systemImage: item.systemImage
                )
                .opacity(0.45)
            }
        }
    }
}

#Preview {
    NavigationStack {
        UtilitiesView()
            .environmentObject(AppViewModel())
    }
}
