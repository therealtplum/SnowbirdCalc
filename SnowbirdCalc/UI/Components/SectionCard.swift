import SwiftUI

/// A reusable card component for grouping related content with a title
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 6)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 1)
        }
    }
}

