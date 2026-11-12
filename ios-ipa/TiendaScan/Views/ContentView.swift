import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProductItem.createdAt, order: .reverse) private var items: [ProductItem]

    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var quickScanItem: ProductItem?

    private var filteredItems: [ProductItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.name.lowercased().contains(query)
                || item.barcodeValue.lowercased().contains(query)
                || item.ocrRawText.lowercased().contains(query)
                || item.notes.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyStateView
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    productListView
                }
            }
            .navigationTitle("TiendaScan")
            .searchable(text: $searchText, prompt: "Buscar por nombre o código...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Añadir", systemImage: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !items.isEmpty {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Añadir producto (2 fotos)", systemImage: "camera.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddProductView()
            }
            .fullScreenCover(item: $quickScanItem) { item in
                FullscreenScannerView(
                    productName: item.name,
                    barcodeValue: item.barcodeValue,
                    symbologyName: item.barcodeSymbology,
                    symbologyIdentifier: item.symbologyIdentifier,
                    croppedPhoto: item.barcodeCroppedData.flatMap(UIImage.init(data:)),
                    originalPhoto: item.barcodePhotoData.flatMap(UIImage.init(data:))
                )
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("Tu catálogo de códigos")
                .font(.title2.bold())

            Text("Haz 2 fotos: una al código de barras/QR y otra al producto para reconocer su nombre con OCR. Listo para escanear con lector de tienda.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showAddSheet = true
            } label: {
                Label("Añadir primer producto", systemImage: "camera.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private var productListView: some View {
        List {
            ForEach(filteredItems) { item in
                NavigationLink {
                    ProductDetailView(item: item)
                } label: {
                    ProductRowView(item: item) {
                        quickScanItem = item
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.insetGrouped)
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let itemToDelete = filteredItems[index]
            modelContext.delete(itemToDelete)
        }
        try? modelContext.save()
    }
}

private struct ProductRowView: View {
    let item: ProductItem
    let onQuickScan: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(2)

                if !item.barcodeValue.isEmpty {
                    HStack(spacing: 6) {
                        if !item.barcodeSymbology.isEmpty {
                            Text(item.barcodeSymbology)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.14))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                        Text(item.barcodeValue)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Solo imagen de código")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 4)

            if !item.barcodeValue.isEmpty || item.barcodePhotoData != nil {
                Button {
                    onQuickScan()
                } label: {
                    Image(systemName: "barcode")
                        .font(.title3)
                        .padding(10)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Mostrar código para escáner")
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let data = item.productPhotoData ?? item.barcodePhotoData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 56, height: 56)
                Image(systemName: "shippingbox")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
