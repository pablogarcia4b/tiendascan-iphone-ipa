import SwiftUI
import UIKit

enum BarcodeDisplayMode: String, CaseIterable, Identifiable {
    case digital = "Digital"
    case cropped = "Recorte"
    case original = "Foto"

    var id: String { rawValue }
}

struct FullscreenScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let productName: String
    let barcodeValue: String
    let symbologyName: String
    let symbologyIdentifier: String
    let croppedPhoto: UIImage?
    let originalPhoto: UIImage?

    @State private var selectedMode: BarcodeDisplayMode = .digital
    @State private var previousBrightness: CGFloat?
    @State private var copied = false

    private var digitalImage: UIImage? {
        BarcodeRenderer.render(
            value: barcodeValue,
            symbologyName: symbologyName,
            symbologyIdentifier: symbologyIdentifier
        )
    }

    private var availableModes: [BarcodeDisplayMode] {
        var modes: [BarcodeDisplayMode] = []
        if digitalImage != nil { modes.append(.digital) }
        if croppedPhoto != nil { modes.append(.cropped) }
        if originalPhoto != nil { modes.append(.original) }
        return modes
    }

    private var currentImage: UIImage? {
        switch selectedMode {
        case .digital:
            return digitalImage ?? croppedPhoto ?? originalPhoto
        case .cropped:
            return croppedPhoto ?? digitalImage ?? originalPhoto
        case .original:
            return originalPhoto ?? croppedPhoto ?? digitalImage
        }
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(productName.isEmpty ? "Producto" : productName)
                            .font(.headline)
                            .foregroundStyle(.black)
                            .lineLimit(2)

                        if !symbologyName.isEmpty {
                            Text(symbologyName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color(white: 0.25))
                    }
                    .accessibilityLabel("Cerrar pantalla de escáner")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if availableModes.count > 1 {
                    Picker("Modo de visualización", selection: $selectedMode) {
                        ForEach(availableModes) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                }

                Spacer()

                if let image = currentImage {
                    Image(uiImage: image)
                        .interpolation(selectedMode == .digital ? .none : .high)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 360)
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                } else {
                    Text("Sin imagen de código disponible")
                        .foregroundStyle(.gray)
                }

                if !barcodeValue.isEmpty {
                    Button {
                        UIPasteboard.general.string = barcodeValue
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copied = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(barcodeValue)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black)
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundStyle(copied ? .green : .blue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Spacer()

                Label("Brillo al máximo para lector de códigos", systemImage: "sun.max.fill")
                    .font(.caption)
                    .foregroundStyle(Color(white: 0.45))
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            if let first = availableModes.first {
                selectedMode = first
            }
            boostBrightness()
        }
        .onDisappear {
            restoreBrightness()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                boostBrightness()
            } else {
                restoreBrightness()
            }
        }
    }

    private func boostBrightness() {
        guard let screen = ScreenBrightnessHelper.currentScreen() else { return }
        if previousBrightness == nil {
            previousBrightness = screen.brightness
        }
        screen.brightness = 1.0
    }

    private func restoreBrightness() {
        guard let prev = previousBrightness,
              let screen = ScreenBrightnessHelper.currentScreen() else { return }
        screen.brightness = prev
        previousBrightness = nil
    }
}
