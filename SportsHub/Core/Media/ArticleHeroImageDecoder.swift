import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

// The decoder constructs this immutable UIImage once; callers only read it on MainActor.
struct ArticleHeroDisplayImage: @unchecked Sendable {
    let image: UIImage
}

actor ArticleHeroImageDecoder {
    static let shared = ArticleHeroImageDecoder()

    func decode<Media: EditorialImageMediaPayload>(
        _ data: Data,
        media: Media,
        maximumPixelSize: Int
    ) -> ArticleHeroDisplayImage? {
        guard !Task.isCancelled, maximumPixelSize > 0 else { return nil }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              let sourceType = CGImageSourceGetType(source),
              let expectedType = UTType(mimeType: media.contentType.rawValue),
              (sourceType as String) == expectedType.identifier,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              (width == media.width && height == media.height)
                || (width == media.height && height == media.width) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            return nil
        }
        return ArticleHeroDisplayImage(image: UIImage(cgImage: thumbnail))
    }
}

typealias VideoPosterDisplayImage = ArticleHeroDisplayImage
typealias VideoPosterImageDecoder = ArticleHeroImageDecoder
