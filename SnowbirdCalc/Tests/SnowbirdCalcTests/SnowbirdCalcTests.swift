//
//  SnowbirdCalcTests.swift
//  SnowbirdCalcTests
//
//  Created by Thomas Plummer on 9/29/25.
//

import Testing
@testable import SnowbirdCalc

struct SnowbirdCalcTests {

    // MARK: - Calculator Tests
    
    @Test func testCalculatorWithEmptyScenario() {
        let scenario = Scenario(name: "Empty", subs: [])
        let output = Calc.compute(scenario)
        
        #expect(output.holdcoEarned == 0.0)
        #expect(output.employerContribution == 0.0)
        #expect(output.totalRetirement == scenario.employeeDeferral)
        #expect(output.totalFederalTax == 0.0)
    }
    
    @Test func testCalculatorInvestmentSubsidiary() {
        let scenario = Scenario(
            name: "Investment Test",
            employeeDeferral: 23_000,
            employerPct: 0.25,
            ordinaryRate: 0.35,
            ltcgRate: 0.20,
            niitRate: 0.038,
            subs: [
                Subsidiary(
                    name: "Markets",
                    kind: .investment,
                    ltcg: 50_000,
                    stcg: 50_000,
                    mgmtFeePct: 0.25
                )
            ]
        )
        
        let output = Calc.compute(scenario)
        
        // Total cap gains: 100,000
        // Management fee: 100,000 * 0.25 = 25,000
        #expect(output.holdcoEarned == 25_000)
        // Net cap gains: 100,000 - 25,000 = 75,000
        #expect(output.marketsNetCapGains == 75_000)
        
        // Employer contribution: 25,000 * 0.25 = 6,250
        #expect(output.employerContribution == 6_250)
        
        // Total retirement: 23,000 + 6,250 = 29,250
        #expect(output.totalRetirement == 29_250)
        
        // HoldCo taxable: 25,000 - 29,250 = -4,250 (negative, so 0 for tax base)
        #expect(output.holdcoTaxable == -4_250)
        
        // Cap gains tax: 75,000 * (0.20 + 0.038) = 17,850
        #expect(output.capGainsAndNIITTax == 17_850)
        
        // Total tax: 0 (ordinary) + 17,850 = 17,850
        #expect(output.totalFederalTax == 17_850)
    }
    
    @Test func testCalculatorActiveBusinessSubsidiary() {
        let scenario = Scenario(
            name: "Credit Test",
            employeeDeferral: 23_000,
            employerPct: 0.25,
            ordinaryRate: 0.35,
            subs: [
                Subsidiary(
                    name: "Credit",
                    kind: .activeBusiness,
                    ordinaryIncome: 100_000,
                    mgmtFeePct: 1.0
                )
            ]
        )
        
        let output = Calc.compute(scenario)
        
        // Management fee: 100,000 * 1.0 = 100,000
        #expect(output.holdcoEarned == 100_000)
        // Net ordinary: 100,000 - 100,000 = 0
        #expect(output.creditNetOrdinary == 0.0)
        
        // Employer contribution: 100,000 * 0.25 = 25,000
        #expect(output.employerContribution == 25_000)
        
        // HoldCo taxable: 100,000 - (23,000 + 25,000) = 52,000
        #expect(output.holdcoTaxable == 52_000)
        
        // Ordinary tax: 52,000 * 0.35 = 18,200
        #expect(output.ordinaryTax == 18_200)
    }
    
    @Test func testCalculatorRoyaltiesSubsidiary() {
        let scenario = Scenario(
            name: "Royalties Test",
            employeeDeferral: 23_000,
            employerPct: 0.25,
            ordinaryRate: 0.35,
            subs: [
                Subsidiary(
                    name: "Royalties",
                    kind: .royalties,
                    ordinaryIncome: 100_000,
                    mgmtFeePct: 0.25,
                    depletionPct: 0.15
                )
            ]
        )
        
        let output = Calc.compute(scenario)
        
        // Management fee: 100,000 * 0.25 = 25,000
        #expect(output.holdcoEarned == 25_000)
        
        // After fee: 100,000 - 25,000 = 75,000
        // After depletion: 75,000 * (1 - 0.15) = 63,750
        #expect(output.royaltiesNetOrdinaryAfterDepletion == 63_750)
    }
    
