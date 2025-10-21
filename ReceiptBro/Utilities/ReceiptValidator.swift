import Foundation
import OSLog

/// Validates and cleans receipt data extracted by Foundation Models
struct ReceiptValidator {

    /// Validation result with warnings and cleaned data
    struct ValidationResult {
        let warnings: [String]
        let hasCriticalIssues: Bool

        var isValid: Bool { !hasCriticalIssues }
    }

    /// Validate a PartiallyGenerated receipt and return warnings
    static func validate(_ data: ReceiptData.PartiallyGenerated) -> ValidationResult {
        var warnings: [String] = []
        var hasCriticalIssues = false

        // Validate required fields
        if data.merchantName == nil {
            warnings.append("Missing merchant name")
            hasCriticalIssues = true
        }

        if data.date == nil {
            warnings.append("Missing date")
            hasCriticalIssues = true
        } else if let date = data.date, !isValidDateFormat(date) {
            warnings.append("Date format should be YYYY-MM-DD, found: \(date)")
        }

        if data.totalAmount == nil {
            warnings.append("Missing total amount")
            hasCriticalIssues = true
        }

        if data.currency == nil {
            warnings.append("Missing currency code")
        }

        // Validate items
        if let items = data.items {
            if items.isEmpty {
                warnings.append("No line items found")
            } else {
                // Check for duplicates
                let duplicates = findDuplicateItems(items)
                if !duplicates.isEmpty {
                    warnings.append("Found duplicate items: \(duplicates.joined(separator: ", "))")
                }

                // Validate item totals
                let itemsWithIssues = validateItemPrices(items)
                warnings.append(contentsOf: itemsWithIssues)

                // Validate sum of items vs total
                if let totalAmount = data.totalAmount, let taxAmount = data.taxAmount {
                    if let sumWarning = validateTotalSum(items: items, taxAmount: taxAmount, totalAmount: totalAmount) {
                        warnings.append(sumWarning)
                    }
                }
            }
        } else {
            warnings.append("No items array provided")
        }

        // Log all warnings
        if !warnings.isEmpty {
            Logger.extraction.warning("Validation found \(warnings.count) issue(s):")
            for warning in warnings {
                Logger.extraction.warning("  - \(warning)")
            }
        } else {
            Logger.extraction.info("Validation passed with no warnings")
        }

        return ValidationResult(warnings: warnings, hasCriticalIssues: hasCriticalIssues)
    }

    // MARK: - Private Validation Methods

    private static func isValidDateFormat(_ date: String) -> Bool {
        // Check for YYYY-MM-DD format
        let pattern = #"^\d{4}-\d{2}-\d{2}$"#
        return date.range(of: pattern, options: .regularExpression) != nil
    }

    private static func findDuplicateItems(_ items: [LineItemData.PartiallyGenerated]) -> [String] {
        var nameCount: [String: Int] = [:]
        var duplicates: [String] = []

        for item in items {
            guard let name = item.name else { continue }

            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            nameCount[normalizedName, default: 0] += 1

            if nameCount[normalizedName] == 2 {
                duplicates.append(name)
            }
        }

        return duplicates
    }

    private static func validateItemPrices(_ items: [LineItemData.PartiallyGenerated]) -> [String] {
        var warnings: [String] = []

        for (index, item) in items.enumerated() {
            guard let quantity = item.quantity,
                  let unitPrice = item.unitPrice,
                  let totalPrice = item.totalPrice else {
                continue
            }

            let calculatedTotal = quantity * unitPrice
            let difference = abs(calculatedTotal - totalPrice)

            // Allow 1 cent tolerance for rounding
            if difference > 0.01 {
                let name = item.name ?? "Item \(index + 1)"
                warnings.append("Price mismatch for '\(name)': \(quantity) × \(unitPrice) = \(calculatedTotal), but total shows \(totalPrice)")
            }
        }

        return warnings
    }

    private static func validateTotalSum(items: [LineItemData.PartiallyGenerated], taxAmount: Double, totalAmount: Double) -> String? {
        var subtotal: Double = 0

        for item in items {
            if let totalPrice = item.totalPrice {
                subtotal += totalPrice
            }
        }

        let calculatedTotal = subtotal + taxAmount
        let difference = abs(calculatedTotal - totalAmount)

        // Allow 5 cent tolerance for rounding issues
        if difference > 0.05 {
            return "Total amount mismatch: items sum to \(subtotal), plus tax \(taxAmount) = \(calculatedTotal), but receipt shows \(totalAmount)"
        }

        return nil
    }

    /// Remove duplicate items (keeps first occurrence)
    static func removeDuplicateItems(from items: [LineItemData.PartiallyGenerated]) -> [LineItemData.PartiallyGenerated] {
        var seen: Set<String> = []
        var uniqueItems: [LineItemData.PartiallyGenerated] = []

        for item in items {
            guard let name = item.name else { continue }

            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if !seen.contains(normalizedName) {
                seen.insert(normalizedName)
                uniqueItems.append(item)
            } else {
                Logger.extraction.info("Removing duplicate item: \(name)")
            }
        }

        return uniqueItems
    }
}
