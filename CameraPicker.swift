import SwiftUI
import UIKit

/// Камера (UIImagePickerController).
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void

        init(onImage: @escaping (UIImage?) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onImage(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
        }
    }
}

/// Означување правоаголник со прст (нормализирани координати 0…1).
struct CropSelectView: View {
    let image: UIImage
    @Binding var selection: CGRect?

    var body: some View {
        GeometryReader { geo in
            let fit = Self.fittedRect(image: image.size, in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                if let selection {
                    let rect = CGRect(x: fit.minX + selection.minX * fit.width,
                                      y: fit.minY + selection.minY * fit.height,
                                      width: selection.width * fit.width,
                                      height: selection.height * fit.height)
                    Path { path in
                        path.addRect(fit)
                        path.addRect(rect)
                    }
                    .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        let a = Self.normalize(value.startLocation, in: fit)
                        let b = Self.normalize(value.location, in: fit)
                        selection = CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                                           width: abs(a.x - b.x), height: abs(a.y - b.y))
                    }
            )
        }
    }

    static func fittedRect(image: CGSize, in container: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0 else { return CGRect(origin: .zero, size: container) }
        let scale = min(container.width / image.width, container.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    private static func normalize(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: min(max((point.x - rect.minX) / rect.width, 0), 1),
                y: min(max((point.y - rect.minY) / rect.height, 0), 1))
    }
}
