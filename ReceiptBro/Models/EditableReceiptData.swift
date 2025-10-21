import Foundation
import SwiftUI

/// Editable wrapper around ReceiptData for review and corrections
/// Uses Decimal for currency precision and @Observable for SwiftUI reactivity
@Observable
final class EditableReceiptData {
    var merchantName: String
    var address: String
    var date: Date
    var transactionId: String
    var paymentMethod: String
    var currency: String
    var items: [EditableLineItem]
    var taxAmount: Decimal
    var totalAmount: Decimal

    /// Computed subtotal from line items
    var calculatedSubtotal: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.totalPrice }
    }

    /// Computed total (subtotal + tax)
    var calculatedTotal: Decimal {
        calculatedSubtotal + taxAmount
    }

    /// Check if totals match within tolerance
    var totalsMatch: Bool {
        abs(calculatedTotal - totalAmount) < 0.05
    }

    init(merchantName: String, address: String, date: Date, transactionId: String, paymentMethod: String, currency: String, items: [EditableLineItem], taxAmount: Decimal, totalAmount: Decimal) {
        self.merchantName = merchantName
        self.address = address
        self.date = date
        self.transactionId = transactionId
        self.paymentMethod = paymentMethod
        self.currency = currency
        self.items = items
        self.taxAmount = taxAmount
        self.totalAmount = totalAmount
    }

    /// Create editable data from extracted PartiallyGenerated receipt
    convenience init?(from partial: ReceiptData.PartiallyGenerated) {
        guard let merchantName = partial.merchantName else {
            print("❌ EditableReceiptData init failed: missing merchantName")
            return nil
        }

        guard let dateString = partial.date else {
            print("❌ EditableReceiptData init failed: missing date")
            return nil
        }

        guard let currency = partial.currency else {
            print("❌ EditableReceiptData init failed: missing currency")
            return nil
        }

        guard let totalAmount = partial.totalAmount else {
            print("❌ EditableReceiptData init failed: missing totalAmount")
            return nil
        }

        // Parse date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: dateString) else {
            print("❌ EditableReceiptData init failed: could not parse date '\(dateString)'")
            return nil
        }

        // Convert items
        var editableItems: [EditableLineItem] = []
        if let items = partial.items {
            editableItems = items.compactMap { EditableLineItem(from: $0) }
            print("✅ Converted \(editableItems.count) of \(items.count) items")
        }

        print("✅ EditableReceiptData created successfully with \(editableItems.count) items")

        self.init(
            merchantName: merchantName,
            address: partial.address ?? "",
            date: date,
            transactionId: partial.transactionId ?? "",
            paymentMethod: partial.paymentMethod ?? "",
            currency: currency,
            items: editableItems,
            taxAmount: Decimal(partial.taxAmount ?? 0.0),
            totalAmount: Decimal(totalAmount)
        )
    }

    /// Convert back to ReceiptData for saving
    func toReceiptData() -> ReceiptData {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        return ReceiptData(
            merchantName: merchantName,
            address: address.isEmpty ? nil : address,
            date: dateFormatter.string(from: date),
            transactionId: transactionId.isEmpty ? nil : transactionId,
            paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
            currency: currency,
            items: items.map { $0.toLineItemData() },
            taxAmount: taxAmount.isZero ? nil : NSDecimalNumber(decimal: taxAmount).doubleValue,
            totalAmount: NSDecimalNumber(decimal: totalAmount).doubleValue
        )
    }

    func addItem() {
        let newItem = EditableLineItem(
            id: UUID(),
            name: "",
            quantity: 1.0,
            unitPrice: 0,
            totalPrice: 0
        )
        items.append(newItem)
    }

    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }
}

/// Editable line item with Decimal precision
@Observable
final class EditableLineItem: Identifiable {
    let id: UUID
    var name: String
    var quantity: Decimal
    var unitPrice: Decimal
    var totalPrice: Decimal

    /// Auto-calculate total from quantity and unit price
    func updateTotalFromQuantityAndPrice() {
        totalPrice = quantity * unitPrice
    }

    /// Auto-calculate unit price from total and quantity
    func updateUnitPriceFromTotal() {
        if quantity > 0 {
            unitPrice = totalPrice / quantity
        }
    }

    init(id: UUID = UUID(), name: String, quantity: Decimal, unitPrice: Decimal, totalPrice: Decimal) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
    }

    /// Create from PartiallyGenerated line item
    convenience init?(from partial: LineItemData.PartiallyGenerated) {
        guard let name = partial.name,
              let quantity = partial.quantity,
              let unitPrice = partial.unitPrice,
              let totalPrice = partial.totalPrice else {
            return nil
        }

        self.init(
            name: name,
            quantity: Decimal(quantity),
            unitPrice: Decimal(unitPrice),
            totalPrice: Decimal(totalPrice)
        )
    }

    /// Convert to LineItemData
    func toLineItemData() -> LineItemData {
        return LineItemData(
            name: name,
            quantity: NSDecimalNumber(decimal: quantity).doubleValue,
            unitPrice: NSDecimalNumber(decimal: unitPrice).doubleValue,
            totalPrice: NSDecimalNumber(decimal: totalPrice).doubleValue
        )
    }
}
