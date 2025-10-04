//
//  PinSetSheet.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/3/25.
//


import SwiftUI

struct PinSetSheet: View {
    @Environment(\.dismiss) private var dismiss

    let signerName: String
    var onSave: (String) -> Void
    var onCancel: () -> Void

    @State private var pin1 = ""
    @State private var pin2 = ""
    @State private var error: String?

    init(signerName: String,
         onSave: @escaping (String) -> Void,
         onCancel: @escaping () -> Void) {
        self.signerName = signerName
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Set 4-digit PIN for \(signerName)") {
                    SecureField("PIN", text: $pin1)
                        .keyboardType(.numberPad)
                        .onChange(of: pin1) { _, new in
                            pin1 = String(new.filter(\.isNumber).prefix(4))
                        }
                        .textContentType(.oneTimeCode)

                    SecureField("Confirm PIN", text: $pin2)
                        .keyboardType(.numberPad)
                        .onChange(of: pin2) { _, new in
                            pin2 = String(new.filter(\.isNumber).prefix(4))
                        }
                        .textContentType(.oneTimeCode)

                    if let err = error {
                        Text(err).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Set PIN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard pin1.count == 4, pin2.count == 4 else {
                            error = "PIN must be 4 digits"
                            return
                        }
                        guard pin1 == pin2 else {
                            error = "PINs do not match"
                            return
                        }
                        onSave(pin1)
                        dismiss()
                    }
                    .disabled(pin1.count != 4 || pin2.count != 4)
                }
            }
        }
    }
}