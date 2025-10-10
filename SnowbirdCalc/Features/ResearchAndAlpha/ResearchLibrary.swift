import Foundation
import Combine
import PDFKit
import UIKit

@MainActor
final class ResearchLibrary: ObservableObject {
    @Published private(set) var allReports: [ResearchReport] = []
    @Published var searchText: String = ""
    @Published var activeTags: Set<String> = []
    @Published var dateFilter: DateInterval? = nil
    @Published var sortDescendingByDate: Bool = true

    private var thumbCache = NSCache<NSURL, UIImage>()

    init() { reload() }

    /// Rescans the bundle off the main actor and publishes back on main.
    func reload() {
        Task.detached(priority: .userInitiated) {
            let items = await Self.scanBundle()
            await MainActor.run {
                let reports = items
                    .map { item in
                        ResearchReport(
                            title: item.title,
                            summary: item.summary,
                            publishedAt: item.publishedAt,
                            tags: item.tags,
                            fileURL: item.fileURL
                        )
                    }
                    .sorted { $0.publishedAt > $1.publishedAt }

                self.allReports = reports
            }
        }
    }

    // MARK: Filtering
    var filteredReports: [ResearchReport] {
        var items = allReports
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            items = items.filter {
                $0.title.lowercased().contains(q)
                || ($0.summary?.lowercased().contains(q) ?? false)
                || $0.tags.joined(separator: " ").lowercased().contains(q)
            }
        }
        if !activeTags.isEmpty {
            items = items.filter { !activeTags.isDisjoint(with: Set($0.tags.map { $0.lowercased() })) }
        }
        if let window = dateFilter {
            items = items.filter { window.contains($0.publishedAt) }
        }
        if sortDescendingByDate { items.sort { $0.publishedAt > $1.publishedAt } }
        else { items.sort { $0.publishedAt < $1.publishedAt } }
        return items
    }

    var allTags: [String] {
        Array(Set(allReports.flatMap { $0.tags.map { $0.lowercased() } })).sorted()
    }

    // MARK: Thumbnails
    /// Supply displayScale from SwiftUI's `@Environment(\.displayScale)`
    func thumbnail(for report: ResearchReport,
                   targetSize: CGSize = CGSize(width: 120, height: 160),
                   displayScale: CGFloat = 2.0) async -> UIImage? {
        let key = report.fileURL as NSURL
        if let cached = thumbCache.object(forKey: key) { return cached }

        guard let doc = PDFDocument(url: report.fileURL),
              let page = doc.page(at: 0) else { return nil }

        let size = CGSize(width: targetSize.width * displayScale,
                          height: targetSize.height * displayScale)
        let img = page.thumbnail(of: size, for: .cropBox)
        thumbCache.setObject(img, forKey: key)
        return img
    }

    // MARK: Bundle Scanning
    /// Async to allow a main-actor hop for decoding if a hidden main-isolated conformance exists.
    static func scanBundle() async -> [(title: String, summary: String?, publishedAt: Date, tags: [String], fileURL: URL)] {
        var out: [(title: String, summary: String?, publishedAt: Date, tags: [String], fileURL: URL)] = []
        let fm = FileManager.default

        // Debug: where is the bundle?
        #if DEBUG
        print("🔎 bundle:", Bundle.main.bundlePath)
        #endif

        // Try 1: explicit folder reference
        let folderRef = Bundle.main.resourceURL?.appendingPathComponent("Research", isDirectory: true)
        var pdfs: [URL] = []

        if let dir = folderRef, (try? dir.checkResourceIsReachable()) == true {
            if let e = fm.enumerator(at: dir,
                                     includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                                     options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                while let obj = e.nextObject() {
                    if let url = obj as? URL, url.pathExtension.lowercased() == "pdf" {
                        pdfs.append(url)
                    }
                }
            }
            #if DEBUG
            print("🔹 Using folder ref at:", dir.path)
            #endif
        } else {
            // Try 2: PDFs under “Research/” subdirectory (no folder ref)
            let subdirPDFs = Bundle.main.urls(forResourcesWithExtension: "pdf", subdirectory: "Research") ?? []
            if !subdirPDFs.isEmpty {
                pdfs.append(contentsOf: subdirPDFs)
                #if DEBUG
                print("🔹 Using subdirectory scan: Research/ (found \(subdirPDFs.count))")
                #endif
            } else {
                // Try 3: Any PDFs anywhere in the bundle (last resort)
                let anyPDFs = Bundle.main.urls(forResourcesWithExtension: "pdf", subdirectory: nil) ?? []
                pdfs.append(contentsOf: anyPDFs)
                #if DEBUG
                print("🔹 Using global PDF scan (found \(anyPDFs.count))")
                #endif
            }
        }

        #if DEBUG
        print("📄 Found \(pdfs.count) PDF(s):")
        pdfs.forEach { print("   • \($0.path)") }
        #endif

        // Formatters
        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let isoSimple = ISO8601DateFormatter()
        let ymd = DateFormatter()
        ymd.calendar = .init(identifier: .gregorian)
        ymd.locale = .init(identifier: "en_US_POSIX")
        ymd.dateFormat = "yyyy-MM-dd"

        for url in pdfs {
            let base = url.deletingPathExtension().lastPathComponent
            var title = base.replacingOccurrences(of: "-", with: " ")
            var summary: String? = nil
            var tags: [String] = []
            var publishedAt: Date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()

            // Sidecar lookup: sibling or bundle/subdir match
            var sidecar = url.deletingLastPathComponent().appendingPathComponent("\(base).json")
            if (try? sidecar.checkResourceIsReachable()) != true {
                sidecar = Bundle.main.url(forResource: base, withExtension: "json", subdirectory: "Research")
                ?? Bundle.main.url(forResource: base, withExtension: "json")
                ?? sidecar
            }

            if (try? sidecar.checkResourceIsReachable()) == true,
               let data = try? Data(contentsOf: sidecar) {
                // Decode on the main actor to satisfy any accidental @MainActor conformance.
                let meta: ResearchSidecarDTO? = await MainActor.run {
                    try? JSONDecoder().decode(ResearchSidecarDTO.self, from: data)
                }
                if let meta {
                    if let t = meta.title, !t.isEmpty { title = t }
                    if let s = meta.summary { summary = s }
                    if let ts = meta.tags { tags = ts }
                    if let p = meta.publishedAt,
                       let d = isoFull.date(from: p) ?? isoSimple.date(from: p) ?? ymd.date(from: p) {
                        publishedAt = d
                    }
                }
            } else {
                // Tags from path segments between .../Research/.../file.pdf
                let comps = url.pathComponents
                if let i = comps.firstIndex(of: "Research"), i + 1 < comps.count - 1 {
                    tags = Array(comps[(i+1)..<(comps.count-1)]).map { $0.lowercased() }
                }
            }

            out.append((
                title: title,
                summary: summary,
                publishedAt: publishedAt,
                tags: tags,
                fileURL: url
            ))
        }

        out.sort { $0.publishedAt > $1.publishedAt }
        return out
    }
}

