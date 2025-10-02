
import Foundation

struct CalculatorOutput: Codable, Equatable {
    var holdcoEarned: Double
    var employerContribution: Double
    var totalRetirement: Double

    var marketsNetCapGains: Double
    var creditNetOrdinary: Double
    var royaltiesNetOrdinaryAfterDepletion: Double
    var farmsNetOrdinary: Double

    var holdcoTaxable: Double
    var ordinaryTax: Double
    var capGainsAndNIITTax: Double
    var totalFederalTax: Double
    var afterTaxIncomeExclRet: Double
}

enum Calc {
    static func compute(_ s: Scenario) -> CalculatorOutput {
        var holdcoEarned = 0.0
        var marketsNetCapGains = 0.0
        var creditNetOrdinary = 0.0
        var royaltiesNetAfterDepletion = 0.0
        var farmsNet = 0.0

        for sub in s.subs {
            switch sub.kind {
            case .investment:
                let totalCG = sub.ltcg + sub.stcg
                let fee = totalCG * sub.mgmtFeePct
                holdcoEarned += fee
                marketsNetCapGains += (totalCG - fee)

            case .activeBusiness:
                let fee = sub.ordinaryIncome * sub.mgmtFeePct
                holdcoEarned += fee
                creditNetOrdinary += (sub.ordinaryIncome - fee)

            case .royalties:
                let fee = sub.ordinaryIncome * sub.mgmtFeePct
                holdcoEarned += fee
                let remaining = max(0, sub.ordinaryIncome - fee)
                royaltiesNetAfterDepletion += remaining * (1 - sub.depletionPct)

            case .passiveFarm:
                let fee = sub.ordinaryIncome * sub.mgmtFeePct
                holdcoEarned += fee
                farmsNet += (sub.ordinaryIncome - fee)
            }
        }

        let employerContribution = holdcoEarned * s.employerPct
        let totalRetirement = s.employeeDeferral + employerContribution
        let holdcoTaxable = holdcoEarned - totalRetirement

        let ordinaryBase = max(0, holdcoTaxable) + max(0, creditNetOrdinary)
                          + max(0, royaltiesNetAfterDepletion) + max(0, farmsNet)
        let ordinaryTax = ordinaryBase * s.ordinaryRate
        let capGainsAndNIITTax = marketsNetCapGains * (s.ltcgRate + s.niitRate)
        let totalFederalTax = ordinaryTax + capGainsAndNIITTax

        let afterTaxIncomeExclRet = (holdcoTaxable + marketsNetCapGains + creditNetOrdinary
                                     + royaltiesNetAfterDepletion + farmsNet) - totalFederalTax

        return .init(
            holdcoEarned: holdcoEarned,
            employerContribution: employerContribution,
            totalRetirement: totalRetirement,
            marketsNetCapGains: marketsNetCapGains,
            creditNetOrdinary: creditNetOrdinary,
            royaltiesNetOrdinaryAfterDepletion: royaltiesNetAfterDepletion,
            farmsNetOrdinary: farmsNet,
            holdcoTaxable: holdcoTaxable,
            ordinaryTax: ordinaryTax,
            capGainsAndNIITTax: capGainsAndNIITTax,
            totalFederalTax: totalFederalTax,
            afterTaxIncomeExclRet: afterTaxIncomeExclRet
        )
    }
}
