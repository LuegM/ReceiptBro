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
}
