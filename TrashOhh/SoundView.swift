//
//  SoundView.swift
//  TrashOhh
//
//  Created by Ledger Heath on 2023/2/1.
//

import Foundation
import Speech
import AVFoundation
import SwiftUI
import CoreML


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
            guard let self = self, let recognizer = self.recognizer, recognizer.isAvailable else {
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
                    
                    if let result = result {
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
    @StateObject var speechRecognizer = SpeechRecognizer()
    @State private var isRecording = false
    @State private var input:String = ""
    @State private var a:Int? = -1
    //let model = text_model()
    let model: text_model = {
    do {
        let config = MLModelConfiguration()
        return try text_model(configuration: config)
    } catch {
        print(error)
        fatalError("Couldn't create model")
    }
    }()
    @State var img = "垃圾箱蓝"

    var body: some View {
        VStack(spacing: 30){
            Image(img)
                .resizable()
                .aspectRatio(contentMode: .fit)
            Text(" 你是什么垃圾?").bold().italic().font(.largeTitle)
                .foregroundColor(.cyan)
            Text(speechRecognizer.transcript)
            Divider()
            if a == 0{
                Text("可回收物").foregroundColor(.green)
            }else if a == 1{
                Text("厨余垃圾").foregroundColor(.yellow)
            }else if a == 2{
                Text("有害垃圾").foregroundColor(.red)
            }else if a == 3{
                Text("其他垃圾").foregroundColor(.gray)
            }else {
                //Text("")
            }
            Button(action: {
                if !isRecording {
                    speechRecognizer.transcribe()
                } else {
                    speechRecognizer.stopTranscribing()
                }
                input = speechRecognizer.transcript
                isRecording.toggle()
            }) {
                Text(isRecording ? "停止" : "录入")
                    .font(.title)
            }.buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                //.foregroundColor(.white)
                .tint(isRecording ? Color.red : Color.blue)
            HStack{
                Button("开始检测   "){
                    let Output = try? model.prediction(text: input)
                    let result = Output!.label
                    if input != ""{
                        if result == "可回收物" {
                            img = "垃圾箱绿"
                            a = 0
                        }else if result == "厨余垃圾"{
                            img = "垃圾箱黄"
                            a = 1
                        }else if result == "有害垃圾"{
                            img = "垃圾箱红"
                            a = 2
                        }else if result == "其他垃圾"{
                            img = "垃圾箱灰"
                            a = 3
                        }
                    }
                }.buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(.cyan)
                Button("清除搜索   "){
                    a = -1
                    input = ""
                    speechRecognizer.transcript=""
                    img = "垃圾箱蓝"
                }.buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(.teal)
                    
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .font(.title)
        .animation(.easeInOut)
    }
}

struct SoundView_Previews: PreviewProvider {
    static var previews: some View {
        SoundView()
    }
}
