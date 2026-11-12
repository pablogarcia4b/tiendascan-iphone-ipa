import PhotosUI
import SwiftData
import SwiftUI
import UIKit

private enum CaptureStep: String, Identifiable {
    case barcode
    case product

    var id: String { rawValue }
}

struct AddProductView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var activeCameraStep: CaptureStep?
    @State private var barcodePickerItem: PhotosPickerItem?
    @State private var productPickerItem: PhotosPickerItem?

    // Paso 1: Código de barras / QR
    @State private var barcodePhoto: UIImage?
    @State private var barcodeCroppedPhoto: UIImage?
    @State private var barcodeValue = ""
    @State private var barcodeSymbology = ""
    @State private var symbologyIdentifier = ""
    @State private var isAnalyzingBarcode = false
    @State private var barcodeStatusMessage: String?
    @State private var barcodeDetectedAutomatically = false

    // Paso 2: Producto & OCR
    @State private var productPhoto: UIImage?
    @State private var productName = ""
    @State private var ocrCandidates: [String] = []
    @State private var ocrRawText = ""
    @State private var isAnalyzingOCR = false

    // Extra
    @State private var notes = ""

    private var canSave: Bool {
        let hasBarcode = !barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || barcodePhoto != nil
        let hasProduct = !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || productPhoto != nil
        return hasBarcode || hasProduct
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    barcodeStepCard
                    productStepCard
                    notesCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Nuevo Producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveProduct()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave || isAnalyzingBarcode || isAnalyzingOCR)
                }
            }
            .sheet(item: $activeCameraStep) { step in
                CameraSheetView { image in
                    switch step {
                    case .barcode:
                        handleBarcodeImage(image)
                    case .product:
                        handleProductImage(image)
                    }
                }
            }
            .onChange(of: barcodePickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let rawImage = UIImage(data: data) {
                        let normalized = rawImage.normalizedAndResized(maxDimension: 2048)
                        await MainActor.run {
                            handleBarcodeImage(normalized)
                        }
                    }
                    await MainActor.run { barcodePickerItem = nil }
                }
            }
            .onChange(of: productPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let rawImage = UIImage(data: data) {
                        let normalized = rawImage.normalizedAndResized(maxDimension: 2048)
                        await MainActor.run {
                            handleProductImage(normalized)
                        }
                    }
                    await MainActor.run { productPickerItem = nil }
                }
            }
        }
    }

    // MARK: - Paso 1 Card

    private var barcodeStepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("1. Código de Barras o QR", systemImage: "barcode.viewfinder")
                    .font(.headline)
                Spacer()
                if barcodeDetectedAutomatically {
                    Label(barcodeSymbology.isEmpty ? "Leído" : barcodeSymbology, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 10) {
                Button {
                    activeCameraStep = .barcode
                } label: {
                    Label(barcodePhoto == nil ? "Hacer foto al código" : "Repetir foto", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                PhotosPicker(selection: $barcodePickerItem, matching: .images) {
                    Label("Galería", systemImage: "photo")
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.bordered)
            }

            if isAnalyzingBarcode {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Leyendo código de barras / QR...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            if let preview = barcodeCroppedPhoto ?? barcodePhoto {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 150)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let msg = barcodeStatusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(barcodeDetectedAutomatically ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Número o contenido del código")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("Ej: 8412345678901", text: $barcodeValue)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Paso 2 Card

    private var productStepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("2. Foto del Producto (OCR)", systemImage: "text.viewfinder")
                    .font(.headline)
                Spacer()
                if productPhoto != nil && !isAnalyzingOCR {
                    Label("Foto lista", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 10) {
                Button {
                    activeCameraStep = .product
                } label: {
                    Label(productPhoto == nil ? "Hacer foto al producto" : "Repetir foto", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)

                PhotosPicker(selection: $productPickerItem, matching: .images) {
                    Label("Galería", systemImage: "photo")
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.bordered)
            }

            if isAnalyzingOCR {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Reconociendo nombre del producto con OCR...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            if let photo = productPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Nombre del producto (detectado por OCR)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("Ej: Leche Entera Hacendado", text: $productName)
                    .textFieldStyle(.roundedBorder)
            }

            if !ocrCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Textos leídos (pulsa para usar como nombre):")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ocrCandidates, id: \.self) { candidate in
                                Button {
                                    productName = candidate
                                } label: {
                                    Text(candidate)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            productName == candidate
                                            ? Color.accentColor
                                            : Color(.tertiarySystemFill)
                                        )
                                        .foregroundStyle(productName == candidate ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notas opcionales")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            TextField("Pasillo, proveedor, precio...", text: $notes)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Processing Logic

    private func handleBarcodeImage(_ image: UIImage) {
        barcodePhoto = image
        barcodeCroppedPhoto = nil
        barcodeStatusMessage = nil
        barcodeDetectedAutomatically = false
        isAnalyzingBarcode = true

        Task {
            let detected = await VisionAnalyzer.detectBarcode(in: image)
            await MainActor.run {
                isAnalyzingBarcode = false
                if let detected {
                    barcodeValue = detected.value
                    barcodeSymbology = detected.symbologyName
                    symbologyIdentifier = detected.symbologyIdentifier
                    barcodeDetectedAutomatically = true
                    barcodeStatusMessage = "Código \(detected.symbologyName) detectado automáticamente."

                    if let cropped = image.croppedFromVisionBox(detected.boundingBox) {
                        barcodeCroppedPhoto = cropped.highContrastBarcodeImage() ?? cropped
                    }
                } else {
                    barcodeDetectedAutomatically = false
                    barcodeStatusMessage = "No se pudo leer automáticamente; la foto se guardará igual y puedes escribir el número."
                }
            }
        }
    }

    private func handleProductImage(_ image: UIImage) {
        productPhoto = image
        isAnalyzingOCR = true

        Task {
            let ocr = await VisionAnalyzer.recognizeProductName(in: image)
            await MainActor.run {
                isAnalyzingOCR = false
                ocrRawText = ocr.rawText
                ocrCandidates = ocr.candidateLines
                if !ocr.suggestedName.isEmpty {
                    productName = ocr.suggestedName
                }
            }
        }
    }

    private func saveProduct() {
        let trimmedName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty
            ? (trimmedCode.isEmpty ? "Producto sin nombre" : "Código \(trimmedCode)")
            : trimmedName

        let newItem = ProductItem(
            name: finalName,
            barcodeValue: trimmedCode,
            barcodeSymbology: barcodeSymbology,
            symbologyIdentifier: symbologyIdentifier,
            ocrRawText: ocrRawText,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            barcodePhotoData: barcodePhoto?.jpegData(compressionQuality: 0.85),
            barcodeCroppedData: barcodeCroppedPhoto?.jpegData(compressionQuality: 0.9),
            productPhotoData: productPhoto?.jpegData(compressionQuality: 0.82)
        )

        modelContext.insert(newItem)
        try? modelContext.save()
        dismiss()
    }
}
