import SwiftUI
import SwiftData
import PhotosUI

/// Manages the complete scanning flow: tips → camera → review
struct ScanningFlowView: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext

    @State private var currentStep: ScanStep = .tips
    @State private var capturedImage: UIImage?
    @State private var extractor = ReceiptExtractor()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false

    enum ScanStep {
        case tips
        case camera
        case review
    }

    var body: some View {
        Group {
            switch currentStep {
            case .tips:
                ScanTipsView(
                    onScanTapped: {
                        currentStep = .camera
                    },
                    onPhotoLibraryTapped: {
                        showingPhotoPicker = true
                    },
                    onDismiss: {
                        dismiss()
                    }
                )

            case .camera:
                DocumentCameraView(
                    onImageCaptured: { image in
                        handleImageCapture(image)
                    },
                    onCancel: {
                        dismiss()
                    }
                )
                .ignoresSafeArea()

            case .review:
                if let image = capturedImage {
                    ReviewView(image: image, extractor: extractor)
                        .environment(\.modelContext, modelContext)
                }
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .task {
            // Check model availability while user reads tips
            extractor.checkModelAvailability()
        }
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    handleImageCapture(image)
                }
            }
        }
    }

    private func handleImageCapture(_ image: UIImage) {
        capturedImage = image
        currentStep = .review

        // Start extraction immediately
        Task {
            await extractor.extractFromImage(image)
        }
    }
}

#Preview {
    ScanningFlowView(
        modelContext: ModelContext(
            try! ModelContainer(for: Receipt.self, LineItem.self)
        )
    )
}
