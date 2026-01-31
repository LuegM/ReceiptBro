import Foundation
import FoundationModels

/// LLM structured output for receipts
@Generable
struct ReceiptData {
    @Guide(description: "The merchant or store name exactly as it appears on the receipt")
    let merchantName: String

    @Guide(description: "Physical street address of the merchant location. Extract street name, number, city, and postal code if shown. EXCLUDE website URLs, email addresses, and phone numbers. Look for address keywords like 'Street', 'Str', 'Ave', 'Road', city names, or postal codes. Example: '500 Broadway, New York, NY 10012' or 'Wexstraße 24, 1200 Wien'.")
    let address: String?

    @Guide(description: "Purchase date in YYYY-MM-DD format only (e.g., '2024-03-15'). Convert formats like '19.08.2025' or '08/19/2025' to '2025-08-19'. Extract from 'Datum:' or 'Date:' field.")
    let date: String

    @Guide(description: "Payment method used. Extract the card type or payment method name only (e.g., 'VISA', 'Cash', 'Credit Card', 'Debit Card'). Do NOT include transaction status text like 'Gegeben' or amounts. Look for card brand names in payment section.")
    let paymentMethod: String?

    @Guide(description: "Currency code in ISO 4217 format. Infer from currency symbols on receipt: $ = USD, € = EUR, £ = GBP, ¥ = JPY/CNY. Default to 'USD' if unclear.")
    @Guide(.anyOf(["USD", "EUR", "GBP", "JPY", "CAD", "CHF", "AUD", "CNY"]))
    let currency: String

    @Guide(description: """
Individual line items purchased. Quantity indicators may appear on the same line ('2 x Milk 3.00')
or on a separate line above the product. The number after 'x' is the unit price. Single letters
(A, B, C) between name and price are tax codes - ignore them. Line items can have negative
totalPrice values for discounts. Sum of totalPrices should match subtotal.
""")
    let items: [LineItemData]

    @Guide(description: "Total discount amount applied to the purchase. ONLY EXTRACT WHEN you see explicit discount keywords like 'Discount', 'Rabatt', 'Rabais', 'Descuento', or negative line items labeled as discounts (e.g., 'Discount -€5.00'). This should be a POSITIVE number representing the discount amount (e.g., if receipt shows '-10.00 Discount', extract 10.00). IMPORTANT: Tax breakdowns (MwSt, VAT, GST) are NOT discounts - these show tax included in prices. Loyalty points, rewards, or 'Ö' symbols are NOT discounts. Omit this field entirely if no explicit discount is shown.")
    let discountAmount: Double?

    @Guide(description: "Tax amount - Look for 'Tax', 'MwSt', 'VAT', 'GST'. EUROPEAN RECEIPTS: Tax is shown as a breakdown AFTER the total (e.g., 'B: 10% MwSt von 3.16 = 0.32' means €0.32 of the total is tax). If multiple tax rates shown, SUM them (0.32 + 0.50 = 0.82). US/CANADA RECEIPTS: Tax line appears BEFORE the total, added to subtotal. Extract the calculated tax amount. IMPORTANT: This is the tax amount, NOT a discount. Omit if no tax shown.")
    let taxAmount: Double?

    @Guide(description: "Tax system used on this receipt. Set to 'included' if tax is part of item prices (European style - look for 'MwSt', 'VAT' breakdowns AFTER the total). Set to 'added' if tax is added to subtotal (US/Canada style - tax line appears BEFORE total). Default to 'included' for EUR/GBP, 'added' for USD/CAD.")
    @Guide(.anyOf(["included", "added"]))
    let taxType: String?

    @Guide(description: "Total amount paid including all taxes and fees. This is the final transaction amount from the receipt.")
    let totalAmount: Double
}

/// Single line item
@Generable
struct LineItemData {
    @Guide(description: "Product or service name exactly as shown on receipt. Preserve original text including brand names and descriptions.")
    let name: String

    @Guide(description: """
Quantity purchased. DEFAULT is 1.0. Look for patterns like '2 x', '3 ×', or '@ 5'.
May appear on same line as product or on a separate line above. If a line shows only
'2 x 0.99', it refers to the next product line (qty=2, unitPrice=0.99).
""")
    let quantity: Double

    @Guide(description: """
Price per single unit. For quantity patterns:
- '2 x 0.99' means unitPrice=0.99 (the number AFTER 'x')
- The total on the product line should equal qty × unitPrice
- For items without quantity indicator: unitPrice equals totalPrice
""")
    let unitPrice: Double

    @Guide(description: """
Total price for this line item (quantity × unitPrice). This is the final price shown for the item.
Can be negative for discount line items (e.g., 'Discount -5.00' would have totalPrice = -5.00).
""")
    let totalPrice: Double
}

// MARK: - Few-Shot Examples

extension ReceiptData {
    // Format examples only - LLM should use actual OCR text values

    static let exampleGroceryReceipt = ReceiptData(
        merchantName: "[EXAMPLE - DO NOT COPY]",
        address: "[FAKE ADDRESS]",
        date: "2024-03-15",
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

    // MARK: - Mock Data

    static let mockLongboards = ReceiptData(
        merchantName: "Longboards",
        address: "92-161 Waipahe Place, Kapolei, HI 96707",
        date: "2019-01-11",
        paymentMethod: "Credit Card",
        currency: "USD",
        items: [
            LineItemData(name: "Green Salad", quantity: 1.0, unitPrice: 8.0, totalPrice: 8.0),
            LineItemData(name: "Wagyu Cheeseburger", quantity: 1.0, unitPrice: 19.0, totalPrice: 19.0),
            LineItemData(name: "Garlic Fries", quantity: 1.0, unitPrice: 2.0, totalPrice: 2.0),
            LineItemData(name: "Drink of the Day", quantity: 1.0, unitPrice: 9.75, totalPrice: 9.75),
            LineItemData(name: "Tea", quantity: 2.0, unitPrice: 4.0, totalPrice: 8.0)
        ],
        discountAmount: 3.30,
        taxAmount: 1.86,
        taxType: "added",
        totalAmount: 41.31
    )

    /// Preview helper - simulates streaming
    static func streamResponse(
        from json: String,
        offsetBy distance: Int = 20,
        delay: Duration = .milliseconds(100)
    ) -> AsyncThrowingStream<ReceiptData.PartiallyGenerated, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var index = json.startIndex
                while index < json.endIndex {
                    let nextIndex = json.index(index, offsetBy: distance, limitedBy: json.endIndex) ?? json.endIndex
                    let substring = String(json[..<nextIndex])
                    let generatedContent = try GeneratedContent(json: substring)
                    let content = try PartiallyGenerated(generatedContent)
                    continuation.yield(content)
                    index = nextIndex
                    try await Task.sleep(for: delay)
                }
                continuation.finish()
            }
        }
    }
}

