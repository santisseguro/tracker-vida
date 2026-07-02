import SwiftUI

struct AICommandBar: View {
    var context: AICommandContext
    var latestCommand: CapturedAICommand?
    var feedback: AICommandBarFeedback? = nil
    var assistantResponse: String? = nil
    var submit: (String) -> Bool

    @State private var text = ""
    @StateObject private var speechInput = SpeechInputService()

    var body: some View {
        AppCard(tint: context.tint, compact: true) {
            HStack(spacing: 8) {
                Image(systemName: context.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(context.tint)
                    .frame(width: 30, height: 30)
                    .background(context.tint.opacity(0.14), in: Circle())

                TextField(context.placeholder, text: $text, axis: .vertical)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1...3)
                    .submitLabel(.send)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(submitCommand)

                Button {
                    speechInput.toggleListening { transcription in
                        text = transcription
                    }
                } label: {
                    Image(systemName: speechInput.isListening ? "mic.fill" : "mic")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(speechInput.isListening ? AppTheme.Colors.warning : context.tint)
                        .frame(width: 34, height: 34)
                        .background((speechInput.isListening ? AppTheme.Colors.warning : context.tint).opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(speechInput.isListening ? "Stop listening" : "Start voice input")

                Button(action: submitCommand) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(canSubmit ? context.tint : .secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .accessibilityLabel("Submit command")
            }

            if speechInput.isListening {
                Label("Listening...", systemImage: "waveform")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.warning)
            }

            if let errorMessage = speechInput.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.warning)
            }

            if let feedback {
                Label(feedback.message, systemImage: feedback.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(feedback.tint)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            } else if let assistantResponse {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.ai)
                        .frame(width: 18, height: 18)
                        .background(AppTheme.Colors.ai.opacity(0.12), in: Circle())

                    Text(assistantResponse)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 8)

                    Text("Local")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.ai)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.ai.opacity(0.12), in: Capsule())
                }
            } else if let latestCommand {
                Label(latestCommand.confirmationText, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(context.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitCommand() {
        let command = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }

        speechInput.stopListening()
        if submit(command) {
            text = ""
        }
    }
}

struct AICommandBarFeedback: Equatable {
    enum Kind: Equatable {
        case confirmation
        case warning
    }

    var message: String
    var kind: Kind

    var symbol: String {
        switch kind {
        case .confirmation:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch kind {
        case .confirmation:
            return AppTheme.Colors.ai
        case .warning:
            return AppTheme.Colors.warning
        }
    }
}

private extension AICommandContext {
    var placeholder: String {
        switch self {
        case .dashboard:
            return "Ask or tell Tracker Vida..."
        case .gymHealth:
            return "Log weight, calories, gym, or sleep..."
        case .university:
            return "Add a task, deadline, or follow-up..."
        case .money:
            return "Log income, expense, transfer, or balance..."
        }
    }

    var symbol: String {
        switch self {
        case .dashboard:
            return "sparkles"
        case .gymHealth:
            return "heart.text.square.fill"
        case .university:
            return "text.badge.plus"
        case .money:
            return "text.bubble.fill"
        }
    }

    var tint: Color {
        switch self {
        case .dashboard:
            return AppTheme.Colors.ai
        case .gymHealth:
            return AppTheme.Colors.health
        case .university:
            return AppTheme.Colors.university
        case .money:
            return AppTheme.Colors.money
        }
    }
}
