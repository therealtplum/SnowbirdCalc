import Foundation
import SwiftSoup

/// Scrapes US Mineral Exchange using their API endpoints
/// 1) Authenticates via /login
/// 2) Scrapes listing IDs from HTML table or API
/// 3) Fetches detailed JSON via /listings/{id} API
///
/// Usage:
///   let scraper = USMEScraper(username: "your_username", password: "your_password")
///   let listings = try await scraper.fetchListings(query: nil)
struct USMEScraper: MineralRightsService {
    
    private let loginURL = URL(string: "https://api.usmineralexchange.com/login?with[]=legal_agreement&remember=1")!
    // Try to get more listings by adding per_page parameter
    private let indexURL = URL(string: "https://www.usmineralexchange.com/mineral-listings/sort/cash-flow/DESC?per_page=100")!
    private let apiDetailBase = "https://api.usmineralexchange.com/listings/"
    
    private let username: String
    private let password: String
    
    private let debugLog = true
    private let maxConcurrency = 6
    
    /// Initialize with USME credentials
    /// - Parameters:
    ///   - username: Your USME username or email
    ///   - password: Your USME password
    init(username: String = "snowbirdcap", password: String = "Z6YxiuxVeXtmV!!") {
        self.username = username
        self.password = password
    }
    
    /// Convenience initializer using environment variables
    /// Set USME_USERNAME and USME_PASSWORD in your environment to override defaults
    static func fromEnvironment() -> USMEScraper? {
        guard let user = ProcessInfo.processInfo.environment["USME_USERNAME"],
              let pass = ProcessInfo.processInfo.environment["USME_PASSWORD"] else {
            return nil
        }
        return USMEScraper(username: user, password: pass)
    }
    
    func fetchListings(query: String?) async throws -> [MineralListing] {
        // 1) Create authenticated session
        let session = makeSession()
        
        // 2) Login
        try await login(session: session)
        if debugLog { print("✅ USME: Logged in successfully") }
        
        // 3) Try API listings endpoint first, fall back to HTML scraping
        var listingIDs: [String] = []
        
        // Try API endpoint
        if let apiIDs = try? await fetchListingIDsFromAPI(session: session), !apiIDs.isEmpty {
            listingIDs = apiIDs
            if debugLog { print("✅ USME: Found \(listingIDs.count) listings from API") }
        } else {
            // Fall back to HTML scraping
            listingIDs = try await fetchListingIDsFromHTML(session: session)
            if debugLog { print("✅ USME: Found \(listingIDs.count) listings from HTML") }
        }
        
        // 4) Fetch detailed data from API with polite concurrency
        let items = await fetchDetailedListings(ids: listingIDs, session: session)
        if debugLog { print("✅ USME: Enriched \(items.count) listings with API data") }
        
        // 5) Optional filter
        if let q = query?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
            let needle = q.lowercased()
            return items.filter {
                $0.title.lowercased().contains(needle)
                || $0.location.lowercased().contains(needle)
                || ($0.listingID ?? "").lowercased().contains(needle)
            }
        }
        
