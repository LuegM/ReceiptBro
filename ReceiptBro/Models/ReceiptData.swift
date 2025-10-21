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

    @Guide(description: "Purchase date in YYYY-MM-DD format only (e.g., '2024-03-15'). Convert formats like '19.08.2025' or '08/19/2025' to '2025-08-19'. Extract from 'Datum:' or 'Date:' field.")
    let date: String

    @Guide(description: "Transaction ID, receipt number, trace number, or order number from the receipt. Look for fields like 'Trace-Nr', 'Transaction', 'Receipt #', 'Bon-Nr', or similar identifiers. Prefer numeric transaction/trace IDs over receipt numbers.")
    let transactionId: String?

    @Guide(description: "Payment method used. Extract from receipt footer (e.g., 'Cash', 'Credit Card', 'Debit Card', 'Mobile Payment', 'VISA ****1234')")
    let paymentMethod: String?

    @Guide(description: "Currency code in ISO 4217 format (e.g., 'USD', 'EUR', 'GBP', 'JPY', 'CAD'). Infer from currency symbols on receipt: $ = USD, € = EUR, £ = GBP, ¥ = JPY/CNY. Default to 'USD' if unclear.")
    let currency: String

    @Guide(description: "Individual line items purchased. Extract product name, quantity, unit price, and total price for each item. Each line item should appear only once - do not create duplicates. The sum of all item totalPrices should approximately equal the receipt subtotal (before tax).")
    let items: [LineItemData]

    @Guide(description: "Tax amount if itemized separately. IMPORTANT: If multiple tax rates shown (e.g., '10% MwSt von 3.16 = 0.32' AND '20% MwSt von 2.49 = 0.50'), you MUST SUM them (0.32 + 0.50 = 0.82). Look for 'Tax', 'MwSt', 'VAT', 'GST'. Extract the calculated tax amount, not the base amount. Omit if no tax shown.")
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

// MARK: - Examples for Few-Shot Prompting

extension ReceiptData {
    /// Example receipts for few-shot prompting to improve extraction accuracy
    /// Property order matches the ReceiptData definition for optimal generation
    /// NOTE: These are format examples only - actual extraction must use values from the provided OCR text

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

    static let exampleUSReceipt = ReceiptData(
        merchantName: "Target",
        address: "500 Broadway, New York, NY 10012",
        date: "2024-06-22",
        transactionId: "T-9847362",
        paymentMethod: "Credit Card",
        currency: "USD",
        items: [
            LineItemData(name: "Paper Towels 6pk", quantity: 1.0, unitPrice: 12.99, totalPrice: 12.99),
            LineItemData(name: "Dish Soap", quantity: 2.0, unitPrice: 3.49, totalPrice: 6.98),
            LineItemData(name: "Laundry Detergent", quantity: 1.0, unitPrice: 18.99, totalPrice: 18.99)
        ],
        taxAmount: 3.16,
        totalAmount: 42.12
    )

    static let exampleRestaurantReceipt = ReceiptData(
        merchantName: "Café Central",
        address: "Herrengasse 14, 1010 Wien",
        date: "2024-09-10",
        transactionId: "4729183",
        paymentMethod: "Cash",
        currency: "EUR",
        items: [
            LineItemData(name: "Cappuccino", quantity: 2.0, unitPrice: 4.50, totalPrice: 9.00),
            LineItemData(name: "Apfelstrudel", quantity: 1.0, unitPrice: 6.80, totalPrice: 6.80),
            LineItemData(name: "Mineral Water", quantity: 1.0, unitPrice: 3.20, totalPrice: 3.20)
        ],
        taxAmount: 1.90,
        totalAmount: 20.90
    )
}

