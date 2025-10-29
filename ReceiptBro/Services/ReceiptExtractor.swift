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

    private let ocrService = OCRService()
    private let session: LanguageModelSession  // Singleton session created once at init

    enum ExtractionProgress {
        case idle
        case performingOCR
        case extractingStructure
        case complete
    }

    enum ExtractionError: LocalizedError {
        case modelUnavailable
        case unsupportedLanguage
        case streamingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "Foundation Models are not available on this device"
            case .unsupportedLanguage:
                return "Language not supported. Please ensure your device's Apple Intelligence language is set to English in Settings > General > Language & Region > Apple Intelligence Language."
            case .streamingFailed(let error):
                return "Extraction failed: \(error.localizedDescription)"
            }
        }
    }

    init() {
        // Create session ONCE at initialization (singleton pattern)
        // This avoids repeated locale validation that can fail with unsupported regions
        let instructions = """
        You are a receipt data extraction assistant. Analyze OCR text from retail receipts and extract structured information with high accuracy. Preserve exact text as it appears on receipts. Only extract information that is clearly present in the OCR text.
        """

        self.session = LanguageModelSession(instructions: instructions)
        Logger.extraction.info("ReceiptExtractor initialized with singleton session")
    }

    /// Check model availability and log status
    func checkModelAvailability() {
        Task {
            Logger.extraction.info("Checking model availability...")
            let model = SystemLanguageModel(useCase: .contentTagging)
            
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
            // Step 1: Document recognition with Vision
            let ocrResult = try await ocrService.extractText(from: image)

            // Store full text for review
            self.ocrText = ocrResult.fullText

            // Step 2: Foundation Models structured extraction with streaming
            progress = .extractingStructure
            await extractStructuredData(from: ocrResult)

        } catch {
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

        // Create a basic OCRResult from plain text (no structured data available)
        let ocrResult = OCRResult(
            fullText: ocrText,
            tables: [],
            paragraphs: [ocrText],
            detectedMoneyAmounts: [],
            detectedDates: [],
            detectedAddresses: []
        )

        await extractStructuredData(from: ocrResult)
    }

    // MARK: - Private Methods

    private func extractStructuredData(from ocrResult: OCRResult) async {
        Logger.extraction.info("Starting Foundation Models structured extraction")
        Logger.extraction.debug("Device language: \(Locale.current.identifier)")
        Logger.extraction.debug("Preferred languages: \(Locale.preferredLanguages)")

        // CRITICAL: Check if OCR actually extracted any text
        if ocrResult.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Logger.extraction.error("No text extracted from OCR - cannot proceed with Foundation Models")
            Logger.extraction.error("RecognizeDocumentsRequest found \(ocrResult.tables.count) tables, \(ocrResult.paragraphs.count) paragraphs")
            self.error = ExtractionError.streamingFailed(
                NSError(domain: "ReceiptExtractor", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "No text was detected in the image. The Vision framework could not recognize any tables or text. Please ensure the image is clear and contains a receipt with visible text."
                ])
            )
            return
        }

        do {
            // Check model availability first
            let model = SystemLanguageModel(useCase: .contentTagging)
            guard case .available = model.availability else {
                Logger.extraction.error("Foundation Models not available")
                self.error = ExtractionError.modelUnavailable
                return
            }

            // Use PromptBuilder for structured, one-shot prompting
            // Separates the extraction task, OCR data, and example cleanly
            let prompt = Prompt {
                "Extract structured receipt data from the OCR text below. Use ONLY the information from this receipt - do not use values from the example."
                ""
                "OCR Text:"
                ocrResult.fullText
                ""
                "IMPORTANT: The example below shows the output format only. Extract actual values from the OCR text above, not from this example:"
                ReceiptData.exampleGroceryReceipt
            }


            // Stream response for progressive UI updates
            let stream = self.session.streamResponse(
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

            // Log the transcript for debugging (access session transcript after streaming)
            Logger.extraction.info("=== TRANSCRIPT DEBUG ===")
            Logger.extraction.info("Total transcript entries: \(self.session.transcript.count)")

            for (index, entry) in self.session.transcript.enumerated() {
                Logger.extraction.info("--- Entry \(index + 1): \(String(describing: entry))")
            }
            Logger.extraction.info("=== END TRANSCRIPT ===\n")

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

            // Check if this is a language-related error
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("unsupported language") || errorMessage.contains("locale") {
                Logger.extraction.error("Language error detected - device Apple Intelligence language may not be supported")
                Logger.extraction.error("Current locale: \(Locale.current.identifier)")
                Logger.extraction.error("Preferred languages: \(Locale.preferredLanguages)")
                self.error = ExtractionError.unsupportedLanguage
            } else {
                self.error = ExtractionError.streamingFailed(error)
            }
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
            discountAmount: partial.discountAmount,
            taxAmount: partial.taxAmount,
            taxType: partial.taxType,
            totalAmount: totalAmount
        )

        Logger.extraction.info("Receipt finalized with \(finalizedItems.count) items in \(currency)")

        // Log the complete object to foundationModel logger
        Logger.foundationModel.info("Foundation Model extraction complete - Created object: \(String(describing: finalizedReceipt))")

        return finalizedReceipt
    }
}
