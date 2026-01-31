import SwiftUI

struct ScanTipsView: View {
    let onLetsGoTapped: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
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
                .padding(.top, 80)

                VStack(alignment: .leading, spacing: 32) {
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
                .padding(.horizontal, 8)
                .padding(.vertical, 32)
                .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 8)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        onLetsGoTapped()
                    } label: {
                        Label("Understood", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 80)
        }
        .glassEffect(in: Rectangle())
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
        onLetsGoTapped: {}
    )
}
