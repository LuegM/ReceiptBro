import SwiftUI

/// Receipt view with tap-to-edit functionality - opens sheets for editing
struct TapToEditReceiptView: View {
    @Bindable var receiptData: EditableReceiptData
    @State private var editingField: ReceiptFieldEditorView.EditableField?
    @State private var editingItem: EditableLineItem?
    @State private var showingFieldEditor = false
    @State private var showingItemEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section - Tappable
            VStack(alignment: .leading, spacing: 8) {
                Text(receiptData.merchantName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingField = .merchantName
                        showingFieldEditor = true
                    }

                if !receiptData.address.isEmpty {
                    Text(receiptData.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingField = .address
                            showingFieldEditor = true
                        }
                }

                Text(receiptData.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingField = .date
                        showingFieldEditor = true
                    }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))

            Divider()

            // Line Items Section - Tappable
            VStack(alignment: .leading, spacing: 0) {
                ForEach(receiptData.items) { item in
                    TapToEditLineItemRow(item: item, currency: receiptData.currency)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingItem = item
                            showingItemEditor = true
                        }

                    if item.id != receiptData.items.last?.id {
                        Divider()
                            .padding(.leading)
                    }
                }

                // Add item button
                Button {
                    let newItem = EditableLineItem(name: "", quantity: 1.0, unitPrice: 0, totalPrice: 0)
                    receiptData.items.append(newItem)
                    editingItem = newItem
                    showingItemEditor = true
                } label: {
                    Label("Add Item", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .buttonStyle(.borderless)

                Divider()
                    .padding(.top)

                // Totals Section - Tappable
                VStack(spacing: 8) {
                    HStack {
                        Text("Subtotal")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(receiptData.calculatedSubtotal, format: .currency(code: receiptData.currency))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Tax")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(receiptData.taxAmount, format: .currency(code: receiptData.currency))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingField = .taxAmount
                        showingFieldEditor = true
                    }

                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(receiptData.totalAmount, format: .currency(code: receiptData.currency))
                            .fontWeight(.semibold)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingField = .totalAmount
                        showingFieldEditor = true
                    }

                    if !receiptData.totalsMatch {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .imageScale(.small)
                            Text("Calculated total: \(receiptData.calculatedTotal, format: .currency(code: receiptData.currency))")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Payment Info Section - Tappable
            VStack(alignment: .leading, spacing: 8) {
                if !receiptData.paymentMethod.isEmpty {
                    Label(receiptData.paymentMethod, systemImage: paymentIcon(for: receiptData.paymentMethod))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingField = .paymentMethod
                            showingFieldEditor = true
                        }
                }

                if !receiptData.transactionId.isEmpty {
                    Text("Transaction: \(receiptData.transactionId)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingField = .transactionId
                            showingFieldEditor = true
                        }
                }

                Text("Currency: \(receiptData.currency)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingField = .currency
                        showingFieldEditor = true
                    }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .sheet(isPresented: $showingFieldEditor) {
            if let field = editingField {
                ReceiptFieldEditorView(receiptData: receiptData, field: field)
            }
        }
        .sheet(isPresented: $showingItemEditor) {
            if let item = editingItem {
                LineItemEditorView(
                    item: item,
                    currency: receiptData.currency,
                    isNew: item.name.isEmpty
                )
            }
        }
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

// MARK: - Tap-to-Edit Line Item Row

struct TapToEditLineItemRow: View {
    @Bindable var item: EditableLineItem
    let currency: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name.isEmpty ? "Untitled Item" : item.name)
                    .font(.body)
                    .foregroundStyle(item.name.isEmpty ? .secondary : .primary)

                if item.quantity != 1.0 {
                    Text("Qty: \(item.quantity, format: .number.precision(.fractionLength(0...2)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.totalPrice, format: .currency(code: currency))
                    .font(.body)

                if item.quantity > 1.0 {
                    Text(item.unitPrice, format: .currency(code: currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    TapToEditReceiptView(receiptData: EditableReceiptData(
        merchantName: "BILLA",
        address: "WEXSTRASSE 24, 1200 WIEN",
        date: Date(),
        transactionId: "072620",
        paymentMethod: "VISA",
        currency: "EUR",
        items: [
            EditableLineItem(name: "Clever Sauerrahm", quantity: 2.0, unitPrice: 0.99, totalPrice: 1.98),
            EditableLineItem(name: "Clever Weizenmehl", quantity: 2.0, unitPrice: 0.75, totalPrice: 1.50),
            EditableLineItem(name: "Happy Day Maracuja", quantity: 1.0, unitPrice: 2.99, totalPrice: 2.99)
        ],
        taxAmount: 0.82,
        totalAmount: 6.47
    ))
    .padding()
}
