import CoreImage
import UIKit

extension UIImage {
    /// Normaliza la orientación EXIF a `.up` y reduce fotos enormes (p. ej. 48 MP del iPhone 17 Pro)
    /// para que Vision, el recorte de código y el almacenamiento sean rápidos y consistentes.
    func normalizedAndResized(maxDimension: CGFloat = 2048) -> UIImage {
        let currentMax = max(size.width, size.height)
        guard currentMax > 0 else { return self }
        let scaleFactor = currentMax > maxDimension ? (maxDimension / currentMax) : 1.0
        let targetSize = CGSize(
            width: max(1, floor(size.width * scaleFactor)),
            height: max(1, floor(size.height * scaleFactor))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Recorta una imagen normalizada (`.up`) usando el `boundingBox` normalizado de Vision (origen abajo-izquierda).
    func croppedFromVisionBox(_ boundingBox: CGRect, paddingRatio: CGFloat = 0.16) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let rawRect = CGRect(
            x: boundingBox.minX * width,
            y: (1.0 - boundingBox.maxY) * height,
            width: boundingBox.width * width,
            height: boundingBox.height * height
        )

        let padX = rawRect.width * paddingRatio
        let padY = rawRect.height * paddingRatio
        let paddedRect = rawRect
            .insetBy(dx: -padX, dy: -padY)
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))

        guard !paddedRect.isEmpty, let croppedCG = cgImage.cropping(to: paddedRect) else {
            return nil
        }
        return UIImage(cgImage: croppedCG, scale: 1.0, orientation: .up)
    }

    /// Genera una versión en escala de grises y alto contraste para mejorar la lectura con pistola láser.
    func highContrastBarcodeImage() -> UIImage? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let context = CIContext()

        guard let colorControls = CIFilter(name: "CIColorControls") else { return nil }
        colorControls.setValue(ciImage, forKey: kCIInputImageKey)
        colorControls.setValue(0.0, forKey: kCIInputSaturationKey)
        colorControls.setValue(1.85, forKey: kCIInputContrastKey)
        colorControls.setValue(0.08, forKey: kCIInputBrightnessKey)

        guard let output = colorControls.outputImage,
              let cgOut = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgOut, scale: 1.0, orientation: .up)
    }
}

@MainActor
enum ScreenBrightnessHelper {
    static func currentScreen() -> UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
    }
}
