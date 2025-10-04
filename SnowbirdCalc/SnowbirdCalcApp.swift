import SwiftUI

@main
struct SnowbirdApp: App {
    @StateObject private var appVM = AppViewModel()
    @StateObject private var signerStore: SignerStore

    init() {
        // Persist signer roster in Documents/
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let store = SignerStore(storageDirectory: docs)
        _signerStore = StateObject(wrappedValue: store)

        // Seed initial signer once
        let seededKey = "didSeedInitialSigners_v1"
        if !UserDefaults.standard.bool(forKey: seededKey) {
            let thomas = Signer(
                fullName: "Thomas Plummer",
                title: "Managing Member",
                email: "tom@snowbirdcap.com",
                isActive: true
            )
            store.upsert(thomas)
            // Temporary PIN — change later via your Signers settings UI or code
            try? store.setPIN("1234", for: thomas.id)

            UserDefaults.standard.set(true, forKey: seededKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appVM)
                .environmentObject(signerStore) // Available app-wide
        }
    }
}
