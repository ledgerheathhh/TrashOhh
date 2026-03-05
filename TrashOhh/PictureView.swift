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
            UIGraphicsEndImageContext()
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
            CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
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
    @State private var showSourceSelector = false
    @State private var selectedImage: UIImage?
    @State private var result: String?
    @State private var errorMessage: String?
    @State private var isDetecting = false

    private var headerImageName: String {
        if let result, let category = TrashCategory(rawValue: result) {
            return category.imageName
        }
        return "垃圾箱蓝"
    }

    private var statusText: String {
        if let result {
            return "识别结果：\(result)"
        }
        if let errorMessage {
            return errorMessage
        }
        return "选择图片后点击“开始检测”"
    }

    private var statusIcon: String {
        if result != nil { return "checkmark.seal.fill" }
        if errorMessage != nil { return "exclamationmark.triangle.fill" }
        return "info.circle.fill"
    }

    private var statusColor: Color {
        if result != nil { return .teal }
        if errorMessage != nil { return .orange }
        return .secondary
    }

    private var canDetect: Bool {
        selectedImage != nil && !isDetecting
    }

    var body: some View {
        RecognitionPageScaffold(headerImageName: headerImageName) {
            RecognitionActionCard(
                title: "待识别图片",
                primaryIcon: "sparkles",
                primaryEnabled: canDetect,
                primaryTint: .teal,
                secondaryEnabled: !isDetecting,
                isPrimaryLoading: isDetecting,
                onPrimaryTap: detectImage,
                onSecondaryTap: clear
            ) {
                Button {
                    showSourceSelector = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))

                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(.teal)

                                Text("点击选择图片")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }

                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
                            .foregroundColor(Color.teal.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: RecognitionUI.actionHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isDetecting)
            }

            RecognitionStatusCard(
                icon: statusIcon,
                text: statusText,
                color: statusColor
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: selectedSourceType) { image in
                selectedImage = image
                result = nil
                errorMessage = nil
            }
        }
        .confirmationDialog("选择图片来源", isPresented: $showSourceSelector, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("拍照") {
                    selectedSourceType = .camera
                    showImagePicker = true
                }
            }

            Button("从相册选择") {
                selectedSourceType = .photoLibrary
                showImagePicker = true
            }

            Button("取消", role: .cancel) {}
        }
    }

    private func clear() {
        selectedImage = nil
        result = nil
        errorMessage = nil
    }

    private func detectImage() {
        guard let selectedImage else {
            errorMessage = "请先选择图片"
            result = nil
            return
        }

        isDetecting = true
        errorMessage = nil
        result = nil

        let model = self.model
        DispatchQueue.global(qos: .userInitiated).async {
            guard let input = selectedImage.resize(to: CGSize(width: 299, height: 299)).pixelBuffer() else {
                DispatchQueue.main.async {
                    isDetecting = false
                    errorMessage = "图片处理失败，请重试"
                    result = nil
                }
                return
            }

            guard let output = try? model.prediction(image: input) else {
                DispatchQueue.main.async {
                    isDetecting = false
                    errorMessage = "识别失败，请更换图片重试"
                    result = nil
                }
                return
            }

            DispatchQueue.main.async {
                isDetecting = false
                result = output.classLabel
                errorMessage = nil
            }
        }
    }
}

struct PictureView_Previews: PreviewProvider {
    static var previews: some View {
        PictureView()
    }
}
