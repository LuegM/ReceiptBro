import Foundation
import FoundationModels
import OSLog
import UIKit

@Observable
@MainActor
final class ReceiptExtractor {
    // Streaming state - uses PartiallyGenerated for progressive updates
    var receiptData: ReceiptData.PartiallyGenerated?
    var ocrText: String?
    var isProcessing = false
    var error: Error?
    var progress: ExtractionProgress = .idle

    private let session: LanguageModelSession
    private let ocrService = OCRService()

    enum ExtractionProgress {
        case idle
        case performingOCR
        case extractingStructure
        case complete
    }

    enum ExtractionError: LocalizedError {
        case modelUnavailable
        case streamingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "Foundation Models are not available on this device"
            case .streamingFailed(let error):
                return "Extraction failed: \(error.localizedDescription)"
            }
        }
    }

    init() {
        // Initialize Foundation Models session with role-focused instructions
        // Instructions define behavior; format constraints are handled by @Guide attributes
        let instructions = """
        You are a receipt data extraction assistant. Analyze OCR text from retail receipts and extract structured information with high accuracy. Preserve exact text as it appears on receipts. Only extract information that is clearly present in the OCR text.
        """

        self.session = LanguageModelSession(instructions: instructions)
        Logger.extraction.info("Foundation Models session initialized")
    }

    /// Check model availability and log status
    func checkModelAvailability() {
        Task {
            Logger.extraction.info("Checking model availability...")
            let model = SystemLanguageModel.default
            
            switch model.availability {
            case .available:
                Logger.extraction.info("Foundation Models are available and ready")
            case .unavailable(let reason):
                Logger.extraction.warning("Foundation Models unavailable: \(String(describing: reason))")
            }
        }
    }

    /// Extract receipt data from an image using OCR + Foundation Models streaming
    /// - Parameter image: The receipt image to process
    func extractFromImage(_ image: UIImage) async {
        isProcessing = true
        progress = .performingOCR
        error = nil
        receiptData = nil
        ocrText = nil

        defer {
            isProcessing = false
            progress = .complete
        }

        do {
            // Step 1: OCR text extraction
            Logger.extraction.info("Starting OCR extraction from image")
            let ocrResult = try await ocrService.extractText(from: image)
            Logger.extraction.info("OCR complete: \(ocrResult.lines.count) lines, avg confidence: \(ocrResult.averageConfidence)")

            // Store OCR text for review
            self.ocrText = ocrResult.fullText

            // Step 2: Foundation Models structured extraction with streaming
            progress = .extractingStructure
            await extractStructuredData(from: ocrResult.fullText)

        } catch {
            Logger.extraction.error("Extraction failed: \(error.localizedDescription)")
            self.error = error
        }
    }

    /// Extract receipt data from pre-extracted OCR text (for testing or manual input)
    /// - Parameter ocrText: Raw OCR text from receipt
    func extractFromText(_ ocrText: String) async {
        isProcessing = true
        progress = .extractingStructure
        error = nil
        receiptData = nil

        defer {
            isProcessing = false
            progress = .complete
        }

        await extractStructuredData(from: ocrText)
    }

    // MARK: - Private Methods

    private func extractStructuredData(from ocrText: String) async {
        Logger.extraction.info("Starting Foundation Models structured extraction")

        do {
            // Check model availability first
            let model = SystemLanguageModel.default
            guard case .available = model.availability else {
                Logger.extraction.error("Foundation Models not available")
                self.error = ExtractionError.modelUnavailable
                return
            }

            // Use PromptBuilder for few-shot prompting with multiple examples
            // Separates the extraction task, OCR data, and examples cleanly
            let prompt = Prompt {
                "Extract structured receipt data from the OCR text below."
                ""
                "CRITICAL RULES:"
                "1. Use ONLY values from the provided OCR text - never copy from examples"
                "2. Each line item must appear exactly once - NO DUPLICATES"
                "3. Verify that item prices sum correctly (quantity × unitPrice = totalPrice)"
                "4. For transaction ID, prefer 'Trace-Nr', 'Trace Number', or similar transaction identifiers"
                "5. For tax amount, SUM all tax lines if multiple rates shown (e.g., 10% + 20%)"
                "6. Date must be in YYYY-MM-DD format"
                ""
                "OCR Text to Extract:"
                ocrText
                ""
                "Format Examples (DO NOT copy these values - use actual data from OCR above):"
                ""
                "Example 1 - European Grocery:"
                ReceiptData.exampleGroceryReceipt
                ""
                "Example 2 - US Retail:"
                ReceiptData.exampleUSReceipt
                ""
                "Example 3 - Restaurant:"
                ReceiptData.exampleRestaurantReceipt
            }

            // Stream response for progressive UI updates
            let stream = session.streamResponse(
                to: prompt,
                generating: ReceiptData.self
            )

            Logger.extraction.info("Streaming Foundation Models response...")

            var chunkCount = 0
            for try await partialResponse in stream {
                // Update with partial data as it streams in
                self.receiptData = partialResponse.content
                chunkCount += 1

                if chunkCount % 5 == 0 {
                    Logger.extraction.debug("Received chunk \(chunkCount)")
                }
            }

            Logger.extraction.info("Streaming complete after \(chunkCount) chunks")

            // Log the partial object created by the Foundation Model
            if let createdObject = self.receiptData {
                Logger.foundationModel.debug("Foundation Model streaming complete - Created partial object: \(String(describing: createdObject))")
            }

            // Auto-clean duplicates after streaming completes
            if var receiptData = self.receiptData, let items = receiptData.items {
                let cleanedItems = ReceiptValidator.removeDuplicateItems(from: items)
                if cleanedItems.count != items.count {
                    Logger.extraction.info("Auto-removed \(items.count - cleanedItems.count) duplicate items")
                    receiptData.items = cleanedItems
                    self.receiptData = receiptData
                }
            }

        } catch {
            Logger.extraction.error("Structured extraction failed: \(error.localizedDescription)")
            self.error = ExtractionError.streamingFailed(error)
        }
    }

    /// Convert the partially generated receipt to a concrete ReceiptData
    /// Call this after streaming is complete and user has reviewed/edited
    func finalizeReceipt() -> ReceiptData? {
        guard let partial = receiptData,
              let merchantName = partial.merchantName,
              let date = partial.date,
              let currency = partial.currency,
              let totalAmount = partial.totalAmount,
              let items = partial.items else {
            Logger.extraction.warning("Cannot finalize receipt - missing required fields")
            return nil
        }

        // Convert partial line items to concrete items
        let finalizedItems = items.compactMap { partialItem -> LineItemData? in
            guard let name = partialItem.name,
                  let quantity = partialItem.quantity,
                  let unitPrice = partialItem.unitPrice,
                  let totalPrice = partialItem.totalPrice else {
                return nil
            }

            return LineItemData(
                name: name,
                quantity: quantity,
                unitPrice: unitPrice,
                totalPrice: totalPrice
            )
        }

        let finalizedReceipt = ReceiptData(
            merchantName: merchantName,
            address: partial.address,
            date: date,
            transactionId: partial.transactionId,
            paymentMethod: partial.paymentMethod,
            currency: currency,
            items: finalizedItems,
            taxAmount: partial.taxAmount,
            totalAmount: totalAmount
        )

        Logger.extraction.info("Receipt finalized with \(finalizedItems.count) items in \(currency)")

        // Log the complete object to foundationModel logger
        Logger.foundationModel.info("Foundation Model extraction complete - Created object: \(String(describing: finalizedReceipt))")

        return finalizedReceipt
    }
}
