import SwiftUI
import SwiftData

@main
struct ReceiptBroApp: App {
    let container: ModelContainer

    init() {
        do {
            let storeURL = URL.applicationSupportDirectory
                .appending(path: "ReceiptBro.sqlite")

            try FileManager.default.createDirectory(
                at: URL.applicationSupportDirectory,
                withIntermediateDirectories: true
            )

            let config = ModelConfiguration(
                url: storeURL,
                cloudKitDatabase: .automatic
            )

            container = try ModelContainer(
                for: Receipt.self, LineItem.self,
                configurations: config
            )

            container.mainContext.autosaveEnabled = true

        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
