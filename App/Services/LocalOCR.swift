import Foundation
import Vision
import ImageIO

enum LocalOCR {
    /// Apple Vision runs on-device; this operation never sends images to a model API.
    static func recognize(_ imageData: Data) async throws -> String {
        let recognition = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2_400
                  ] as CFDictionary) else { throw PhotoNormalizer.ImageError.invalidImage }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            try Task.checkCancellation()
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }
        return try await withTaskCancellationHandler {
            try await recognition.value
        } onCancel: {
            recognition.cancel()
        }
    }
}
