//
//  PDFViewerView.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/9/25.
//


import SwiftUI
import PDFKit

struct PDFViewerView: View, Identifiable {
    var id: UUID { report.id }
    let report: ResearchReport

    var body: some View {
        NavigationStack {
            PDFKitRepresentedView(url: report.fileURL)
                .navigationTitle(report.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: report.fileURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

private struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemBackground
        if let doc = PDFDocument(url: url) {
            view.document = doc
        }
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url, let doc = PDFDocument(url: url) {
            uiView.document = doc
        }
    }
}