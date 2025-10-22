//
//  QRCodeRenderer.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/21/25.
//


// QRCodeRenderer.swift
import SwiftUI
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

@MainActor
enum QRCodeRenderer {
    static let context = CIContext()
    static let qrFilter = CIFilter.qrCodeGenerator()

    static func image(from string: String, scale: CGFloat = 8) -> Image {
        let data = Data(string.utf8)
        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.correctionLevel = "M" // good balance
        guard let output = qrFilter.outputImage else { return Image(systemName: "qrcode") }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        if let cgimg = context.createCGImage(transformed, from: transformed.extent) {
            return Image(decorative: cgimg, scale: 1, orientation: .up)
        }
        return Image(systemName: "qrcode")
    }
}

/// Writes a .vcf to a temporary file for sharing.
@MainActor
func makeVCardTempFile(from vcard: String, suggestedName: String = "Contact") -> URL? {
    let name = suggestedName.replacingOccurrences(of: " ", with: "_")
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(name).vcf")
    do {
        try vcard.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    } catch {
        print("Failed to write vCard: \(error)")
        return nil
    }
}