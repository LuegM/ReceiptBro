import Foundation
import FoundationModels

/// Foundation Models structured output model for receipt extraction
/// Properties are ordered for optimal generation quality (summary fields last)
@Generable
struct ReceiptData {
    @Guide(description: "The merchant or store name exactly as it appears on the receipt")
    let merchantName: String

    @Guide(description: "Street address of the merchant location, if shown on receipt")
    let address: String?

    @Guide(description: "Purchase date in YYYY-MM-DD format. Extract from receipt date/time stamp.")
    let date: String

    @Guide(description: "Transaction ID, receipt number, trace number, or order number from the receipt. Look for fields like 'Trace-Nr', 'Transaction', 'Receipt #', 'Bon-Nr', or similar identifiers. Prefer numeric transaction/trace IDs over receipt numbers.")
    let transactionId: String?

    @Guide(description: "Payment method used. Extract from receipt footer (e.g., 'Cash', 'Credit Card', 'Debit Card', 'Mobile Payment', 'VISA ****1234')")
    let paymentMethod: String?

    @Guide(description: "Currency code in ISO 4217 format (e.g., 'USD', 'EUR', 'GBP', 'JPY', 'CAD'). Infer from currency symbols on receipt: $ = USD, € = EUR, £ = GBP, ¥ = JPY/CNY. Default to 'USD' if unclear.")
    let currency: String

    @Guide(description: "Individual line items purchased. Extract product name, quantity, unit price, and total price for each item. Each line item should appear only once - do not create duplicates. The sum of all item totalPrices should approximately equal the receipt subtotal (before tax).")
    let items: [LineItemData]

    @Guide(description: "Tax amount if itemized separately on the receipt. May appear as single 'Tax' line or as percentage breakdown (e.g., '10% MwSt' or 'VAT'). Sum all tax amounts if multiple rates shown. Omit if no tax information is present.")
    let taxAmount: Double?

    @Guide(description: "Total amount paid including all taxes and fees. This is the final transaction amount from the receipt.")
    let totalAmount: Double
}

/// Individual line item on a receipt
/// Properties ordered for optimal generation: identifiers first, calculations last
@Generable
struct LineItemData {
    @Guide(description: "Product or service name exactly as shown on receipt. Preserve original text including brand names and descriptions.")
    let name: String

    @Guide(description: "Quantity purchased. Extract from receipt or default to 1.0 if quantity is not explicitly shown.")
    let quantity: Double

    @Guide(description: "Price per single unit. If receipt shows only total price and quantity, calculate as totalPrice ÷ quantity.")
    let unitPrice: Double

    @Guide(description: "Total price for this line item. Extract from receipt or calculate as quantity × unitPrice.")
    let totalPrice: Double
}

// MARK: - Example for One-Shot Prompting

extension ReceiptData {
    /// Example receipt for one-shot prompting to improve extraction accuracy
    /// Property order matches the ReceiptData definition for optimal generation
    /// NOTE: This is a format example only - actual extraction must use values from the provided OCR text
    static let exampleGroceryReceipt = ReceiptData(
        merchantName: "SuperMarkt Plus",
        address: "Hauptstrasse 45, 1010 Wien",
        date: "2024-03-15",
        transactionId: "058291",
        paymentMethod: "Debit Card",
        currency: "EUR",
        items: [
            LineItemData(name: "Bio Apfel", quantity: 1.5, unitPrice: 2.99, totalPrice: 4.49),
            LineItemData(name: "Vollmilch 1L", quantity: 2.0, unitPrice: 1.19, totalPrice: 2.38),
            LineItemData(name: "Brot Vollkorn", quantity: 1.0, unitPrice: 3.49, totalPrice: 3.49),
            LineItemData(name: "Butter 250g", quantity: 1.0, unitPrice: 2.79, totalPrice: 2.79)
        ],
        taxAmount: 0.82,
        totalAmount: 13.15
    )
}
