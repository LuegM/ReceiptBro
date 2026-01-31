import Foundation
import FoundationModels
import OSLog
import SwiftUI
import UIKit

@Observable
@MainActor
final class ReceiptExtractor {
    var receiptData: ReceiptData.PartiallyGenerated?
    var ocrText: String?
    var isProcessing = false
    var error: Error?
    var progress: ExtractionProgress = .idle

    private let ocrService = OCRService()
    private let session: LanguageModelSession

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
        let instructions = """
        You are a receipt data extraction assistant. Analyze OCR text from retail receipts and extract structured information with high accuracy. Preserve exact text as it appears on receipts. Only extract information that is clearly present in the OCR text.

        CRITICAL RULES:

        1. QUANTITY LINES WITH EXPLICIT MULTIPLIER:
        When you see a pattern like '2 x 0.99' or '2 x 0,99' merged with a product line (e.g., '2 x 0.99 Clever Sauerrahm 1.98'), this means:
        - quantity = 2, unitPrice = 0.99, totalPrice = 1.98
        The product name is everything between the unit price and the total price.

        2. INFER QUANTITY WHEN MATH INDICATES MULTIPLES:
        When a line starts with just a price followed by a product and ends with a larger price (e.g., '0.99 Clever Sauerrahm 1.98'), check the math:
        - If firstPrice × 2 = lastPrice → quantity = 2
        - If firstPrice × 3 = lastPrice → quantity = 3
        - If firstPrice = lastPrice → quantity = 1
        Example: '0.99 Clever Sauerrahm 1.98' → 0.99 × 2 = 1.98 → quantity=2, unitPrice=0.99, totalPrice=1.98

        3. ALL PRICES MUST BE POSITIVE:
        Never output negative values for unitPrice or totalPrice. If you calculate a negative, something is wrong.

        4. DISCOUNT RULES:
        - ONLY set discountAmount if there is an EXPLICIT discount keyword: 'Discount', 'Rabatt', 'Rabais', '-', 'Savings'
        - Tax lines (MwSt, VAT, GST, Sales Tax, Tax) are NOT discounts - leave discountAmount as null
        - If unsure, leave discountAmount as null
        """

        self.session = LanguageModelSession(instructions: instructions)
        Logger.extraction.info("ReceiptExtractor initialized with singleton session")
    }

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

    /// OCR + LLM streaming extraction
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
            let ocrResult = try await ocrService.extractText(from: image)
            self.ocrText = ocrResult.fullText
            progress = .extractingStructure
            await extractStructuredData(from: ocrResult)

        } catch {
            self.error = error
        }
    }

    /// From raw OCR text (for testing)
    func extractFromText(_ ocrText: String) async {
        isProcessing = true
        progress = .extractingStructure
        error = nil
        receiptData = nil

        defer {
            isProcessing = false
            progress = .complete
        }

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

    // MARK: - Private

    private func extractStructuredData(from ocrResult: OCRResult) async {
        Logger.extraction.info("Starting Foundation Models structured extraction")
        Logger.extraction.debug("Device language: \(Locale.current.identifier)")
        Logger.extraction.debug("Preferred languages: \(Locale.preferredLanguages)")

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
            let model = SystemLanguageModel(useCase: .contentTagging)
            guard case .available = model.availability else {
                Logger.extraction.error("Foundation Models not available")
                self.error = ExtractionError.modelUnavailable
                return
            }

            let prompt = Prompt {
                "Extract structured receipt data from the OCR text below. Use ONLY the information from this receipt - do not use values from the example."
                ""
                "OCR Text:"
                ocrResult.fullText
                ""
            }

            let stream = self.session.streamResponse(
                to: prompt,
                generating: ReceiptData.self,
                includeSchemaInPrompt: true,
                options: GenerationOptions(
                    sampling: .greedy
                )
            )

            Logger.extraction.info("Streaming Foundation Models response...")

            var chunkCount = 0
            for try await partialResponse in stream {
                withAnimation(.smooth) {
                    self.receiptData = partialResponse.content
                }
                chunkCount += 1

                if chunkCount % 5 == 0 {
                    Logger.extraction.debug("Received chunk \(chunkCount)")
                }
            }

            Logger.extraction.info("Streaming complete after \(chunkCount) chunks")

            Logger.extraction.info("=== TRANSCRIPT DEBUG ===")
            Logger.extraction.info("Total transcript entries: \(self.session.transcript.count)")

            for (index, entry) in self.session.transcript.enumerated() {
                Logger.extraction.info("--- Entry \(index + 1): \(String(describing: entry))")
            }
            Logger.extraction.info("=== END TRANSCRIPT ===\n")

            if let createdObject = self.receiptData {
                Logger.foundationModel.debug("Foundation Model streaming complete - Created partial object: \(String(describing: createdObject))")
            }

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

    /// Convert partial to concrete ReceiptData after user review
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
