import Foundation
import UIKit
import Vision

struct BarcodeDetectionResult: Sendable {
    let value: String
    let symbologyName: String
    let symbologyIdentifier: String
    let boundingBox: CGRect
}

struct OCRDetectionResult: Sendable {
    let suggestedName: String
    let candidateLines: [String]
    let rawText: String
}

enum VisionAnalyzer {
    /// Detecta el código de barras o QR principal en una imagen normalizada (`.up`).
    static func detectBarcode(in image: UIImage) async -> BarcodeDetectionResult? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectBarcodesRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let valid = observations.filter {
                        guard let payload = $0.payloadStringValue else { return false }
                        return !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }

                    let best = valid.max { a, b in
                        let areaA = a.boundingBox.width * a.boundingBox.height
                        let areaB = b.boundingBox.width * b.boundingBox.height
                        return (Double(a.confidence) * Double(areaA)) < (Double(b.confidence) * Double(areaB))
                    }

                    if let best,
                       let value = best.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines) {
                        let result = BarcodeDetectionResult(
                            value: value,
                            symbologyName: friendlySymbologyName(best.symbology),
                            symbologyIdentifier: best.symbology.rawValue,
                            boundingBox: best.boundingBox
                        )
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Extrae texto con OCR (`VNRecognizeTextRequest`) y sugiere el nombre del producto
    /// priorizando las líneas de mayor tamaño visual en el envase o etiqueta.
    static func recognizeProductName(in image: UIImage) async -> OCRDetectionResult {
        guard let cgImage = image.cgImage else {
            return OCRDetectionResult(suggestedName: "", candidateLines: [], rawText: "")
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["es-ES", "en-US"]

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

                do {
                    try handler.perform([request])
                    let observations = request.results ?? []

                    struct LineInfo {
                        let text: String
                        let height: CGFloat
                        let midY: CGFloat
                    }

                    var lines: [LineInfo] = []
                    for obs in observations {
                        guard let candidate = obs.topCandidates(1).first else { continue }
                        let cleaned = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard cleaned.count >= 2 else { continue }
                        lines.append(LineInfo(
                            text: cleaned,
                            height: obs.boundingBox.height,
                            midY: obs.boundingBox.midY
                        ))
                    }

                    let rawText = lines
                        .sorted { $0.midY > $1.midY }
                        .map(\.text)
                        .joined(separator: "\n")

                    let meaningful = lines.filter {
                        $0.text.rangeOfCharacter(from: .letters) != nil
                    }
                    let pool = meaningful.isEmpty ? lines : meaningful
                    let sortedBySize = pool.sorted { $0.height > $1.height }

                    var suggestedName = ""
                    if let maxH = sortedBySize.first?.height {
                        let prominent = pool
                            .filter { $0.height >= maxH * 0.62 }
                            .sorted { $0.midY > $1.midY }
                            .prefix(2)
                            .map(\.text)
                        suggestedName = prominent.joined(separator: " ")
                    }

                    var seen = Set<String>()
                    var candidateLines: [String] = []
                    for item in sortedBySize {
                        let key = item.text.lowercased()
                        if !seen.contains(key) {
                            seen.insert(key)
                            candidateLines.append(item.text)
                        }
                        if candidateLines.count >= 12 { break }
                    }

                    continuation.resume(returning: OCRDetectionResult(
                        suggestedName: suggestedName,
                        candidateLines: candidateLines,
                        rawText: rawText
                    ))
                } catch {
                    continuation.resume(returning: OCRDetectionResult(suggestedName: "", candidateLines: [], rawText: ""))
                }
            }
        }
    }

    private static func friendlySymbologyName(_ symbology: VNBarcodeSymbology) -> String {
        switch symbology {
        case .ean13: return "EAN-13"
        case .ean8: return "EAN-8"
        case .upce: return "UPC-E"
        case .qr: return "Código QR"
        case .code128: return "Code 128"
        case .code39: return "Code 39"
        case .code93: return "Code 93"
        case .itf14: return "ITF-14"
        case .aztec: return "Aztec"
        case .pdf417: return "PDF417"
        case .dataMatrix: return "Data Matrix"
        default:
            return symbology.rawValue
                .replacingOccurrences(of: "VNBarcodeSymbology", with: "")
        }
    }
}
