import SwiftData
import SwiftUI
import UIKit

struct ProductDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var item: ProductItem

    @State private var selectedMode: BarcodeDisplayMode = .digital
    @State private var showFullscreenScanner = false
    @State private var showFullProductPhoto = false
    @State private var showDeleteAlert = false
    @State private var copied = false

    private var originalBarcodePhoto: UIImage? {
        item.barcodePhotoData.flatMap(UIImage.init(data:))
    }

    private var croppedBarcodePhoto: UIImage? {
        item.barcodeCroppedData.flatMap(UIImage.init(data:))
    }

    private var productPhoto: UIImage? {
        item.productPhotoData.flatMap(UIImage.init(data:))
    }

    private var digitalBarcodeImage: UIImage? {
        BarcodeRenderer.render(
            value: item.barcodeValue,
            symbologyName: item.barcodeSymbology,
            symbologyIdentifier: item.symbologyIdentifier
        )
    }

    private var availableModes: [BarcodeDisplayMode] {
        var modes: [BarcodeDisplayMode] = []
        if digitalBarcodeImage != nil { modes.append(.digital) }
        if croppedBarcodePhoto != nil { modes.append(.cropped) }
        if originalBarcodePhoto != nil { modes.append(.original) }
        return modes
    }

    private var displayedBarcodeImage: UIImage? {
        switch selectedMode {
        case .digital:
            return digitalBarcodeImage ?? croppedBarcodePhoto ?? originalBarcodePhoto
        case .cropped:
            return croppedBarcodePhoto ?? digitalBarcodeImage ?? originalBarcodePhoto
        case .original:
            return originalBarcodePhoto ?? croppedBarcodePhoto ?? digitalBarcodeImage
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                barcodeCard
                productInfoCard
                if !item.ocrRawText.isEmpty {
                    ocrSectionCard
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.name.isEmpty ? "Producto" : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            if let first = availableModes.first {
                selectedMode = first
            }
        }
        .fullScreenCover(isPresented: $showFullscreenScanner) {
            FullscreenScannerView(
                productName: item.name,
                barcodeValue: item.barcodeValue,
                symbologyName: item.barcodeSymbology,
                symbologyIdentifier: item.symbologyIdentifier,
                croppedPhoto: croppedBarcodePhoto,
                originalPhoto: originalBarcodePhoto
            )
        }
        .sheet(isPresented: $showFullProductPhoto) {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if let photo = productPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cerrar") { showFullProductPhoto = false }
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .alert("Eliminar producto", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("¿Seguro que quieres eliminar \"\(item.name)\"?")
        }
    }

    private var barcodeCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Código para Escáner", systemImage: "barcode.viewfinder")
                    .font(.headline)
                Spacer()
                if !item.barcodeSymbology.isEmpty {
                    Text(item.barcodeSymbology)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }

            if availableModes.count > 1 {
                Picker("Vista del código", selection: $selectedMode) {
                    ForEach(availableModes) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button {
                showFullscreenScanner = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)

                    if let img = displayedBarcodeImage {
                        Image(uiImage: img)
                            .interpolation(selectedMode == .digital ? .none : .high)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .padding(14)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "barcode")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Sin imagen disponible")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(32)
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Text(item.barcodeValue.isEmpty ? "Sin número" : item.barcodeValue)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .textSelection(.enabled)

                Spacer()

                if !item.barcodeValue.isEmpty {
                    Button {
                        UIPasteboard.general.string = item.barcodeValue
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copiado" : "Copiar", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                }
            }

            Button {
                showFullscreenScanner = true
            } label: {
                Label("Abrir en Pantalla Completa (Brillo 100%)", systemImage: "sun.max.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var productInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Detalles del Producto")
                .font(.headline)

            if let photo = productPhoto {
                Button {
                    showFullProductPhoto = true
                } label: {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .bottomTrailing) {
                            Label("Ampliar", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .padding(8)
                        }
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Nombre del producto")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("Nombre", text: $item.name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Número / Texto del código")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("Código de barras o QR", text: $item.barcodeValue)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notas (opcional)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("Pasillo, proveedor, precio...", text: $item.notes, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Guardado: \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var ocrSectionCard: some View {
        DisclosureGroup("Texto detectado por OCR en el envase") {
            Text(item.ocrRawText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
