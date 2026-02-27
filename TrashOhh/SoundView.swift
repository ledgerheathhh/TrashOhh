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

class SpeechRecognizer: ObservableObject {
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable

        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }

    @Published var transcript: String = ""

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?

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

    deinit {
        reset()
    }

    func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
    }

    func transcribe() {
        DispatchQueue(label: "Speech Recognizer Queue", qos: .background).async { [weak self] in
            guard let self = self,
                  let recognizer = self.recognizer,
                  recognizer.isAvailable else {
                self?.speakError(RecognizerError.recognizerIsUnavailable)
                return
            }

            do {
                let (audioEngine, request) = try Self.prepareEngine()
                self.audioEngine = audioEngine
                self.request = request

                self.task = recognizer.recognitionTask(with: request) { result, error in
                    let receivedFinalResult = result?.isFinal ?? false
                    let receivedError = error != nil

                    if receivedFinalResult || receivedError {
                        audioEngine.stop()
                        audioEngine.inputNode.removeTap(onBus: 0)
                    }

                    if let result {
                        self.speak(result.bestTranscription.formattedString)
                    }
                }
            } catch {
                self.reset()
                self.speakError(error)
            }
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
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        return (audioEngine, request)
    }

    func stopTranscribing() {
        reset()
    }

    private func speak(_ message: String) {
        transcript = message
    }

    private func speakError(_ error: Error) {
        var errorMessage = ""
        if let error = error as? RecognizerError {
            errorMessage += error.message
        } else {
            errorMessage += error.localizedDescription
        }
        transcript = "<< \(errorMessage) >>"
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

            Text(speechRecognizer.transcript)
                .font(.body)

            Divider()

            if let category {
                Text(category.rawValue)
                    .foregroundColor(category.displayColor)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.orange)
            }

            Button(action: toggleRecording) {
                Text(isRecording ? "停止" : "录入")
                    .font(.title)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(isRecording ? .red : .blue)

            HStack {
                Button("开始检测") {
                    classifyTranscript()
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

    private func toggleRecording() {
        if !isRecording {
            speechRecognizer.transcribe()
        } else {
            speechRecognizer.stopTranscribing()
        }
        isRecording.toggle()
    }

    private func classifyTranscript() {
        let transcript = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
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
        if isRecording {
            speechRecognizer.stopTranscribing()
            isRecording = false
        }
        speechRecognizer.transcript = ""
        category = nil
        errorMessage = nil
    }
}

struct SoundView_Previews: PreviewProvider {
    static var previews: some View {
        SoundView()
    }
}
