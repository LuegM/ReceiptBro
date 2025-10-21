import SwiftUI

/// Sheet for editing individual receipt fields with tap-to-edit pattern
struct ReceiptFieldEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var receiptData: EditableReceiptData
    let field: EditableField

    enum EditableField {
        case merchantName
        case address
        case date
        case transactionId
        case paymentMethod
        case currency
        case taxAmount
        case totalAmount

        var title: String {
            switch self {
            case .merchantName: return "Merchant Name"
            case .address: return "Address"
            case .date: return "Date"
            case .transactionId: return "Transaction ID"
            case .paymentMethod: return "Payment Method"
            case .currency: return "Currency"
            case .taxAmount: return "Tax Amount"
            case .totalAmount: return "Total Amount"
            }
        }

        var icon: String {
            switch self {
            case .merchantName: return "building.2"
            case .address: return "location"
            case .date: return "calendar"
            case .transactionId: return "number"
            case .paymentMethod: return "creditcard"
            case .currency: return "dollarsign.circle"
            case .taxAmount: return "percent"
            case .totalAmount: return "sum"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    switch field {
                    case .merchantName:
                        TextField("Merchant Name", text: $receiptData.merchantName)
                    case .address:
                        TextField("Address", text: $receiptData.address, axis: .vertical)
                            .lineLimit(2...4)
                    case .date:
                        DatePicker("Date", selection: $receiptData.date, displayedComponents: .date)
                    case .transactionId:
                        TextField("Transaction ID", text: $receiptData.transactionId)
                    case .paymentMethod:
                        TextField("Payment Method", text: $receiptData.paymentMethod)
                    case .currency:
                        TextField("Currency Code", text: $receiptData.currency)
                            .textInputAutocapitalization(.characters)
                    case .taxAmount:
                        HStack {
                            Text("Tax Amount")
                            Spacer()
                            TextField("0.00", value: $receiptData.taxAmount, format: .number.precision(.fractionLength(2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    case .totalAmount:
                        HStack {
                            Text("Total Amount")
                            Spacer()
                            TextField("0.00", value: $receiptData.totalAmount, format: .number.precision(.fractionLength(2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                // Show calculated totals for validation
                if field == .taxAmount || field == .totalAmount {
                    Section("Calculated Values") {
                        HStack {
                            Text("Subtotal (from items)")
                            Spacer()
                            Text(receiptData.calculatedSubtotal, format: .currency(code: receiptData.currency))
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Calculated Total")
                            Spacer()
                            Text(receiptData.calculatedTotal, format: .currency(code: receiptData.currency))
                                .foregroundStyle(.secondary)
                        }

                        if !receiptData.totalsMatch {
                            Label("Totals don't match", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle(field.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ReceiptFieldEditorView(
        receiptData: EditableReceiptData(
            merchantName: "BILLA",
            address: "WEXSTRASSE 24, 1200 WIEN",
            date: Date(),
            transactionId: "072620",
            paymentMethod: "VISA",
            currency: "EUR",
            items: [],
            taxAmount: 0.82,
            totalAmount: 6.47
        ),
        field: .merchantName
    )
}
