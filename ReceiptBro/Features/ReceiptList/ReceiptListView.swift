import SwiftUI
import SwiftData
import PhotosUI

/// Main list view showing all saved receipts
struct ReceiptListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]
    @State private var extractor: ReceiptExtractor?
    @State private var searchText = ""
    @State private var showingScanView = false
    @State private var showingPhotoPicker = false
    @State private var showingReviewView = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    
    var filteredReceipts: [Receipt] {
        if searchText.isEmpty {
            return receipts
        } else {
            return receipts.filter { receipt in
                receipt.merchantName.localizedCaseInsensitiveContains(searchText) ||
                receipt.address?.localizedCaseInsensitiveContains(searchText) == true ||
                receipt.transactionId?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }

    var body: some View {
        List {
            ForEach(filteredReceipts) { receipt in
                NavigationLink {
                    ReceiptDetailView(receipt: receipt)
                } label: {
                    ReceiptRowView(receipt: receipt)
                }
            }
            .onDelete(perform: deleteReceipts)
        }
        .overlay {
            if receipts.isEmpty {
                EmptyStateView(
                    onTakePhotoTapped: {
                        showingScanView = true
                    },
                    onFromLibraryTapped: {
                        showingPhotoPicker = true
                    }
                )
            }
        }
        .if(!receipts.isEmpty) { view in
            view.searchable(text: $searchText, prompt: "Search receipts")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingScanView = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                    }
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("From Library", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Label("Add Receipt", systemImage: "document.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingScanView) {
            ScanView(onImageCaptured: { image in
                handleImageCapture(image)
            })
        }
        .sheet(isPresented: $showingReviewView) {
            if let image = capturedImage, let extractor = extractor {
                ReviewView(image: image, extractor: extractor)
                    .interactiveDismissDisabled()
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    handleImageCapture(image)
                }
                
                selectedPhotoItem = nil
            }
        }
    }

    private func deleteReceipts(at offsets: IndexSet) {
        for index in offsets {
            let receipt = filteredReceipts[index]
            modelContext.delete(receipt)
        }
    }

    private func handleImageCapture(_ image: UIImage) {
        capturedImage = image

        // Create a fresh extractor for each scan to avoid context window accumulation
        // LanguageModelSession maintains a transcript that cannot be cleared,
        // so we need a new session (via new extractor) for each document
        extractor = ReceiptExtractor()

        // Dismiss ScanView if it's showing
        showingScanView = false

        // Show ReviewView
        showingReviewView = true

        // Start extraction immediately
        Task {
            await extractor?.extractFromImage(image)
        }
    }
}

struct ReceiptRowView: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or icon
            if let imageData = receipt.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.gradient)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.white)
                    }
            }

            // Receipt info
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.merchantName)
                    .font(.headline)
                    .lineLimit(1)

                Text(receipt.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let paymentMethod = receipt.paymentMethod {
                    Text(paymentMethod)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Amount
            Text(receipt.totalAmount, format: .currency(code: receipt.currency))
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ReceiptListView()
    }
    .modelContainer(for: [Receipt.self, LineItem.self], inMemory: true)
}
