//
//  AppIconPickerView.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/5/25.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Data Model

struct AppIconOption: Identifiable, Hashable {
    let id = UUID()
    /// Pass `nil` for primary icon
    let iconKey: String?
    let displayName: String
    /// Name of an Image Set (NOT an App Icon Set) in your .xcassets
    let previewAssetName: String
}

final class AppIconModel: ObservableObject {
    @Published var currentIconKey: String? = UIApplication.shared.alternateIconName

    var supportsAlternateIcons: Bool { UIApplication.shared.supportsAlternateIcons }

    func setIcon(_ key: String?, completion: @escaping (Error?) -> Void) {
        guard supportsAlternateIcons else {
            completion(NSError(domain: "AppIcon",
                               code: 1,
                               userInfo: [NSLocalizedDescriptionKey: "Alternate icons not supported on this device."]))
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

// MARK: - Safe Image Loader

private enum PreviewAssetLoader {
    /// Try multiple strategies to resolve an asset image.
    static func loadImage(named name: String, catalogPrefix: String? = nil) -> UIImage? {
        // 1) Plain lookup (SwiftUI will use this too)
        if let ui = UIImage(named: name, in: .main, compatibleWith: nil) { return ui }

        // 2) If your asset catalog has "Provides Namespace" enabled, names can be qualified by catalog.
        if let prefix = catalogPrefix {
            let qualified = "\(prefix)/\(name)"
            if let ui = UIImage(named: qualified, in: .main, compatibleWith: nil) { return ui }
        }

        // 3) Nothing found
        return nil
    }
}

// MARK: - Picker View

struct AppIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = AppIconModel()
    @State private var errorText: String?

    /// If your .xcassets (the *file name* in the navigator) has **Provides Namespace** enabled,
    /// set this to that catalog’s name (e.g., "Assets" or "AppAssets").
    /// Otherwise, leave it nil.
    private let assetCatalogPrefix: String? = nil

    // OPTION A: runtime keys match your Alternate App Icon Sets
    // Previews must be Image Sets you created: AppIconPreview-*
    private let options: [AppIconOption] = [
        .init(iconKey: nil,                 displayName: "Default",   previewAssetName: "AppIconPreview-Default"),
        .init(iconKey: "AppIcon-Farms",     displayName: "Farms",     previewAssetName: "AppIconPreview-Farms"),
        .init(iconKey: "AppIcon-Tech",      displayName: "Tech",      previewAssetName: "AppIconPreview-Tech"),
        .init(iconKey: "AppIcon-Royalties", displayName: "Royalties", previewAssetName: "AppIconPreview-Royalties"),
        .init(iconKey: "AppIcon-Markets",   displayName: "Markets",   previewAssetName: "AppIconPreview-Markets"),
        .init(iconKey: "AppIcon-Foundation",   displayName: "Foundation",   previewAssetName: "AppIconPreview-Foundation"),
    ]

    // Adaptive grid for nice wrapping
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 16)]

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { content }
            } else {
                NavigationView { content }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !model.supportsAlternateIcons {
                Text("This device doesn’t support alternate icons.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            LazyVGrid(columns: columns, spacing: 16) {
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
                            previewTile(named: opt.previewAssetName)
                                .overlay(selectionRing(selected: model.currentIconKey == opt.iconKey))
                            Text(opt.displayName)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text(opt.displayName))
                        .accessibilityValue(model.currentIconKey == opt.iconKey ? Text("Selected") : Text(""))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
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
        .onAppear {
            // Print which previews are found/missing to help diagnose asset names
            debugCheckPreviewAssets(options.map { $0.previewAssetName })
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func previewTile(named assetName: String) -> some View {
        if let ui = PreviewAssetLoader.loadImage(named: assetName, catalogPrefix: assetCatalogPrefix) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(20)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondary.opacity(0.12))
                VStack(spacing: 8) {
                    Image(systemName: "app.fill")
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .padding(22)
                    Text("Missing:\n\(assetName)")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                }
                .padding(6)
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }

    @ViewBuilder
    private func selectionRing(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(selected ? Color.accentColor : .clear, lineWidth: 3)
    }

    private func debugCheckPreviewAssets(_ names: [String]) {
        for n in names {
            let foundPlain = (UIImage(named: n, in: .main, compatibleWith: nil) != nil)
            let foundQualified: Bool
            if let prefix = assetCatalogPrefix {
                foundQualified = (UIImage(named: "\(prefix)/\(n)", in: .main, compatibleWith: nil) != nil)
            } else {
                foundQualified = false
            }
            print("Preview asset '\(n)': plain=\(foundPlain) qualified=\(foundQualified)")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AppIconPickerView_Previews: PreviewProvider {
    static var previews: some View {
        AppIconPickerView()
    }
}
#endif
