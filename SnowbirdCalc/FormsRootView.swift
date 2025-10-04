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

    /// Use canonical template IDs (not filenames). Loader will resolve by id even if filenames change.
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
    private func openTemplate(_ id: String) {
        guard let tmpl = loadTemplate(byId: id) else {
            loadError = "Couldn’t load a template with id '\(id)'. Check Templates/ and JSON id."
            return
        }
        selectedTemplate = tmpl
    }

    // MARK: - Loader (robust)
    /// Loads a template by its `id` field, regardless of filename.
    private func loadTemplate(byId id: String) -> FormTemplate? {
        let bundle = Bundle.main

        // Fast path: try exact filename "id.json" in Templates/ then bundle root
        if let direct = bundle.url(forResource: id, withExtension: "json", subdirectory: "Templates")
            ?? bundle.url(forResource: id, withExtension: "json") {
            if let tmpl = decodeTemplate(at: direct) {
                print("✅ Loaded template by filename: \(direct.lastPathComponent)")
                return tmpl
            } else {
                print("⚠️ Found file but failed to decode: \(direct.lastPathComponent)")
            }
        } else {
            print("ℹ️ Direct file '\(id).json' not found. Scanning bundle for matching id…")
        }

        // Robust path: scan Templates/ dir, then bundle root, and match JSON `id`
        if let templatesDir = bundle.url(forResource: "Templates", withExtension: nil),
           let matched = scanDirectory(templatesDir, matchId: id) {
            return matched
        }
        if let bundleRoot = bundle.resourceURL,
           let matched = scanDirectory(bundleRoot, matchId: id) {
            return matched
        }

        print("❌ No template with id '\(id)' found in bundle.")
        return nil
    }

    /// Scans a directory for *.json files, decodes `id` cheaply, and returns the full template if ids match.
    private func scanDirectory(_ directory: URL, matchId: String) -> FormTemplate? {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return nil }

        for url in items where url.pathExtension.lowercased() == "json" {
            // Cheap pre-pass: only decode the "id" field
            struct Probe: Decodable { let id: String? }
            guard
                let data = try? Data(contentsOf: url),
                let probe = try? JSONDecoder().decode(Probe.self, from: data),
                probe.id == matchId
            else { continue }

            if let tmpl = try? JSONDecoder().decode(FormTemplate.self, from: data) {
                print("✅ Matched template id '\(matchId)' at \(url.lastPathComponent)")
                return tmpl
            } else {
                print("⚠️ Matched id but failed full decode at \(url.lastPathComponent)")
            }
        }
        return nil
    }

    private func decodeTemplate(at url: URL) -> FormTemplate? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FormTemplate.self, from: data)
    }

    // MARK: - UI helpers
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
