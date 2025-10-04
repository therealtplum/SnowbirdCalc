//
//  DynamicFormView.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/2/25.
//

import SwiftUI
import Foundation

// MARK: - DynamicFormView
// SwiftUI renderer for FormTemplate
// Depends on: FormTemplateModels.swift, EntityDirectory.swift, ValuesPath.swift, ResolutionIdService.swift, MustacheLite.swift
// For PDF export, add PDFExporter.swift (provided) and an optional Assets entry named "SnowbirdLetterhead".

public struct DynamicFormView: View {
    public let template: FormTemplate
    public let directory: DirectoryStore
    public let idService: ResolutionIdService

    @State private var values: [String: Any] = [:]
    @State private var showPreview = false
    @State private var renderedTitle: String = ""
    @State private var renderedBody: String = ""
    @State private var formErrors: [String] = []

    public init(template: FormTemplate, directory: DirectoryStore, idService: ResolutionIdService) {
        self.template = template
        self.directory = directory
        self.idService = idService
        _values = State(initialValue: ["$template": ["typeTag": template.typeTag]])
    }

    public var body: some View {
        NavigationView {
            Form {
                ForEach(template.fields, id: \.id) { field in
                    if isVisible(field) { fieldView(field) }
                }

                if !formErrors.isEmpty {
                    Section(header: Text("Issues")) {
                        ForEach(formErrors, id: \.self) { Text($0).foregroundColor(.red) }
                    }
                }
            }
            .navigationTitle(template.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") { generateTapped() }
                }
            }
            .sheet(isPresented: $showPreview) {
                ResolutionPreviewSheet(title: renderedTitle, content: renderedBody)
            }
        }
        .onAppear { primeDefaults() }
    }
}

// MARK: - Field Views (NO body here)
extension DynamicFormView {
    @ViewBuilder
    fileprivate func fieldView(_ field: FormTemplate.Field) -> some View {
        switch field.type {
        case "text": textField(field)
        case "multiline": multilineField(field)
        case "date": dateField(field)
        case "money": moneyField(field)
        case "number": numberField(field)
        case "boolean": booleanField(field)
        case "enum": enumField(field)
        case "multiselect": multiselectField(field)
        case "entity": entityField(field)
        case "signer": signerField(field)
        case "computed": EmptyView()
        default: Text("Unsupported field type: \(field.type)").foregroundColor(.orange)
        }
    }

    fileprivate func textField(_ field: FormTemplate.Field) -> some View {
        let binding = Binding<String>(
            get: { (values[field.id] as? String) ?? "" },
            set: { values[field.id] = $0 }
        )
        return Section(header: Text(field.label)) {
            TextField(field.placeholder ?? "", text: binding)
        }
    }

    fileprivate func multilineField(_ field: FormTemplate.Field) -> some View {
        let binding = Binding<String>(
            get: { (values[field.id] as? String) ?? "" },
            set: { values[field.id] = $0 }
        )
        return Section(header: Text(field.label)) {
            TextEditor(text: binding).frame(minHeight: 120)
        }
    }

    // ✅ Writes today's date back on first read, so the model is never nil
    fileprivate func dateField(_ field: FormTemplate.Field) -> some View {
        let binding = Binding<Date>(
            get: {
                if let iso = values[field.id] as? String, let d = dateFromISO(iso) {
                    return d
                }
                let today = Calendar.current.startOfDay(for: Date())
                values[field.id] = isoDate(today)
                return today
            },
            set: { values[field.id] = isoDate($0) }
        )
        return Section(header: Text(field.label)) {
            DatePicker("", selection: binding, displayedComponents: [.date])
                .datePickerStyle(.compact)
        }
    }

    fileprivate func moneyField(_ field: FormTemplate.Field) -> some View {
        let binding = Binding<String>(
            get: {
                if let d = values[field.id] as? Double { return String(d) }
                if let s = values[field.id] as? String { return s }
                return ""
            },
            set: { values[field.id] = Double($0.filter { "0123456789.-".contains($0) }) ?? 0 }
        )
        return Section(header: Text(field.label)) {
            TextField("0", text: binding).keyboardType(.decimalPad)
        }
    }

