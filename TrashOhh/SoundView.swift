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
        !isRecording && !normalizedTranscript.isEmpty && !normalizedTranscript.hasPrefix("<<")
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
        return "录入语音后点击“开始检测”"
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
        RecognitionPageScaffold(headerImageName: currentImageName) {
            RecognitionActionCard(
                title: "识别文本",
                primaryEnabled: canClassify,
                primaryTint: .teal,
                secondaryEnabled: true,
                onPrimaryTap: classifyTranscript,
                onSecondaryTap: clear
            ) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: RecognitionUI.innerCornerRadius, style: .continuous)
                        .fill(Color(.systemBackground))

                    RoundedRectangle(cornerRadius: RecognitionUI.innerCornerRadius, style: .continuous)
                        .stroke(Color.teal.opacity(0.2), lineWidth: 1)

                    Group {
                        if speechRecognizer.transcript.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle")
                                    .font(.system(size: 30, weight: .regular))
                                    .foregroundColor(isRecording ? .red : .teal)

                                Text(isRecording ? "正在录音..." : "点击右下角麦克风开始录音")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                Text(speechRecognizer.transcript)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 12)
                                    .padding(.bottom, 42)
                            }
                        }
                    }

                    Button(action: toggleRecording) {
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(isRecording ? Color.red : Color.teal, in: Circle())
                    }
                    .padding(10)
                }
            }

            RecognitionStatusCard(
                icon: statusIcon,
                text: statusText,
                color: statusColor
            )
        }
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