        return items
    }
    
    // MARK: - Session Setup
    
    private func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X)",
            "Content-Type": "application/json",
            "Accept": "application/json, text/html",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.timeoutIntervalForRequest = 30
        return URLSession(configuration: cfg)
    }
    
    // MARK: - Authentication
    
    private func login(session: URLSession) async throws {
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = [
            "username_or_email": username,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }
    }
    
    // MARK: - Fetching Listing IDs
    
    private func fetchListingIDsFromAPI(session: URLSession) async throws -> [String]? {
        // Try the API listings endpoint
        let apiURL = URL(string: "https://api.usmineralexchange.com/listings?status=active&per_page=100")!
        
        let (data, resp) = try await session.data(from: apiURL)
        guard let http = resp as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return nil
        }
        
        // Try to parse JSON response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let listings = json["data"] as? [[String: Any]] {
            let ids = listings.compactMap { $0["id"] as? Int }.map { String($0) }
            return ids
        }
        
        return nil
    }
    
    private func fetchListingIDsFromHTML(session: URLSession) async throws -> [String] {
        let (data, resp) = try await session.data(from: indexURL)
        guard let http = resp as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        
        if debugLog {
            print("📄 HTML length: \(html.count) characters")
        }
        
        let doc = try SwiftSoup.parse(html)
        let rows = try doc.select("div.table_table_row__KQQZp")
        
        if debugLog {
            print("🔍 Found \(rows.count) table rows in HTML")
        }
        
        var ids: [String] = []
        for row in rows {
            guard let idRaw = try row.select("div[class*=table_listings_item_col__id__]").first()?.text(),
                  idRaw.range(of: #"^\d{6}$"#, options: .regularExpression) != nil else {
                continue
            }
            ids.append(idRaw)
        }
        
        if debugLog {
            print("📋 Extracted listing IDs: \(ids)")
        }
        
        return ids
    }
    
    // MARK: - API Detail Fetching
    
    private func fetchDetailedListings(ids: [String], session: URLSession) async -> [MineralListing] {
        var items: [MineralListing] = []
        let chunks = ids.chunked(into: maxConcurrency)
        
        for chunk in chunks {
            await withTaskGroup(of: MineralListing?.self) { group in
                for id in chunk {
                    group.addTask {
                        await self.fetchListingDetail(id: id, session: session)
                    }
                }
                
                for await item in group {
                    if let item = item {
                        items.append(item)
                    }
                }
            }
        }
        
        return items
    }
    
    private func fetchListingDetail(id: String, session: URLSession) async -> MineralListing? {
        let urlString = "\(apiDetailBase)\(id)?with[]=county&with[]=state&with[]=media_maps&with[]=media_documents"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, resp) = try await session.data(from: url)
            guard let http = resp as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return nil
            }
            
            let decoder = JSONDecoder()
            // Set up date decoding for ISO8601 format
            decoder.dateDecodingStrategy = .iso8601
            
            let details = try decoder.decode(ListingDetails.self, from: data)
            
            // Filter out expired, sold, or inactive listings
            guard details.status?.lowercased() == "active" else {
                if debugLog {
                    print("⏭️  Skipping listing \(id) - status: \(details.status ?? "unknown")")
                }
                return nil
            }
            
            return convertToMineralListing(details)
        } catch {
            if debugLog {
                print("⚠️  Failed to fetch listing \(id): \(error)")
            }
            return nil
        }
    }
    
    // MARK: - Conversion
    
    private func convertToMineralListing(_ details: ListingDetails) -> MineralListing {
        let location = [
            details.county?.name,
            details.state?.name
        ].compactMap { $0 }.joined(separator: ", ")
        
        let detailURL = URL(string: "https://www.usmineralexchange.com/en/mineral-listings-view/\(details.id)")!
        
        // Parse starting bid - handle per-acre pricing
        let (priceUSD, priceNote) = parseStartingBid(
            bidString: details.startingBid,
            netAcres: details.netAcres,
            bidBasis: details.bidBasis
        )
        
        // Calculate royalty fraction if available
        let royaltyFraction = details.royaltyPercentage.map { $0 / 100.0 }
        
        // Build notes
        var notesArray: [String] = []
        if let cf = details.averageMonthlyCashFlow {
            notesArray.append("Monthly Cash Flow: \(cf.formatted(.currency(code: "USD")))")
        }
        if let note = priceNote {
            notesArray.append(note)
        }
        if let op = details.operatorName, !op.isEmpty {
            notesArray.append("Operator: \(op)")
        }
        if let lessee = details.lessee, !lessee.isEmpty {
            notesArray.append("Lessee: \(lessee)")
        }
        if details.isActiveLease == true {
            notesArray.append("Active Lease")
        }
        if details.isHeldByProduction == true {
            notesArray.append("Held by Production")
        }
        if let docs = details.mediaDocuments, !docs.isEmpty {
            notesArray.append("\(docs.count) documents attached")
        }
        
        let notes = notesArray.isEmpty ? nil : notesArray.joined(separator: " • ")
        
        if debugLog {
            print("📋 Converting listing \(details.id):")
            print("   Title: \(details.title)")
            print("   Raw Starting Bid: \(details.startingBid ?? "nil")")
            print("   Parsed Price: \(priceUSD?.description ?? "nil")")
            if let note = priceNote {
                print("   Price Note: \(note)")
            }
            print("   Raw Cash Flow: \(details.averageMonthlyCashFlow?.description ?? "nil")")
            print("   Net Acres: \(details.netAcres?.description ?? "nil")")
        }
        
        return MineralListing(
            id: UUID(),
            source: "US Mineral Exchange",
            title: details.title,
            location: location,
            acres: details.netAcres,
            netMineralAcres: details.netAcres,
            royaltyFraction: royaltyFraction,
            priceUSD: priceUSD,
            url: detailURL,
            postedAt: details.activatedAt,
            notes: notes,
            listingID: String(details.id),
            cashFlowUSD: details.averageMonthlyCashFlow
        )
    }
    
    // MARK: - Parsing Helpers
    
    private func parseStartingBid(bidString: String?, netAcres: Double?, bidBasis: String?) -> (price: Double?, note: String?) {
        guard let bidStr = bidString else { return (nil, nil) }
        
        let lowercased = bidStr.lowercased()
        
        // Check if it's a per-acre pricing model
        let isPerAcre = lowercased.contains("per") && (
            lowercased.contains("acre") ||
            lowercased.contains("nma") ||
            lowercased.contains("nra") ||
            lowercased.contains("nri") ||
            lowercased.contains("ndi")
        )
        
        // Parse the number
        guard let perUnitPrice = Self.parseDollar(bidStr) else {
            return (nil, nil)
        }
        
        if isPerAcre {
            // Determine the unit type
            let unitType: String
            if lowercased.contains("nra") || lowercased.contains("net royalty acre") {
                unitType = "NRA"
            } else if lowercased.contains("nma") || lowercased.contains("net mineral acre") {
                unitType = "NMA"
            } else if lowercased.contains("nri") || lowercased.contains("net revenue interest") {
                unitType = "NRI"
            } else if lowercased.contains("ndi") || lowercased.contains("net decimal interest") {
                unitType = "NDI"
            } else {
                unitType = "acre"
            }
            
            // Try to calculate total if we have acres
            if let acres = netAcres, acres > 0 {
                let totalPrice = perUnitPrice * acres
                let note = "Priced at \(perUnitPrice.formatted(.currency(code: "USD"))) per \(unitType) × \(acres.formatted(.number.precision(.fractionLength(2)))) = \(totalPrice.formatted(.currency(code: "USD")))"
                return (totalPrice, note)
            } else {
                // No acres data, return per-unit price with note
                let note = "Priced at \(perUnitPrice.formatted(.currency(code: "USD"))) per \(unitType) (acres unknown)"
                return (nil, note)
            }
        } else {
            // Regular total price
            return (perUnitPrice, nil)
        }
    }
    
    private static func parseDollar(_ s: String) -> Double? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle "per NMA" or "per acre" suffixes - extract just the number
        let withoutSuffix = trimmed.replacingOccurrences(
            of: #"\s+(per|/)\s+.+$"#,
            with: "",
            options: .regularExpression
        )
        
        // "120k" or "$120k"
        if let kRange = withoutSuffix.range(of: #"^\s*\$?\s*([\d]+(?:\.\d+)?)\s*[kK]\s*$"#, options: .regularExpression) {
            let numStr = String(withoutSuffix[kRange]).replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            if let base = Double(numStr) { return base * 1_000 }
        }
        
        // Plain dollars with commas
        let cleaned = withoutSuffix.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(cleaned)
    }
}

