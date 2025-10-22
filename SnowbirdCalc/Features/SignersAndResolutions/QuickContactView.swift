// QuickContactView.swift
import SwiftUI
import UniformTypeIdentifiers
import Contacts
import ContactsUI
import UIKit

// MARK: - iOS 16+ Transferable for vCard
@available(iOS 16.0, *)
struct VCardTransfer: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .vCard) { item in
            item.data
        }
        .suggestedFileName({ item in
            item.filename
        })
    }
}

@MainActor
struct QuickContactView: View {
    // MARK: - Sheet Router (editor only)
    private enum SheetKind: Identifiable {
        case editor(id: UUID = UUID())
        var id: UUID {
            switch self {
            case .editor(let id): return id
            }
        }
    }

    // MARK: - State
    @State private var card = BusinessCardStore.load()
    @State private var qrImage: Image? = nil
    @State private var activeSheet: SheetKind? = nil
    @State private var prebuiltVCardData: Data = Data() // prepared vCard bytes
    @State private var isPresentingSomething = false    // gate to avoid presentation races

    // Retained delegate to dismiss CNContactViewController
    @State private var contactDelegate = ContactDelegate()

    // MARK: - Derived
    private var mecard: String { card.meCardText() }
    private var vcardText: String { card.vCardText() }
    private var vcardFileName: String {
        let base = card.fullName.isEmpty ? "Contact" : card.fullName
        return base
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text(card.fullName)
                        .font(.largeTitle).bold()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // QR Code (cached)
                (qrImage ?? Image(systemName: "qrcode"))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 240, height: 240)
                    .accessibilityLabel("QR code for \(card.fullName) contact")

