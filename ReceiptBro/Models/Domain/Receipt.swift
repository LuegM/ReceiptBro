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
    var taxType: String?
    var paymentMethod: String?
    var address: String?
    var currency: String
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
        self.address = address
        self.currency = currency
        self.imageData = imageData
        self.items = items
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// From ReceiptData (LLM output)
    convenience init(from receiptData: ReceiptData, imageData: Data? = nil) throws {
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
            address: receiptData.address,
            currency: receiptData.currency,
            imageData: imageData,
            items: []
        )

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
