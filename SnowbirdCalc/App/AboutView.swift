//
//  AboutView.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 9/30/25.
//


import SwiftUI

struct AboutView: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "SnowbirdCalc"
    }
    private var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(v) (build \(b))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    header

                    card("What this app is") {
                        Text("\(appName) helps you model a holding-company structure with multiple subsidiaries — markets/trading, royalties, farms, active or passive businesses — and see the impact on federal taxes, cap gains, NIIT, and qualified retirement contributions.")
                    }

                    card("How it works") {
                        bullet("Create scenarios and add subsidiaries (Markets, Credit, Royalties, Farms, etc.).")
                        bullet("Adjust inputs (income, LTCG/STCG, management fee %, depletion, rates).")
                        bullet("The calculator recomputes: employer contribution, total retirement, ordinary/cap gain/NIIT taxes, and after-tax cash.")
                        bullet("Charts visualize tax composition and cash vs. retirement.")
                    }

                    card("What you’re supposed to do") {
                        bullet("Experiment with fee policies and entity mix to compare outcomes.")
                        bullet("Use multiple scenarios to A/B different strategies.")
                        bullet("Export screenshots or values when meeting with your tax pro.")
                    }

                    card("Who I am") {
                        // Edit this to your preferred bio
                        Text("Built by Thomas Plummer for personal modeling and planning. This tool is provided as-is for exploration and discussion — not as professional advice.")
                    }

                    disclaimer
                }
                .padding(16)
            }
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // parent sheet dismisses automatically via .sheet
                        // no-op; system provides swipe-down to dismiss
                    }
                    .tint(.secondary)
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tint)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading) {
                Text(appName).font(.title2.weight(.semibold))
                Text(versionString).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            content()
                .font(.body)
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 1)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().frame(width: 6, height: 6).foregroundStyle(.secondary)
            Text(text)
        }
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Huge disclaimer")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("""
This app is **for informational and educational purposes only**. It **does not provide tax, legal, accounting, or investment advice**. Federal and state tax laws, contribution limits, plan qualification rules, and filing requirements **change regularly** and depend on your specific facts and circumstances. **Always consult a qualified CPA and/or attorney** before implementing any structure, election, or plan described or modeled here.

By using this app you agree that **no client-advisor relationship** is formed, and the author(s) and contributors **are not responsible** for any decisions or outcomes. **You are solely responsible** for verifying calculations, assumptions, and compliance with all applicable laws and regulations.
""")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 1)
    }
}