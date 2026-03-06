//
//  TextView.swift
//  TrashOhh
//
//  Created by Ledger Heath on 2023/1/14.
//

import CoreML
import SwiftUI

enum TrashCategory: String {
    case recyclable = "可回收物"
    case kitchen = "厨余垃圾"
    case hazardous = "有害垃圾"
    case other = "其他垃圾"

    var imageName: String {
        switch self {
        case .recyclable: return "垃圾箱绿"
        case .kitchen: return "垃圾箱黄"
        case .hazardous: return "垃圾箱红"
        case .other: return "垃圾箱灰"
        }
    }

    var displayColor: Color {
        switch self {
        case .recyclable: return .green
        case .kitchen: return .yellow
        case .hazardous: return .red
        case .other: return .gray
        }
    }
}

final class TrashTextClassifier {
    private let model: text_model

    init() {
        do {
            let config = MLModelConfiguration()
            model = try text_model(configuration: config)
        } catch {
            print(error)
            fatalError("Couldn't create model")
        }
    }

    func classify(text: String) -> TrashCategory? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              let output = try? model.prediction(text: normalized) else {
            return nil
        }

        return TrashCategory(rawValue: output.label)
    }
}

enum RecognitionUI {
    static let actionHeight: CGFloat = 164
    static let cardCornerRadius: CGFloat = 20
    static let innerCornerRadius: CGFloat = 12
}

struct RecognitionPageScaffold<Content: View>: View {
    let headerImageName: String
    let titleText: String
    let content: Content

    init(
        headerImageName: String,
        titleText: String = "你是什么垃圾?",
        @ViewBuilder content: () -> Content
    ) {
        self.headerImageName = headerImageName
        self.titleText = titleText
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.teal.opacity(0.12), Color.cyan.opacity(0.08), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Image(headerImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RecognitionUI.cardCornerRadius, style: .continuous))

                    Text(titleText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.teal)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

                    content
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
        .navigationBarHidden(true)
    }
}

struct RecognitionActionCard<Content: View>: View {
    let title: String
    let primaryTitle: String
    let primaryIcon: String?
    let primaryEnabled: Bool
    let primaryTint: Color
    let secondaryEnabled: Bool
    let isPrimaryLoading: Bool
    let onPrimaryTap: () -> Void
    let onSecondaryTap: () -> Void
    let content: Content

    init(
        title: String,
        primaryTitle: String = "开始检测",
        primaryIcon: String? = nil,
        primaryEnabled: Bool,
        primaryTint: Color = .teal,
        secondaryEnabled: Bool = true,
        isPrimaryLoading: Bool = false,
        onPrimaryTap: @escaping () -> Void,
        onSecondaryTap: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.primaryTitle = primaryTitle
        self.primaryIcon = primaryIcon
        self.primaryEnabled = primaryEnabled
        self.primaryTint = primaryTint
        self.secondaryEnabled = secondaryEnabled
        self.isPrimaryLoading = isPrimaryLoading
        self.onPrimaryTap = onPrimaryTap
        self.onSecondaryTap = onSecondaryTap
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            content
                .frame(height: RecognitionUI.actionHeight, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .clipped()

            HStack(spacing: 12) {
                Button(action: onPrimaryTap) {
                    if isPrimaryLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("识别中...")
                        }
                        .frame(maxWidth: .infinity)
                    } else if let primaryIcon {
                        Label(primaryTitle, systemImage: primaryIcon)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(primaryTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(primaryTint)
                .disabled(!primaryEnabled)

                Button("清空", action: onSecondaryTap)
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .frame(width: 86)
                    .disabled(!secondaryEnabled)
            }
            .frame(height: 44)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RecognitionUI.cardCornerRadius, style: .continuous))
    }
}

struct RecognitionStatusCard: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.headline)

            Text(text)
                .font(.body)
                .foregroundColor(color)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.systemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        }
    }
}

struct TextView: View {
    private let classifier = TrashTextClassifier()

    @State private var input: String = ""
    @State private var category: TrashCategory?
    @State private var errorMessage: String?

    private var normalizedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canClassify: Bool {
        !normalizedInput.isEmpty
    }

    private let headerImageName = "垃圾箱蓝"

    private var statusText: String {
        if let category {
            return "分类结果：\(category.rawValue)"
        }
        if let errorMessage {
            return errorMessage
        }
        return "输入垃圾名称后点击“开始检测”"
    }

    private var statusIcon: String {
        if category != nil { return "checkmark.seal.fill" }
        if errorMessage != nil { return "exclamationmark.triangle.fill" }
        return "info.circle.fill"
    }

    private var statusColor: Color {
        if let category { return category.displayColor }
        if errorMessage != nil { return .orange }
        return .secondary
    }

    var body: some View {
        RecognitionPageScaffold(headerImageName: headerImageName) {
            RecognitionActionCard(
                title: "垃圾名称",
                primaryEnabled: canClassify,
                onPrimaryTap: classifyInput,
                onSecondaryTap: clear
            ) {
                TextField("例如：电池 / 苹果核 / 塑料瓶", text: $input)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit(classifyInput)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: RecognitionUI.innerCornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: RecognitionUI.innerCornerRadius, style: .continuous)
                            .stroke(Color.teal.opacity(0.2), lineWidth: 1)
                    }
            }

            RecognitionStatusCard(
                icon: statusIcon,
                text: statusText,
                color: statusColor
            )
        }
        .animation(.easeInOut, value: category)
        .onChange(of: input) { _ in
            if category != nil || errorMessage != nil {
                category = nil
                errorMessage = nil
            }
        }
    }

    private func classifyInput() {
        guard canClassify else {
            category = nil
            errorMessage = "请输入垃圾名称"
            return
        }

        input = normalizedInput

        guard let result = classifier.classify(text: normalizedInput) else {
            category = nil
            errorMessage = "暂未识别该垃圾，请换个名称重试"
            return
        }

        category = result
        errorMessage = nil
    }

    private func clear() {
        input = ""
        category = nil
        errorMessage = nil
    }
}

struct TextView_Previews: PreviewProvider {
    static var previews: some View {
        TextView()
    }
}
