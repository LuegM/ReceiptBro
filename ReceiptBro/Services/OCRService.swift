import UIKit
import Vision
import DataDetection
import OSLog

@MainActor
final class OCRService {
    enum OCRError: LocalizedError {
        case noTextFound
        case imageConversionFailed
        case noDocumentFound
        case processingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noTextFound:
                return "No text was detected in the image. Please try again with a clearer photo."
            case .imageConversionFailed:
                return "Failed to convert image to data format."
            case .noDocumentFound:
                return "No document was detected in the image."
            case .processingFailed(let error):
                return "Failed to process image: \(error.localizedDescription)"
            }
        }
    }

    /// Extract structured document data from image using Vision framework
    /// Tries RecognizeDocumentsRequest first (for table receipts), falls back to VNRecognizeTextRequest
    /// - Parameter image: The receipt image to process
    /// - Returns: Structured OCR result with tables, paragraphs, and detected data
    func extractText(from image: UIImage) async throws -> OCRResult {
        Logger.ocr.info("Starting document recognition")

        // Convert UIImage to Data (for Swift 6 API)
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            Logger.ocr.error("Failed to convert UIImage to JPEG data")
            throw OCRError.imageConversionFailed
        }

        // Convert UIImage to CGImage (for old API fallback)
        guard let cgImage = image.cgImage else {
            Logger.ocr.error("Failed to get CGImage from UIImage")
            throw OCRError.imageConversionFailed
        }

        do {
            // Try Swift 6 RecognizeDocumentsRequest first (for receipts with table structure)
            Logger.ocr.info("Attempting RecognizeDocumentsRequest for table extraction")
            let request = RecognizeDocumentsRequest()
            let observations = try await request.perform(on: imageData)

            if let document = observations.first?.document, !document.tables.isEmpty {
                // Success! Found tables
                Logger.ocr.info("Document has \(document.tables.count) tables - using structured extraction")
                return try await extractFromDocumentObservation(document)
            } else {
                // No tables found - fall back to text recognition
                Logger.ocr.warning("No tables detected - falling back to VNRecognizeTextRequest")
                return try await extractFromTextRecognition(cgImage)
            }

        } catch {
            // RecognizeDocumentsRequest failed - fall back
            Logger.ocr.warning("RecognizeDocumentsRequest failed: \(error.localizedDescription)")
            Logger.ocr.info("Falling back to VNRecognizeTextRequest")
            return try await extractFromTextRecognition(cgImage)
        }
    }

    // MARK: - Private Extraction Methods

    /// Extract from DocumentObservation (Swift 6 API - structured documents including receipts)
    private func extractFromDocumentObservation(_ document: DocumentObservation.Container) async throws -> OCRResult {
        Logger.ocr.debug("Processing document with \(document.tables.count) tables, \(document.paragraphs.count) paragraphs")

        // Extract tables from document
        let tables = document.tables.map { extractTable(from: $0) }

        // Extract paragraphs (text outside tables)
        let paragraphs = document.paragraphs.map { $0.transcript }

        var detectedMoney: [DetectedMoney] = []
        var detectedDates: [DateComponents] = []
        var detectedAddresses: [String] = []

        // Extract detected data from paragraphs
        for paragraph in document.paragraphs {
            for data in paragraph.detectedData {
                switch data.match.details {
                case .moneyAmount(let money):
                    let currencyCode = money.currency.identifier
                    detectedMoney.append(DetectedMoney(
                        amount: money.amount,
                        currencyCode: currencyCode
                    ))
                case .calendarEvent(let event):
                    if let startDate = event.startDate {
                        detectedDates.append(Calendar.current.dateComponents([.year, .month, .day], from: startDate))
                    }
                case .postalAddress(let address):
                    let addressString = [
                        address.street,
                        address.city,
                        address.state,
                        address.postalCode
                    ].compactMap { $0 }.joined(separator: ", ")
                    if !addressString.isEmpty {
                        detectedAddresses.append(addressString)
                    }
                default:
                    break
                }
            }
        }

        // Extract detected data from tables
        for table in document.tables {
            for row in table.rows {
                for cell in row {
                    for data in cell.content.text.detectedData {
                        switch data.match.details {
                        case .moneyAmount(let money):
                            let currencyCode = money.currency.identifier
                            detectedMoney.append(DetectedMoney(
                                amount: money.amount,
                                currencyCode: currencyCode
                            ))
                        case .calendarEvent(let event):
                            if let startDate = event.startDate {
                                detectedDates.append(Calendar.current.dateComponents([.year, .month, .day], from: startDate))
                            }
                        case .postalAddress(let address):
                            let addressString = [
                                address.street,
                                address.city,
                                address.state,
                                address.postalCode
                            ].compactMap { $0 }.joined(separator: ", ")
                            if !addressString.isEmpty {
                                detectedAddresses.append(addressString)
                            }
                        default:
                            break
                        }
                    }
                }
            }
        }

        // Get full text from both paragraphs and tables
        var fullTextParts: [String] = []

        // Add paragraph text
        if !paragraphs.isEmpty {
            fullTextParts.append(contentsOf: paragraphs)
        }

        // Add table text
        if !tables.isEmpty {
            let tableText = tables.flatMap { table in
                table.rows.flatMap { $0 }
            }.joined(separator: "\n")
            fullTextParts.append(tableText)
        }

        let fullText = fullTextParts.joined(separator: "\n")

        Logger.ocr.info("Document recognition complete:")
        Logger.ocr.info("  Tables: \(tables.count)")
        Logger.ocr.info("  Paragraphs: \(paragraphs.count)")
        Logger.ocr.info("  Detected money: \(detectedMoney.count)")
        Logger.ocr.info("  Detected dates: \(detectedDates.count)")
        Logger.ocr.info("  Detected addresses: \(detectedAddresses.count)")
        Logger.ocr.info("  Total text length: \(fullText.count) characters")

        return OCRResult(
            fullText: fullText,
            tables: tables,
            paragraphs: paragraphs,
            detectedMoneyAmounts: detectedMoney,
            detectedDates: detectedDates,
            detectedAddresses: detectedAddresses
        )
    }
    
    private func extractFromTextRecognition(_ cgImage: CGImage) async throws -> OCRResult {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    Logger.ocr.error("Vision text request failed: \(error.localizedDescription)")
                    continuation.resume(throwing: OCRError.processingFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    Logger.ocr.warning("No text observations found")
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                // Extract word data with bounding box information
                var wordData: [(text: String, y: CGFloat, x: CGFloat, height: CGFloat)] = []

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let box = observation.boundingBox
                    wordData.append((
                        text: candidate.string,
                        y: box.midY,
                        x: box.minX,
                        height: box.height
                    ))
                }

                // Calculate adaptive Y tolerance based on median text height
                let heights = wordData.map { $0.height }.sorted()
                let medianHeight = heights.isEmpty ? 0.02 : heights[heights.count / 2]
                // Use 40% of median height as tolerance for line grouping
                let yTolerance: CGFloat = medianHeight * 0.4

                Logger.ocr.debug("Median text height: \(medianHeight), Y tolerance: \(yTolerance)")

                // Group words into lines based on Y position
                var lines: [[(text: String, x: CGFloat, y: CGFloat)]] = []

                for word in wordData {
                    // Try to find an existing line within yTolerance of Y
                    if let index = lines.firstIndex(where: { abs($0.first!.y - word.y) < yTolerance }) {
                        lines[index].append((text: word.text, x: word.x, y: word.y))
                    } else {
                        lines.append([(text: word.text, x: word.x, y: word.y)])
                    }
                }

                // Sort lines by Y position (top to bottom - highest Y first since Vision uses bottom-left origin)
                lines.sort { line1, line2 in
                    guard let y1 = line1.first?.y, let y2 = line2.first?.y else { return false }
                    return y1 > y2
                }

                // Sort each line's words by X position (left to right) and extract the text
                let finalLines: [String] = lines.map { line in
                    line.sorted(by: { $0.x < $1.x }).map { $0.text }.joined(separator: " ")
                }

                // Join all lines into a full text string
                let fullText = finalLines.joined(separator: "\n")

                Logger.ocr.info("Text recognition complete:")
                Logger.ocr.info("  Reconstructed Lines: \(finalLines.count)")
                Logger.ocr.info("  Full text length: \(fullText.count) characters")

                // Return OCRResult with grouped lines as paragraphs
                let result = OCRResult(
                    fullText: fullText,
                    tables: [],
                    paragraphs: finalLines,
                    detectedMoneyAmounts: [],
                    detectedDates: [],
                    detectedAddresses: []
                )

                continuation.resume(returning: result)
            }

            // Configure text recognition request
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["de-DE", "en-US"]
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                Logger.ocr.error("Failed to perform Vision request: \(error.localizedDescription)")
                continuation.resume(throwing: OCRError.processingFailed(error))
            }
        }
    }



    private func extractTable(from table: DocumentObservation.Container.Table) -> DocumentTable {
        let rows = table.rows.map { row in
            row.map { cell in
                cell.content.text.transcript
            }
        }
        return DocumentTable(rows: rows)
    }
}

// MARK: - OCR Result Types

struct OCRResult {
    let fullText: String
    let tables: [DocumentTable]
    let paragraphs: [String]
    let detectedMoneyAmounts: [DetectedMoney]
    let detectedDates: [DateComponents]
    let detectedAddresses: [String]
}

struct DocumentTable {
    let rows: [[String]]
}

struct DetectedMoney {
    let amount: Decimal
    let currencyCode: String?
}
