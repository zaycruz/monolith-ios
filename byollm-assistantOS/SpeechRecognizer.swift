//
//  SpeechRecognizer.swift
//  byollm-assistantOS
//
//  Created by master on 12/21/25.
//

import Foundation
import Speech
import AVFoundation

enum SpeechTranscriptComposer {
    static func compose(draft: String, transcript: String) -> String {
        guard !draft.isEmpty else { return transcript }
        guard !transcript.isEmpty else { return draft }
        return draft.last?.isWhitespace == true ? draft + transcript : draft + " " + transcript
    }
}

@MainActor
class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var isStarting: Bool = false
    @Published var errorMessage: String?
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var authorizationGeneration = 0
    
    func startRecording() {
        guard !isRecording, !isStarting else { return }
        authorizationGeneration += 1
        let generation = authorizationGeneration
        isStarting = true
        errorMessage = nil
        Task { await authorizeAndStart(generation: generation) }
    }

    private func authorizeAndStart(generation: Int) async {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard generation == authorizationGeneration else { return }
        guard speechStatus == .authorized else {
            isStarting = false
            errorMessage = "Allow Speech Recognition in Settings to dictate messages."
            return
        }

        let microphoneAllowed = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard generation == authorizationGeneration else { return }
        guard microphoneAllowed else {
            isStarting = false
            errorMessage = "Allow Microphone access in Settings to dictate messages."
            return
        }

        beginRecording(generation: generation)
    }

    private func beginRecording(generation: Int) {
        guard generation == authorizationGeneration else { return }
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            isStarting = false
            errorMessage = "Speech recognizer not available"
            return
        }
        guard speechRecognizer.supportsOnDeviceRecognition else {
            isStarting = false
            errorMessage = "On-device speech recognition is unavailable for this language."
            return
        }
        
        transcript = ""
        errorMessage = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to configure audio session"
            isStarting = false
            cleanup()
            return
        }
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            errorMessage = "Failed to create audio engine"
            isStarting = false
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Failed to create recognition request"
            isStarting = false
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        recognitionRequest.requiresOnDeviceRecognition = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let request = recognitionRequest

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self, generation == self.authorizationGeneration else { return }
                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.stopRecording() }
                }
                
                if let error = error {
                    // Ignore cancellation errors
                    let nsError = error as NSError
                    if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 {
                        self.errorMessage = error.localizedDescription
                        self.stopRecording()
                    }
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            isStarting = false
        } catch {
            errorMessage = "Failed to start audio engine"
            isStarting = false
            cleanup()
        }
    }
    
    func stopRecording() {
        authorizationGeneration += 1
        cleanup()
        isRecording = false
        isStarting = false
    }
    
    private func cleanup() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
