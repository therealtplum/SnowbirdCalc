//
//  BusinessCard.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/21/25.
//


// BusinessCard.swift
import Foundation

struct BusinessCard: Codable, Equatable, Sendable {
    var givenName: String
    var familyName: String
    var jobTitle: String
    var company: String
    var email: String
    var phone: String
    var website: String
    var city: String
    var region: String
    var country: String

    var fullName: String { [givenName, familyName].joined(separator: " ").trimmingCharacters(in: .whitespaces) }

    /// vCard 3.0 text (works well for share/export)
    func vCardText() -> String {
        var lines: [String] = [
            "BEGIN:VCARD",
            "VERSION:3.0",
            "N:\(familyName);\(givenName);;;",
            "FN:\(fullName)"
        ]
        if !company.isEmpty { lines.append("ORG:\(company)") }
        if !jobTitle.isEmpty { lines.append("TITLE:\(jobTitle)") }
        if !email.isEmpty { lines.append("EMAIL;TYPE=INTERNET,WORK:\(email)") }
        if !phone.isEmpty { lines.append("TEL;TYPE=CELL,VOICE:\(phone)") }
        if !website.isEmpty { lines.append("URL:\(website)") }

        let location = [city, region, country].filter{ !$0.isEmpty }.joined(separator: ", ")
        if !location.isEmpty { lines.append("ADR;TYPE=WORK:;;;\(city);\(region);;\(country)") }
        lines.append(contentsOf: ["END:VCARD"])
        return lines.joined(separator: "\n")
    }

    /// MECARD text (compact for QR; many scanners can add contact directly)
    func meCardText() -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: ":", with: "\\:")
             .replacingOccurrences(of: ";", with: "\\;")
             .replacingOccurrences(of: ",", with: "\\,")
        }
        var parts: [String] = ["MECARD:"]
        if !fullName.isEmpty { parts.append("N:\(esc(fullName));") }
        if !phone.isEmpty { parts.append("TEL:\(esc(phone));") }
        if !email.isEmpty { parts.append("EMAIL:\(esc(email));") }
        if !company.isEmpty { parts.append("ORG:\(esc(company));") }
        if !jobTitle.isEmpty { parts.append("TITLE:\(esc(jobTitle));") }
        if !website.isEmpty { parts.append("URL:\(esc(website));") }
        let addr = [city, region, country].filter{ !$0.isEmpty }.joined(separator: " ")
        if !addr.isEmpty { parts.append("ADR:\(esc(addr));") }
        parts.append(";") // terminator
        return parts.joined()
    }
}

// Simple storage (UserDefaults). Replace with Keychain if you prefer.
enum BusinessCardStore {
    private static let key = "BusinessCard.current"
    @MainActor static func load() -> BusinessCard {
        if let data = UserDefaults.standard.data(forKey: key),
           let card = try? JSONDecoder().decode(BusinessCard.self, from: data) {
            return card
        }
        // sensible defaults to edit later
        return BusinessCard(
            givenName: "Your",
            familyName: "Name",
            jobTitle: "Title",
            company: "Company",
            email: "you@example.com",
            phone: "+1 (555) 123-4567",
            website: "https://example.com",
            city: "City",
            region: "State",
            country: "USA"
        )
    }

    @MainActor static func save(_ card: BusinessCard) {
        if let data = try? JSONEncoder().encode(card) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}