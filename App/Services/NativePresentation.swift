#if os(iOS)
import SwiftUI
import UIKit
import AVFoundation

/// Camera permission is requested only after the user explicitly opens this sheet.
struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    var onCancel: () -> Void = {}
    var onError: (Error) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> CameraHostController {
        let controller = CameraHostController()
        let coordinator = context.coordinator
        controller.onAppear = { [weak controller, weak coordinator] in
            guard let controller else { return }
            coordinator?.start(in: controller)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraHostController, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CameraPicker
        private var started = false
        init(_ parent: CameraPicker) { self.parent = parent }

        func start(in host: UIViewController) {
            guard !started else { return }
            started = true
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                parent.onError(CameraError.unavailable)
                return
            }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: presentCamera(in: host)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self, weak host] granted in
                    DispatchQueue.main.async {
                        guard let self, let host, host.viewIfLoaded?.window != nil else { return }
                        if granted { self.presentCamera(in: host) }
                        else { self.presentAccessHelp(in: host) }
                    }
                }
            default: presentAccessHelp(in: host)
            }
        }

        private func presentCamera(in host: UIViewController) {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.delegate = self
            picker.modalPresentationStyle = .fullScreen
            host.present(picker, animated: true)
        }

        private func presentAccessHelp(in host: UIViewController) {
            let alert = UIAlertController(title: "相机访问未开启", message: "可以前往系统设置允许相机访问，或返回后从相册选择照片。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "返回", style: .cancel) { [weak self] _ in self?.parent.onCancel() })
            alert.addAction(UIAlertAction(title: "打开设置", style: .default) { [weak self] _ in
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                self?.parent.onCancel()
            })
            host.present(alert, animated: true)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            do {
                guard let image = info[.originalImage] as? UIImage,
                      let source = image.jpegData(compressionQuality: 0.9) else {
                    throw PhotoNormalizer.ImageError.invalidImage
                }
                parent.onPick(try PhotoNormalizer.jpeg(data: source))
            } catch {
                parent.onError(error)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
            picker.dismiss(animated: true)
        }
    }

    enum CameraError: LocalizedError {
        case unavailable
        var errorDescription: String? { "此设备没有可用相机，请从相册选择照片。" }
    }
}

final class CameraHostController: UIViewController {
    var onAppear: (() -> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onAppear?()
    }
}

struct UISystemShare: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