                // Primary actions — system-consistent, readable in light/dark
                HStack(spacing: 12) {
                    // Primary: Share vCard
                    if #available(iOS 16.0, *) {
                        ShareLink(
                            item: VCardTransfer(data: prebuiltVCardData, filename: vcardFileName),
                            preview: SharePreview(vcardFileName, image: Image(systemName: "person.crop.square"))
                        ) {
                            Label("Share vCard", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(prebuiltVCardData.isEmpty || isPresentingSomething)
                        .accessibilityIdentifier("ShareVCardShareLink")
                    } else {
                        // iOS 15 fallback: activity controller with UTI + small async hop
                        Button {
                            guard !isPresentingSomething, !prebuiltVCardData.isEmpty else { return }
                            let source = VCardActivityItemSource( // <-- keep ONLY one definition of this class (e.g., in VCardSharing.swift)
                                data: prebuiltVCardData,
                                filename: vcardFileName
                            )
                            presentActivity(with: [source])
                        } label: {
                            Label("Share vCard", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(prebuiltVCardData.isEmpty || isPresentingSomething)
                        .accessibilityIdentifier("ShareVCardButton_Fallback")
                    }

                    // Secondary: Copy vCard text
                    Button {
                        UIPasteboard.general.string = vcardText
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label("Copy vCard", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .accessibilityIdentifier("CopyVCardButton")
                }
                .controlSize(.large)

                // Quick info tiles
                VStack(alignment: .leading, spacing: 8) {
                    if !card.phone.isEmpty, let telURL = telURL {
                        Link(destination: telURL) {
                            Label(card.phone, systemImage: "phone.fill")
                        }
                    }
                    if !card.email.isEmpty, let mailURL = URL(string: "mailto:\(card.email)") {
                        Link(destination: mailURL) {
                            Label(card.email, systemImage: "envelope.fill")
                        }
                    }
                    if let siteURL = websiteURL {
                        Link(destination: siteURL) {
                            Label(card.website, systemImage: "globe")
                        }
                    }
                    if !locationText.isEmpty {
                        Label(locationText, systemImage: "mappin.and.ellipse")
                    }
                }
                .font(.body)
                .tint(.primary)
                .padding(.top, 8)

                // Editor trigger (routes through the single sheet)
                Button {
                    guard !isPresentingSomething else { return }
                    isPresentingSomething = true
                    activeSheet = .editor()
                } label: {
                    Label("Edit my details", systemImage: "pencil")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.large)
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle("Quick Contact")

        // Single unified sheet (only for editor). onDismiss resets the presentation gate.
        .sheet(item: $activeSheet, onDismiss: { isPresentingSomething = false }) { sheet in
            switch sheet {
            case .editor:
                EditorForm(card: $card) {
                    BusinessCardStore.save(card)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    activeSheet = nil
                    regenerateQR(from: mecard)
                    prepareVCardData() // keep Data current after edits
                }
            }
        }

        // Precompute visuals + share data
        .onAppear {
            regenerateQR(from: mecard)
            prepareVCardData()
        }
        .applyOnChange(of: mecard) { _, newValue in
            regenerateQR(from: newValue)
        }
        .applyOnChange(of: vcardText) { _, _ in
            prepareVCardData()
        }
    }

    // MARK: - Helpers

    private var headerSubtitle: String {
        let parts = [card.jobTitle, card.company].filter { !$0.isEmpty }
        return parts.joined(separator: " • ")
    }

    private var locationText: String {
        [card.city, card.region, card.country].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private var telURL: URL? {
        let digits = card.phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }

    private var websiteURL: URL? {
        guard !card.website.isEmpty else { return nil }
        if let url = URL(string: card.website), url.scheme != nil { return url }
        return URL(string: "https://\(card.website)")
    }

    // QRCodeRenderer.image(...) is @MainActor — keep it simple & fast
    private func regenerateQR(from payload: String) {
        qrImage = QRCodeRenderer.image(from: payload, scale: 10)
    }

    // Prepare vCard bytes off-main (Data is Sendable; keeps UI snappy)
    private func prepareVCardData() {
        let text = vcardText
        Task.detached(priority: .utility) {
            let data = text.data(using: .utf8) ?? Data()
            await MainActor.run { self.prebuiltVCardData = data }
        }
    }

    // iOS 15 fallback to present share sheet with UTI + small hop to avoid gesture timeout
    private func presentActivity(with items: [Any]) {
        Task { @MainActor in
            guard !isPresentingSomething else { return }
            isPresentingSomething = true

            // Small hop lets layout settle and reduces "gesture gate timed out" on some devices
            try? await Task.sleep(nanoseconds: 120_000_000)

            let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
            vc.completionWithItemsHandler = { _, _, _, _ in
                Task { @MainActor in self.isPresentingSomething = false }
            }

            guard
                let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })?
                    .windows.first(where: { $0.isKeyWindow }),
                let root = window.rootViewController
            else {
                isPresentingSomething = false
                return
            }
            root.present(vc, animated: true)
        }
    }

    // MARK: Add to Contacts (no Share sheet)
    private func presentAddToContacts() {
        guard
            let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })?
                .windows.first(where: { $0.isKeyWindow }),
            let root = window.rootViewController
        else { return }

        let c = CNMutableContact()
        c.givenName = card.givenName
        c.familyName = card.familyName
        if !card.jobTitle.isEmpty { c.jobTitle = card.jobTitle }
        if !card.company.isEmpty { c.organizationName = card.company }
        if !card.email.isEmpty {
            c.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: card.email as NSString)]
        }
        if !card.phone.isEmpty {
            let digits = card.phone.filter { $0.isNumber || $0 == "+" }
            c.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: digits))]
        }
        if !card.website.isEmpty {
            let urlString = card.website.hasPrefix("http") ? card.website : "https://\(card.website)"
            c.urlAddresses = [CNLabeledValue(label: CNLabelURLAddressHomePage, value: urlString as NSString)]
        }
        if !card.city.isEmpty || !card.region.isEmpty || !card.country.isEmpty {
            let addr = CNMutablePostalAddress()
            addr.city = card.city
            addr.state = card.region
            addr.country = card.country
            c.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: addr)]
        }

        let vc = CNContactViewController(forNewContact: c)
        vc.contactStore = CNContactStore()
        vc.delegate = contactDelegate

        let nav = UINavigationController(rootViewController: vc)
        root.present(nav, animated: true)
    }
}

// MARK: - Delegate to dismiss CNContactViewController
final class ContactDelegate: NSObject, CNContactViewControllerDelegate {
    func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
        viewController.dismiss(animated: true)
    }
}

// MARK: - Editor (Sheet Content)

@MainActor
private struct EditorForm: View {
    @Binding var card: BusinessCard
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First", text: $card.givenName)
                    TextField("Last", text: $card.familyName)
                }
                Section("Work") {
                    TextField("Title", text: $card.jobTitle)
                    TextField("Company", text: $card.company)
                    TextField("Website", text: $card.website)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                Section("Contact") {
                    TextField("Phone", text: $card.phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $card.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Location") {
                    TextField("City", text: $card.city)
                    TextField("Region/State", text: $card.region)
                    TextField("Country", text: $card.country)
                }
            }
            .navigationTitle("Edit Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onDone() }
                        .bold()
                }
            }
        }
    }
}

// MARK: - Back-compat helper for onChange (iOS 15–17)

private extension View {
    /// Uses the iOS 17 two-parameter `onChange` when available; falls back to the iOS 15 form.
    @ViewBuilder
    func applyOnChange<Value: Equatable>(
        of value: Value,
        _ action: @escaping (_ oldValue: Value, _ newValue: Value) -> Void
    ) -> some View {
        if #available(iOS 17, *) {
            self.onChange(of: value, action)
        } else {
            self.onChange(of: value) { newValue in
                action(value, newValue)
            }
        }
    }
}
