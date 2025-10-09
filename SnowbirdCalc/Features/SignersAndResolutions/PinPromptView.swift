//
//  PinPromptView.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/3/25.
//


import SwiftUI

public struct PinPromptView: View {
    public let signerName: String
    public var onSubmit: (String) -> Void
    public var onCancel: () -> Void

    @State private var pin: String = ""

    public init(signerName: String,
                onSubmit: @escaping (String) -> Void,
                onCancel: @escaping () -> Void) {
        self.signerName = signerName
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Enter PIN for \(signerName)")
                .font(.headline)
            TextField("4-digit PIN", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .onChange(of: pin) { _, new in
                    if new.count > 4 { pin = String(new.prefix(4)) }
                }
                .multilineTextAlignment(.center)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Verify") {
                    onSubmit(pin)
                }
                .disabled(pin.count != 4)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}