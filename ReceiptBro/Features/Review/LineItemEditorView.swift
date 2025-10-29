import SwiftUI

/// Sheet for adding or editing a line item
struct LineItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: EditableLineItem
    let currency: String
    let isNew: Bool

    @FocusState private var focusedField: ItemField?
    @State private var autoCalculateTotal = true

    enum ItemField: Hashable {
        case name, quantity, unitPrice, totalPrice
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product Details") {
                    TextField("Product Name", text: $item.name)
                        .focused($focusedField, equals: .name)
                }

                Section("Pricing") {
                    HStack {
                        Text("Quantity")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("1.0", value: $item.quantity, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .quantity)
                            .onChange(of: item.quantity) {
                                if autoCalculateTotal {
                                    item.updateTotalFromQuantityAndPrice()
                                }
                            }
                    }

                    HStack {
                        Text("Unit Price")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("0.00", value: $item.unitPrice, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .unitPrice)
                            .onChange(of: item.unitPrice) {
                                if autoCalculateTotal {
                                    item.updateTotalFromQuantityAndPrice()
                                }
                            }
                    }

                    HStack {
                        Text("Total Price")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("0.00", value: $item.totalPrice, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .totalPrice)
                            .onChange(of: item.totalPrice) {
                                autoCalculateTotal = false
                                item.updateUnitPriceFromTotal()
                            }
                    }
                }

                Section {
                    Toggle("Auto-calculate Total", isOn: $autoCalculateTotal)
                        .onChange(of: autoCalculateTotal) { _, newValue in
                            if newValue {
                                item.updateTotalFromQuantityAndPrice()
                            }
                        }
                } footer: {
                    Text("When enabled, total price = quantity × unit price")
                }
            }
            .navigationTitle(isNew ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(item.name.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
        .onAppear {
            if isNew {
                focusedField = .name
            }
        }
    }
}

#Preview("New Item") {
    LineItemEditorView(
        item: EditableLineItem(name: "", quantity: 1.0, unitPrice: 0, totalPrice: 0),
        currency: "USD",
        isNew: true
    )
}

#Preview("Edit Item") {
    LineItemEditorView(
        item: EditableLineItem(name: "Organic Bananas", quantity: 2.5, unitPrice: 0.79, totalPrice: 1.98),
        currency: "EUR",
        isNew: false
    )
}
