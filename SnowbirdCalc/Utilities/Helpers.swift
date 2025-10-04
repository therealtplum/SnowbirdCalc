//
//  Helpers.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/3/25.
//


import SwiftUI

extension Binding {
    /// Converts a Binding to an optional into a non-optional with a default value.
    static func withDefault(_ source: Binding<Value?>, default defaultValue: @autoclosure @escaping () -> Value) -> Binding<Value> {
        Binding<Value>(
            get: { source.wrappedValue ?? defaultValue() },
            set: { source.wrappedValue = $0 }
        )
    }
}