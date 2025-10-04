import SwiftUI

struct SignerEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var signer: Signer
    var onSave: (Signer) -> Void
    var onCancel: () -> Void

    init(signer: Signer,
         onSave: @escaping (Signer) -> Void,
         onCancel: @escaping () -> Void) {
        _signer = State(initialValue: signer)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Identity") {
                    TextField("Full name", text: Binding(
                        get: { signer.fullName }, set: { signer.fullName = $0 }
                    ))
                    TextField("Title", text: Binding(
                        get: { signer.title ?? "" }, set: { signer.title = $0 }
                    ))
                    TextField("Email", text: Binding(
                        get: { signer.email ?? "" }, set: { signer.email = $0 }
                    ))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                }
                Section {
                    Toggle("Active", isOn: Binding(
                        get: { signer.isActive }, set: { signer.isActive = $0 }
                    ))
                }
            }
            .navigationTitle(signer.fullName.isEmpty ? "New Signer" : "Edit Signer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(signer)
                        dismiss()
                    }
                    .disabled(signer.fullName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
