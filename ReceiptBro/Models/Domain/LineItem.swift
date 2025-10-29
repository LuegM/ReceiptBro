import Foundation
import SwiftData

@Model
final class LineItem {
    var id: UUID
    var name: String
    var quantity: Double
    var unitPrice: Double
    var totalPrice: Double

    var receipt: Receipt?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unitPrice: Double,
        totalPrice: Double,
        receipt: Receipt? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.receipt = receipt
    }

    /// Create LineItem from Foundation Models extracted data
    convenience init(from itemData: LineItemData, receipt: Receipt? = nil) {
        self.init(
            name: itemData.name,
            quantity: itemData.quantity,
            unitPrice: itemData.unitPrice,
            totalPrice: itemData.totalPrice,
            receipt: receipt
        )
    }
}
