//
//  AppIconOption.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/5/25.
//


import SwiftUI
import UIKit
import Combine

struct AppIconOption: Identifiable, Hashable {
    let id = UUID()
    /// Pass `nil` for primary
    let iconKey: String?
    let displayName: String
    /// Optional preview image from Assets for nicer UI; fallback uses SF Symbol.
    let previewAssetName: String?
}

final class AppIconModel: ObservableObject {
    @Published var currentIconKey: String? = UIApplication.shared.alternateIconName

    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    func setIcon(_ key: String?, completion: @escaping (Error?) -> Void) {
        guard supportsAlternateIcons else {
            completion(NSError(domain: "AppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Alternate icons not supported on this device."]))
            return
        }
        UIApplication.shared.setAlternateIconName(key) { [weak self] error in
            DispatchQueue.main.async {
                self?.currentIconKey = UIApplication.shared.alternateIconName
                completion(error)
            }
        }
    }
}

struct AppIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = AppIconModel()
    @State private var errorText: String?

    // Match these keys to Info.plist CFBundleAlternateIcons keys.
    private let options: [AppIconOption] = [
        .init(iconKey: nil,          displayName: "Default",   previewAssetName: "AppIconPreview-Default"),
        .init(iconKey: "Farms",      displayName: "Farms",     previewAssetName: "AppIconPreview-Farms"),
        .init(iconKey: "Tech",       displayName: "Tech",      previewAssetName: "AppIconPreview-Tech"),
        .init(iconKey: "Royalties",  displayName: "Royalties", previewAssetName: "AppIconPreview-Royalties"),
        .init(iconKey: "Markets",    displayName: "Markets",   previewAssetName: "AppIconPreview-Markets"),
    ]

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                if !model.supportsAlternateIcons {
                    Text("This device doesn’t support alternate icons.")
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 16)], spacing: 16) {
                    ForEach(options) { opt in
                        Button {
                            model.setIcon(opt.iconKey) { err in
                                if let err = err {
                                    errorText = err.localizedDescription
                                } else {
                                    dismiss()
                                }
                            }
                        } label: {
                            VStack(spacing: 8) {
                                if let asset = opt.previewAssetName, UIImage(named: asset) != nil {
                                    Image(asset)
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fit)
                                        .cornerRadius(20)
                                } else {
                                    // Fallback visual if you don't add preview images to Assets
                                    Image(systemName: "app.fill")
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fit)
                                        .padding(22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20).fill(Color.secondary.opacity(0.15))
                                        )
                                }

                                Text(opt.displayName)
                                    .font(.footnote)
                                    .foregroundStyle(.primary)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(model.currentIconKey == opt.iconKey ? Color.accentColor : .clear, lineWidth: 3)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                if let errorText {
                    Text(errorText).foregroundStyle(.red).padding(.horizontal)
                }

                Text("iOS will show a confirmation when changing the app icon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Choose App Icon")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
