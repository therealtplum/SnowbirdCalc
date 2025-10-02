import SwiftUI
import Charts

struct ChartsSection: View {
    let output: CalculatorOutput
    private let usd: FloatingPointFormatStyle<Double>.Currency = .currency(code: "USD")

    private struct Datum: Identifiable {
        let id = UUID()
        let label: String
        let amount: Double
    }

    private var taxSeries: [Datum] {
        [.init(label: "Ordinary Tax", amount: output.ordinaryTax),
         .init(label: "Cap+NIIT Tax", amount: output.capGainsAndNIITTax)]
    }

    private var flowSeries: [Datum] {
        [.init(label: "Retirement", amount: output.totalRetirement),
         .init(label: "After-Tax Cash", amount: output.afterTaxIncomeExclRet)]
    }

    var body: some View {
        VStack(spacing: 18) {
            chartBlock(title: "Tax composition", data: taxSeries)
            chartBlock(title: "Cash & retirement", data: flowSeries)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Components

    @ViewBuilder
    private func chartBlock(title: String, data: [Datum]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Chart(data) { d in
                BarMark(
                    x: .value("Amount", d.amount),
                    y: .value("Category", d.label)
                )
                .cornerRadius(6)
                .foregroundStyle(color(for: d.label))
                .annotation(position: .trailing, alignment: .trailing) {
                    Text(usd.format(d.amount))
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .frame(height: 180)
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    if let v = value.as(Double.self) { AxisValueLabel(usd.format(v)) }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartPlotStyle { plot in
                plot
                    .background(Color(uiColor: .secondarySystemBackground))   // neutral card-ish bg
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func color(for label: String) -> Color {
        // Muted, professional palette
        switch label {
        case "Ordinary Tax":     return Color.indigo.opacity(0.65)
        case "Cap+NIIT Tax":     return Color.teal.opacity(0.65)
        case "Retirement":       return Color.green.opacity(0.55)
        case "After-Tax Cash":   return Color.blue.opacity(0.60)
        default:                 return .accentColor.opacity(0.6)
        }
    }
}
