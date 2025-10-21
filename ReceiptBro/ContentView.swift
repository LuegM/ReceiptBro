import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]
    @State private var showingScanner = false

    var body: some View {
        NavigationStack {
            Group {
                if receipts.isEmpty {
                    EmptyStateView(onScanTapped: {
                        showingScanner = true
                    })
                } else {
                    ReceiptListView(receipts: receipts)
                }
            }
            .navigationTitle("ReceiptBro")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan Receipt", systemImage: "camera.fill")
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScanningFlowView(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Receipt.self, LineItem.self], inMemory: true)
}
