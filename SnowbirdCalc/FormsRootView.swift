import SwiftUI

struct FormsRootView: View {
    // MARK: - State
    @State private var selectedTemplate: FormTemplate?
    @State private var loadError: String?
    @State private var showSigners = false

    // MARK: - Environment
    @EnvironmentObject private var signerStore: SignerStore

    // MARK: - Services
    private let directory: DirectoryStore
    private let idService = ResolutionIdService()

    private let templateIds = [
        "resolution.distribution.v1",
        "resolution.bank.open.v1",
        "resolution.officer.appointment.v1"
    ]

    // MARK: - Init
    init() {
        let bundle = Bundle.main
        let entitiesURL =
            bundle.url(forResource: "entities", withExtension: "json", subdirectory: "Entities") ??
            bundle.url(forResource: "entities", withExtension: "json")

        if let url = entitiesURL, let store = try? DirectoryStore(jsonURL: url) {
            self.directory = store
            print("✅ Loaded entities from:", url.path)
        } else {
            print("⚠️ entities.json not found; using empty directory.")
            self.directory = DirectoryStore.empty
        }
    }

    // MARK: - Body
    var body: some View {
        List {
            Section("Resolutions") {
                ForEach(templateIds, id: \.self) { id in
                    Button {
                        openTemplate(id)
                    } label: {
                        HStack {
                            Image(systemName: icon(for: id))
                            Text(title(for: id))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            // Optional: quick access inside the list too (keep or remove)
            Section("Administration") {
                Button {
                    showSigners = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.rectangle.stack")
                        Text("Manage Signatories")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle("Forms")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSigners = true
                } label: {
                    Label("Authorized Signatories", systemImage: "person.crop.rectangle.stack")
                }
            }
        }
        // Present preview form only when selectedTemplate is non-nil
        .sheet(item: $selectedTemplate) { tmpl in
            DynamicFormView(template: tmpl, directory: directory, idService: idService)
                // signerStore is already available via environment, no need to inject again
        }
        // Present the Signers Manager
        .sheet(isPresented: $showSigners) {
            SignersManagerView()
                .environmentObject(signerStore) // Explicit is fine; inherited env also works
        }
        .alert("Template missing", isPresented: .constant(loadError != nil)) {
            Button("OK") { loadError = nil }
        } message: {
            Text(loadError ?? "")
        }
    }

    // MARK: - Actions
    private func openTemplate(_ name: String) {
        guard let tmpl = loadTemplate(name) else {
            loadError = "Couldn’t load \(name).json. Check Templates/ and filename."
            return
        }
        selectedTemplate = tmpl
    }

    // MARK: - Helpers
    private func loadTemplate(_ name: String) -> FormTemplate? {
        let bundle = Bundle.main
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Templates")
              ?? bundle.url(forResource: name, withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FormTemplate.self, from: data)
    }

    private func title(for id: String) -> String {
        switch id {
        case "resolution.distribution.v1":        return "Distribution Authorization"
        case "resolution.bank.open.v1":           return "Bank Account Opening"
        case "resolution.officer.appointment.v1": return "Officer Appointment"
        default:                                  return id
        }
    }

    private func icon(for id: String) -> String {
        switch id {
        case "resolution.distribution.v1":        return "arrow.down.left.and.arrow.up.right"
        case "resolution.bank.open.v1":           return "banknote"
        case "resolution.officer.appointment.v1": return "person.crop.rectangle"
        default:                                  return "doc.text"
        }
    }
}

// If FormTemplate already has `id: String` from JSON, this is enough:
extension FormTemplate: Identifiable {}

// Provide a safe empty directory fallback.
extension DirectoryStore {
    static var empty: DirectoryStore {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("empty_entities.json")
        if !FileManager.default.fileExists(atPath: tmp.path) {
            let minimal = #"{ "version":1, "updatedAt":"", "entities":[] }"#
            try? minimal.data(using: .utf8)?.write(to: tmp)
        }
        return try! DirectoryStore(jsonURL: tmp)
    }
}
