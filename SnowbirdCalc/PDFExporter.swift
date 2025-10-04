//
//  PDFExporter.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/2/25.
//


import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Public API
enum PDFExporter {
    /// Renders the given resolution into a PDF and returns a file URL you can share.
    /// - Parameters:
    ///   - title: Title shown on the document
    ///   - bodyMarkdown: The resolution body in Markdown (we'll render it nicely)
    ///   - includeLetterhead: If true, shows Image("SnowbirdLetterhead") at the top
    ///   - fileName: Base filename without extension
    static func exportResolutionPDF(title: String,
                                    bodyMarkdown: String,
                                    includeLetterhead: Bool,
                                    fileName: String = "Resolution") -> URL? {
        let view = ResolutionDocumentView(title: title,
                                          bodyMarkdown: bodyMarkdown,
                                          includeLetterhead: includeLetterhead)

        // Render as a long image first (simple and reliable)
        let contentWidth: CGFloat = 612 // 8.5 * 72 pt (US Letter width)
        let renderedImage = renderViewToImage(view: view
                                                .frame(maxWidth: contentWidth, alignment: .leading)
                                                .padding(.horizontal, 32)
                                                .padding(.vertical, 40)
        )

        guard let img = renderedImage else { return nil }

        // Write a single-page PDF using the image size (height grows with content)
        let pdfBounds = CGRect(origin: .zero, size: img.size)
        let tmpURL = temporaryPDFURL(fileName: fileName)

        let renderer = UIGraphicsPDFRenderer(bounds: pdfBounds)
        do {
            try renderer.writePDF(to: tmpURL) { ctx in
                ctx.beginPage()
                img.draw(in: pdfBounds)
            }
            return tmpURL
        } catch {
            print("⚠️ PDF write failed: \(error)")
            return nil
        }
    }
}

// MARK: - ResolutionDocumentView (PDF content)
fileprivate struct ResolutionDocumentView: View {
    let title: String
    let bodyMarkdown: String
    let includeLetterhead: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if includeLetterhead, let _ = UIImage(named: "SnowbirdLetterhead") {
                // The asset can be PNG/PDF; just add to Assets as "SnowbirdLetterhead"
                Image("SnowbirdLetterhead")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .padding(.bottom, 8)
            }

            Text(title)
                .font(.system(.title2, design: .serif))
                .bold()
                .padding(.bottom, 6)

            Divider()

            // Render markdown formatted body
            if let attributed = try? AttributedString(markdown: bodyMarkdown) {
                Text(attributed)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(bodyMarkdown)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Helpers
fileprivate func renderViewToImage<V: View>(view: V) -> UIImage? {
    let renderer = ImageRenderer(content: view)
    renderer.scale = UIScreen.main.scale
    // Prefer non-opaque so letterhead PNG with transparency looks right
    if #available(iOS 17.0, *) {
        renderer.isOpaque = false
    }
    return renderer.uiImage
}

fileprivate func temporaryPDFURL(fileName: String) -> URL {
    let safe = fileName.replacingOccurrences(of: "/", with: "-")
    return URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(safe)
        .appendingPathExtension("pdf")
}

// MARK: - ShareSheet wrapper (SwiftUI)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}