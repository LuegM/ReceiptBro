import SwiftUI

struct ModelUnavailableView: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Device Not Supported")
                    .font(.title2)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
                    .foregroundStyle(.orange.gradient)
            }
        } description: {
            Text("\nReceiptBro **requires Foundation Models** which are not available on this device.\n\nFoundation Models require iOS 18.2 or later on a compatible device.")
        }
    }
}

#Preview {
    ModelUnavailableView()
}
