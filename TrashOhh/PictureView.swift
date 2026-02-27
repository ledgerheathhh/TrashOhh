//
//  PictureView.swift
//  TrashOhh
//
//  Created by Ledger Heath on 2023/1/13.
//

import CoreML
import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let dismiss: DismissAction
        private let onImagePicked: (UIImage) -> Void

        init(dismiss: DismissAction, onImagePicked: @escaping (UIImage) -> Void) {
            self.dismiss = dismiss
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let uiImage = info[.originalImage] as? UIImage else {
                dismiss()
                return
            }

            onImagePicked(uiImage)
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss, onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

extension UIImage {
    func resize(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return self
        }
        UIGraphicsEndImageContext()

        return resizedImage
    }

    func pixelBuffer() -> CVPixelBuffer? {
        let width = self.size.width
        let height = self.size.height
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(width),
            Int(height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }

        CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        return resultPixelBuffer
    }
}

struct PictureView: View {
    private let model: picture_model = {
        do {
            let config = MLModelConfiguration()
            return try picture_model(configuration: config)
        } catch {
            print(error)
            fatalError("Couldn't create model")
        }
    }()

    @State private var selectedSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var result: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 30) {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image("垃圾")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            Text("你是什么垃圾?")
                .bold()
                .italic()
                .font(.largeTitle)

            if let result {
                Text(result)
                    .foregroundColor(.red)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.orange)
            }

            HStack(spacing: 30) {
                Button("相机") {
                    selectedSourceType = .camera
                    showImagePicker = true
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.mint)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                Button("图库") {
                    selectedSourceType = .photoLibrary
                    showImagePicker = true
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.green)
            }
            .fullScreenCover(isPresented: $showImagePicker) {
                ImagePicker(sourceType: selectedSourceType) { image in
                    selectedImage = image
                    result = nil
                    errorMessage = nil
                }
            }

            HStack(spacing: 30) {
                Button("检测") {
                    detectImage()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.cyan)
                .disabled(selectedImage == nil)

                Button("重置") {
                    selectedImage = nil
                    result = nil
                    errorMessage = nil
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .font(.title)
    }

    private func detectImage() {
        guard let selectedImage else {
            errorMessage = "请先选择图片"
            result = nil
            return
        }

        guard let input = selectedImage.resize(to: CGSize(width: 299, height: 299)).pixelBuffer() else {
            errorMessage = "图片处理失败，请重试"
            result = nil
            return
        }

        guard let output = try? model.prediction(image: input) else {
            errorMessage = "识别失败，请更换图片重试"
            result = nil
            return
        }

        result = output.classLabel
        errorMessage = nil
    }
}

struct PictureView_Previews: PreviewProvider {
    static var previews: some View {
        PictureView()
    }
}
