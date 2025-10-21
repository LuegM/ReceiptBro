import SwiftUI
import SwiftData
import OSLog

/// Main review screen where users can see streaming data and edit before saving
struct ReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let image: UIImage
    let extractor: ReceiptExtractor

    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveError: Error?
    @State private var editableData: EditableReceiptData?
    @State private var validationWarnings: [String] = []
    @State private var showEditableView = false

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

                    // Receipt display
                    if let receiptData = extractor.receiptData {
                        VStack(spacing: 16) {
                            // Show validation warnings if any
                            if !validationWarnings.isEmpty {
                                ValidationWarningsView(warnings: validationWarnings)
                                    .padding(.horizontal)
                            }

                            // Show tap-to-edit view if editing is available
                            if showEditableView, let editableData = editableData {
                                TapToEditReceiptView(receiptData: editableData)
                                    .padding(.horizontal)
                            } else {
                                VirtualReceiptView(data: receiptData)
                                    .padding(.horizontal)
                            }
                        }
                    }

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
                    if !extractor.isProcessing && extractor.receiptData != nil {
                        if showEditableView {
                            Button("Done Editing") {
                                showEditableView = false
                            }
                        } else {
                            Button("Edit") {
                                enterEditMode()
                            }
                        }
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
                // When processing completes, validate the data
                if wasProcessing && !isProcessing && extractor.receiptData != nil {
                    validateExtractedData()
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

    private func enterEditMode() {
        // Create editable data from current receipt if not already created
        if editableData == nil, let receiptData = extractor.receiptData {
            Logger.ui.info("Creating editable receipt data")
            if let editable = EditableReceiptData(from: receiptData) {
                editableData = editable
                Logger.ui.info("Editable data created successfully")
            } else {
                Logger.ui.error("Failed to create EditableReceiptData from partial data")
                Logger.ui.error("Merchant: \(String(describing: receiptData.merchantName))")
                Logger.ui.error("Date: \(String(describing: receiptData.date))")
                Logger.ui.error("Currency: \(String(describing: receiptData.currency))")
                Logger.ui.error("Total: \(String(describing: receiptData.totalAmount))")
                return
            }
        }
        showEditableView = true
    }

    private func saveReceipt() async {
        // If editing, convert back to ReceiptData first
        var finalizedData: ReceiptData?

        if let editableData = editableData, showEditableView {
            finalizedData = editableData.toReceiptData()
        } else {
            finalizedData = extractor.finalizeReceipt()
        }

        guard let finalizedData = finalizedData else {
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

    private func validateExtractedData() {
        if let receiptData = extractor.receiptData {
            let result = ReceiptValidator.validate(receiptData)
            validationWarnings = result.warnings

            // Auto-remove duplicates if found
            if !result.warnings.filter({ $0.contains("duplicate") }).isEmpty {
                if var items = receiptData.items {
                    items = ReceiptValidator.removeDuplicateItems(from: items)
                    // Note: Can't directly modify receiptData.items as it's immutable
                    // The user will need to manually delete duplicates in edit mode
                }
            }
        }
    }
}

// MARK: - Validation Warnings View

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

// MARK: - View Extension for Validation

extension ReviewView {
    /// Call validation after extraction completes
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
