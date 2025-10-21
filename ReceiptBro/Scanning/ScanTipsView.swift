import SwiftUI

/// Tips screen shown before scanning to help users get better results
struct ScanTipsView: View {
    let onScanTapped: () -> Void
    let onPhotoLibraryTapped: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)

                    Text("Scan Your Receipt")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Follow these tips for best results")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                // Tips list
                VStack(alignment: .leading, spacing: 20) {
                    TipRow(
                        icon: "light.max",
                        title: "Good Lighting",
                        description: "Ensure the receipt is well-lit and avoid shadows"
                    )

                    TipRow(
                        icon: "square.dashed",
                        title: "Full Receipt",
                        description: "Capture the entire receipt from top to bottom"
                    )

                    TipRow(
                        icon: "camera.metering.center.weighted",
                        title: "Steady Shot",
                        description: "Hold your device steady and wait for auto-capture"
                    )

                    TipRow(
                        icon: "eye",
                        title: "Clear Text",
                        description: "Make sure all text is sharp and readable"
                    )
                }
                .padding(.horizontal)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        onScanTapped()
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        onPhotoLibraryTapped()
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ScanTipsView(
        onScanTapped: {},
        onPhotoLibraryTapped: {},
        onDismiss: {}
    )
}
