//
//  View+Extension.swift
//  ReceiptBro
//
//  Created by Michael Luegmayer on 24.10.25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Expand width + align horizontally
    func hAlign(_ alignment: Alignment) -> some View {
        frame(maxWidth: .infinity, alignment: alignment)
    }

    /// Expand height + align vertically
    func vAlign(_ alignment: Alignment) -> some View {
        frame(maxHeight: .infinity, alignment: alignment)
    }
}

// MARK: - Optional Binding Helpers

extension Binding where Value == String? {
    /// Optional -> non-optional for TextField
    var bound: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

extension Binding where Value == Double? {
    var bound: Binding<Double> {
        Binding<Double>(
            get: { self.wrappedValue ?? 0 },
            set: { self.wrappedValue = $0 }
        )
    }
}

extension Binding where Value == [LineItemData.PartiallyGenerated]? {
    var bound: Binding<[LineItemData.PartiallyGenerated]> {
        Binding<[LineItemData.PartiallyGenerated]>(
            get: { self.wrappedValue ?? [] },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

extension Binding where Value == ReceiptData.PartiallyGenerated? {
    /// Only use when value is known non-nil
    var bound: Binding<ReceiptData.PartiallyGenerated> {
        Binding<ReceiptData.PartiallyGenerated>(
            get: { self.wrappedValue! },
            set: { self.wrappedValue = $0 }
        )
    }
}
