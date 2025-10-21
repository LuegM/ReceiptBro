import SwiftUI

/// Displays receipt data as it streams in from Foundation Models
/// Handles PartiallyGenerated content with progressive rendering
struct VirtualReceiptView: View {
    let data: ReceiptData.PartiallyGenerated

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            VStack(alignment: .leading, spacing: 8) {
                if let merchantName = data.merchantName {
                    Text(merchantName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.opacity)
                } else {
                    shimmerPlaceholder(width: 200, height: 28)
                }

                if let address = data.address {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }

                if let date = data.date {
                    Text(formatDate(date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))

            Divider()

            // Line Items Section
            VStack(alignment: .leading, spacing: 0) {
                if let items = data.items, !items.isEmpty {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        LineItemRow(item: item, currency: data.currency ?? "USD")
                            .contentTransition(.opacity)

                        if index < items.count - 1 {
                            Divider()
                                .padding(.leading)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            shimmerPlaceholder(width: .infinity, height: 44)
                        }
                    }
                    .padding()
                }

                Divider()
                    .padding(.top)

                // Totals Section
                VStack(spacing: 8) {
                    if let taxAmount = data.taxAmount {
                        HStack {
                            Text("Tax")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(taxAmount, format: .currency(code: data.currency ?? "USD"))
                        }
                        .contentTransition(.opacity)
                    }

                    if let totalAmount = data.totalAmount {
                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(totalAmount, format: .currency(code: data.currency ?? "USD"))
                                .fontWeight(.semibold)
                        }
                        .contentTransition(.opacity)
                    } else {
                        shimmerPlaceholder(width: .infinity, height: 24)
                    }
                }
                .padding()
            }

            Divider()

            // Payment Info Section
            VStack(alignment: .leading, spacing: 8) {
                if let paymentMethod = data.paymentMethod {
                    Label(paymentMethod, systemImage: paymentIcon(for: paymentMethod))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }

                if let transactionId = data.transactionId {
                    Text("Transaction: \(transactionId)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .contentTransition(.opacity)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Helper Views

    private func shimmerPlaceholder(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(width: width == .infinity ? nil : width, height: height)
            .frame(maxWidth: width == .infinity ? .infinity : nil)
            .shimmering()
    }

    // MARK: - Helpers

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }

    private func paymentIcon(for method: String) -> String {
        let lowercased = method.lowercased()
        if lowercased.contains("cash") {
            return "banknote"
        } else if lowercased.contains("credit") {
            return "creditcard"
        } else if lowercased.contains("debit") {
            return "creditcard.fill"
        } else if lowercased.contains("mobile") || lowercased.contains("apple") {
            return "wave.3.right"
        } else {
            return "dollarsign.circle"
        }
    }
}

// MARK: - Line Item Row

struct LineItemRow: View {
    let item: LineItemData.PartiallyGenerated
    var currency: String = "USD"

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                if let name = item.name {
                    Text(name)
                        .font(.body)
                } else {
                    shimmer(width: 120, height: 18)
                }

                if let quantity = item.quantity, quantity != 1.0 {
                    Text("Qty: \(quantity, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let totalPrice = item.totalPrice {
                    Text(totalPrice, format: .currency(code: currency))
                        .font(.body)
                } else {
                    shimmer(width: 60, height: 18)
                }

                if let unitPrice = item.unitPrice,
                   let quantity = item.quantity,
                   quantity > 1.0 {
                    Text(unitPrice, format: .currency(code: currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func shimmer(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmering()
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

// MARK: - Preview

//#Preview("Streaming Receipt") {
//    // Create an empty PartiallyGenerated for streaming preview (all properties are nil)
//    VirtualReceiptView(data: ReceiptData.PartiallyGenerated())
//        .padding()
//}
//
//#Preview("Complete Receipt") {
//    // Create a sample PartiallyGenerated with data populated
//    // All properties in PartiallyGenerated are optional versions of the original properties
//    var sampleData = ReceiptData.PartiallyGenerated()
//    sampleData.merchantName = "Whole Foods Market"
//    sampleData.date = "2025-10-15"
//    sampleData.totalAmount = 47.83
//    sampleData.taxAmount = 3.21
//    sampleData.paymentMethod = "Credit Card"
//    sampleData.transactionId = "TXN-456789"
//    sampleData.address = "123 Market St, San Francisco, CA 94103"
//    
//    // Create sample line items - these are also optional in PartiallyGenerated
//    var item1 = LineItemData.PartiallyGenerated()
//    item1.name = "Organic Bananas"
//    item1.quantity = 2.5
//    item1.unitPrice = 0.79
//    item1.totalPrice = 1.98
//    
//    var item2 = LineItemData.PartiallyGenerated()
//    item2.name = "Almond Milk"
//    item2.quantity = 1.0
//    item2.unitPrice = 4.99
//    item2.totalPrice = 4.99
//    
//    var item3 = LineItemData.PartiallyGenerated()
//    item3.name = "Whole Grain Bread"
//    item3.quantity = 2.0
//    item3.unitPrice = 5.49
//    item3.totalPrice = 10.98
//    
//    sampleData.items = [item1, item2, item3]
//    
//    VirtualReceiptView(data: sampleData)
//        .padding()
//}
