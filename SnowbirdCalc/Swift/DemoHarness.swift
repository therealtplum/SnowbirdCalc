import Foundation

// Minimal harness that demonstrates generating a resolutionId and rendering the title/body text.
// Integrate with SwiftUI form UI & PDF export in your app.

struct DemoHarness {
    func run() throws {
        // Load entities
        let entitiesURL = Bundle.main.url(forResource: "entities", withExtension: "json")!
        let dir = try DirectoryStore(jsonURL: entitiesURL)

        // Load a template
        let tmplURL = Bundle.main.url(forResource: "resolution.distribution.v1", withExtension: "json", subdirectory: "Templates")!
        let data = try Data(contentsOf: tmplURL)
        let template = try JSONDecoder().decode(FormTemplate.self, from: data)

        // Mock values as if collected from UI
        var values: [String:Any] = [
            "$template": ["typeTag": template.typeTag],
            "date": "2025-10-02",
            "fromEntity": try dumpEntity(dir.entity(by: "SHOLD")),
            "toEntity": try dumpEntity(dir.entity(by: "SMARK")),
            "amount": 250000,
            "purpose": "Working capital for new property acquisition",
            "method": "Wire",
            "effectiveDate": "2025-10-05",
            "signers": [
                ["name":"Thomas Plummer","title":"Manager / Sole Member","signatureBlock":"(Signature)"]
            ]
        ]

        // Generate resolutionId
        var bag = ValuesBag(values)
        let service = ResolutionIdService()
        let date = ISO8601DateFormatter().date(from: "2025-10-02T00:00:00Z")!
        let resolutionId = service.generateResolutionId(entityId: "SHOLD", date: date, typeTag: template.typeTag)
        values["resolutionId"] = resolutionId
        bag.raw = values

        // Render doc
        let engine = MustacheLite()
        var titleBag = bag
        let title = engine.render(template.document.title, values: &titleBag)
        var bodyBag = bag
        let body = engine.render(template.document.bodyMd, values: &bodyBag)

        print(title)
        print("\n---\n")
        print(body)
    }

    private func dumpEntity(_ e: EntityDirectory.Entity?) throws -> [String:Any] {
        guard let e else { throw NSError(domain: "Demo", code: 1) }
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
}
