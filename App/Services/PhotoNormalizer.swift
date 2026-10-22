import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoNormalizer {
    enum ImageError: LocalizedError {
        case invalidImage, encodingFailed, imageTooLarge
        var errorDescription: String? {
            switch self {
            case .invalidImage: return "无法读取这张图片，请重新选择 JPG、PNG 或 HEIC 照片。"
            case .encodingFailed: return "图片转换失败，请重新选择照片。"
            case .imageTooLarge: return "图片文件过大，请先裁剪或选择另一张图片。"
            }
        }
    }

    /// Decodes only a thumbnail, bakes orientation, and creates a fresh JPEG.
    /// GPS, EXIF and original filenames are not copied into the saved/uploaded image.
    static func jpeg(data: Data) throws -> Data {
        guard data.count <= 50 * 1_024 * 1_024 else { throw ImageError.imageTooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_600,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw ImageError.invalidImage }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImageError.encodingFailed
        }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: 0.82
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ImageError.encodingFailed }
        return output as Data
    }
}
