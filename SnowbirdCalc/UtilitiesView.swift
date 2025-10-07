import SwiftUI

struct UtilitiesView: View {
    @EnvironmentObject var vm: AppViewModel

    // Adaptive grid that looks good on iPhone + iPad
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                // SCENARIOS (active)
                NavigationLink {
                    ScenarioListView()
                        .environmentObject(vm)
                } label: {
                    UtilityTile(
                        title: "Scenarios",
                        subtitle: "Model outcomes",
                        systemImage: "list.bullet.rectangle"
                    )
                }
                .buttonStyle(.plain)

                // EXAMPLES OF FUTURE UTILITIES (placeholders)
                UtilityTile(
                    title: "Calculator",
                    subtitle: "Quick math",
                    systemImage: "function"
                )
                .opacity(0.45)

                UtilityTile(
                    title: "Exports",
                    subtitle: "PDF / DOCX",
                    systemImage: "square.and.arrow.up"
                )
                .opacity(0.45)

                UtilityTile(
                    title: "Logo & Theme",
                    subtitle: "App appearance",
                    systemImage: "paintpalette"
                )
                .opacity(0.45)
            }
            .padding(16)
        }
        .navigationTitle("Utilities")
        .background(Color(.systemGroupedBackground))
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

// MARK: - Preview

#Preview {
    NavigationStack {
        UtilitiesView()
            .environmentObject(AppViewModel())
    }
}
