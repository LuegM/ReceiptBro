import SwiftUI

/// Empty state view shown when no receipts exist
struct EmptyStateView: View {
    let onScanTapped: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "doc.text.image")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)

            // Title and description
            VStack(spacing: 12) {
                Text("No Receipts Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Scan your first receipt to get started.\nWe'll digitize it automatically using AI.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Call to action
            Button {
                onScanTapped()
            } label: {
                Label("Scan Receipt", systemImage: "camera.fill")
                    .font(.headline)
                    .fontDesign(.rounded)
//                    .foregroundStyle(.white)
//                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
//                    .background(Color.blue.gradient)
//                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    EmptyStateView(onScanTapped: {})
}
