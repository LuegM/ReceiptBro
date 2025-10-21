import UIKit
import Vision
import OSLog

@MainActor
final class OCRService {
    enum OCRError: LocalizedError {
        case noTextFound
        case processingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noTextFound:
                return "No text was detected in the image. Please try again with a clearer photo."
            case .processingFailed(let error):
                return "Failed to process image: \(error.localizedDescription)"
            }
        }
    }

    /// Extract text from image using Vision framework
    /// - Parameter image: The receipt image to process
    /// - Returns: Extracted text and confidence scores
    func extractText(from image: UIImage) async throws -> OCRResult {
        Logger.ocr.info("Starting OCR text extraction")

        guard let cgImage = image.cgImage else {
            Logger.ocr.error("Failed to get CGImage from UIImage")
            throw OCRError.processingFailed(NSError(domain: "OCRService", code: -1))
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    Logger.ocr.error("Vision request failed: \(error.localizedDescription)")
                    continuation.resume(throwing: OCRError.processingFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    Logger.ocr.warning("No text observations found in image")
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                // Extract text and confidence scores
                var extractedLines: [OCRLine] = []

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else {
                        continue
                    }

                    let line = OCRLine(
                        text: topCandidate.string,
                        confidence: topCandidate.confidence,
                        boundingBox: observation.boundingBox
                    )

                    extractedLines.append(line)
                }

                // Combine all text
                let fullText = extractedLines
                    .map { $0.text }
                    .joined(separator: "\n")

                let avgConfidence = extractedLines.isEmpty ? 0.0 :
                    extractedLines.map { $0.confidence }.reduce(0, +) / Float(extractedLines.count)

                Logger.ocr.info("Extracted \(extractedLines.count) text lines with avg confidence: \(avgConfidence)")
                Logger.ocr.debug("\(fullText)")
                
                let result = OCRResult(
                    fullText: fullText,
                    lines: extractedLines,
                    averageConfidence: avgConfidence
                )

                continuation.resume(returning: result)
            }

            // Configure for optimal receipt scanning
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            // Use automatic language detection for receipts
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
}

// MARK: - OCR Result Types

struct OCRResult {
    let fullText: String
    let lines: [OCRLine]
    let averageConfidence: Float

    /// Get lines with confidence below threshold for user review
    func lowConfidenceLines(threshold: Float = 0.7) -> [OCRLine] {
        lines.filter { $0.confidence < threshold }
    }
}

struct OCRLine {
    let text: String
    let confidence: Float
    let boundingBox: CGRect

    var isLowConfidence: Bool {
        confidence < 0.7
    }
}
