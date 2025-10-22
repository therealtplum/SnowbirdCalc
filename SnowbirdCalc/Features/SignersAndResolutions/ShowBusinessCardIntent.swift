// ShowBusinessCardIntent.swift
import AppIntents
import SwiftUI

@available(iOS 17, *)
struct ShowBusinessCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Show My Business Card"
    static var description = IntentDescription("Opens your QR code and vCard for quick sharing.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        .result(
            dialog: "Here’s your card.",
            view: NavigationStack { QuickContactView() } // OK now
        )
    }
}
