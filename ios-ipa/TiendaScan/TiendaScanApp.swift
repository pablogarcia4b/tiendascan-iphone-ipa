import SwiftData
import SwiftUI

@main
struct TiendaScanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: ProductItem.self)
    }
}