    @Test func testCalculatorPassiveFarmSubsidiary() {
        let scenario = Scenario(
            name: "Farms Test",
            employeeDeferral: 23_000,
            employerPct: 0.25,
            ordinaryRate: 0.35,
            subs: [
                Subsidiary(
                    name: "Farms",
                    kind: .passiveFarm,
                    ordinaryIncome: 50_000,
                    mgmtFeePct: 0.0
                )
            ]
        )
        
        let output = Calc.compute(scenario)
        
        // Management fee: 50,000 * 0.0 = 0
        #expect(output.holdcoEarned == 0.0)
        // Net ordinary: 50,000 - 0 = 50,000
        #expect(output.farmsNetOrdinary == 50_000)
    }
    
    @Test func testCalculatorMultipleSubsidiaries() {
        let scenario = Scenario(
            name: "Multiple Test",
            employeeDeferral: 23_000,
            employerPct: 0.25,
            ordinaryRate: 0.35,
            ltcgRate: 0.20,
            niitRate: 0.038,
            subs: [
                Subsidiary(name: "Markets", kind: .investment, ltcg: 50_000, stcg: 50_000, mgmtFeePct: 0.25),
                Subsidiary(name: "Credit", kind: .activeBusiness, ordinaryIncome: 75_000, mgmtFeePct: 1.0)
            ]
        )
        
        let output = Calc.compute(scenario)
        
        // Markets: 25,000 fee, Credit: 75,000 fee
        // Total HoldCo earned: 100,000
        #expect(output.holdcoEarned == 100_000)
        
        // Employer contribution: 100,000 * 0.25 = 25,000
        #expect(output.employerContribution == 25_000)
        
        // Total retirement: 23,000 + 25,000 = 48,000
        #expect(output.totalRetirement == 48_000)
    }
    
    @Test func testCalculatorEdgeCaseNegativeValues() {
        let scenario = Scenario(
            name: "Edge Case",
            employeeDeferral: 100_000, // Very high deferral
            employerPct: 0.25,
            ordinaryRate: 0.35,
            subs: [
                Subsidiary(
                    name: "Small",
                    kind: .activeBusiness,
                    ordinaryIncome: 10_000,
                    mgmtFeePct: 0.5
                )
            ]
        )
        
        let output = Calc.compute(scenario)
        
        // HoldCo earned: 5,000
        // Employer contribution: 1,250
        // Total retirement: 100,000 + 1,250 = 101,250
        // HoldCo taxable: 5,000 - 101,250 = -96,250 (negative)
        #expect(output.holdcoTaxable < 0)
        #expect(output.holdcoTaxable == -96_250)
        
        // Ordinary tax base should be max(0, -96,250) + max(0, 5,000) = 5,000
        // But creditNetOrdinary is 5,000 (10,000 - 5,000 fee)
        // So ordinary tax: 5,000 * 0.35 = 1,750
        #expect(output.ordinaryTax == 1_750)
    }
    
    @Test func testCalculatorZeroRates() {
        let scenario = Scenario(
            name: "Zero Rates",
            employeeDeferral: 23_000,
            employerPct: 0.0,
            ordinaryRate: 0.0,
            ltcgRate: 0.0,
            niitRate: 0.0,
            subs: [
                Subsidiary(
                    name: "Test",
                    kind: .investment,
                    ltcg: 100_000,
                    stcg: 0,
                    mgmtFeePct: 0.25
                )
            ]
        )
        
        let output = Calc.compute(scenario)
        
        // Should still calculate correctly with zero rates
        #expect(output.holdcoEarned == 25_000)
        #expect(output.employerContribution == 0.0)
        #expect(output.ordinaryTax == 0.0)
        #expect(output.capGainsAndNIITTax == 0.0)
        #expect(output.totalFederalTax == 0.0)
    }
    
    // MARK: - Formatters Tests
    
    @Test func testFormattersPercent() {
        // Test 0-1 range
        let result1 = Formatters.percent(0.25)
        #expect(result1.contains("25"))
        
        // Test 0-100 range
        let result2 = Formatters.percent(25.0)
        #expect(result2.contains("25"))
        
        // Test edge cases
        let result3 = Formatters.percent(0.0)
        #expect(result3.contains("0"))
        
        let result4 = Formatters.percent(1.0)
        #expect(result4.contains("100"))
    }
    
    @Test func testFormattersDollar() {
        let result1 = Formatters.dollar(1000.0)
        #expect(result1.contains("1,000") || result1.contains("1000"))
        
        let result2 = Formatters.dollar(0.0)
        #expect(result2.contains("0") || result2 == "$0")
        
        let result3 = Formatters.dollar(1_500_000.0)
        #expect(result3.contains("1,500,000") || result3.contains("1500000"))
    }
}
