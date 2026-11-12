# TiendaScan (iOS / iPhone)

Aplicación sencilla para tienda en iPhone diseñada en **Swift + SwiftUI** con almacenamiento offline (**SwiftData**) y visión artificial nativa (**Apple Vision** + **CoreImage**).

## Funciones incluidas

1. **Captura con 2 fotos desde cámara (o galería):**
   - **Foto 1 (Código de barras / QR):** Detecta el número o contenido automáticamente con `VNDetectBarcodesRequest`, recorta el código en alto contraste y guarda tanto el número como la imagen original y recortada.
   - **Foto 2 (Producto + OCR):** Extrae el texto del envase/etiqueta con `VNRecognizeTextRequest` (español e inglés), sugiere el nombre más grande como título del producto y ofrece botones rápidos con el resto de textos detectados.
2. **Catálogo local sin conexión:**
   - Guarda múltiples productos en el iPhone usando `SwiftData`.
   - Buscador instantáneo por nombre del producto, número de código o texto detectado.
3. **Modo Escáner para lector físico de tienda:**
   - Al abrir un código en pantalla completa, sube el brillo de la pantalla al **100%** automáticamente (y restaura el brillo anterior al cerrar).
   - Permite alternar entre el **código digital regenerado en alta definición** (EAN-13, EAN-8, Code 128, QR, Aztec, PDF417), el **recorte en alto contraste** y la **foto original**.

## Compilar el `.ipa` con GitHub Actions

Al estar en Windows, la compilación de `.ipa` requiere macOS (`xcodebuild`). El repositorio incluye el flujo `.github/workflows/build-ipa.yml` que genera el proyecto con `xcodegen` en `macos-latest` y produce `TiendaScan.ipa` listo para instalar (por ejemplo, mediante AltStore, SideStore o Sideloadly).

### Subida y compilación automática desde Windows

1. Crea un *Personal Access Token* en GitHub con permisos `repo` y `workflow`.
2. Ejecuta en PowerShell dentro de esta carpeta:
   ```powershell
   .\subir-y-compilar.ps1
   ```
3. Al finalizar, encontrarás el archivo `TiendaScan.ipa` en esta misma carpeta.
