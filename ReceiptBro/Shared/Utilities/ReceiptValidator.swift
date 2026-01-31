import Foundation
import OSLog

// Validates extracted receipt data for completeness and math accuracy
struct ReceiptValidator {

    // MARK: - Result Types

    struct ValidationResult {
        let warnings: [String]
        let hasCriticalIssues: Bool
        let fieldIssues: [FieldIssue] // Field-specific validation issues
        let correctedData: ReceiptData.PartiallyGenerated? // Auto-corrected receipt data if corrections were made

        var isValid: Bool { !hasCriticalIssues }
    }

    struct FieldIssue {
        let field: ReceiptField
        let message: String
        let severity: Severity

        enum Severity {
            case warning
            case error
        }
    }

    enum ReceiptField {
        case merchantName
        case date
        case totalAmount
        case taxAmount
        case currency
        case items
        case paymentMethod
    }

    // MARK: - Main Validation

    // Checks required fields, validates math, auto-corrects common LLM errors
    static func validate(_ data: ReceiptData.PartiallyGenerated) -> ValidationResult {
        var warnings: [String] = []
        var fieldIssues: [FieldIssue] = []
        var hasCriticalIssues = false
        var correctedData = data
        var hasCorrections = false

        // Discount == tax = likely model confusion
        if let discount = data.discountAmount,
           let tax = data.taxAmount,
           abs(discount - tax) < 0.01 {
            Logger.extraction.warning("⚠️ Discount (\(discount)) equals tax (\(tax)) - this is likely an extraction error. The model may have confused tax breakdown with a discount. Auto-correcting by removing discount.")
            correctedData.discountAmount = nil
            hasCorrections = true
            warnings.append("Removed invalid discount - tax amount was incorrectly extracted as discount")
        }

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

        if let items = data.items {
            if items.isEmpty {
                let message = "No line items found"
                warnings.append(message)
                fieldIssues.append(FieldIssue(field: .items, message: message, severity: .warning))
            } else {
                let duplicates = findDuplicateItems(items)
                if !duplicates.isEmpty {
                    let message = "Found duplicate items: \(duplicates.joined(separator: ", "))"
                    warnings.append(message)
                    fieldIssues.append(FieldIssue(field: .items, message: "Duplicate items detected", severity: .warning))
                }

                let itemsWithIssues = validateItemPrices(items)
                warnings.append(contentsOf: itemsWithIssues)
                if !itemsWithIssues.isEmpty {
                    fieldIssues.append(FieldIssue(field: .items, message: "Some item prices don't match quantity × unit price", severity: .warning))
                }

                if let totalAmount = correctedData.totalAmount {
                    let taxValidation = validateTaxAndTotal(
                        items: items,
                        taxAmount: correctedData.taxAmount,
                        totalAmount: totalAmount,
                        taxType: correctedData.taxType,
                        discountAmount: correctedData.discountAmount
                    )

                    if let taxWarning = taxValidation.warning {
                        warnings.append(taxWarning)
                        fieldIssues.append(FieldIssue(field: .totalAmount, message: taxWarning, severity: .warning))
                    }

                    if let correctedTaxType = taxValidation.correctedTaxType {
                        Logger.extraction.info("Auto-correcting taxType from '\(correctedData.taxType ?? "nil")' to '\(correctedTaxType)'")
                        correctedData.taxType = correctedTaxType
                        hasCorrections = true
                    }

                    let quantityIssues = detectQuantityExtractionErrors(
                        items: items,
                        totalAmount: totalAmount,
                        taxAmount: correctedData.taxAmount,
                        discountAmount: correctedData.discountAmount
                    )

                    for issue in quantityIssues {
                        let message = issue.message
                        warnings.append("Possible quantity error: \(message)")
                        fieldIssues.append(FieldIssue(
                            field: .items,
                            message: "Check quantity for '\(issue.itemName)' - may be \(issue.suggestedQuantity) not \(issue.currentQuantity)",
                            severity: issue.confidence == .high ? .warning : .warning
                        ))
                    }
                }
            }
        } else {
            warnings.append("No items array provided")
            fieldIssues.append(FieldIssue(field: .items, message: "No items found", severity: .error))
        }

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

    // MARK: - Format Validation

    // YYYY-MM-DD format check
    private static func isValidDateFormat(_ date: String) -> Bool {
        let pattern = #"^\d{4}-\d{2}-\d{2}$"#
        return date.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Duplicate Detection

    // Finds items with identical names
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

    // MARK: - Price Validation

    // Checks quantity × unitPrice = totalPrice
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

            if difference > 0.01 {
                let name = item.name ?? "Item \(index + 1)"
                warnings.append("Price mismatch for '\(name)': \(quantity) × \(unitPrice) = \(calculatedTotal), but total shows \(totalPrice)")
            }
        }

        return warnings
    }

