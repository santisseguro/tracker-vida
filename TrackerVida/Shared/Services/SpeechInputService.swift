import AVFoundation
import Foundation
import Speech

enum SpeechInputError: LocalizedError, Equatable {
    case recognizerUnavailable
    case speechPermissionDenied
    case microphonePermissionDenied
    case audioEngineFailed
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is unavailable right now."
        case .speechPermissionDenied:
            return "Speech recognition permission is needed to dictate commands."
        case .microphonePermissionDenied:
            return "Microphone permission is needed to dictate commands."
        case .audioEngineFailed:
            return "Could not start the microphone."
        case .recognitionFailed(let message):
            return message
        }
    }
}

@MainActor
final class SpeechInputService: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var isAvailable: Bool {
        recognizer?.isAvailable == true
    }

    func toggleListening(onTranscription: @escaping (String) -> Void) {
        if isListening {
            stopListening()
        } else {
            startListening(onTranscription: onTranscription)
        }
    }

    func startListening(onTranscription: @escaping (String) -> Void) {
        errorMessage = nil

        guard isAvailable else {
            report(.recognizerUnavailable)
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            guard speechStatus == .authorized else {
                Task { @MainActor in
                    self?.report(.speechPermissionDenied)
                }
                return
            }

            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    guard granted else {
                        self?.report(.microphonePermissionDenied)
                        return
                    }

                    self?.beginRecognition(onTranscription: onTranscription)
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
    }

    private func beginRecognition(onTranscription: @escaping (String) -> Void) {
        stopListening()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isListening = true
        } catch {
            report(.audioEngineFailed)
            return
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    onTranscription(result.bestTranscription.formattedString)
                }

                if let error {
                    self?.report(.recognitionFailed(error.localizedDescription))
                    self?.stopListening()
                    return
                }

                if result?.isFinal == true {
                    self?.stopListening()
                }
            }
        }
    }

    private func report(_ error: SpeechInputError) {
        errorMessage = error.localizedDescription
        isListening = false
    }
}
