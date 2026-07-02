import Foundation

protocol AIAssistantService {
    func respond(to request: AIAssistantRequest, context: AISectionContext) async -> AIAssistantResult
}

struct LocalAIAssistantService: AIAssistantService {
    func respond(to request: AIAssistantRequest, context: AISectionContext) async -> AIAssistantResult {
        let intent = classify(request, context: context)

        return AIAssistantResult(
            requestID: request.id,
            section: request.section,
            intent: intent,
            response: response(for: intent, context: context),
            requiresFollowUp: intent.kind == .pendingFollowUp,
            providerResponse: .localStub,
            createdAt: request.createdAt
        )
    }

    private func classify(_ request: AIAssistantRequest, context: AISectionContext) -> AIAssistantIntent {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .unknown(text) }

        if looksLikeReadOnlyQuestion(text) {
            return .readOnlyQuestion(
                AIReadOnlyQuestionIntent(
                    section: request.section,
                    question: text,
                    topic: topic(for: text, section: context.section)
                )
            )
        }

        if looksLikeAction(text) {
            return .action(
                AIActionIntent(
                    section: request.section,
                    actionName: "local_stub_action",
                    arguments: ["rawText": text],
                    requiresConfirmation: true,
                    confidence: 0.2
                )
            )
        }

        return .unknown(text)
    }

    private func response(for intent: AIAssistantIntent, context: AISectionContext) -> String {
        switch intent {
        case .readOnlyQuestion:
            return "Local assistant foundation is ready for \(context.section.title). Read-only analysis will use this section context before a real AI provider is connected."
        case .action:
            return "Local assistant foundation detected an action, but execution is intentionally not connected here yet."
        case .pendingFollowUp(let followUp):
            return followUp.prompt
        case .unknown:
            return "Local assistant foundation received this input, but no section assistant has handled it yet."
        }
    }

    private func looksLikeReadOnlyQuestion(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        return normalizedText.hasSuffix("?")
            || normalizedText.hasPrefix("what ")
            || normalizedText.hasPrefix("why ")
            || normalizedText.hasPrefix("how ")
            || normalizedText.hasPrefix("cuanto ")
            || normalizedText.hasPrefix("que ")
            || normalizedText.hasPrefix("qué ")
            || normalizedText.hasPrefix("por que ")
            || normalizedText.hasPrefix("por qué ")
            || normalizedText.hasPrefix("cuando ")
            || normalizedText.hasPrefix("cuándo ")
    }

    private func looksLikeAction(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        let actionWords = [
            "add",
            "create",
            "log",
            "mark",
            "register",
            "agrega",
            "agregá",
            "crea",
            "creá",
            "marca",
            "marcá",
            "registra",
            "registrá",
            "gaste",
            "gasté",
            "pague",
            "pagué",
            "transferi",
            "transferí"
        ]

        return actionWords.contains { normalizedText.hasPrefix($0) }
    }

    private func topic(for text: String, section: AICommandContext) -> AIReadOnlyQuestionTopic {
        let normalizedText = normalized(text)

        switch section {
        case .dashboard:
            return .crossSectionSummary
        case .gymHealth:
            return .healthProgress
        case .university:
            if normalizedText.contains("class") || normalizedText.contains("clase") {
                return .universitySchedule
            }
            return .universityTasks
        case .money:
            if normalizedText.contains("spend") || normalizedText.contains("gaste") || normalizedText.contains("gasté") {
                return .moneySpending
            }
            return .moneySummary
        }
    }

    private func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

// Future Gemini/OpenAI adapters should conform to AIAssistantService, decode
// structured provider output into AIAssistantIntent, and leave AppStore
// mutations to validated local action executors.
