//
//  Signer.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/3/25.
//


import Foundation

public struct Signer: Identifiable, Codable, Hashable {
    public let id: UUID
    public var fullName: String
    public var title: String?
    public var email: String?
    public var isActive: Bool
    /// Optional Base64-encoded PNG/JPEG of a signature image if you support it
    public var signatureImageBase64: String?

    public init(id: UUID = UUID(),
                fullName: String,
                title: String? = nil,
                email: String? = nil,
                isActive: Bool = true,
                signatureImageBase64: String? = nil) {
        self.id = id
        self.fullName = fullName
        self.title = title
        self.email = email
        self.isActive = isActive
        self.signatureImageBase64 = signatureImageBase64
    }
}