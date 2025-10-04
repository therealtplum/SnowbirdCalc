//
//  DynamicFormView.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/2/25.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import UIKit

// One rendered signature block shown under the resolution preview
struct SignatureBlock: Identifiable {
    let id = UUID()
    let name: String
    let title: String
    let date: Date
    let image: UIImage?
}

public struct DynamicFormView: View {
    public let template: FormTemplate
    public let directory: DirectoryStore
    public let idService: ResolutionIdService

    @EnvironmentObject var signerStore: SignerStore

    @State private var values: [String: Any] = [:]
    @State private var showPreview = false
    @State private var renderedTitle: String = ""
    @State private var renderedBody: String = ""
    @State private var formErrors: [String] = []

    // multi-signer flow (type == "signers")
    @State private var selectedSignerIDs: Set<UUID> = []
    @State private var pinQueue: [UUID] = []
    @State private var pinSheetSigner: Signer?
    @State private var pendingCompletion: (() -> Void)?
    @State private var pinError: String?

    // single-select flow (type == "signerSelect")
    @State private var signerSelectSelections: [String: String] = [:]  // fieldId -> verified signerId
    @State private var signerSelectStaging: [String: String] = [:]     // fieldId -> staged signerId (for UI)
    @State private var pinVerifyFieldId: String?
    @State private var pinVerifySigner: Signer?
    @State private var pinVerifyError: String?

    // preview
    @State private var signatureBlocks: [SignatureBlock] = []

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
                ResolutionPreviewSheet(
                    title: renderedTitle,
                    content: renderedBody,
                    signatureBlocks: signatureBlocks
                )
            }
            // Multi-signer PIN queue
            .sheet(item: $pinSheetSigner, onDismiss: {
                pinQueue.removeAll(); pendingCompletion = nil
            }) { signer in
                PinPromptView(
                    signerName: signer.fullName,
                    onSubmit: { pin in
                        if signerStore.verifyPIN(pin, for: signer.id) {
                            pinQueue.removeFirst()
                            pinSheetSigner = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                advancePinQueue()
                            }
                        } else {
                            pinError = "Incorrect PIN for \(signer.fullName)."
                        }
                    },
                    onCancel: {
                        pinQueue.removeAll()
                        pinSheetSigner = nil
                        pendingCompletion = nil
                    }
                )
            }
            // Single-select PIN prompt
            .sheet(item: $pinVerifySigner) { signer in
                PinVerifySheet(
                    signerName: signer.fullName,
                    onSubmit: { pin in
                        if signerStore.verifyPIN(pin, for: signer.id) {
                            if let fieldId = pinVerifyFieldId {
                                signerSelectSelections[fieldId] = signer.id.uuidString
                                signerSelectStaging[fieldId]    = signer.id.uuidString
                                values[fieldId] = [
                                    "id": signer.id.uuidString,
                                    "name": signer.fullName,
                                    "title": signer.title ?? ""
                                ]
                            }
                            pinVerifySigner = nil
                            pinVerifyFieldId = nil
                        } else {
                            pinVerifyError = "Incorrect PIN for \(signer.fullName)."
                        }
                    },
                    onCancel: {
                        if let fieldId = pinVerifyFieldId {
                            signerSelectStaging[fieldId] = signerSelectSelections[fieldId] ?? ""
                        }
                        pinVerifySigner = nil
                        pinVerifyFieldId = nil
                    }
                )
            }
            .alert("Verification Failed", isPresented: Binding(
                get: { pinError != nil || pinVerifyError != nil },
                set: { _ in pinError = nil; pinVerifyError = nil })
            ) {
                Button("OK", role: .cancel) { pinError = nil; pinVerifyError = nil }
            } message: {
                Text(pinError ?? pinVerifyError ?? "")
            }
        }
        .onAppear { primeDefaults() }
    }
}