    // MARK: - Tax & Total Validation

    private struct TaxValidationResult {
        let warning: String?
        let taxTypeWarning: String?
        let correctedTaxType: String?
    }

    // Verifies items + tax = total, detects included vs added tax
    private static func validateTaxAndTotal(
        items: [LineItemData.PartiallyGenerated],
        taxAmount: Double?,
        totalAmount: Double,
        taxType: String?,
        discountAmount: Double? = nil
    ) -> TaxValidationResult {
        var itemsSum: Double = 0
        for item in items {
            if let totalPrice = item.totalPrice {
                itemsSum += totalPrice
            }
        }

        let discount = discountAmount ?? 0
        let subtotalAfterDiscount = itemsSum - discount

        Logger.extraction.info("=== TAX & TOTAL VALIDATION ===")
        Logger.extraction.info("  Items sum: \(String(format: "%.2f", itemsSum))")
        if discount > 0 {
            Logger.extraction.info("  Discount: -\(String(format: "%.2f", discount))")
            Logger.extraction.info("  Subtotal: \(String(format: "%.2f", subtotalAfterDiscount))")
        }
        Logger.extraction.info("  Tax amount: \(taxAmount.map { String(format: "%.2f", $0) } ?? "nil")")
        Logger.extraction.info("  Tax type: \(taxType ?? "nil")")
        Logger.extraction.info("  Total on receipt: \(String(format: "%.2f", totalAmount))")

        guard let taxAmount = taxAmount else {
            let difference = abs(subtotalAfterDiscount - totalAmount)
            if difference > 0.05 {
                let warningText: String
                if discount > 0 {
                    warningText = "Items sum to \(String(format: "%.2f", itemsSum)), minus discount \(String(format: "%.2f", discount)) = \(String(format: "%.2f", subtotalAfterDiscount)), but total is \(String(format: "%.2f", totalAmount)) (difference: \(String(format: "%.2f", difference)))"
                } else {
                    warningText = "Items sum to \(String(format: "%.2f", itemsSum)), but total is \(String(format: "%.2f", totalAmount)) (difference: \(String(format: "%.2f", difference)))"
                }
                return TaxValidationResult(
                    warning: warningText,
                    taxTypeWarning: nil,
                    correctedTaxType: nil
                )
            }
            return TaxValidationResult(warning: nil, taxTypeWarning: nil, correctedTaxType: nil)
        }

        let tolerance: Double = 0.05
        let includedDifference = abs(subtotalAfterDiscount - totalAmount)
        let addedDifference = abs((subtotalAfterDiscount + taxAmount) - totalAmount)

        var warning: String? = nil
        var correctedTaxType: String? = nil

        if includedDifference <= tolerance {
            if let taxType = taxType, taxType != "included" {
                correctedTaxType = "included"
                if discount > 0 {
                    Logger.extraction.info("Detected tax is included (items: \(String(format: "%.2f", itemsSum)) - discount: \(String(format: "%.2f", discount)) = \(String(format: "%.2f", subtotalAfterDiscount)) ≈ total: \(String(format: "%.2f", totalAmount))), correcting taxType from '\(taxType)' to 'included'")
                } else {
                    Logger.extraction.info("Detected tax is included (items: \(String(format: "%.2f", itemsSum)) ≈ total: \(String(format: "%.2f", totalAmount))), correcting taxType from '\(taxType)' to 'included'")
                }
            } else {
                Logger.extraction.info("✅ Tax validation PASSED (included): \(String(format: "%.2f", subtotalAfterDiscount)) ≈ \(String(format: "%.2f", totalAmount)) (diff: \(String(format: "%.2f", includedDifference)))")
            }
        } else if addedDifference <= tolerance {
            if let taxType = taxType, taxType != "added" {
                correctedTaxType = "added"
                if discount > 0 {
                    Logger.extraction.info("Detected tax is added (items: \(String(format: "%.2f", itemsSum)) - discount: \(String(format: "%.2f", discount)) + tax: \(String(format: "%.2f", taxAmount)) = \(String(format: "%.2f", subtotalAfterDiscount + taxAmount)) ≈ total: \(String(format: "%.2f", totalAmount))), correcting taxType from '\(taxType)' to 'added'")
                } else {
                    Logger.extraction.info("Detected tax is added (items: \(String(format: "%.2f", itemsSum)) + tax: \(String(format: "%.2f", taxAmount)) = \(String(format: "%.2f", itemsSum + taxAmount)) ≈ total: \(String(format: "%.2f", totalAmount))), correcting taxType from '\(taxType)' to 'added'")
                }
            } else {
                Logger.extraction.info("✅ Tax validation PASSED (added): \(String(format: "%.2f", subtotalAfterDiscount)) + \(String(format: "%.2f", taxAmount)) = \(String(format: "%.2f", subtotalAfterDiscount + taxAmount)) ≈ \(String(format: "%.2f", totalAmount)) (diff: \(String(format: "%.2f", addedDifference)))")
            }
        } else {
            Logger.extraction.warning("❌ Tax validation FAILED:")
            Logger.extraction.warning("  If tax included: \(String(format: "%.2f", subtotalAfterDiscount)) ≠ \(String(format: "%.2f", totalAmount)) (diff: \(String(format: "%.2f", includedDifference)))")
            Logger.extraction.warning("  If tax added: \(String(format: "%.2f", subtotalAfterDiscount + taxAmount)) ≠ \(String(format: "%.2f", totalAmount)) (diff: \(String(format: "%.2f", addedDifference)))")

            if discount > 0 {
                warning = """
                Total amount mismatch:
                • Items sum: \(String(format: "%.2f", itemsSum))
                • Discount: -\(String(format: "%.2f", discount))
                • Subtotal after discount: \(String(format: "%.2f", subtotalAfterDiscount))
                • Tax: \(String(format: "%.2f", taxAmount))
                • Total on receipt: \(String(format: "%.2f", totalAmount))

                Neither calculation matches:
                • If tax included: \(String(format: "%.2f", subtotalAfterDiscount)) ≠ \(String(format: "%.2f", totalAmount)) (diff: \(String(format: "%.2f", includedDifference)))
                • If tax added: \(String(format: "%.2f", subtotalAfterDiscount + taxAmount)) ≠ \(String(format: "%.2f", totalAmount)) (diff: \(String(format: "%.2f", addedDifference)))

                Please verify items, discount, or tax amount.
                """
            } else {
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
        }

        return TaxValidationResult(warning: warning, taxTypeWarning: nil, correctedTaxType: correctedTaxType)
    }

    // MARK: - Quantity Error Detection

    // Catches LLM qty=1 errors by comparing missing amounts to total difference
    static func detectQuantityExtractionErrors(
        items: [LineItemData.PartiallyGenerated],
        totalAmount: Double,
        taxAmount: Double? = nil,
        discountAmount: Double? = nil
    ) -> [QuantityIssue] {
        var issues: [QuantityIssue] = []

        let itemsSum = items.compactMap { $0.totalPrice }.reduce(0, +)
        let discount = discountAmount ?? 0
        let tax = taxAmount ?? 0

        // Calculate the expected total (items - discount for included tax, items - discount + tax for added tax)
        let subtotalAfterDiscount = itemsSum - discount

        let differenceIncluded = abs(subtotalAfterDiscount - totalAmount)
        let differenceAdded = abs((subtotalAfterDiscount + tax) - totalAmount)
        let difference = min(differenceIncluded, differenceAdded)

        guard difference > 0.05 else { return [] }

        Logger.extraction.debug("Quantity error detection: items=\(String(format: "%.2f", itemsSum)), total=\(String(format: "%.2f", totalAmount)), diff=\(String(format: "%.2f", difference))")

        for item in items {
            guard let quantity = item.quantity,
                  let unitPrice = item.unitPrice,
                  let totalPrice = item.totalPrice,
                  let name = item.name else {
                continue
            }

            guard quantity == 1.0 else { continue }

            for possibleQty in 2...5 {
                let missingAmount = unitPrice * Double(possibleQty - 1)
                let newDifference = abs(difference - missingAmount)

                if newDifference < 0.10 && missingAmount > 0.05 {
                    let suggestedTotal = unitPrice * Double(possibleQty)

                    issues.append(QuantityIssue(
                        itemName: name,
                        currentQuantity: Int(quantity),
                        suggestedQuantity: possibleQty,
                        currentUnitPrice: unitPrice,
                        currentTotal: totalPrice,
                        suggestedTotal: suggestedTotal,
                        confidence: newDifference < 0.05 ? .high : .medium
                    ))

                    Logger.extraction.warning("Possible quantity error: '\(name)' may have qty=\(possibleQty) instead of 1 (would fix \(String(format: "%.2f", missingAmount)) difference)")
                    break
                }
            }
        }

        return issues
    }

    // Suggested fix for a quantity extraction error
    struct QuantityIssue {
        let itemName: String
        let currentQuantity: Int
        let suggestedQuantity: Int
        let currentUnitPrice: Double
        let currentTotal: Double
        let suggestedTotal: Double
        let confidence: Confidence

        enum Confidence {
            case high
            case medium
        }

        var message: String {
            "'\(itemName)' may have quantity \(suggestedQuantity) instead of \(currentQuantity) (would change total from \(String(format: "%.2f", currentTotal)) to \(String(format: "%.2f", suggestedTotal)))"
        }
    }

    // MARK: - Deduplication

    // Removes duplicate items, keeps first occurrence
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
