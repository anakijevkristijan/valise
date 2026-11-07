import UIKit
import Vision
import CoreImage

/// Од фотографија → стикер (предметот исечен, со бел раб). Сè се прави на телефонот.
/// Ако на сликата има лице, главата се отсекува; ако лицето и понатаму се гледа - не се прави стикер.
enum StickerMaker {

    enum Outcome {
        case sticker(UIImage)
        case noSubject
        case hasFace
    }

    /// Стикер = само предметот без позадина. Слика = исечениот дел со позадината, во бела рамка.
    enum Style { case sticker, photo }

    private static let context = CIContext()

    /// `crop` е нормализиран правоаголник (0…1) во однос на сликата, или nil за цела слика.
    static func make(from source: UIImage, crop: CGRect? = nil, style: Style = .sticker) async -> Outcome {
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

            if style == .photo {
                // Исечена слика: лице никако не смее да остане.
                if largestFace(in: image) != nil { return .hasFace }
                return .sticker(framedPhoto(image))
            }

            // Без рачно означување: само главниот предмет (најголем и најблиску до средината; кај обувки - двете)
            guard let lifted = liftSubject(image, mainOnly: crop == nil) else { return .noSubject }
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
    /// `mainOnly` - од повеќе предмети на сликата (перница, закачалка…) само главниот.
    private static func liftSubject(_ image: CGImage, mainOnly: Bool) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
            let instances = mainOnly ? mainInstances(observation) : observation.allInstances
            let buffer = try observation.generateMaskedImage(ofInstances: instances,
                                                             from: handler,
                                                             croppedToInstancesExtent: true)
            let masked = CIImage(cvPixelBuffer: buffer)
            return context.createCGImage(masked, from: masked.extent)
        } catch {
            return nil
        }
    }

    /// Главниот предмет: најголем и најблиску до средината на сликата.
    /// Друг предмет што е речиси ист по големина (втората обувка од парот) исто така се зема.
    private static func mainInstances(_ observation: VNInstanceMaskObservation) -> IndexSet {
        let all = observation.allInstances
        guard all.count > 1 else { return all }
        let mask = observation.instanceMask
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return all }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        guard width > 0, height > 0 else { return all }

        // Секој пиксел од предметот носи поени - повеќе ако е поблиску до средината
        var score = [Double](repeating: 0, count: 256)
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        let cx = Double(width) / 2, cy = Double(height) / 2
        let reach = (cx * cx + cy * cy).squareRoot()
        for y in stride(from: 0, to: height, by: 2) {
            let row = pixels + y * rowBytes
            let dy = Double(y) - cy
            for x in stride(from: 0, to: width, by: 2) {
                let label = Int(row[x])
                guard label != 0 else { continue }
                let dx = Double(x) - cx
                let closeness = 1 - min(1, (dx * dx + dy * dy).squareRoot() / reach)
                score[label] += 0.35 + closeness
            }
        }
        guard let best = all.max(by: { score[$0] < score[$1] }), score[best] > 0 else { return all }
        let kept = all.filter { score[$0] >= score[best] * 0.6 }
        return IndexSet(kept)
    }

    /// Исечената слика во бела рамка со заоблени агли (како полароид).
    private static func framedPhoto(_ image: CGImage) -> UIImage {
        let source = UIImage(cgImage: image)
        let longest = max(source.size.width, source.size.height)
        let scale = longest > 1000 ? 1000 / longest : 1
        let inner = CGSize(width: (source.size.width * scale).rounded(), height: (source.size.height * scale).rounded())
        let border = max(inner.width, inner.height) * 0.035
        let size = CGSize(width: inner.width + border * 2, height: inner.height + border * 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: border * 1.6).fill()
            let rect = CGRect(x: border, y: border, width: inner.width, height: inner.height)
            UIBezierPath(roundedRect: rect, cornerRadius: border * 0.9).addClip()
            source.draw(in: rect)
        }
    }

    /// Бел раб околу предметот - изглед на стикер.
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
