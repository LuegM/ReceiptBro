import SwiftUI
import SwiftData
import OSLog
import Shimmer

struct ReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let image: UIImage
    @Bindable var extractor: ReceiptExtractor

    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveError: Error?
    @State private var validationWarnings: [String] = []
    @State private var validationFieldIssues: [ReceiptValidator.FieldIssue] = []
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            Group {
                if let error = extractor.error {
                    ScrollView {
                        errorView(error)
                            .padding()
                    }
                } else if extractor.receiptData != nil {
                    ScrollViewReceiptEditorView(
                        receiptData: $extractor.receiptData.bound,
                        isStreaming: extractor.isProcessing,
                        validationIssues: validationFieldIssues,
                        ocrText: extractor.ocrText,
                        showProgress: extractor.isProcessing,
                        progressMessage: progressMessage,
                        image: image
                    )
                    .environment(\.editMode, $editMode)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            if extractor.isProcessing {
                                extractionProgressView
                            }
                        }
                        .padding()
                    }
                }
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
                    if !extractor.isProcessing && extractor.receiptData != nil {
                        EditButton()
                            .environment(\.editMode, $editMode)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
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
            .onChange(of: extractor.isProcessing) { wasProcessing, isProcessing in
                if wasProcessing && !isProcessing && extractor.receiptData != nil {
                    validateExtractedData()
                }
            }
        }
    }

    // MARK: - Subviews

    private var extractionProgressView: some View {
        HStack(spacing: 12) {
            Image(systemName: (extractor.progress == .performingOCR ? "text.magnifyingglass" : "sparkles"))
                .symbolEffect(.variableColor, options: .repeat(.continuous))

            Text(progressMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .shimmering(bandSize: 1)
            
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

    // MARK: - Computed Properties

    private var progressMessage: String {
        switch extractor.progress {
        case .idle:
            return "Initializing..."
        case .performingOCR:
            return "Reading text from image..."
        case .extractingStructure:
            return "Extracting receipt details using onDevice AI..."
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
            let imageData = image.jpegData(compressionQuality: 0.7)
            let receipt = try Receipt(from: finalizedData, imageData: imageData)
            modelContext.insert(receipt)
            try modelContext.save()

            Logger.storage.info("Receipt saved successfully: \(receipt.merchantName)")
            dismiss()

        } catch {
            Logger.storage.error("Failed to save receipt: \(error.localizedDescription)")
            saveError = error
            showingSaveError = true
        }
    }

    private func validateExtractedData() {
        if let receiptData = extractor.receiptData {
            let result = ReceiptValidator.validate(receiptData)
            validationWarnings = result.warnings
            validationFieldIssues = result.fieldIssues

            if let correctedData = result.correctedData {
                extractor.receiptData = correctedData
            }
        }
    }
}

struct ValidationWarningsView: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("Validation Warnings")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            ForEach(warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Tap **Edit** to correct these issues")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension ReviewView {
    func performValidation() {
        validateExtractedData()
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
