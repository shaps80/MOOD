#if canImport(ImageIO)
import CoreGraphics
import Foundation
import ImageIO
import PixlPlatform

enum PNGDecoder {
    static func decode(
        _ bytes: [UInt8],
        path: AssetPath
    ) throws(AssetError) -> DecodedTexture {
        guard path.value.lowercased().hasSuffix(".png") else {
            throw .unsupportedTexture(path.value)
        }

        let data = Data(bytes)
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            nil
        ),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
        image.width > 0,
        image.height > 0
        else {
            throw .invalidTexture(path.value)
        }

        let width = image.width
        let height = image.height
        guard width <= Int(UInt32.max) / 4 else {
            throw .invalidTexture(path.value)
        }
        let bytesPerRow = width * 4
        guard height <= Int.max / bytesPerRow else {
            throw .invalidTexture(path.value)
        }
        var pixels = [UInt8](
            repeating: 0,
            count: bytesPerRow * height
        )
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue

        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }

            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
            return true
        }

        guard rendered else {
            throw .invalidTexture(path.value)
        }
        return DecodedTexture(
            width: width,
            height: height,
            bytes: pixels
        )
    }
}
#else
import PixlPlatform
import Swift

enum PNGDecoder {
    static func decode(
        _ bytes: [UInt8],
        path: AssetPath
    ) throws(AssetError) -> DecodedTexture {
        throw .unsupportedTexture(path.value)
    }
}
#endif
