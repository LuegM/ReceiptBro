import Foundation
import OSLog

/// Validates and cleans receipt data extracted by Foundation Models
struct ReceiptValidator {

    /// Validation result with warnings and corrected data
    struct ValidationResult {
        let warnings: [String]
        let hasCriticalIssues: Bool
        let fieldIssues: [FieldIssue] // Field-specific validation issues
        let correctedData: ReceiptData.PartiallyGenerated? // Auto-corrected receipt data if corrections were made

        var isValid: Bool { !hasCriticalIssues }
    }

    /// Field-specific validation issue for inline display
    struct FieldIssue {
        let field: ReceiptField
        let message: String
        let severity: Severity

        enum Severity {
            case warning
            case error
        }
    }

    /// Receipt fields that can have validation issues
    enum ReceiptField {
        case merchantName
        case date
        case totalAmount
        case taxAmount
        case currency
        case items
        case paymentMethod
    }

    /// Validate a PartiallyGenerated receipt and return warnings with auto-corrections
    static func validate(_ data: ReceiptData.PartiallyGenerated) -> ValidationResult {
        var warnings: [String] = []
        var fieldIssues: [FieldIssue] = []
        var hasCriticalIssues = false
        var correctedData = data // Start with a copy that we'll modify if needed
        var hasCorrections = false

        // Validate required fields
        if data.merchantName == nil {
            warnings.append("Missing merchant name")
            fieldIssues.append(FieldIssue(field: .merchantName, message: "Missing merchant name", severity: .error))
            hasCriticalIssues = true
        }

        if data.date == nil {
            warnings.append("Missing date")
            fieldIssues.append(FieldIssue(field: .date, message: "Missing date", severity: .error))
            hasCriticalIssues = true
        } else if let date = data.date, !isValidDateFormat(date) {
            let message = "Date format should be YYYY-MM-DD, found: \(date)"
            warnings.append(message)
            fieldIssues.append(FieldIssue(field: .date, message: message, severity: .warning))
        }

        if data.totalAmount == nil {
            warnings.append("Missing total amount")
            fieldIssues.append(FieldIssue(field: .totalAmount, message: "Missing total amount", severity: .error))
            hasCriticalIssues = true
        }

        if data.currency == nil {
            warnings.append("Missing currency code")
            fieldIssues.append(FieldIssue(field: .currency, message: "Missing currency code", severity: .warning))
        }

        // Validate items
        if let items = data.items {
            if items.isEmpty {
                let message = "No line items found"
                warnings.append(message)
                fieldIssues.append(FieldIssue(field: .items, message: message, severity: .warning))
            } else {
                // Check for duplicates
                let duplicates = findDuplicateItems(items)
                if !duplicates.isEmpty {
                    let message = "Found duplicate items: \(duplicates.joined(separator: ", "))"
                    warnings.append(message)
                    fieldIssues.append(FieldIssue(field: .items, message: "Duplicate items detected", severity: .warning))
                }

                // Validate item totals (quantity × unit price = total price)
                let itemsWithIssues = validateItemPrices(items)
                warnings.append(contentsOf: itemsWithIssues)
                if !itemsWithIssues.isEmpty {
                    fieldIssues.append(FieldIssue(field: .items, message: "Some item prices don't match quantity × unit price", severity: .warning))
                }

                // Validate sum of items vs total - MOVED TO END
                // This should be the last check as we need all items to be correct first
                if let totalAmount = data.totalAmount {
                    // Check tax type and calculate accordingly
                    let taxValidation = validateTaxAndTotal(
                        items: items,
                        taxAmount: data.taxAmount,
                        totalAmount: totalAmount,
                        taxType: data.taxType
                    )

                    if let taxWarning = taxValidation.warning {
                        warnings.append(taxWarning)
                        fieldIssues.append(FieldIssue(field: .totalAmount, message: taxWarning, severity: .warning))
                    }

                    // Auto-correct tax type if it's wrong
                    if let correctedTaxType = taxValidation.correctedTaxType {
                        Logger.extraction.info("Auto-correcting taxType from '\(data.taxType ?? "nil")' to '\(correctedTaxType)'")
                        correctedData.taxType = correctedTaxType
                        hasCorrections = true
                    }
                }
            }
        } else {
            warnings.append("No items array provided")
            fieldIssues.append(FieldIssue(field: .items, message: "No items found", severity: .error))
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

        if hasCorrections {
            Logger.extraction.info("Auto-corrections were applied to the receipt data")
        }

        return ValidationResult(
            warnings: warnings,
            hasCriticalIssues: hasCriticalIssues,
            fieldIssues: fieldIssues,
            correctedData: hasCorrections ? correctedData : nil
        )
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

    /// Validation result for tax and total checking
    private struct TaxValidationResult {
        let warning: String?
        let taxTypeWarning: String?
        let correctedTaxType: String? // The correct tax type if auto-correction is needed
    }

    /// Comprehensive validation of tax calculation and total amount
    /// This method automatically detects whether tax is included or added
    private static func validateTaxAndTotal(
        items: [LineItemData.PartiallyGenerated],
        taxAmount: Double?,
        totalAmount: Double,
        taxType: String?
    ) -> TaxValidationResult {
        // Calculate sum of all items
        var itemsSum: Double = 0
        for item in items {
            if let totalPrice = item.totalPrice {
                itemsSum += totalPrice
            }
        }

        // If no tax amount is provided, just check if items sum matches total
        guard let taxAmount = taxAmount else {
            let difference = abs(itemsSum - totalAmount)
            if difference > 0.05 {
                return TaxValidationResult(
                    warning: "Items sum to \(String(format: "%.2f", itemsSum)), but total is \(String(format: "%.2f", totalAmount)) (difference: \(String(format: "%.2f", difference)))",
                    taxTypeWarning: nil,
                    correctedTaxType: nil
                )
            }
            return TaxValidationResult(warning: nil, taxTypeWarning: nil, correctedTaxType: nil)
        }

        // Tax amount is provided - determine if it's included or added
        let tolerance: Double = 0.05

        // Check if tax is INCLUDED (European style): items already contain tax
        // In this case: itemsSum should ≈ totalAmount
        let includedDifference = abs(itemsSum - totalAmount)

        // Check if tax is ADDED (US style): tax is added to items subtotal
        // In this case: itemsSum + taxAmount should ≈ totalAmount
        let addedDifference = abs((itemsSum + taxAmount) - totalAmount)

        var warning: String? = nil
        var correctedTaxType: String? = nil

        // Determine which calculation is correct
        if includedDifference <= tolerance {
            // Tax is INCLUDED - auto-correct if taxType is wrong
            if let taxType = taxType, taxType != "included" {
                correctedTaxType = "included"
                Logger.extraction.info("Detected tax is included (items: \(String(format: "%.2f", itemsSum)) ≈ total: \(String(format: "%.2f", totalAmount))), correcting taxType from '\(taxType)' to 'included'")
            }
            // No warning - validation passed for included tax
        } else if addedDifference <= tolerance {
            // Tax is ADDED - auto-correct if taxType is wrong
            if let taxType = taxType, taxType != "added" {
                correctedTaxType = "added"
                Logger.extraction.info("Detected tax is added (items: \(String(format: "%.2f", itemsSum)) + tax: \(String(format: "%.2f", taxAmount)) = \(String(format: "%.2f", itemsSum + taxAmount)) ≈ total: \(String(format: "%.2f", totalAmount))), correcting taxType from '\(taxType)' to 'added'")
            }
            // No warning - validation passed for added tax
        } else {
            // Neither calculation works - something is wrong
            warning = """
            Total amount mismatch:
            • Items sum: \(String(format: "%.2f", itemsSum))
            • Tax: \(String(format: "%.2f", taxAmount))
            • Total on receipt: \(String(format: "%.2f", totalAmount))

            Neither calculation matches:
            • If tax included: \(String(format: "%.2f", itemsSum)) ≠ \(String(format: "%.2f", totalAmount)) (diff: \(String(format: "%.2f", includedDifference)))
            • If tax added: \(String(format: "%.2f", itemsSum + taxAmount)) ≠ \(String(format: "%.2f", totalAmount)) (diff: \(String(format: "%.2f", addedDifference)))

            Please verify items or tax amount.
            """
        }

        return TaxValidationResult(warning: warning, taxTypeWarning: nil, correctedTaxType: correctedTaxType)
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
