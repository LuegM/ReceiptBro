import SwiftUI

struct EmptyStateView: View {
    var onTakePhotoTapped: () -> Void = {}
    var onFromLibraryTapped: () -> Void = {}

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("No Receipts Yet")
                    .font(.title2)
                    .fontDesign(.rounded)
            } icon: {
                Image(systemName: "receipt.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
                    .foregroundStyle(.gray.gradient.opacity(0.5))
                    .overlay {
                      // Background stroke for contrast
                      RoundedRectangle(cornerRadius: 8)
                          .stroke(Color(.systemBackground), lineWidth: 6)
                          .frame(width: 130, height: 6)
                          .rotationEffect(.degrees(-45))

                      // Main slash
                        RoundedRectangle(cornerRadius: 8)
                          .fill(.gray.opacity(0.7))
                          .frame(width: 130, height: 4)
                          .rotationEffect(.degrees(-45))
                  }
                    .padding(.bottom, 16)
            }
        } description: {
            Text("\nScan your first receipt to get started.\nWe'll digitize it automatically using **onDevice** AI.\n")
        } actions: {
            Menu {
                Button {
                    onFromLibraryTapped()
                } label: {
                    Label("From Library", systemImage: "photo.on.rectangle")
                }
                Button {
                    onTakePhotoTapped()
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                }
            } label: {
                Label("Add Receipt", systemImage: "document.badge.plus.fill")
                    .font(.headline)
                    .fontDesign(.rounded)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(.glassProminent)
        }
    }
}

#Preview {
    EmptyStateView()
}
