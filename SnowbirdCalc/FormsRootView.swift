import SwiftUI

struct FormsRootView: View {
    @State private var selectedTemplate: FormTemplate?
    @State private var isPresenting = false
    @State private var loadError: String?

    private let directory: DirectoryStore
    private let idService = ResolutionIdService()

    /// Template file stems (without .json)
    private let templateIds = [
        "resolution.distribution.v1",
        "resolution.bank.open.v1",
        "resolution.officer.appointment.v1"
    ]

    // MARK: - Init
    init() {
        let bundle = Bundle.main

        // Load Entities/entities.json (prefer Entities/ subdir; fall back to root)
        let entitiesURL =
            bundle.url(forResource: "entities", withExtension: "json", subdirectory: "Entities") ??
            bundle.url(forResource: "entities", withExtension: "json")

        if let url = entitiesURL, let store = try? DirectoryStore(jsonURL: url) {
            self.directory = store
            print("✅ Loaded entities from:", url.path)
        } else {
            print("⚠️ entities.json not found in Entities/ or bundle root. Seeding empty directory.")
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
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Forms")
        .sheet(isPresented: $isPresenting) {
            if let tmpl = selectedTemplate {
                DynamicFormView(template: tmpl, directory: directory, idService: idService)
            }
        }
        .alert("Template missing", isPresented: .constant(loadError != nil), actions: {
            Button("OK") { loadError = nil }
        }, message: {
            Text(loadError ?? "")
        })
        // 🔎 Log when the Forms tab actually appears
        .onAppear {
            let bundle = Bundle.main
            if let root = bundle.resourcePath,
               let sub = try? FileManager.default.subpathsOfDirectory(atPath: root) {
                let jsons = sub.filter { $0.hasSuffix(".json") }
                print("📦 (onAppear) JSON in bundle:", jsons)
            }
        }
    }

    // MARK: - Actions
    private func openTemplate(_ name: String) {
        // 🔎 Log at tap time so we see what the bundle contains right now
        let bundle = Bundle.main
        if let root = bundle.resourcePath,
           let sub = try? FileManager.default.subpathsOfDirectory(atPath: root) {
            print("🧭 trying to open:", name)
            print("📦 (tap) JSON in bundle:", sub.filter { $0.hasSuffix(".json") })
        }

        guard let tmpl = loadTemplate(name) else {
            loadError = "Couldn’t load \(name).json. Make sure it’s included once in Templates/ (or bundle root) and spelled exactly."
            return
        }
        selectedTemplate = tmpl
        isPresenting = true
    }

    // MARK: - Loading helpers
    private func loadTemplate(_ name: String) -> FormTemplate? {
        let bundle = Bundle.main
        // Prefer Templates/ subdir; fall back to root
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Templates")
              ?? bundle.url(forResource: name, withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url) else {
            print("⚠️ \(name).json not found in Templates/ or root.")
            return nil
        }
        do {
            let t = try JSONDecoder().decode(FormTemplate.self, from: data)
            print("✅ Loaded template:", url.path)
            return t
        } catch {
            print("⚠️ Failed to decode \(name).json:", error)
            return nil
        }
    }

    // MARK: - Labels
    private func title(for id: String) -> String {
        switch id {
        case "resolution.distribution.v1":         return "Distribution Authorization"
        case "resolution.bank.open.v1":            return "Bank Account Opening"
        case "resolution.officer.appointment.v1":  return "Officer Appointment"
        default:                                   return id
        }
    }

    private func icon(for id: String) -> String {
        switch id {
        case "resolution.distribution.v1":         return "arrow.down.left.and.arrow.up.right"
        case "resolution.bank.open.v1":            return "banknote"
        case "resolution.officer.appointment.v1":  return "person.crop.rectangle"
        default:                                   return "doc.text"
        }
    }
}

// Minimal empty fallback; adjust to your DirectoryStore API if needed.
extension DirectoryStore {
    static var empty: DirectoryStore {
        // Create a tiny, valid JSON on disk so existing initializer can read it.
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("empty_entities.json")
        if !FileManager.default.fileExists(atPath: tmp.path) {
            let empty = Data(#"{ "version":1, "updatedAt":"", "entities":[] }"#.utf8)
            try? empty.write(to: tmp)
        }
        return (try? DirectoryStore(jsonURL: tmp))! // safe for dev; handle errors more gracefully in prod
    }
}
