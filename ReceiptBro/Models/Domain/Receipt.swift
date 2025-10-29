import Foundation
import SwiftData

@Model
final class Receipt {
    var id: UUID
    var merchantName: String
    var date: Date
    var totalAmount: Double
    var discountAmount: Double?
    var taxAmount: Double?
    var taxType: String? // "included" or "added"
    var paymentMethod: String?
    var transactionId: String?
    var address: String?
    var currency: String // ISO 4217 currency code (e.g., "USD", "EUR", "GBP")
    var imageData: Data?

    @Relationship(deleteRule: .cascade, inverse: \LineItem.receipt)
    var items: [LineItem]

    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        merchantName: String,
        date: Date,
        totalAmount: Double,
        discountAmount: Double? = nil,
        taxAmount: Double? = nil,
        taxType: String? = nil,
        paymentMethod: String? = nil,
        transactionId: String? = nil,
        address: String? = nil,
        currency: String = "USD",
        imageData: Data? = nil,
        items: [LineItem] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.merchantName = merchantName
        self.date = date
        self.totalAmount = totalAmount
        self.discountAmount = discountAmount
        self.taxAmount = taxAmount
        self.taxType = taxType
        self.paymentMethod = paymentMethod
        self.transactionId = transactionId
        self.address = address
        self.currency = currency
        self.imageData = imageData
        self.items = items
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Create Receipt from Foundation Models extracted data
    convenience init(from receiptData: ReceiptData, imageData: Data? = nil) throws {
        // Parse date string to Date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        guard let parsedDate = formatter.date(from: receiptData.date) else {
            throw ReceiptError.invalidDateFormat
        }

        self.init(
            merchantName: receiptData.merchantName,
            date: parsedDate,
            totalAmount: receiptData.totalAmount,
            discountAmount: receiptData.discountAmount,
            taxAmount: receiptData.taxAmount,
            taxType: receiptData.taxType,
            paymentMethod: receiptData.paymentMethod,
            transactionId: receiptData.transactionId,
            address: receiptData.address,
            currency: receiptData.currency,
            imageData: imageData,
            items: []
        )

        // Create line items and establish relationship
        self.items = receiptData.items.map { itemData in
            LineItem(from: itemData, receipt: self)
        }
    }
}

enum ReceiptError: LocalizedError {
    case invalidDateFormat

    var errorDescription: String? {
        switch self {
        case .invalidDateFormat:
            return "Invalid date format. Expected YYYY-MM-DD."
        }
    }
}
