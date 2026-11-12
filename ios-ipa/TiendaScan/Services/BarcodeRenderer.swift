import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum BarcodeRenderer {
    private static let context = CIContext()

    static func is2DCode(symbologyName: String, symbologyIdentifier: String) -> Bool {
        let combined = (symbologyName + " " + symbologyIdentifier).lowercased()
        return combined.contains("qr") || combined.contains("aztec") || combined.contains("datamatrix")
    }

    /// Genera una imagen vectorial/pixel-perfect en blanco y negro puro para leer con escáneres físicos.
    static func render(
        value: String,
        symbologyName: String,
        symbologyIdentifier: String
    ) -> UIImage? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let idLower = (symbologyName + " " + symbologyIdentifier).lowercased()

        if idLower.contains("qr") {
            return renderQR(trimmed)
        }
        if idLower.contains("aztec") {
            return renderAztec(trimmed)
        }
        if idLower.contains("pdf417") {
            return renderPDF417(trimmed)
        }
        if let ean13 = renderEAN13IfValid(trimmed) {
            return ean13
        }
        if idLower.contains("ean8") || idLower.contains("ean-8"),
           let ean8 = renderEAN8IfValid(trimmed) {
            return ean8
        }
        if trimmed.count == 8, let ean8 = renderEAN8IfValid(trimmed) {
            return ean8
        }

        return renderCode128(trimmed)
    }

    // MARK: - CoreImage 2D & Code128

    private static func renderQR(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        return crispImage(from: output, targetSize: CGSize(width: 720, height: 720))
    }

    private static func renderAztec(_ text: String) -> UIImage? {
        let filter = CIFilter.aztecCodeGenerator()
        filter.message = Data(text.utf8)
        guard let output = filter.outputImage else { return nil }
        return crispImage(from: output, targetSize: CGSize(width: 720, height: 720))
    }

    private static func renderPDF417(_ text: String) -> UIImage? {
        let filter = CIFilter.pdf417BarcodeGenerator()
        filter.message = Data(text.utf8)
        guard let output = filter.outputImage else { return nil }
        return crispImage(from: output, targetSize: CGSize(width: 900, height: 340))
    }

    private static func renderCode128(_ text: String) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = text.data(using: .ascii) ?? Data(text.utf8)
        filter.quietSpace = 10
        filter.barcodeHeight = 90
        guard let output = filter.outputImage else { return nil }
        return crispImage(from: output, targetSize: CGSize(width: 960, height: 340))
    }

    private static func crispImage(from ciImage: CIImage, targetSize: CGSize) -> UIImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true

        let margin: CGFloat = 24
        let availableWidth = max(1, targetSize.width - margin * 2)
        let availableHeight = max(1, targetSize.height - margin * 2)

        let srcWidth = CGFloat(cgImage.width)
        let srcHeight = CGFloat(cgImage.height)
        let scale = min(availableWidth / max(1, srcWidth), availableHeight / max(1, srcHeight))
        let fittedWidth = srcWidth * scale
        let fittedHeight = srcHeight * scale
        let drawRect = CGRect(
            x: (targetSize.width - fittedWidth) / 2.0,
            y: (targetSize.height - fittedHeight) / 2.0,
            width: fittedWidth,
            height: fittedHeight
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))

            let cgCtx = ctx.cgContext
            cgCtx.interpolationQuality = .none
            cgCtx.setShouldAntialias(false)

            UIImage(cgImage: cgImage).draw(in: drawRect)
        }
    }

    // MARK: - Pure Swift EAN-13 & EAN-8 (ISO/IEC 15420)

    private static let lCodes = [
        "0001101", "0011001", "0010011", "0111101", "0100011",
        "0110001", "0101111", "0111011", "0110111", "0001011"
    ]
    private static let gCodes = [
        "0100111", "0110011", "0011011", "0100001", "0011101",
        "0111001", "0000101", "0010001", "0001001", "0010111"
    ]
    private static let rCodes = [
        "1110010", "1100110", "1101100", "1000010", "1011100",
        "1001110", "1010000", "1000100", "1001000", "1110100"
    ]
    private static let ean13Parity = [
        "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
        "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"
    ]

    private static func digits(from text: String) -> [Int]? {
        let chars = Array(text)
        var result: [Int] = []
        result.reserveCapacity(chars.count)
        for ch in chars {
            guard let val = ch.wholeNumberValue, ch.isASCII else { return nil }
            result.append(val)
        }
        return result
    }

    private static func renderEAN13IfValid(_ text: String) -> UIImage? {
        guard text.count == 13, let d = digits(from: text) else { return nil }
        let sum = (0..<12).reduce(0) { acc, i in
            acc + d[i] * (i % 2 == 0 ? 1 : 3)
        }
        let expectedCheck = (10 - (sum % 10)) % 10
        guard d[12] == expectedCheck else { return nil }

        let pattern = Array(ean13Parity[d[0]])
        var bits = "101"
        for i in 1...6 {
            bits += (pattern[i - 1] == "L") ? lCodes[d[i]] : gCodes[d[i]]
        }
        bits += "01010"
        for i in 7...12 {
            bits += rCodes[d[i]]
        }
        bits += "101"

        return draw1DBitString(bits)
    }

    private static func renderEAN8IfValid(_ text: String) -> UIImage? {
        guard text.count == 8, let d = digits(from: text) else { return nil }
        let sum = (0..<7).reduce(0) { acc, i in
            acc + d[i] * (i % 2 == 0 ? 3 : 1)
        }
        let expectedCheck = (10 - (sum % 10)) % 10
        guard d[7] == expectedCheck else { return nil }

        var bits = "101"
        for i in 0...3 {
            bits += lCodes[d[i]]
        }
        bits += "01010"
        for i in 4...7 {
            bits += rCodes[d[i]]
        }
        bits += "101"

        return draw1DBitString(bits)
    }

    private static func draw1DBitString(_ bits: String) -> UIImage {
        let quietModules = 11
        let moduleWidth: CGFloat = 8
        let totalModules = bits.count + quietModules * 2
        let width = CGFloat(totalModules) * moduleWidth
        let height: CGFloat = 340
        let topMargin: CGFloat = 24
        let barHeight = height - topMargin * 2

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            let cgCtx = ctx.cgContext
            cgCtx.setShouldAntialias(false)
            UIColor.black.setFill()

            for (index, ch) in bits.enumerated() where ch == "1" {
                let x = CGFloat(quietModules + index) * moduleWidth
                cgCtx.fill(CGRect(x: x, y: topMargin, width: moduleWidth, height: barHeight))
            }
        }
    }
}