    fileprivate func numberField(_ field: FormTemplate.Field) -> some View {
        let binding = Binding<String>(
            get: {
                if let d = values[field.id] as? Double { return String(d) }
                if let n = values[field.id] as? Int { return String(n) }
                return (values[field.id] as? String) ?? ""
            },
            set: { values[field.id] = Double($0.filter { "0123456789.-".contains($0) }) ?? 0 }
        )
        return Section(header: Text(field.label)) {
            TextField("0", text: binding).keyboardType(.decimalPad)
        }
    }

    fileprivate func booleanField(_ field: FormTemplate.Field) -> some View {
        let binding = Binding<Bool>(
            get: { (values[field.id] as? Bool) ?? false },
            set: { values[field.id] = $0 }
        )
        return Toggle(isOn: binding) { Text(field.label) }
    }

    // ✅ NO early returns; single Section with internal branching
    fileprivate func enumField(_ field: FormTemplate.Field) -> some View {
        let options = field.options ?? []

        // Prepare selection binding (writes default on first read)
        let selection = Binding<String>(
            get: {
                if let current = values[field.id] as? String, options.contains(current) {
                    return current
                }
                if let def = options.first {
                    values[field.id] = def
                    return def
                }
                return "" // placeholder when options are empty
            },
            set: { values[field.id] = $0 }
        )

        return Section(header: Text(field.label)) {
            if options.isEmpty {
                Text("No options available").foregroundStyle(.secondary)
            } else {
                Picker(field.label, selection: selection) {
                    ForEach(options, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
    }

    fileprivate func multiselectField(_ field: FormTemplate.Field) -> some View {
        let options = field.options ?? []
        let selected = Binding<[String]>(
            get: { (values[field.id] as? [String]) ?? [] },
            set: { values[field.id] = $0 }
        )
        return Section(header: Text(field.label)) {
            ForEach(options, id: \.self) { opt in
                let isOn = Binding<Bool>(
                    get: { selected.wrappedValue.contains(opt) },
                    set: { yes in
                        var set = selected.wrappedValue
                        if yes, !set.contains(opt) { set.append(opt) }
                        else { set.removeAll { $0 == opt } }
                        selected.wrappedValue = set
                    }
                )
                Toggle(isOn: isOn) { Text(optLabel(opt)) }
            }
        }
    }

    // ✅ NO early returns; single Section with internal branching
    fileprivate func entityField(_ field: FormTemplate.Field) -> some View {
        let entities = directory.dir.entities
        let ids = entities.map { $0.id }

        // Prepare selection binding (writes first entity on first read)
        let selection = Binding<String>(
            get: {
                if let dict = values[field.id] as? [String: Any],
                   let id = dict["id"] as? String,
                   ids.contains(id) {
                    return id
                }
                if let first = entities.first {
                    values[field.id] = dumpEntity(first)
                    return first.id
                }
                return "" // placeholder when empty
            },
            set: { newId in values[field.id] = dumpEntity(directory.entity(by: newId)) }
        )

        return Section(header: Text(field.label)) {
            if entities.isEmpty {
                Text("No entities found").foregroundStyle(.secondary)
            } else {
                Picker(field.label, selection: selection) {
                    ForEach(entities, id: \.id) { e in
                        VStack(alignment: .leading) {
                            Text(e.legalName).font(.body)
                            if let j = e.jurisdiction {
                                Text("\(e.id) • \(j)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(e.id)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    fileprivate func signerField(_ field: FormTemplate.Field) -> some View {
        let minItems = field.minItems ?? 0
        let list = (values[field.id] as? [[String:Any]]) ?? []
        return Section(header: Text(field.label)) {
            ForEach(Array(list.enumerated()), id: \.offset) { idx, item in
                SignerRow(
                    index: idx,
                    name: item["name"] as? String ?? "",
                    title: item["title"] as? String ?? ""
                ) { newName, newTitle in
                    var arr = (values[field.id] as? [[String:Any]]) ?? []
                    arr[idx]["name"] = newName
                    arr[idx]["title"] = newTitle
                    values[field.id] = arr
                } onDelete: {
                    var arr = (values[field.id] as? [[String:Any]]) ?? []
                    if arr.count > minItems { arr.remove(at: idx); values[field.id] = arr }
                }
            }
            Button {
                var arr = (values[field.id] as? [[String:Any]]) ?? []
                arr.append(["name":"","title":"","signatureBlock":"(Signature)"])
                values[field.id] = arr
            } label: {
                Label("Add Signer", systemImage: "plus.circle")
            }
        }
        .onAppear {
            if list.isEmpty && minItems > 0 {
                var seed: [[String:Any]] = []
                for _ in 0..<minItems {
                    seed.append(["name":"","title":"","signatureBlock":"(Signature)"])
                }
                values[field.id] = seed
            }
        }
    }
}

// MARK: - Actions & Validation (NO body here)
extension DynamicFormView {
    fileprivate func generateTapped() {
        formErrors.removeAll()

        // Validate required/visible fields
        for f in template.fields {
            if !isVisible(f) { continue }
            if (f.required ?? false) && isEmpty(values[f.id]) {
                formErrors.append("\(f.label) is required.")
            }
            if let v = f.validate { applyValidation(v, field: f) }
        }
        guard formErrors.isEmpty else { return }

        // Inject computed resolutionId if present
        if let comp = template.fields.first(where: { $0.id == "resolutionId" })?.compute,
           comp.fn == "generateResolutionId" {
            let entityId: String = (try? ValuesBag(values).valueAt(comp.args["entityIdPath"] ?? "")) ?? ""
            let dateStr: String = (try? ValuesBag(values).valueAt(comp.args["datePath"] ?? "")) ?? ""
            let typeTag: String = template.typeTag
            let date = ISO8601DateFormatter().date(from: dateStr + "T00:00:00Z") ?? Date()
            let rid = idService.generateResolutionId(entityId: entityId, date: date, typeTag: typeTag)
            values["resolutionId"] = rid
        }

        // Render via MustacheLite
        var bag = ValuesBag(values)
        let engine = MustacheLite()

        var tbag = bag
        let title = engine.render(template.document.title, values: &tbag)

        var bbag = bag
        let body = engine.render(template.document.bodyMd, values: &bbag)

        renderedTitle = title
        renderedBody = body
        showPreview = true
    }

    fileprivate func applyValidation(_ rule: FormTemplate.Validation, field: FormTemplate.Field) {
        if let other = rule.notEqualField {
            let a = (values[field.id] as Any?)
            let b = (values[other] as Any?)
            if compareEqual(a, b) {
                formErrors.append(rule.message ?? "\(field.label) must differ from \(other)")
            }
        }
        if let gte = rule.gteField {
            let aStr = (values[field.id] as? String) ?? ""
            let bStr = (values[gte] as? String) ?? ""
            if let a = dateFromISO(aStr), let b = dateFromISO(bStr), a >= b {
                // ok
            } else if !aStr.isEmpty && !bStr.isEmpty {
                formErrors.append(rule.message ?? "\(field.label) must be on/after \(gte)")
            }
        }
    }
}

// MARK: - Helpers (NO body here)
extension DynamicFormView {
    fileprivate func isVisible(_ field: FormTemplate.Field) -> Bool {
        guard let cond = field.visibleIf else { return true }

        // includes for multiselect
        if let needle = cond.includes {
            return (values[cond.field] as? [String])?.contains(needle) ?? false
        }

        // equals for primitives
        switch cond.equals {
        case .string(let s): return (values[cond.field] as? String) == s
        case .bool(let b):   return (values[cond.field] as? Bool) == b
        case .number(let d): return ((values[cond.field] as? Double) ?? 0) == d
        default: return false
        }
    }

    fileprivate func isEmpty(_ v: Any?) -> Bool {
        guard let v else { return true }
        if let s = v as? String { return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if let a = v as? [Any] { return a.isEmpty }
        if let dict = v as? [String:Any] { return dict.isEmpty }
        return false
    }

    fileprivate func compareEqual(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (let da as [String:Any], let db as [String:Any]):
            return (da["id"] as? String) == (db["id"] as? String)
        case (let sa as String, let sb as String):
            return sa == sb
        default:
            return false
        }
    }

    fileprivate func dateFromISO(_ s: String?) -> Date? {
        guard let s else { return nil }
        return ISO8601DateFormatter().date(from: s + "T00:00:00Z")
    }

    fileprivate func isoDate(_ d: Date) -> String {
        let c = Calendar.current
        let y = c.component(.year, from: d)
        let m = c.component(.month, from: d)
        let day = c.component(.day, from: d)
        return String(format: "%04d-%02d-%02d", y, m, day)
    }

    fileprivate func dumpEntity(_ e: EntityDirectory.Entity?) -> [String:Any] {
        guard let e else { return [:] }
        return [
            "id": e.id,
            "legalName": e.legalName,
            "shortName": e.shortName ?? "",
            "jurisdiction": e.jurisdiction ?? "",
            "ein": e.ein ?? "",
            "effectiveDate": e.effectiveDate ?? "",
            "status": e.status ?? ""
        ]
    }

    fileprivate func optLabel(_ raw: String) -> String { raw }

    fileprivate func primeDefaults() {
        // seed default dates to today where missing (helps before field renders)
        for f in template.fields where f.type == "date" && values[f.id] == nil {
            values[f.id] = isoDate(Date())
        }
    }
}

// MARK: - SignerRow (separate type; its own body is fine)
fileprivate struct SignerRow: View {
    let index: Int
    @State var name: String
    @State var title: String
    var onChange: (String,String) -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Signer \(index + 1)").font(.headline)
                Spacer()
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
            }
            TextField("Name", text: Binding(get: { name }, set: { name = $0; onChange(name,title) }))
            TextField("Title", text: Binding(get: { title }, set: { title = $0; onChange(name,title) }))
        }
    }
}

// MARK: - Preview Sheet with PDF Export
public struct ResolutionPreviewSheet: View {
    let title: String
    let content: String
    @Environment(\.dismiss) private var dismiss

    @State private var showingShare = false
    @State private var shareURL: URL?

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title).font(.title3).bold()
                    Divider()
                    if let attributed = try? AttributedString(markdown: content) {
                        Text(attributed).font(.body)
                    } else {
                        Text(content).font(.body)
                    }
                }
                .padding()
            }
            .navigationTitle("Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button("Export PDF (Plain)") {
                            exportPDF(includeLetterhead: false)
                        }
                        Button("Export PDF (Snowbird Letterhead)") {
                            exportPDF(includeLetterhead: true)
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShare) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func exportPDF(includeLetterhead: Bool) {
        // ⚠️ Temporarily disabled PDF generation
        print("📄 Export PDF tapped (includeLetterhead=\(includeLetterhead)) — currently disabled.")
        // shareURL = nil
        // showingShare = false
    }

    private func sanitizedFileName(from s: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return s.components(separatedBy: invalid).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Optional: Demo Host for local testing (not used in app entry)
public struct FormsDemoHost: View {
    @State private var template: FormTemplate?
    private let dirStore: DirectoryStore
    private let idService = ResolutionIdService()

    public init() {
        let bundle = Bundle.main

        // Entities: try Entities/ then root
        let entitiesURL =
            bundle.url(forResource: "entities", withExtension: "json", subdirectory: "Entities") ??
            bundle.url(forResource: "entities", withExtension: "json")

        if let url = entitiesURL, let store = try? DirectoryStore(jsonURL: url) {
            self.dirStore = store
        } else {
            // Minimal empty fallback for testing
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("empty_entities.json")
            if !FileManager.default.fileExists(atPath: tmp.path) {
                let empty = #"{ "version":1, "updatedAt":"", "entities":[] }"#
                try? empty.data(using: .utf8)?.write(to: tmp)
            }
            self.dirStore = try! DirectoryStore(jsonURL: tmp)
        }

        // Load one template for quick demo
        let templateURL =
            bundle.url(forResource: "resolution.distribution.v1", withExtension: "json", subdirectory: "Templates") ??
            bundle.url(forResource: "resolution.distribution.v1", withExtension: "json")
        if let url = templateURL,
           let data = try? Data(contentsOf: url),
           let tmpl = try? JSONDecoder().decode(FormTemplate.self, from: data) {
            _template = State(initialValue: tmpl)
        }
    }

    public var body: some View {
        Group {
            if let tmpl = template {
                DynamicFormView(template: tmpl, directory: dirStore, idService: idService)
            } else {
                Text("Template not found in bundle.")
            }
        }
    }
}
