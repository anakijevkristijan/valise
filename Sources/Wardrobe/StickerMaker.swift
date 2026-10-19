import UIKit
import Vision
import CoreImage

/// Од фотографија → стикер (предметот исечен, со бел раб). Сè се прави на телефонот.
/// Ако на сликата има лице, главата се отсекува; ако лицето и понатаму се гледа — не се прави стикер.
enum StickerMaker {

    enum Outcome {
        case sticker(UIImage)
        case noSubject
        case hasFace
    }

    private static let context = CIContext()

    /// `crop` е нормализиран правоаголник (0…1) во однос на сликата, или nil за цела слика.
    static func make(from source: UIImage, crop: CGRect? = nil) async -> Outcome {
        let prepared = source.normalized(maxSide: 1600)
        return await Task.detached(priority: .userInitiated) { () -> Outcome in
            guard var image = prepared.cgImage else { return .noSubject }

            if let crop {
                let w = CGFloat(image.width)
                let h = CGFloat(image.height)
                let rect = CGRect(x: crop.minX * w, y: crop.minY * h, width: crop.width * w, height: crop.height * h).integral
                if rect.width > 20, rect.height > 20, let cropped = image.cropping(to: rect) {
                    image = cropped
                }
            }

            // Лице → отсечи сè над брадата
            if let face = largestFace(in: image) {
                let h = CGFloat(image.height)
                let w = CGFloat(image.width)
                let chin = (1 - face.minY) * h + face.height * h * 0.18
                guard h - chin > h * 0.3,
                      let below = image.cropping(to: CGRect(x: 0, y: chin, width: w, height: h - chin)) else {
                    return .hasFace
                }
                image = below
            }

            guard let lifted = liftSubject(image) else { return .noSubject }
            if largestFace(in: lifted) != nil { return .hasFace }

            let radius = max(6, CGFloat(max(lifted.width, lifted.height)) * 0.012)
            let finished = addOutline(lifted, radius: radius) ?? lifted
            return .sticker(UIImage(cgImage: finished))
        }.value
    }

    // MARK: Делови

    private static func largestFace(in image: CGImage) -> CGRect? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil else { return nil }
        return (request.results ?? [])
            .map(\.boundingBox)
            .max { $0.width * $0.height < $1.width * $1.height }
    }

    /// Apple „кревање предмет“ (iOS 17): го враќа предметот без позадина.
    private static func liftSubject(_ image: CGImage) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
            let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances,
                                                             from: handler,
                                                             croppedToInstancesExtent: true)
            let masked = CIImage(cvPixelBuffer: buffer)
            return context.createCGImage(masked, from: masked.extent)
        } catch {
            return nil
        }
    }

    /// Бел раб околу предметот — изглед на стикер.
    private static func addOutline(_ image: CGImage, radius: CGFloat) -> CGImage? {
        let pad = radius * 2
        let canvas = CGRect(x: 0, y: 0,
                            width: CGFloat(image.width) + pad * 2,
                            height: CGFloat(image.height) + pad * 2)
        let subject = CIImage(cgImage: image).transformed(by: CGAffineTransform(translationX: pad, y: pad))
        let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: canvas)
        let clear = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: canvas)

        guard let blend = CIFilter(name: "CIBlendWithAlphaMask") else { return nil }
        blend.setValue(white, forKey: kCIInputImageKey)
        blend.setValue(clear, forKey: kCIInputBackgroundImageKey)
        blend.setValue(subject, forKey: kCIInputMaskImageKey)
        guard let silhouette = blend.outputImage else { return nil }

        let border = silhouette
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: canvas)
        return context.createCGImage(subject.composited(over: border), from: canvas)
    }
}

extension UIImage {
    /// Исправена ориентација и намалена големина (секогаш нова слика).
    func normalized(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        let ratio = longest > maxSide ? maxSide / longest : 1
        let target = CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
