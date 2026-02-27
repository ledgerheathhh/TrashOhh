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

    private var currentImageName: String {
        category?.imageName ?? "垃圾箱蓝"
    }

    var body: some View {
        VStack(spacing: 30) {
            Image(currentImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)

            Text("你是什么垃圾?")
                .bold()
                .italic()
                .font(.largeTitle)
                .foregroundColor(.cyan)

            Divider()

            TextField("请输入要识别的垃圾名称", text: $input)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            Divider()

            if let category {
                Text(category.rawValue)
                    .foregroundColor(category.displayColor)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.orange)
            }

            HStack {
                Button("开始检测") {
                    classifyInput()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.cyan)

                Button("清除搜索") {
                    clear()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.teal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .font(.title)
        .animation(.easeInOut, value: category)
    }

    private func classifyInput() {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            category = nil
            errorMessage = "请输入垃圾名称"
            return
        }

        input = normalized

        guard let result = classifier.classify(text: normalized) else {
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
