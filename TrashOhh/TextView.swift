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

    private var currentImageName: String {
        category?.imageName ?? "垃圾箱蓝"
    }

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
        ZStack {
            LinearGradient(
                colors: [Color.teal.opacity(0.12), Color.cyan.opacity(0.08), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Image(currentImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text("你是什么垃圾?")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.teal)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("垃圾名称")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        TextField("例如：电池 / 苹果核 / 塑料瓶", text: $input)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .submitLabel(.search)
                            .onSubmit(classifyInput)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.teal.opacity(0.2), lineWidth: 1)
                            }

                        HStack(spacing: 12) {
                            Button("开始检测", action: classifyInput)
                                .buttonStyle(.borderedProminent)
                                .tint(.teal)
                                .disabled(!canClassify)

                            Button("清空", action: clear)
                                .buttonStyle(.bordered)
                                .tint(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    HStack(spacing: 10) {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                            .font(.headline)

                        Text(statusText)
                            .font(.body)
                            .foregroundColor(statusColor)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(Color(.systemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(statusColor.opacity(0.25), lineWidth: 1)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("文本识别")
        .navigationBarTitleDisplayMode(.inline)
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
