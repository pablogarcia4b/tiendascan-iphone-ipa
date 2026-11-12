import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                let normalized = image.normalizedAndResized(maxDimension: 2048)
                parent.onImagePicked(normalized)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct CameraSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let onImagePicked: (UIImage) -> Void

    var body: some View {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            CameraPicker(onImagePicked: onImagePicked)
                .ignoresSafeArea()
        } else {
            NavigationStack {
                ContentUnavailableView(
                    "Cámara no disponible",
                    systemImage: "camera.fill",
                    description: Text("Este dispositivo no tiene cámara activa. Usa el botón de Galería para probar con una foto.")
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                }
            }
        }
    }
}