// MARK: - API Models

struct ListingDetails: Codable {
    let id: Int
    let title: String
    let netAcres: Double?
    let legalLocation: String?
    let isActiveLease: Bool?
    let leaseTerms: String?
    let leaseBonus: String?
    let royaltyPercentage: Double?
    let isHeldByProduction: Bool?
    let averageMonthlyCashFlow: Double?
    let operatorName: String?
    let lessee: String?
    let comment: String?
    let startingBid: String?
    let bidBasis: String?
    let status: String?
    let type: String?
    let county: County?
    let state: StateInfo?
    let mediaMaps: [Media]?
    let mediaDocuments: [Media]?
    let activatedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, comment, lessee, county, state, status, type
        case netAcres = "net_acres"
        case legalLocation = "legal_location"
        case isActiveLease = "is_active_lease"
        case leaseTerms = "lease_terms"
        case leaseBonus = "lease_bonus"
        case royaltyPercentage = "royalty_percentage"
        case isHeldByProduction = "is_held_by_production"
        case averageMonthlyCashFlow = "average_monthly_cash_flow"
        case operatorName = "operator"
        case startingBid = "starting_bid"
        case bidBasis = "bid_basis"
        case mediaMaps = "media_maps"
        case mediaDocuments = "media_documents"
        case activatedAt = "activated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct County: Codable {
    let id: Int
    let name: String
    let stateId: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case stateId = "state_id"
    }
}

struct StateInfo: Codable {
    let id: Int
    let name: String
    let code: String
}

struct Media: Codable {
    let id: Int
    let name: String
    let link: String
    let size: Int
    let isPublic: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, link, size
        case isPublic = "is_public"
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var res: [[Element]] = []
        var i = 0
        while i < count {
            let j = Swift.min(i + size, count)
            res.append(Array(self[i..<j]))
            i = j
        }
        return res
    }
}
