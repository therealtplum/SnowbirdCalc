//
//  SignerStore.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/3/25.
//


import Foundation
import CryptoKit
import Security
import Combine

public final class SignerStore: ObservableObject {
    @Published public private(set) var signers: [Signer] = []

    private let fileURL: URL
    private let keychainService = "com.snowbird.signers.pin"

    public init(storageDirectory: URL) {
        self.fileURL = storageDirectory.appendingPathComponent("signers.json")
        load()
    }

    // MARK: CRUD
    public func upsert(_ signer: Signer) {
        if let idx = signers.firstIndex(where: { $0.id == signer.id }) {
            signers[idx] = signer
        } else {
            signers.append(signer)
        }
        save()
    }

    public func deactivate(_ id: UUID) {
        guard let i = signers.firstIndex(where: { $0.id == id }) else { return }
        signers[i].isActive = false
        save()
    }

    // MARK: PINs
    /// Set or update a 4-digit PIN for a signer
    public func setPIN(_ pin: String, for signerId: UUID) throws {
        guard Self.isValidPIN(pin) else { throw NSError(domain: "SignerStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "PIN must be 4 digits"]) }
        let hash = Self.sha256(pin)
        try keychainSet(hash, account: signerId.uuidString)
    }

    /// Verify a 4-digit PIN for a signer
    public func verifyPIN(_ pin: String, for signerId: UUID) -> Bool {
        guard let stored = try? keychainGet(account: signerId.uuidString) else { return false }
        return stored == Self.sha256(pin)
    }

    public static func isValidPIN(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }

    // MARK: File IO
    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([Signer].self, from: data) {
            self.signers = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(signers) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: Hash + Keychain
    private static func sha256(_ s: String) -> Data {
        let digest = SHA256.hash(data: s.data(using: .utf8)!)
        return Data(digest)
    }

    private func keychainSet(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        let add: [String: Any] = query.merging([
            kSecValueData as String: data
        ], uniquingKeysWith: { $1 })
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    private func keychainGet(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return data
    }
}