// MARK: - Field Views
extension DynamicFormView {
    @ViewBuilder
    fileprivate func fieldView(_ field: FormTemplate.Field) -> some View {
        switch field.type {
        case "text":        textField(field)
        case "multiline":   multilineField(field)
        case "date":        dateField(field)
        case "money":       moneyField(field)
        case "number":      numberField(field)
        case "boolean":     booleanField(field)
        case "enum":        enumField(field)
        case "multiselect": multiselectField(field)
        case "entity":      entityField(field)
        case "signer":      legacySignerField(field)         // old manual array of signers
        case "signerSelect": signerSelectField(field)        // dropdown (PIN-gated)
        case "signers":     authorizedSignersField(field)    // multi-select (PIN-gated on Generate)
        case "computed":    EmptyView()
        default:
            Text("Unsupported field type: \(field.type)").foregroundColor(.orange)
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

    fileprivate func dateField(_ field: FormTemplate.Field) -> some View {
        let isRequired = field.required ?? false
        func dateBinding() -> Binding<Date> {
            Binding<Date>(
                get: {
                    if let iso = values[field.id] as? String, let d = dateFromISO(iso) {
                        return d
                    }
                    let today = Calendar.current.startOfDay(for: Date())
                    if isRequired { values[field.id] = isoDate(today) }
                    return today
                },
                set: { values[field.id] = isoDate($0) }
            )
        }
        return Section(header: Text(field.label)) {
            if isRequired {
                DatePicker("", selection: dateBinding(), displayedComponents: [.date]).datePickerStyle(.compact)
            } else {
                let hasDate = Binding<Bool>(
                    get: { values[field.id] != nil },
                    set: { include in
                        if include {
                            if values[field.id] == nil {
                                let today = Calendar.current.startOfDay(for: Date())
                                values[field.id] = isoDate(today)
                            }
                        } else { values[field.id] = nil }
                    }
                )
                Toggle("Include \(field.label)", isOn: hasDate)
                if hasDate.wrappedValue {
                    DatePicker("", selection: dateBinding(), displayedComponents: [.date]).datePickerStyle(.compact)
                } else {
                    Text("No \(field.label.lowercased())").foregroundStyle(.secondary)
                }
            }
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
            set: { values[field.id] = Double($0.filter { "0123456789.-".contains($0) }) }
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

    fileprivate func enumField(_ field: FormTemplate.Field) -> some View {
        let options = field.options ?? []
        let selection = Binding<String>(
            get: {
                if let current = values[field.id] as? String, options.contains(current) { return current }
                if let def = options.first { values[field.id] = def; return def }
                return ""
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
                Toggle(isOn: isOn) { Text(opt) }
            }
        }
    }

    fileprivate func entityField(_ field: FormTemplate.Field) -> some View {
        let entities = directory.dir.entities
        let ids = entities.map { $0.id }
        let selection = Binding<String>(
            get: {
                if let dict = values[field.id] as? [String: Any],
                   let id = dict["id"] as? String,
                   ids.contains(id) { return id }
                if let first = entities.first {
                    values[field.id] = dumpEntity(first)
                    return first.id
                }
                return ""
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
                                Text("\(e.id) • \(j)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tag(e.id)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // Single-select signer dropdown (PIN-gated)
    fileprivate func signerSelectField(_ field: FormTemplate.Field) -> some View {
        let approved = signerStore.signers.filter { $0.isActive }
        let fieldId = field.id

        // Verified selection (what's committed to values[])
        let verified = signerSelectSelections[fieldId] ?? ""

        // Staged selection drives the Picker UI
        let staged = Binding<String>(
            get: { signerSelectStaging[fieldId] ?? verified },
            set: { newId in
                signerSelectStaging[fieldId] = newId  // update UI immediately so menu closes
                guard !newId.isEmpty, newId != verified,
                      let signer = approved.first(where: { $0.id.uuidString == newId }) else { return }
                // present PIN after menu closes
                DispatchQueue.main.async {
                    pinVerifyFieldId = fieldId
                    pinVerifySigner  = signer
                }
            }
        )

        return Section(header: Text(field.label)) {
            if approved.isEmpty {
                Text("No approved signers available").foregroundStyle(.secondary)
            } else {
                Picker(field.label, selection: staged) {
                    Text("Select...").tag("")
                    ForEach(approved, id: \.id) { s in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.fullName)
                            if let t = s.title, !t.isEmpty {
                                Text(t).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tag(s.id.uuidString) // tag the outer view
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .onAppear {
            if signerSelectStaging[fieldId] == nil {
                if let dict = values[fieldId] as? [String: Any],
                   let id = dict["id"] as? String,
                   approved.contains(where: { $0.id.uuidString == id }) {
                    signerSelectSelections[fieldId] = id
                    signerSelectStaging[fieldId] = id
                } else {
                    signerSelectStaging[fieldId] = verified
                }
            }
        }
    }

    // Legacy manual signer array inputs
    fileprivate func legacySignerField(_ field: FormTemplate.Field) -> some View {
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
            } label: { Label("Add Signer", systemImage: "plus.circle") }
        }
        .onAppear {
            if list.isEmpty && minItems > 0 {
                var seed: [[String:Any]] = []
                for _ in 0..<minItems { seed.append(["name":"","title":"","signatureBlock":"(Signature)"]) }
                values[field.id] = seed
            }
        }
    }

    // Multi-select approved signers (for templates needing >1 approver)
    fileprivate func authorizedSignersField(_ field: FormTemplate.Field) -> some View {
        Section(header: Text(field.label)) {
            SignerPickerView(store: signerStore, selected: $selectedSignerIDs)
            if (field.required ?? false) && selectedSignerIDs.isEmpty {
                Text("Select at least one signer").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Actions & Validation
extension DynamicFormView {
    fileprivate func generateTapped() {
        formErrors.removeAll()

        for f in template.fields {
            if !isVisible(f) { continue }
            if (f.required ?? false) && isEmpty(values[f.id]) {
                formErrors.append("\(f.label) is required.")
            }
            if let v = f.validate { applyValidation(v, field: f) }
        }

        if template.fields.contains(where: { $0.type == "signers" && ($0.required ?? false) }) && selectedSignerIDs.isEmpty {
            formErrors.append("Approving Signer(s) are required.")
        }

        guard formErrors.isEmpty else { return }

        if template.fields.contains(where: { $0.type == "signers" }) {
            beginSignerVerification {
                self.renderAndShowPreview()
            }
        } else {
            renderAndShowPreview()
        }
    }

    private func renderAndShowPreview() {
        // computed resolutionId support
        if let comp = template.fields.first(where: { $0.id == "resolutionId" })?.compute,
           comp.fn == "generateResolutionId" {
            let entityId: String = (try? ValuesBag(values).valueAt(comp.args["entityIdPath"] ?? "")) ?? ""
            let dateStr: String = (try? ValuesBag(values).valueAt(comp.args["datePath"] ?? "")) ?? ""
            let typeTag: String = template.typeTag
            let date = ISO8601DateFormatter().date(from: dateStr + "T00:00:00Z") ?? Date()
            let rid = idService.generateResolutionId(entityId: entityId, date: date, typeTag: typeTag)
            values["resolutionId"] = rid
        }

        // multi-select signer injection (ids + names/titles)
        if !selectedSignerIDs.isEmpty {
            values["approvedSignerIds"] = selectedSignerIDs.map { $0.uuidString }
            values["approvedSigners"] = signerStore.signers
                .filter { selectedSignerIDs.contains($0.id) }
                .map { ["name": $0.fullName, "title": $0.title ?? ""] }
        }

        // single-select signer convenience keys
        injectSignerValuesForTemplates(into: &values)

        var bag = ValuesBag(values)
        let engine = MustacheLite()

        var tbag = bag
        let title = engine.render(template.document.title, values: &tbag)

        var bbag = bag
        let body = engine.render(template.document.bodyMd, values: &bbag)

        // Build signature blocks from whichever signer fields you use
        var blocks: [SignatureBlock] = []

        // 1) multi-select case (type == "signers")
        let multi = signerStore.signers.filter { selectedSignerIDs.contains($0.id) }
        for s in multi {
            blocks.append(SignatureBlock(
                name: s.fullName,
                title: s.title ?? "",
                date: Date(),
                image: signerStore.signatureImage(for: s.id)
            ))
        }

        // 2) single-select case(s) (type == "signerSelect")
        for f in template.fields where f.type == "signerSelect" {
            if let dict = values[f.id] as? [String: Any],
               let idStr = dict["id"] as? String,
               let uuid = UUID(uuidString: idStr),
               let s = signerStore.signers.first(where: { $0.id == uuid }) {
                blocks.append(SignatureBlock(
                    name: s.fullName,
                    title: s.title ?? "",
                    date: Date(),
                    image: signerStore.signatureImage(for: s.id)
                ))
            }
        }

        // de-dup if the same signer appears twice
        var seen = Set<String>()
        signatureBlocks = blocks.filter { block in
            let key = block.name + "|" + block.title
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        renderedTitle = title
        renderedBody  = body
        showPreview   = true
    }

    fileprivate func beginSignerVerification(then completion: @escaping () -> Void) {
        let chosen = signerStore.signers.filter { selectedSignerIDs.contains($0.id) }
        guard !chosen.isEmpty else { completion(); return }
        pinQueue = chosen.map(\.id)
        pendingCompletion = completion
        advancePinQueue()
    }

    fileprivate func advancePinQueue() {
        guard let next = pinQueue.first,
              let signer = signerStore.signers.first(where: { $0.id == next }) else {
            pendingCompletion?(); pendingCompletion = nil
            return
        }
        pinSheetSigner = signer
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

// MARK: - Helpers
extension DynamicFormView {
    fileprivate func isVisible(_ field: FormTemplate.Field) -> Bool {
        guard let cond = field.visibleIf else { return true }
        if let needle = cond.includes {
            return (values[cond.field] as? [String])?.contains(needle) ?? false
        }
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
        return String(format: "%04d-%02d-%02d",
                      c.component(.year, from: d),
                      c.component(.month, from: d),
                      c.component(.day, from: d))
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
            "address": e.address ?? "",
            "email": e.email ?? ""
        ]
    }

    fileprivate func optLabel(_ raw: String) -> String { raw }

    fileprivate func primeDefaults() {
        for f in template.fields where f.type == "date" && (f.required ?? false) && values[f.id] == nil {
            values[f.id] = isoDate(Date())
        }
    }

    /// Inject signer-friendly keys for Mustache templates (single & multi)
    fileprivate func injectSignerValuesForTemplates(into values: inout [String: Any]) {
        var firstSignerSelectDict: [String: Any]? = nil

        for f in template.fields where f.type == "signerSelect" {
            if let dict = values[f.id] as? [String: Any],
               let id = dict["id"] as? String, !id.isEmpty {

                if firstSignerSelectDict == nil { firstSignerSelectDict = dict }

                var signerFields = (values["signerFields"] as? [String: Any]) ?? [:]
                signerFields[f.id] = dict
                values["signerFields"] = signerFields

                if f.id == "approvingSigner" {
                    values["approvingSigner"] = dict
                }
            }
        }

        if values["approvingSigner"] == nil, let first = firstSignerSelectDict {
            values["approvingSigner"] = first
        }

        if !selectedSignerIDs.isEmpty {
            let arr = signerStore.signers
                .filter { selectedSignerIDs.contains($0.id) }
                .map { ["name": $0.fullName, "title": $0.title ?? ""] }
            values["approvedSigners"] = arr
            values["approvedSignerIds"] = selectedSignerIDs.map { $0.uuidString }
        }
    }
}

// MARK: - Legacy SignerRow (manual entry)
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

// MARK: - Preview Sheet (PDF export disabled)
public struct ResolutionPreviewSheet: View {
    let title: String
    let content: String
    let signatureBlocks: [SignatureBlock]
    @Environment(\.dismiss) private var dismiss

    @State private var showingShare = false
    @State private var shareURL: URL?

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(.title3).bold()

                    Divider()

                    // Render markdown if possible, otherwise plain text
                    if let attributed = try? AttributedString(markdown: content) {
                        Text(attributed).font(.body)
                    } else {
                        Text(content).font(.body)
                    }

                    // Always render signature blocks AFTER the content
                    if !signatureBlocks.isEmpty {
                        Divider().padding(.top, 8)
                        ForEach(signatureBlocks) { block in
                            SignatureBlockView(block: block)
                        }
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
                        Button("Export PDF (Plain)") { exportPDF(includeLetterhead: false) }
                        Button("Export PDF (Snowbird Letterhead)") { exportPDF(includeLetterhead: true) }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShare) {
                if let url = shareURL { ResolutionShareSheet(items: [url]) }
            }
        }
    }

    private func exportPDF(includeLetterhead: Bool) {
        // Stub: wire up your PDF exporter here
        print("📄 Export PDF tapped (includeLetterhead=\(includeLetterhead)) — currently disabled.")
        // shareURL = generatedURL
        // showingShare = true
    }
}

// Renders one signature block (image + /s/ + title + date)
fileprivate struct SignatureBlockView: View {
    let block: SignatureBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let img = block.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                    .padding(.bottom, 2)
            } else {
                Text("(No signature image on file)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("/s/ \(block.name)")
                .font(.body).bold()

            if !block.title.isEmpty {
                Text(block.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Electronic Signature — \(format(block.date))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.vertical, 6)
    }

    private func format(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
}

#if canImport(UIKit)
fileprivate struct ResolutionShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - PIN Verify Sheet (for single-select)
fileprivate struct PinVerifySheet: View {
    let signerName: String
    var onSubmit: (String) -> Void
    var onCancel: () -> Void

    @State private var pin: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Verify \(signerName)") {
                    SecureField("4-digit PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .onChange(of: pin) { new in
                            pin = String(new.filter(\.isNumber).prefix(4))
                        }
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle("Enter PIN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verify") { onSubmit(pin) }
                        .disabled(pin.count != 4)
                }
            }
        }
    }
}
