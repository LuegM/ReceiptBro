import SwiftUI
import VisionKit
import OSLog

struct ScanView: View {
    @Environment(\.dismiss) var dismiss

    @AppStorage("hasSeenTipps") var hasSeenTipps: Bool = false

    let onImageCaptured: (UIImage) -> Void

    var body: some View {
        DocumentCameraView(
            onImageCaptured: { image in
                onImageCaptured(image)
            },
            onCancel: {
                dismiss()
            }
        )
        .interactiveDismissDisabled()
        .ignoresSafeArea()
        .if(!hasSeenTipps) { view in
            view.overlay {
                ScanTipsView(onLetsGoTapped: {
                    hasSeenTipps = true
                    }
                )
                .ignoresSafeArea()
            }
        }
    }
}

/// VNDocumentCameraViewController wrapper
struct DocumentCameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let onImageCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        Logger.scanning.info("Document camera initialized")
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, onCancel: onCancel)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImageCaptured: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImageCaptured = onImageCaptured
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            Logger.scanning.info("Document camera scan completed with \(scan.pageCount) page(s)")

            guard scan.pageCount > 0 else {
                Logger.scanning.warning("No pages in scan")
                onCancel()
                return
            }

            let image = scan.imageOfPage(at: 0)
            Logger.scanning.info("Captured image size: \(image.size.width)x\(image.size.height)")

            onImageCaptured(image)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            Logger.scanning.info("Document camera cancelled by user")
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            Logger.scanning.error("Document camera failed: \(error.localizedDescription)")
            onCancel()
        }
    }
}
