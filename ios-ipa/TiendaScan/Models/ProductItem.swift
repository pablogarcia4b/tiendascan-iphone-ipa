import Foundation
import SwiftData

@Model
final class ProductItem {
    var itemUUID: UUID
    var name: String
    var barcodeValue: String
    var barcodeSymbology: String
    var symbologyIdentifier: String
    var ocrRawText: String
    var notes: String
    var createdAt: Date

    @Attribute(.externalStorage)
    var barcodePhotoData: Data?

    @Attribute(.externalStorage)
    var barcodeCroppedData: Data?

    @Attribute(.externalStorage)
    var productPhotoData: Data?

    init(
        itemUUID: UUID = UUID(),
        name: String,
        barcodeValue: String,
        barcodeSymbology: String = "",
        symbologyIdentifier: String = "",
        ocrRawText: String = "",
        notes: String = "",
        createdAt: Date = Date(),
        barcodePhotoData: Data? = nil,
        barcodeCroppedData: Data? = nil,
        productPhotoData: Data? = nil
    ) {
        self.itemUUID = itemUUID
        self.name = name
        self.barcodeValue = barcodeValue
        self.barcodeSymbology = barcodeSymbology
        self.symbologyIdentifier = symbologyIdentifier
        self.ocrRawText = ocrRawText
        self.notes = notes
        self.createdAt = createdAt
        self.barcodePhotoData = barcodePhotoData
        self.barcodeCroppedData = barcodeCroppedData
        self.productPhotoData = productPhotoData
    }
}
