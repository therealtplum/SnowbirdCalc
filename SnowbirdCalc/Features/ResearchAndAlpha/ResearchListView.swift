//
//  ResearchListView.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/9/25.
//


import SwiftUI

public struct ResearchListView: View {
    @StateObject private var lib = ResearchLibrary()
    @State private var selectedReport: ResearchReport?
    @State private var showFilters = false
    @State private var dateRange: ClosedRange<Date> = {
        let now = Date()
        let aYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        return aYearAgo...now
    }()
    @State private var useDateFilter = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if lib.filteredReports.isEmpty {
                    ContentUnavailableView("No research yet",
                                           systemImage: "doc.richtext",
                                           description: Text("Drop PDFs into the app bundle’s Research folder. Optional JSON sidecars add title, tags, and summary."))
                } else {
                    List(lib.filteredReports) { report in
                        Button {
                            selectedReport = report
                        } label: {
                            ResearchRow(report: report, lib: lib)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Research")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $lib.sortDescendingByDate) {
                            Text("Newest first").tag(true)
                            Text("Oldest first").tag(false)
                        }
                        .pickerStyle(.inline)

                        Toggle(isOn: $useDateFilter.animation()) { Text("Filter by Date") }

                        if useDateFilter {
                            DatePicker("From", selection: Binding(
                                get: { dateRange.lowerBound },
                                set: { dateRange = $0...dateRange.upperBound }
                            ), displayedComponents: .date)

                            DatePicker("To", selection: Binding(
                                get: { dateRange.upperBound },
                                set: { dateRange = dateRange.lowerBound...$0 }
                            ), displayedComponents: .date)

                            Button("Apply Date Filter") {
                                lib.dateFilter = DateInterval(start: dateRange.lowerBound,
                                                              end: Calendar.current.date(byAdding: .day, value: 1, to: dateRange.upperBound) ?? dateRange.upperBound)
                            }
                            Button("Clear Date Filter") {
                                lib.dateFilter = nil
                                useDateFilter = false
                            }
                        }
                    } label: {
                        Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { lib.reload() }
                        } label: {
                            Label("Rescan Library", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $lib.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search titles, tags, summaries"))
            .safeAreaInset(edge: .top) {
                if !lib.allTags.isEmpty {
                    TagChips(allTags: lib.allTags, active: $lib.activeTags)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
            }
            .sheet(item: $selectedReport) { report in
                PDFViewerView(report: report)
            }
        }
    }
}

private struct ResearchRow: View {
    let report: ResearchReport
    @ObservedObject var lib: ResearchLibrary
    @State private var thumb: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08))
                if let t = thumb {
                    Image(uiImage: t)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "doc.richtext.fill")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                Task { self.thumb = await lib.thumbnail(for: report, targetSize: CGSize(width: 144, height: 192)) }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(report.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let s = report.summary, !s.isEmpty {
                    Text(s)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(report.publishedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !report.tags.isEmpty {
                        Text("•").font(.caption).foregroundStyle(.tertiary)
                        Text(report.tags.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

/// Horizontal chip filter
private struct TagChips: View {
    let allTags: [String]
    @Binding var active: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allTags, id: \.self) { tag in
                    let isOn = active.contains(tag)
                    Button {
                        if isOn { active.remove(tag) } else { active.insert(tag) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .imageScale(.small)
                            Text(tag.capitalized)
                                .font(.caption)
                                .bold()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(isOn ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }
}
