import SwiftUI

public struct SignersManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var signerStore: SignerStore

    // removed showEditor/showPIN (not needed with .sheet(item:))
    @State private var editingSigner: Signer? = nil
    @State private var pinTarget: Signer? = nil

    public init() {}

    public var body: some View {
        NavigationView {
            List {
                Section("Active") {
                    let actives = signerStore.signers.filter { $0.isActive }
                    if actives.isEmpty {
                        Text("No active signers").foregroundStyle(.secondary)
                    } else {
                        ForEach(actives) { signer in
                            signerRow(signer)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        signerStore.deactivate(signer.id)
                                    } label: {
                                        Label("Deactivate", systemImage: "xmark.circle")
                                    }
                                }
                        }
                    }
                }

                Section("Inactive") {
                    let inactives = signerStore.signers.filter { !$0.isActive }
                    if inactives.isEmpty {
                        Text("No inactive signers").foregroundStyle(.secondary)
                    } else {
                        ForEach(inactives) { signer in
                            signerRow(signer, showDeactivate: false)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        var s = signer
                                        s.isActive = true
                                        signerStore.upsert(s)
                                    } label: {
                                        Label("Activate", systemImage: "checkmark.circle")
                                    }.tint(.green)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Authorized Signatories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingSigner = Signer(fullName: "", title: "", email: "", isActive: true)
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            // ✅ Editor sheet — shows only when editingSigner != nil
            .sheet(item: $editingSigner) { signer in
                SignerEditorSheet(
                    signer: signer,
                    onSave: { updated in
                        signerStore.upsert(updated)
                        editingSigner = nil
                    },
                    onCancel: {
                        editingSigner = nil
                    }
                )
            }
            // ✅ PIN sheet — shows only when pinTarget != nil
            .sheet(item: $pinTarget) { target in
                PinSetSheet(
                    signerName: target.fullName,
                    onSave: { pin in
                        try? signerStore.setPIN(pin, for: target.id)
                        pinTarget = nil
                    },
                    onCancel: {
                        pinTarget = nil
                    }
                )
            }
        }
    }

    // MARK: - Row
    @ViewBuilder
    private func signerRow(_ signer: Signer, showDeactivate: Bool = true) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(signer.fullName).font(.body)
                HStack(spacing: 6) {
                    if let t = signer.title, !t.isEmpty {
                        Text(t).font(.caption).foregroundStyle(.secondary)
                    }
                    if let e = signer.email, !e.isEmpty {
                        Text("•").font(.caption).foregroundStyle(.secondary)
                        Text(e).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Menu {
                Button {
                    editingSigner = signer
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    pinTarget = signer
                } label: {
                    Label("Set PIN", systemImage: "key.fill")
                }
                if showDeactivate {
                    Button(role: .destructive) {
                        signerStore.deactivate(signer.id)
                    } label: {
                        Label("Deactivate", systemImage: "xmark.circle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingSigner = signer
        }
    }
}
