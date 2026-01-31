import SwiftUI
import SwiftData

struct ReceiptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let receipt: Receipt

    @State private var showingDeleteConfirmation = false
    @State private var showingShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Image
                if let imageData = receipt.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }

                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(receipt.merchantName)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let address = receipt.address {
                            Label(address, systemImage: "mappin.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Label(receipt.date.formatted(date: .long, time: .omitted), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // Line Items
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(receipt.items) { item in
                            LineItemDetailRow(item: item)

                            if item.id != receipt.items.last?.id {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }

                    Divider()

                    // Totals
                    VStack(spacing: 12) {
                        if let taxAmount = receipt.taxAmount {
                            HStack {
                                Text("Tax")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(taxAmount, format: .currency(code: receipt.currency))
                            }
                        }

                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(receipt.totalAmount, format: .currency(code: receipt.currency))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()

                    Divider()

                    // Extra Info
                    VStack(alignment: .leading, spacing: 12) {
                        if let paymentMethod = receipt.paymentMethod {
                            DetailInfoRow(
                                icon: "creditcard.fill",
                                label: "Payment Method",
                                value: paymentMethod
                            )
                        }

                        DetailInfoRow(
                            icon: "clock.fill",
                            label: "Added",
                            value: receipt.createdAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("Receipt Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Delete Receipt?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteReceipt()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func deleteReceipt() {
        modelContext.delete(receipt)
        try? modelContext.save()
        dismiss()
    }
}

struct LineItemDetailRow: View {
    let item: LineItem

    var currency: String {
        item.receipt?.currency ?? "USD"
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)

                if item.quantity != 1.0 {
                    Text("Qty: \(item.quantity, specifier: "%.2f") × \(item.unitPrice, format: .currency(code: currency))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(item.totalPrice, format: .currency(code: currency))
                .font(.body)
        }
        .padding()
    }
}

struct DetailInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline)
            }

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        if let sampleReceipt = try? Receipt(
            from: ReceiptData.exampleGroceryReceipt
        ) {
            ReceiptDetailView(receipt: sampleReceipt)
        }
    }
    .modelContainer(for: [Receipt.self, LineItem.self], inMemory: true)
}
