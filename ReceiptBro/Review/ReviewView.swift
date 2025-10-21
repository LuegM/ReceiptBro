import SwiftUI
import SwiftData
import OSLog

/// Main review screen where users can see streaming data and edit before saving
struct ReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let image: UIImage
    let extractor: ReceiptExtractor

    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveError: Error?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Progress indicator
                    if extractor.isProcessing {
                        extractionProgressView
                    }

                    // Error state
                    if let error = extractor.error {
                        errorView(error)
                    }

                    // Streaming receipt display
                    if let receiptData = extractor.receiptData {
                        VirtualReceiptView(data: receiptData)
                            .padding(.horizontal)
                    }

                    // Thumbnail of original image
//                    if !extractor.isProcessing {
//                        originalImageThumbnail
//                    }
                    
                    // OCR text section
                    if !extractor.isProcessing, let ocrText = extractor.ocrText {
                        ocrTextSection(ocrText)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Review Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        Task {
                            await saveReceipt()
                        }
                    }
                    .disabled(extractor.isProcessing || extractor.receiptData == nil)
                    .fontWeight(.semibold)
                }
            }
            .alert("Save Failed", isPresented: $showingSaveError) {
                Button("OK") { }
            } message: {
                if let error = saveError {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Subviews

    private var extractionProgressView: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .symbolEffect(.variableColor, options: .repeat(.continuous))

            Text(progressMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Extraction Failed")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func ocrTextSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OCR Text")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxHeight: 200)
            .padding(.horizontal)
        }
    }

//    private var originalImageThumbnail: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("Original Image")
//                .font(.subheadline)
//                .foregroundStyle(.secondary)
//
//            Image(uiImage: image)
//                .resizable()
//                .scaledToFit()
//                .frame(maxHeight: 300)
//                .clipShape(RoundedRectangle(cornerRadius: 8))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 8)
//                        .stroke(Color(.separator), lineWidth: 1)
//                )
//        }
//        .padding(.horizontal)
//    }

    // MARK: - Computed Properties

    private var progressMessage: String {
        switch extractor.progress {
        case .idle:
            return "Initializing..."
        case .performingOCR:
            return "Reading text from image..."
        case .extractingStructure:
            return "Extracting receipt details..."
        case .complete:
            return "Complete"
        }
    }

    // MARK: - Actions

    private func saveReceipt() async {
        guard let finalizedData = extractor.finalizeReceipt() else {
            saveError = NSError(
                domain: "ReviewView",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot save incomplete receipt data"]
            )
            showingSaveError = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            // Convert image to data for storage
            let imageData = image.jpegData(compressionQuality: 0.7)

            // Create Receipt from finalized data
            let receipt = try Receipt(from: finalizedData, imageData: imageData)

            // Insert into SwiftData context
            modelContext.insert(receipt)

            // Save context
            try modelContext.save()

            Logger.storage.info("Receipt saved successfully: \(receipt.merchantName)")

            // Dismiss after successful save
            dismiss()

        } catch {
            Logger.storage.error("Failed to save receipt: \(error.localizedDescription)")
            saveError = error
            showingSaveError = true
        }
    }
}

// MARK: - Previews

#Preview("Initial State") {
    let extractor = ReceiptExtractor()
    
    ReviewView(
        image: UIImage(systemName: "doc.text.fill")!,
        extractor: extractor
    )
    .modelContainer(for: [Receipt.self, LineItem.self], inMemory: true)
}

#Preview("Processing - OCR") {
    let extractor = ReceiptExtractor()
    extractor.isProcessing = true
    extractor.progress = .performingOCR
    
    return ReviewView(
        image: UIImage(systemName: "doc.text.fill")!,
        extractor: extractor
    )
    .modelContainer(for: [Receipt.self, LineItem.self], inMemory: true)
}

#Preview("Processing - Extracting Structure") {
    let extractor = ReceiptExtractor()
    extractor.isProcessing = true
    extractor.progress = .extractingStructure
    extractor.ocrText = "WHOLE FOODS MARKET\n123 Main St\nApples $3.99\nBread $2.49\nTotal: $6.48"
    
    return ReviewView(
        image: UIImage(systemName: "doc.text.fill")!,
        extractor: extractor
    )
    .modelContainer(for: [Receipt.self, LineItem.self], inMemory: true)
}

#Preview("Error State") {
    let extractor = ReceiptExtractor()
    extractor.isProcessing = false
    extractor.progress = .complete
    extractor.error = NSError(
        domain: "ReceiptExtractor",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Foundation Models are not available on this device. Please ensure you have iOS 18.2 or later with Apple Intelligence enabled."]
    )
    extractor.ocrText = "Some OCR text that was extracted before the error occurred..."
    
    return ReviewView(
        image: UIImage(systemName: "doc.text.fill")!,
        extractor: extractor
    )
    .modelContainer(for: [Receipt.self, LineItem.self], inMemory: true)
}
