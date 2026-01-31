import SwiftUI
import Shimmer
import FoundationModels

struct ScrollViewReceiptEditorView: View {
    var receiptData: Binding<ReceiptData.PartiallyGenerated>
    let isStreaming: Bool
    var validationIssues: [ReceiptValidator.FieldIssue] = []
    var ocrText: String? = nil
    var showProgress: Bool = false
    var progressMessage: String = ""
    var image: UIImage? = nil

    @State var showOCRText: Bool = false
    @State private var showScrollToEndImageSheet = false
    @State private var bottomPullOffset: CGFloat = 0.0
    @State private var indicatorDefaultHeight: CGFloat? = nil
    @State private var crossedPullThreshold = false
    @State private var hapticTriggered = false
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.editMode) private var editMode

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    private var data: ReceiptData.PartiallyGenerated {
        receiptData.wrappedValue
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                if showProgress {
                    progressSection
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                }

                merchantSection
                lineItemsSection
                totalsSection
                paymentSection

                if !showOCRText {
                    Button {
                        showOCRText.toggle()
                    } label: {
                        Label("reveal OCR Text", systemImage: "eye")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .contentTransition(.opacity)
                } else if let ocrText = ocrText, !isStreaming, showOCRText {
                    ocrTextSection(ocrText)
                        .contentTransition(.opacity)
                }

                // Pull to view image hint
                if image != nil && !isStreaming {
                    let pullThreshold: CGFloat = 80.0  // Match threshold in onScrollGeometryChange
                    let displayThreshold: CGFloat = 0.3  // Start showing at 30% of threshold
                    let pullFactor = bottomPullOffset / pullThreshold

                    if pullFactor > displayThreshold {
                        // Calculate scale: 0 at displayThreshold, 1.0 at 100% threshold
                        let scaleFactor = displayThreshold >= 1 ? 1.0 :
                            1 / (1 - displayThreshold) * pullFactor + (1 - 1 / (1 - displayThreshold))

                        VStack(spacing: 8) {
                            Image(systemName: pullFactor >= 1.0 ? "photo.circle.fill" : "arrow.up.circle")
                                .font(.title)
                                .foregroundStyle(pullFactor >= 1.0 ? .blue : .secondary)
                                .symbolEffect(.bounce, value: pullFactor >= 1.0 ? pullFactor : 0)

                            Text(pullFactor >= 1.0 ? "Release to view image" : "Pull up to view image")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .overlay {
                            GeometryReader { geo in
                                Color.clear.preference(key: IndicatorHeightKey.self, value: geo.size.height)
                            }
                        }
                        .onPreferenceChange(IndicatorHeightKey.self) { newHeight in
                            if let current = indicatorDefaultHeight {
                                if abs(current - newHeight) > 1 {
                                    indicatorDefaultHeight = newHeight
                                }
                            } else {
                                indicatorDefaultHeight = newHeight
                            }
                        }
                        .scaleEffect(min(scaleFactor, 1.0))
                        .frame(height: indicatorDefaultHeight != nil ? min(scaleFactor, 1.0) * indicatorDefaultHeight! : nil)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .animation(.easeOut(duration: 0.2), value: bottomPullOffset)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .scrollIndicators(.hidden)
        .animation(.default, value: showScrollToEndImageSheet)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            let contentHeight = geometry.contentSize.height
            let visibleHeight = geometry.containerSize.height
            let offset = geometry.contentOffset.y

            let maxOffset = contentHeight - visibleHeight
            return max(0, offset - maxOffset)
        } action: { oldOffset, newOffset in
            let threshold: CGFloat = 80.0
            let roundedOffset = (newOffset / 5).rounded() * 5
            let roundedOldOffset = (bottomPullOffset / 5).rounded() * 5

            if roundedOffset != roundedOldOffset {
                bottomPullOffset = roundedOffset
            }

            if newOffset >= threshold && !crossedPullThreshold {
                crossedPullThreshold = true
                if !hapticTriggered && image != nil && !isStreaming {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    hapticTriggered = true
                }
            }

            if crossedPullThreshold && oldOffset > threshold * 0.5 && newOffset < threshold * 0.3
               && image != nil && !isStreaming {
                showScrollToEndImageSheet = true
                crossedPullThreshold = false
                hapticTriggered = false
            }

            if newOffset < threshold * 0.3 {
                crossedPullThreshold = false
                hapticTriggered = false
            }
        }
        .sheet(isPresented: $showScrollToEndImageSheet) {
            if let image = image {
                NavigationStack {
                    ScrollViewZoomableImageView(image: image)
                        .navigationTitle("Receipt Image")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showScrollToEndImageSheet = false
                                }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Progress Section

    @ViewBuilder
    private var progressSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .symbolEffect(.variableColor, options: .repeat(.continuous))

            Text(progressMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .shimmering(bandSize: 3)

            Spacer()
        }
    }

    // MARK: - Merchant Section

    @ViewBuilder
    private var merchantSection: some View {
        VStack(spacing: 12) {
            VStack{
                Circle()
                    .fill(colorScheme == .light ? Color(.systemGray5) : Color(.systemGray4))
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Image(systemName: "receipt")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    )


                // Merchant name
                HStack {
                    Group {
                        if isEditing {
                            TextField("Merchant", text: receiptData.merchantName.bound)
                                .multilineTextAlignment(.center)
                                .font(.headline)
                                .textFieldStyle(.roundedBorder)
                        } else if let merchantName = data.merchantName {
                            Text(merchantName)
                                .contentTransition(.opacity)
                                .font(.headline)
                        } else {
                            Text("Not found")
                                .redacted(reason: isStreaming ? .placeholder : [])
                                .shimmering(active: isStreaming)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let issue = validationIssues.first(where: { $0.field == .merchantName }) {
                        ValidationBadge(issue: issue, compact: true)
                    }
                }

                // Address
                Group {
                    if isEditing {
                        TextField("Address", text: receiptData.address.bound, axis: .vertical)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                    } else if let address = data.address {
                        Text(address)
                            .contentTransition(.opacity)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Not found")
                            .redacted(reason: isStreaming ? .placeholder : [])
                            .shimmering(active: isStreaming)
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .hAlign(.center)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        
        // Date footer
        HStack(alignment: .center) {
            if let issue = validationIssues.first(where: { $0.field == .date }) {
                ValidationBadge(issue: issue, compact: true)
                    .opacity(0.8)
            }
            if isEditing {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { parseDate(data.date) ?? Date() },
                        set: { receiptData.date.wrappedValue = formatDate($0) }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
            } else if let date = data.date {
                Text(formatDateForDisplay(date))
                    .contentTransition(.opacity)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not found")
                    .redacted(reason: isStreaming ? .placeholder : [])
                    .shimmering(active: isStreaming)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .hAlign(.trailing)
        .padding(.trailing, 32)
        .padding(.top, 8)
    }

    // MARK: - Line Items Section

    @ViewBuilder
    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Items")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .padding(.top, 20)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                if data.items != nil {
                    ForEach(receiptData.items.bound) { $item in
                        VStack(spacing: 0) {
                            if isEditing {
                                HStack(alignment: .center) {
                                    lineItemEditRow(item: $item)

                                    Button(role: .destructive) {
                                        withAnimation {
                                            receiptData.wrappedValue.items?.removeAll { $0.id == item.id }
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                    .padding(.trailing, 24)
                                }
                            } else {
                                lineItemViewRow(item: item)
                            }

                            if item.id != receiptData.items.bound.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                } else if isStreaming {
                    // Placeholder items while streaming
                    ForEach(0..<3, id: \.self) { _ in
                        HStack {
                            Text("Loading item...")
                                .redacted(reason: .placeholder)
                                .shimmering()
                            Spacer()
                            Text("$0.00")
                                .redacted(reason: .placeholder)
                                .shimmering()
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)

            if let issue = validationIssues.first(where: { $0.field == .items }) {
                Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Totals Section

    @ViewBuilder
    private var totalsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Totals")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .padding(.top, 20)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                // Subtotal
                LabeledContent("Subtotal") {
                    Text(calculatedSubtotal, format: .currency(code: data.currency ?? "USD"))
                        .contentTransition(.numericText())
                        .foregroundStyle(.secondary)
                        .opacity(data.items == nil && isStreaming ? 0.5 : 1.0)
                        .redacted(reason: data.items == nil && isStreaming ? .placeholder : [])
                        .shimmering(active: data.items == nil && isStreaming)
                }
                .padding()

                Divider()
                    .padding(.leading, 16)

                // Discount
                if let discount = data.discountAmount, discount > 0 {
                    LabeledContent {
                        VStack(alignment: .trailing){
                            Text(-discount, format: .currency(code: data.currency ?? "USD"))
                                .contentTransition(.numericText())
                                .foregroundStyle(.green)
                            Text(calculatedSubtotal - discount, format: .currency(code: data.currency ?? "USD"))
                                .contentTransition(.numericText())
                                .font(.caption)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Discount")
                            Text("Subtotal After Discount")
                                .font(.caption)
                        }
                    }
                    .padding()

                    Divider()
                        .padding(.leading, 16)
                }

                LabeledContent {
                    VStack(alignment: .trailing){
                        if isEditing {
                            TextField("Total", value: receiptData.totalAmount.bound, format: .currency(code: data.currency ?? "USD"))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        } else {
                            Text(data.totalAmount ?? 0, format: .currency(code: data.currency ?? "USD"))
                                .contentTransition(.numericText())
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .opacity(data.totalAmount == nil && isStreaming ? 0.5 : 1.0)
                                .redacted(reason: data.totalAmount == nil && isStreaming ? .placeholder : [])
                                .shimmering(active: data.totalAmount == nil && isStreaming)
                        }

                        if isEditing {
                            TextField("Tax", value: receiptData.taxAmount.bound, format: .currency(code: data.currency ?? "USD"))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .font(.caption)
                        } else {
                            Text(data.taxAmount ?? 0, format: .currency(code: data.currency ?? "USD"))
                                .contentTransition(.numericText())
                                .font(.caption)
                                .opacity(data.taxAmount == nil && isStreaming ? 0.5 : 1.0)
                                .redacted(reason: data.taxAmount == nil && isStreaming ? .placeholder : [])
                                .shimmering(active: data.taxAmount == nil && isStreaming)
                        }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text("Total")
                            .fontWeight(.semibold)
                        Text("Tax")
                            .font(.caption)
                    }
                }
                .padding()


                // Mismatch warning
                if !isStreaming && !totalsMatch {
                    Divider()

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .imageScale(.small)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total mismatch")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("Calculated: \(calculatedTotal, format: .currency(code: data.currency ?? "USD"))")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Payment Section

    @ViewBuilder
    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Payment Info")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .padding(.top, 20)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                // Payment Method
                if isEditing {
                    HStack {
                        Text("Payment Method")
                        Spacer()
                        TextField("Payment Method", text: receiptData.paymentMethod.bound)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding()
                } else {
                    LabeledContent("Payment Method") {
                        if let paymentMethod = data.paymentMethod {
                            Text(paymentMethod)
                                .contentTransition(.opacity)
                        } else {
                            Text("Not found")
                                .redacted(reason: isStreaming ? .placeholder : [])
                                .shimmering(active: isStreaming)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }

                Divider()
                    .padding(.leading, 16)

                // Currency
                if isEditing {
                    Picker("Currency", selection: receiptData.currency.bound) {
                        ForEach(["USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD"], id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    .padding()
                } else {
                    LabeledContent("Currency") {
                        if let currency = data.currency {
                            Text(currency)
                                .contentTransition(.opacity)
                        } else {
                            Text("USD")
                                .redacted(reason: isStreaming ? .placeholder : [])
                                .shimmering(active: isStreaming)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Line Item Row Views

    @ViewBuilder
    private func lineItemViewRow(item: LineItemData.PartiallyGenerated) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent {
                Text(item.totalPrice ?? 0, format: .currency(code: data.currency ?? "USD"))
                    .contentTransition(.numericText())
                    .font(.body)
                    .opacity(item.totalPrice == nil && isStreaming ? 0.5 : 1.0)
                    .redacted(reason: item.totalPrice == nil && isStreaming ? .placeholder : [])
                    .shimmering(active: item.totalPrice == nil && isStreaming)
            } label: {
                if let name = item.name {
                    Text(name)
                        .contentTransition(.opacity)
                        .font(.body)
                } else {
                    Text("Unknown Item")
                        .redacted(reason: .placeholder)
                        .shimmering()
                        .foregroundStyle(.secondary)
                }
            }

            // qty > 1 details
            if let quantity = item.quantity,
               let unitPrice = item.unitPrice,
               quantity > 1.0 {
                HStack(spacing: 4) {
                    Text("\(quantity, format: .number.precision(.fractionLength(0...2))) × \(unitPrice, format: .currency(code: data.currency ?? "USD"))")
                        .contentTransition(.numericText())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func lineItemEditRow(item: Binding<LineItemData.PartiallyGenerated>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Item name", text: item.name.bound)
                .font(.body)

            HStack {
                TextField("Qty", value: item.quantity.bound, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)

                Text("×")
                    .foregroundStyle(.secondary)

                TextField("Price", value: item.unitPrice.bound, format: .currency(code: data.currency ?? "USD"))
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)

                Text("=")
                    .foregroundStyle(.secondary)

                TextField("Total", value: item.totalPrice.bound, format: .currency(code: data.currency ?? "USD"))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            .font(.caption)
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var calculatedSubtotal: Double {
        guard let items = data.items else { return 0 }
        return items.reduce(0) { $0 + ($1.totalPrice ?? 0) }
    }

    private var calculatedTotal: Double {
        let subtotal = calculatedSubtotal
        let discount = data.discountAmount ?? 0
        let tax = data.taxAmount ?? 0
        let taxType = data.taxType ?? "included"
        if taxType == "included" {
            return subtotal - discount
        } else {
            return subtotal - discount + tax
        }
    }

    private var totalsMatch: Bool {
        guard let totalAmount = data.totalAmount else { return true }
        return abs(calculatedTotal - totalAmount) < 0.05
    }

    // MARK: - Helper Methods

    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: dateString)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    private func formatDateForDisplay(_ dateString: String?) -> String {
        guard let dateString = dateString,
              let date = parseDate(dateString) else {
            return dateString ?? "Not found"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - OCR Text Section

    @ViewBuilder
    private func ocrTextSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OCR Text")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 32)
                .padding(.top, 20)
                .padding(.bottom, 8)

            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
        }
    }
}

private struct ScrollViewZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @GestureState private var magnifyBy: CGFloat = 1.0

    var magnification: some Gesture {
        MagnificationGesture()
            .updating($magnifyBy) { value, gestureState, _ in
                gestureState = value
            }
            .onEnded { value in
                scale *= value
                scale = min(max(scale, 1.0), 4.0)  // 1x-4x
            }
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale * magnifyBy)
                .gesture(magnification)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Preference Keys

struct IndicatorHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Validation Badge

struct ValidationBadge: View {
    let issue: ReceiptValidator.FieldIssue
    var compact: Bool = false
    @State private var showTooltip = false

    var body: some View {
        Button(action: {
            showTooltip.toggle()
        }) {
            Image(systemName: issue.severity == .error ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(compact ? .caption : .callout)
                .foregroundStyle(issue.severity == .error ? .red : .orange)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTooltip) {
            Text(issue.message)
                .font(.caption)
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Preview Helpers

extension UIImage {
    static func createSampleReceiptImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 600))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 600))

            let headerText = "SAMPLE RECEIPT\nRestaurant Name\n123 Main St"
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            headerText.draw(in: CGRect(x: 20, y: 20, width: 260, height: 100), withAttributes: headerAttrs)

            let itemsText = "Item 1          $10.00\nItem 2          $15.00\nItem 3          $8.50"
            let itemsAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            itemsText.draw(in: CGRect(x: 20, y: 140, width: 260, height: 100), withAttributes: itemsAttrs)

            let totalText = "TOTAL:         $33.50"
            let totalAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            totalText.draw(in: CGRect(x: 20, y: 260, width: 260, height: 30), withAttributes: totalAttrs)
        }
    }
}

// MARK: - Previews

private struct StreamingPreview: View {
    @State private var receiptData: ReceiptData.PartiallyGenerated?
    @State private var isStreaming = true
    private let sampleImage = UIImage.createSampleReceiptImage()

    var body: some View {
        NavigationStack {
            if let receiptData {
                ScrollViewReceiptEditorView(
                    receiptData: .constant(receiptData),
                    isStreaming: isStreaming,
                    showProgress: isStreaming,
                    progressMessage: "Extracting receipt details...",
                    image: sampleImage
                )
                .navigationTitle("Receipt")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ProgressView()
            }
        }
        .task {
            do {
                let json = #"{"merchantName": "Longboards", "address": "92-161 Waipahe Place, Kapolei, HI 96707", "date": "2019-01-11", "currency": "USD", "items": [{"name": "Green Salad", "quantity": 1.0, "unitPrice": 8.0, "totalPrice": 8.0}, {"name": "Wagyu Cheeseburger", "quantity": 1.0, "unitPrice": 19.0, "totalPrice": 19.0}], "totalAmount": 41.31}"#

                for try await receipt in ReceiptData.streamResponse(from: json) {
                    self.receiptData = receipt
                }
                isStreaming = false
            } catch {
                print("Error generating receipt: \(error)")
            }
        }
    }
}

private struct ViewModePreview: View {
    @State private var receiptData = ReceiptData.mockLongboards.asPartiallyGenerated()
    private let sampleImage = UIImage.createSampleReceiptImage()

    var body: some View {
        NavigationStack {
            ScrollViewReceiptEditorView(
                receiptData: $receiptData,
                isStreaming: false,
                ocrText: "Longboards\n92-161 Waipahe Place\nKapolei, HI 96707\n\nGreen Salad $8.00\nWagyu Cheeseburger $19.00\nGarlic Fries $2.00\nDrink of the Day $9.75\nTea $4.00\n\nSubtotal: $42.75\nDiscount: -$3.30\nTax: $1.86\nTotal: $41.31",
                image: sampleImage
            )
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                EditButton()
            }
        }
    }
}

private struct EditModePreview: View {
    @State private var receiptData = ReceiptData.mockLongboards.asPartiallyGenerated()
    private let sampleImage = UIImage.createSampleReceiptImage()

    var body: some View {
        NavigationStack {
            ScrollViewReceiptEditorView(
                receiptData: $receiptData,
                isStreaming: false,
                image: sampleImage
            )
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Edit Receipt")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ValidationPreview: View {
    @State private var receiptData = ReceiptData.mockLongboards.asPartiallyGenerated()
    private let sampleImage = UIImage.createSampleReceiptImage()

    var body: some View {
        NavigationStack {
            ScrollViewReceiptEditorView(
                receiptData: $receiptData,
                isStreaming: false,
                validationIssues: [
                    ReceiptValidator.FieldIssue(
                        field: .merchantName,
                        message: "Merchant name seems unusual or incomplete",
                        severity: .warning
                    ),
                    ReceiptValidator.FieldIssue(
                        field: .date,
                        message: "Date format should be YYYY-MM-DD",
                        severity: .error
                    ),
                    ReceiptValidator.FieldIssue(
                        field: .totalAmount,
                        message: "Total doesn't match calculated amount",
                        severity: .warning
                    ),
                    ReceiptValidator.FieldIssue(
                        field: .items,
                        message: "Duplicate items detected",
                        severity: .warning
                    )
                ],
                image: sampleImage
            )
            .navigationTitle("Receipt with Issues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                EditButton()
            }
        }
    }
}

#Preview("Streaming") {
    StreamingPreview()
}

#Preview("View Mode") {
    ViewModePreview()
}

#Preview("Edit Mode") {
    EditModePreview()
}

#Preview("With Validation Issues") {
    ValidationPreview()
}
