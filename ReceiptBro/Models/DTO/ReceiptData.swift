import Foundation
import FoundationModels

/// Foundation Models structured output model for receipt extraction
/// Properties are ordered for optimal generation quality (summary fields last)
@Generable
struct ReceiptData {
    @Guide(description: "The merchant or store name exactly as it appears on the receipt")
    let merchantName: String

    @Guide(description: "Physical street address of the merchant location. Extract street name, number, city, and postal code if shown. EXCLUDE website URLs, email addresses, and phone numbers. Look for address keywords like 'Street', 'Str', 'Ave', 'Road', city names, or postal codes. Example: '500 Broadway, New York, NY 10012' or 'Wexstraße 24, 1200 Wien'.")
    let address: String?

    @Guide(description: "Purchase date in YYYY-MM-DD format only (e.g., '2024-03-15'). Convert formats like '19.08.2025' or '08/19/2025' to '2025-08-19'. Extract from 'Datum:' or 'Date:' field.")
    let date: String

    @Guide(description: "Transaction ID, receipt number, trace number, or order number from the receipt. Look for fields like 'Trace-Nr', 'Transaction', 'Receipt #', 'Bon-Nr', or similar identifiers. Prefer numeric transaction/trace IDs over receipt numbers.")
    let transactionId: String?

    @Guide(description: "Payment method used. Extract the card type or payment method name only (e.g., 'VISA', 'Cash', 'Credit Card', 'Debit Card'). Do NOT include transaction status text like 'Gegeben' or amounts. Look for card brand names in payment section.")
    let paymentMethod: String?

    @Guide(description: "Currency code in ISO 4217 format. Infer from currency symbols on receipt: $ = USD, € = EUR, £ = GBP, ¥ = JPY/CNY. Default to 'USD' if unclear.")
    @Guide(.anyOf(["USD", "EUR", "GBP", "JPY", "CAD", "CHF", "AUD", "CNY"]))
    let currency: String

    @Guide(description: "Individual line items purchased (each appears exactly once). For each item extract: product name, quantity (default 1.0 unless explicit '2 x' indicator present), unit price, and total price. Line items can have negative totalPrice values if they represent per-item discounts. Sum of all totalPrices should match receipt subtotal after discounts.")
    let items: [LineItemData]

    @Guide(description: "Total discount amount applied to the purchase. Extract from 'Discount', 'Rabatt', or negative line items (e.g., '-10.00', 'Discount -€5.00'). This should be a POSITIVE number representing the discount amount (e.g., if receipt shows '-10.00', extract 10.00). If discounts are applied per-item (shown as negative line items), sum all negative item values. Omit if no discount shown.")
    let discountAmount: Double?

    @Guide(description: "Tax amount - EUROPEAN RECEIPTS ONLY: Tax is shown as a breakdown of tax ALREADY INCLUDED in prices (e.g., '10% MwSt von 3.16 = 0.32' means €0.32 of the €3.16 total is tax). If multiple tax rates shown, SUM the calculated amounts (0.32 + 0.50 = 0.82). US RECEIPTS: Tax added to subtotal. Look for 'Tax', 'MwSt', 'VAT', 'GST'. Extract the calculated tax amount. Omit if no tax shown.")
    let taxAmount: Double?

    @Guide(description: "Tax system used on this receipt. Set to 'included' if tax is part of item prices (European style - look for 'MwSt', 'VAT' breakdowns AFTER the total). Set to 'added' if tax is added to subtotal (US/Canada style - tax line appears BEFORE total). Default to 'included' for EUR/GBP, 'added' for USD/CAD.")
    @Guide(.anyOf(["included", "added"]))
    let taxType: String?

    @Guide(description: "Total amount paid including all taxes and fees. This is the final transaction amount from the receipt.")
    let totalAmount: Double
}

/// Individual line item on a receipt
/// Properties ordered for optimal generation: identifiers first, calculations last
@Generable
struct LineItemData {
    @Guide(description: "Product or service name exactly as shown on receipt. Preserve original text including brand names and descriptions.")
    let name: String

    @Guide(description: "Quantity purchased. DEFAULT is 1.0. ONLY change if you see explicit text '2 x', '3 ×', or '@ 5' immediately BEFORE the product name on the SAME LINE. DO NOT infer from patterns. DO NOT assume previous items' patterns continue. Each line is independent.")
    let quantity: Double

    @Guide(description: "Price per single unit. For items with quantity indicator: the number after 'x' or '×' is the unit price. For items without quantity indicator: same as totalPrice since quantity is 1.")
    let unitPrice: Double

    @Guide(description: "Total price for this line item (quantity × unitPrice). For items without quantity indicator, this equals the single price shown. Can be negative for discount line items (e.g., 'Discount -5.00' would have totalPrice = -5.00).")
    let totalPrice: Double
}

// MARK: - Examples for Few-Shot Prompting

extension ReceiptData {
    /// Example receipts for few-shot prompting to improve extraction accuracy
    /// Property order matches the ReceiptData definition for optimal generation
    /// NOTE: These are format examples only - actual extraction must use values from the provided OCR text

    static let exampleGroceryReceipt = ReceiptData(
        merchantName: "[EXAMPLE - DO NOT COPY]",
        address: "[FAKE ADDRESS]",
        date: "2024-03-15",
        transactionId: "EX123",
        paymentMethod: "Card",
        currency: "EUR",
        items: [
            LineItemData(name: "[Item A]", quantity: 2.0, unitPrice: 1.50, totalPrice: 3.00),
            LineItemData(name: "[Item B]", quantity: 1.0, unitPrice: 2.50, totalPrice: 2.50)
        ],
        discountAmount: nil,
        taxAmount: 0.45,
        taxType: "included",
        totalAmount: 5.50
    )

    static let exampleUSReceipt = ReceiptData(
        merchantName: "[EXAMPLE RETAILER - DO NOT COPY]",
        address: "[FAKE ADDRESS - DO NOT USE]",
        date: "2024-06-22",
        transactionId: "EXAMPLE-456",
        paymentMethod: "Credit Card",
        currency: "USD",
        items: [
            LineItemData(name: "[Item X - PLACEHOLDER]", quantity: 1.0, unitPrice: 12.99, totalPrice: 12.99),
            LineItemData(name: "[Item Y - PLACEHOLDER]", quantity: 2.0, unitPrice: 3.49, totalPrice: 6.98),
            LineItemData(name: "[Item Z - PLACEHOLDER]", quantity: 1.0, unitPrice: 18.99, totalPrice: 18.99)
        ],
        discountAmount: nil,
        taxAmount: 3.16,
        taxType: "added",
        totalAmount: 42.12
    )

    static let exampleRestaurantReceipt = ReceiptData(
        merchantName: "[EXAMPLE RESTAURANT - DO NOT COPY]",
        address: "[FAKE ADDRESS - DO NOT USE]",
        date: "2024-09-10",
        transactionId: "EXAMPLE-789",
        paymentMethod: "Cash",
        currency: "EUR",
        items: [
            LineItemData(name: "[Food Item 1 - PLACEHOLDER]", quantity: 2.0, unitPrice: 4.50, totalPrice: 9.00),
            LineItemData(name: "[Food Item 2 - PLACEHOLDER]", quantity: 1.0, unitPrice: 6.80, totalPrice: 6.80),
            LineItemData(name: "[Beverage - PLACEHOLDER]", quantity: 1.0, unitPrice: 3.20, totalPrice: 3.20)
        ],
        discountAmount: nil,
        taxAmount: 1.90,
        taxType: "included",
        totalAmount: 20.90
    )
}

