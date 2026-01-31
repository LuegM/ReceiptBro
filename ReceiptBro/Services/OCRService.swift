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

    /// Tries RecognizeDocumentsRequest first, falls back to VNRecognizeTextRequest
    func extractText(from image: UIImage) async throws -> OCRResult {
        Logger.ocr.info("Starting document recognition")

        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            Logger.ocr.error("Failed to convert UIImage to JPEG data")
            throw OCRError.imageConversionFailed
        }

        guard let cgImage = image.cgImage else {
            Logger.ocr.error("Failed to get CGImage from UIImage")
            throw OCRError.imageConversionFailed
        }

        do {
            Logger.ocr.info("Attempting RecognizeDocumentsRequest for table extraction")
            let request = RecognizeDocumentsRequest()
            let observations = try await request.perform(on: imageData)

            if let document = observations.first?.document, !document.tables.isEmpty {
                Logger.ocr.info("Document has \(document.tables.count) tables - using structured extraction")
                return try await extractFromDocumentObservation(document)
            } else {
                Logger.ocr.warning("No tables detected - falling back to VNRecognizeTextRequest")
                return try await extractFromTextRecognition(cgImage)
            }

        } catch {
            Logger.ocr.warning("RecognizeDocumentsRequest failed: \(error.localizedDescription)")
            Logger.ocr.info("Falling back to VNRecognizeTextRequest")
            return try await extractFromTextRecognition(cgImage)
        }
    }

    // MARK: - Private

    private func extractFromDocumentObservation(_ document: DocumentObservation.Container) async throws -> OCRResult {
        Logger.ocr.debug("Processing document with \(document.tables.count) tables, \(document.paragraphs.count) paragraphs")

        let tables = document.tables.map { extractTable(from: $0) }
        let paragraphs = document.paragraphs.map { $0.transcript }

        var detectedMoney: [DetectedMoney] = []
        var detectedDates: [DateComponents] = []
        var detectedAddresses: [String] = []

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

        var fullTextParts: [String] = []
        if !paragraphs.isEmpty {
            fullTextParts.append(contentsOf: paragraphs)
        }
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

                var wordData: [(text: String, y: CGFloat, x: CGFloat, height: CGFloat)] = []

                for observation in observations {
                    let allCandidates = observation.topCandidates(3)
                    let box = observation.boundingBox

                    for (idx, candidate) in allCandidates.enumerated() {
                        Logger.ocr.debug("Candidate[\(idx)] '\(candidate.string)' conf=\(String(format: "%.2f", candidate.confidence)) y=\(String(format: "%.4f", box.midY))")
                    }

                    guard let candidate = allCandidates.first else { continue }
                    wordData.append((
                        text: candidate.string,
                        y: box.midY,
                        x: box.minX,
                        height: box.height
                    ))
                }

                Logger.ocr.info("=== RAW OBSERVATIONS (\(wordData.count) total) ===")
                for (index, word) in wordData.enumerated() {
                    Logger.ocr.info("[\(index)] '\(word.text)' y=\(String(format: "%.4f", word.y)) x=\(String(format: "%.4f", word.x)) h=\(String(format: "%.4f", word.height))")
                }
                Logger.ocr.info("=== END RAW OBSERVATIONS ===")

                let heights = wordData.map { $0.height }.sorted()
                let medianHeight = heights.isEmpty ? 0.02 : heights[heights.count / 2]
                let yTolerance: CGFloat = medianHeight * 0.4

                Logger.ocr.debug("Median text height: \(medianHeight), Y tolerance: \(yTolerance)")

                var lines: [[(text: String, x: CGFloat, y: CGFloat)]] = []

                for word in wordData {
                    if let index = lines.firstIndex(where: { abs($0.first!.y - word.y) < yTolerance }) {
                        lines[index].append((text: word.text, x: word.x, y: word.y))
                    } else {
                        lines.append([(text: word.text, x: word.x, y: word.y)])
                    }
                }

                // Top to bottom (Vision uses bottom-left origin)
                lines.sort { line1, line2 in
                    guard let y1 = line1.first?.y, let y2 = line2.first?.y else { return false }
                    return y1 > y2
                }

                let finalLines: [String] = lines.map { line in
                    line.sorted(by: { $0.x < $1.x }).map { $0.text }.joined(separator: " ")
                }

                Logger.ocr.info("=== GROUPED LINES (\(finalLines.count) total) ===")
                for (index, line) in finalLines.enumerated() {
                    Logger.ocr.info("Line[\(index)]: '\(line)'")
                }
                Logger.ocr.info("=== END GROUPED LINES ===")

                let mergedLines = self.mergeQuantityLines(finalLines)

                Logger.ocr.info("=== MERGED LINES (\(mergedLines.count) total) ===")
                for (index, line) in mergedLines.enumerated() {
                    Logger.ocr.info("Merged[\(index)]: '\(line)'")
                }
                Logger.ocr.info("=== END MERGED LINES ===")

                let fullText = mergedLines.joined(separator: "\n")

                Logger.ocr.info("Text recognition complete:")
                Logger.ocr.info("  Original Lines: \(finalLines.count), Merged Lines: \(mergedLines.count)")
                Logger.ocr.info("  Full text length: \(fullText.count) characters")

                let result = OCRResult(
                    fullText: fullText,
                    tables: [],
                    paragraphs: mergedLines,
                    detectedMoneyAmounts: [],
                    detectedDates: [],
                    detectedAddresses: []
                )

                continuation.resume(returning: result)
            }

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



    /// Merge "2 x 0.99" lines with the following product line
    private func mergeQuantityLines(_ lines: [String]) -> [String] {
        var result: [String] = []
        var pendingQuantityLine: String? = nil
        let quantityPattern = #"^\s*(\d+\s*[xX×]\s*)?\d+[.,]\d{2}\s*$"#

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let pending = pendingQuantityLine {
                result.append("\(pending) \(trimmed)")
                pendingQuantityLine = nil
                Logger.ocr.debug("Merged quantity line: '\(pending)' with '\(trimmed)'")
            } else if trimmed.range(of: quantityPattern, options: .regularExpression) != nil {
                // 2+ letters = product name, not qty line
                let hasProductNameWord = trimmed.range(of: #"[a-zA-ZäöüÄÖÜß]{2,}"#, options: .regularExpression) != nil
                guard !hasProductNameWord else {
                    result.append(trimmed)
                    continue
                }
                pendingQuantityLine = trimmed
                Logger.ocr.debug("Found quantity line to merge: '\(trimmed)'")
            } else {
                result.append(trimmed)
            }
        }

        if let pending = pendingQuantityLine {
            result.append(pending)
            Logger.ocr.warning("Trailing quantity line not merged: '\(pending)'")
        }

        return result
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
