import SwiftUI
import SwiftData

/// Main list view showing all saved receipts
struct ReceiptListView: View {
    let receipts: [Receipt]
    @State private var searchText = ""

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
        .searchable(text: $searchText, prompt: "Search receipts")
    }

    private func deleteReceipts(at offsets: IndexSet) {
        // Deletion is handled by SwiftData
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
        ReceiptListView(receipts: [])
    }
    .modelContainer(for: [Receipt.self, LineItem.self], inMemory: true)
}
