//
//  FormsRootView.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/2/25.
//


import SwiftUI

struct FormsRootView: View {
    @State private var presentingTemplate: FormTemplate?
    private let directory: DirectoryStore
    private let idService = ResolutionIdService()

    private let templateIds = [
        "resolution.distribution.v1",
        "resolution.bank.open.v1",
        "resolution.officer.appointment.v1"
    ]

    init() {
        let bundle = Bundle.main
        // Entities: try Entities/ then root
        let entitiesURL =
            bundle.url(forResource: "entities", withExtension: "json", subdirectory: "Entities") ??
            bundle.url(forResource: "entities", withExtension: "json")!
        self.directory = try! DirectoryStore(jsonURL: entitiesURL)
    }

    var body: some View {
        List {
            Section("Resolutions") {
                ForEach(templateIds, id: \.self) { id in
                    Button {
                        if let t = loadTemplate(id) { presentingTemplate = t }
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
        }
        .navigationTitle("Forms")
        .sheet(item: $presentingTemplate) { tmpl in
            DynamicFormView(template: tmpl,
                            directory: directory,
                            idService: idService)
        }
    }

    private func loadTemplate(_ name: String) -> FormTemplate? {
        let bundle = Bundle.main
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Templates")
              ?? bundle.url(forResource: name, withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FormTemplate.self, from: data)
    }

    private func title(for id: String) -> String {
        switch id {
        case "resolution.distribution.v1": return "Distribution Authorization"
        case "resolution.bank.open.v1":    return "Bank Account Opening"
        case "resolution.officer.appointment.v1": return "Officer Appointment"
        default: return id
        }
    }
    private func icon(for id: String) -> String {
        switch id {
        case "resolution.distribution.v1": return "arrow.down.left.and.arrow.up.right"
        case "resolution.bank.open.v1":    return "banknote"
        case "resolution.officer.appointment.v1": return "person.crop.rectangle"
        default: return "doc.text"
        }
    }
}

extension FormTemplate: Identifiable {
}
