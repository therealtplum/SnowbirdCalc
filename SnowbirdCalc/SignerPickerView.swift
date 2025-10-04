import SwiftUI

public struct SignerPickerView: View {
    @ObservedObject var store: SignerStore
    @Binding var selected: Set<UUID>

    public init(store: SignerStore, selected: Binding<Set<UUID>>) {
        self.store = store
        self._selected = selected
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(store.signers.filter { $0.isActive }) { signer in
                Toggle(isOn: Binding(
                    get: { selected.contains(signer.id) },
                    set: { isOn in
                        if isOn {
                            _ = selected.insert(signer.id)   // ignore tuple return
                        } else {
                            _ = selected.remove(signer.id)   // ignore optional return
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(signer.fullName).font(.body)
                        if let t = signer.title, !t.isEmpty {
                            Text(t).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if store.signers.filter({ $0.isActive }).isEmpty {
                Text("No active signers yet. Add one in Settings → Signers.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
