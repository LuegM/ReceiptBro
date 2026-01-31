import SwiftUI
import SwiftData
import FoundationModels

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isModelAvailable = true

    var body: some View {
        NavigationStack {
            if isModelAvailable {
                ReceiptListView()
                    .navigationTitle("ReceiptBro")
            } else {
                ModelUnavailableView()
            }
            
        }
        .onAppear {
            checkModelAvailability()
        }
    }

    private func checkModelAvailability() {
        let model = SystemLanguageModel(useCase: .contentTagging)
        isModelAvailable = model.availability == .available
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Receipt.self, LineItem.self], inMemory: true)
}
