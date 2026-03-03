//
//  SoundView.swift
//  TrashOhh
//
//  Created by Ledger Heath on 2023/2/1.
//

import AVFoundation
import Foundation
import Speech
import SwiftUI

@MainActor
final class SpeechRecognizer: ObservableObject {
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable

        var message: String {
            switch self {
            case .nilRecognizer: return "语音识别器初始化失败"
            case .notAuthorizedToRecognize: return "未获得语音识别权限"
            case .notPermittedToRecord: return "未获得麦克风权限"
            case .recognizerIsUnavailable: return "语音识别服务当前不可用"
            }
        }
    }

    @Published var transcript: String = ""

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    private var activeSessionID = UUID()

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))

        Task(priority: .background) {
            do {
                guard recognizer != nil else {
                    throw RecognizerError.nilRecognizer
                }
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                    throw RecognizerError.notPermittedToRecord
                }
            } catch {
                speakError(error)
            }
        }
    }

    func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        request = nil
        task = nil
    }

    @discardableResult
    func transcribe() -> Bool {
        guard let recognizer = recognizer else {
            speakError(RecognizerError.nilRecognizer)
            return false
        }
        guard recognizer.isAvailable else {
            speakError(RecognizerError.recognizerIsUnavailable)
            return false
        }

        activeSessionID = UUID()
        let sessionID = activeSessionID
        reset()

        do {
            let (audioEngine, request) = try Self.prepareEngine()
            self.audioEngine = audioEngine
            self.request = request

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                let receivedFinalResult = result?.isFinal ?? false
                let receivedError = error != nil

                if receivedFinalResult || receivedError {
                    audioEngine.stop()
                    audioEngine.inputNode.removeTap(onBus: 0)
                }

                if let result {
                    Task { @MainActor in
                        guard self.activeSessionID == sessionID else { return }
                        self.speak(result.bestTranscription.formattedString)
                    }
                }

                if let error {
                    Task { @MainActor in
                        guard self.activeSessionID == sessionID else { return }
                        self.speakError(error)
                    }
                }
            }
            return true
        } catch {
            reset()
            speakError(error)
            return false
        }
    }

    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
            (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            _ = when
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        return (audioEngine, request)
    }

    func stopTranscribing() {
        request?.endAudio()
        audioEngine?.stop()
    }

    func cancelTranscribing() {
        activeSessionID = UUID()
        reset()
    }

    func clearTranscript() {
        transcript = ""
    }

    private func speak(_ message: String) {
        transcript = message
    }

    private func speakError(_ error: Error) {
        if let recognizerError = error as? RecognizerError {
            transcript = "<< \(recognizerError.message) >>"
        } else {
            transcript = "<< \(error.localizedDescription) >>"
        }
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}

struct SoundView: View {
    private let classifier = TrashTextClassifier()

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isRecording = false
    @State private var category: TrashCategory?
    @State private var errorMessage: String?

    private var currentImageName: String {
        category?.imageName ?? "垃圾箱蓝"
    }

    private var normalizedTranscript: String {
        speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canClassify: Bool {
        !normalizedTranscript.isEmpty && !normalizedTranscript.hasPrefix("<<")
    }

    private var statusText: String {
        if let category {
            return "分类结果：\(category.rawValue)"
        }
        if let errorMessage {
            return errorMessage
        }
        if isRecording {
            return "录音中，请说出垃圾名称"
        }
        return "点击录音后再进行检测"
    }

    private var statusColor: Color {
        if category != nil { return .teal }
        if errorMessage != nil { return .orange }
        return isRecording ? .red : .secondary
    }

    private var statusIcon: String {
        if category != nil { return "checkmark.seal.fill" }
        if errorMessage != nil { return "exclamationmark.triangle.fill" }
        return isRecording ? "waveform.circle.fill" : "info.circle.fill"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.12), Color.cyan.opacity(0.1), Color.white],
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
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("识别文本")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(speechRecognizer.transcript.isEmpty ? "尚未录入语音内容" : speechRecognizer.transcript)
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
                            .padding(12)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            }

                        Button(action: toggleRecording) {
                            Label(isRecording ? "停止录音" : "开始录音", systemImage: isRecording ? "stop.circle.fill" : "mic.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isRecording ? .red : .blue)

                        HStack(spacing: 12) {
                            Button("开始检测", action: classifyTranscript)
                                .buttonStyle(.borderedProminent)
                                .tint(.teal)
                                .disabled(!canClassify)

                            Button("清空", action: clear)
                                .buttonStyle(.bordered)
                                .tint(.secondary)
                        }
                    }
                    .padding(16)
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
        .navigationTitle("语音识别")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut, value: category)
        .onChange(of: speechRecognizer.transcript) { _ in
            if category != nil {
                category = nil
            }
            if errorMessage != nil {
                errorMessage = nil
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            speechRecognizer.stopTranscribing()
            isRecording = false
        } else {
            errorMessage = nil
            category = nil
            speechRecognizer.clearTranscript()
            isRecording = speechRecognizer.transcribe()
        }
    }

    private func classifyTranscript() {
        let transcript = normalizedTranscript
        guard !transcript.isEmpty else {
            category = nil
            errorMessage = "请先录入语音内容"
            return
        }

        if transcript.hasPrefix("<<") {
            category = nil
            errorMessage = transcript
            return
        }

        guard let result = classifier.classify(text: transcript) else {
            category = nil
            errorMessage = "暂未识别该垃圾，请重试"
            return
        }

        category = result
        errorMessage = nil
    }

    private func clear() {
        speechRecognizer.cancelTranscribing()
        isRecording = false
        speechRecognizer.clearTranscript()
        category = nil
        errorMessage = nil
    }
}

struct SoundView_Previews: PreviewProvider {
    static var previews: some View {
        SoundView()
    }
}
