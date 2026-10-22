import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Run with scripts/test-native.sh, never as an app target. No API or Keychain access.
@main
struct NativeSmoke {
    @MainActor static func main() async throws {
        #if !NATIVE_SERVICE_SMOKE_TEST
        fatalError("Compile with NATIVE_SERVICE_SMOKE_TEST to isolate test storage.")
        #else
        let fixtureURL = LocalFiles.directory
        let temporaryRoot = FileManager.default.temporaryDirectory.standardizedFileURL
        guard fixtureURL.deletingLastPathComponent().standardizedFileURL == temporaryRoot,
              fixtureURL.lastPathComponent.hasPrefix("kaii-native-smoke-"),
              UUID(uuidString: String(fixtureURL.lastPathComponent.dropFirst("kaii-native-smoke-".count))) != nil else {
            fatalError("Refusing to use nonisolated storage for smoke tests.")
        }
        defer {
            // The exact UUID directory above was generated exclusively for this test process.
            if FileManager.default.fileExists(atPath: fixtureURL.path) {
                do { try FileManager.default.removeItem(at: fixtureURL) }
                catch { print("Test fixtures retained at \(fixtureURL.path): \(error.localizedDescription)") }
            }
        }

        let image = NSImage(size: NSSize(width: 2200, height: 1200))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2200, height: 1200)).fill()
        ("PROTEIN 20g" as NSString).draw(at: NSPoint(x: 100, y: 600), withAttributes: [
            .font: NSFont.systemFont(ofSize: 90), .foregroundColor: NSColor.black
        ])
        image.unlockFocus()
        var rect = NSRect(origin: .zero, size: image.size)
        let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
        let original = NSMutableData()
        let destination = CGImageDestinationCreateWithData(original, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, cgImage, [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 40.0, kCGImagePropertyGPSLongitude: 116.0],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "SECRET TEST METADATA"]
        ] as CFDictionary)
        precondition(CGImageDestinationFinalize(destination))
        let normalized = try PhotoNormalizer.jpeg(data: original as Data)
        let decoded = CGImageSourceCreateWithData(normalized as CFData, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(decoded, 0, nil)! as NSDictionary
        precondition((properties[kCGImagePropertyPixelWidth] as! Int) <= 1600)
        precondition((properties[kCGImagePropertyPixelHeight] as! Int) <= 1600)
        precondition(properties[kCGImagePropertyGPSDictionary] == nil)
        let exif = properties[kCGImagePropertyExifDictionary] as? NSDictionary
        precondition(exif?[kCGImagePropertyExifUserComment] == nil)
        print("PASS image resize and metadata removal")
        do { _ = try PhotoNormalizer.jpeg(data: Data("not an image".utf8)); fatalError("invalid image accepted") }
        catch { print("PASS malformed image rejected") }
        let recognized = try await LocalOCR.recognize(normalized)
        precondition(recognized.uppercased().contains("PROTEIN"), recognized)
        print("PASS on-device OCR")

        struct Entry: Codable, Equatable { let value: String }
        let filename = "smoke.json"
        let url = fixtureURL.appendingPathComponent(filename)
        try LocalFiles.save(Entry(value: "牛奶"), filename: filename)
        let loaded = try LocalFiles.load(Entry.self, filename: filename)
        precondition(loaded == Entry(value: "牛奶"))
        print("PASS local JSON roundtrip")
        let malformed = Data("broken-json".utf8)
        try malformed.write(to: url)
        do { _ = try LocalFiles.load(Entry.self, filename: filename); fatalError("corruption hidden") }
        catch {}
        let preserved = try Data(contentsOf: url)
        precondition(preserved == malformed)
        print("PASS corruption surfaced and preserved")
        do { _ = try LocalFiles.load(Entry.self, filename: "../escape.json"); fatalError("traversal accepted") }
        catch { print("PASS path traversal rejected") }
        let photo = try LocalFiles.savePhoto(normalized)
        precondition(LocalFiles.photo(photo) != nil)
        try LocalFiles.removePhoto(photo)
        precondition(LocalFiles.photo(photo) == nil)
        print("PASS local photo roundtrip and scoped removal")
        try runPrivateProviderSetupChecks()
        #endif
    }
}
