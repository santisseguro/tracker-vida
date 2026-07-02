import XCTest
@testable import TrackerVida

final class DomainModelTests: XCTestCase {
    func testCapturedAICommandTrimsTextAndConfirmsContext() {
        let command = CapturedAICommand(
            id: EntityID(uuidString: "00000000-0000-0000-0000-00000000A001")!,
            context: .money,
            text: "  log expense 12000 comida  ",
            createdAt: MockData.today
        )

        XCTAssertEqual(command.text, "log expense 12000 comida")
        XCTAssertEqual(command.context, .money)
        XCTAssertEqual(command.confirmationText, "Captured for Money")
    }

    func testAIAssistantRequestAndResultEncodeDecode() throws {
        let request = AIAssistantRequest(
            id: EntityID(uuidString: "00000000-0000-0000-0000-00000000A101")!,
            section: .university,
            text: "  What classes do I have tomorrow?  ",
            createdAt: MockData.today
        )
        let proposedAction = AIActionIntent(
            section: .university,
            actionName: "add_task",
            arguments: ["title": "Read chapter"],
            requiresConfirmation: true,
            confidence: 0.7
        )
        let followUp = AIPendingFollowUpIntent(
            id: EntityID(uuidString: "00000000-0000-0000-0000-00000000A102")!,
            section: .university,
            originalText: request.text,
            prompt: "What deadline should I use?",
            missingFields: ["dueDate"],
            proposedAction: proposedAction,
            createdAt: MockData.today
        )
        let result = AIAssistantResult(
            id: EntityID(uuidString: "00000000-0000-0000-0000-00000000A103")!,
            requestID: request.id,
            section: request.section,
            intent: .pendingFollowUp(followUp),
            response: "What deadline should I use?",
            requiresFollowUp: true,
            providerResponse: .localStub,
            createdAt: MockData.today
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decodedRequest = try decoder.decode(AIAssistantRequest.self, from: encoder.encode(request))
        let decodedResult = try decoder.decode(AIAssistantResult.self, from: encoder.encode(result))

        XCTAssertEqual(decodedRequest.text, "What classes do I have tomorrow?")
        XCTAssertEqual(decodedResult.intent.kind, .pendingFollowUp)
        XCTAssertEqual(decodedResult.providerResponse, .localStub)

        guard case .pendingFollowUp(let decodedFollowUp) = decodedResult.intent else {
            return XCTFail("Expected pending follow-up intent")
        }

        XCTAssertEqual(decodedFollowUp.missingFields, ["dueDate"])
        XCTAssertEqual(decodedFollowUp.proposedAction?.actionName, "add_task")
    }

    func testAIAssistantIntentDistinguishesReadOnlyAndAction() {
        let question = AIAssistantIntent.readOnlyQuestion(
            AIReadOnlyQuestionIntent(
                section: .gymHealth,
                question: "Am I on track?",
                topic: .healthProgress
            )
        )
        let action = AIAssistantIntent.action(
            AIActionIntent(
                section: .money,
                actionName: "add_expense",
                arguments: ["amount": "12000"],
                requiresConfirmation: false
            )
        )

        XCTAssertEqual(question.kind, .readOnlyQuestion)
        XCTAssertEqual(action.kind, .action)
    }

    func testAIAssistantPendingFollowUpRepresentation() {
        let action = AIActionIntent(
            section: .money,
            actionName: "add_transfer",
            arguments: ["amount": "50", "currency": "USDT"],
            requiresConfirmation: true
        )
        let followUp = AIPendingFollowUpIntent(
            section: .money,
            originalText: "Transfer 50 USDT",
            prompt: "Which destination account should I use?",
            missingFields: ["toAccountID"],
            proposedAction: action,
            createdAt: MockData.today
        )
        let intent = AIAssistantIntent.pendingFollowUp(followUp)

        XCTAssertEqual(intent.kind, .pendingFollowUp)
        XCTAssertEqual(followUp.section, .money)
        XCTAssertEqual(followUp.proposedAction?.requiresConfirmation, true)
        XCTAssertEqual(followUp.missingFields, ["toAccountID"])
    }

    @MainActor
    func testAIAssistantUniversityContextBuilderReturnsClassesAndTasks() {
        let store = AppStore(currentDate: MockData.today)
        let context = AIAssistantContextBuilder.universityContext(from: store)

        XCTAssertEqual(context.section, .university)
        XCTAssertNil(context.money)
        XCTAssertEqual(context.university?.classes.map(\.id), store.universityState.classes.map(\.id))
        XCTAssertEqual(context.university?.activeCriticalTasks.count, store.universityState.activeCriticalTasks.count)
        XCTAssertTrue(context.university?.todayClasses.contains { $0.classID == MockData.algebraClassID } == true)
        XCTAssertTrue(context.university?.upcomingClassesThisWeek.contains { $0.classID == MockData.programmingClassID } == true)
    }

    @MainActor
    func testAIAssistantHealthContextBuilderReturnsProgressAndOrder() {
        let store = AppStore(currentDate: MockData.today)
        let context = AIAssistantContextBuilder.gymHealthContext(from: store)
        let healthContext = context.gymHealth

        XCTAssertEqual(context.section, .gymHealth)
        XCTAssertEqual(healthContext?.currentWeightKg, store.gymHealthState.progress.currentWeightKg)
        XCTAssertEqual(healthContext?.targetWeightKg, MockData.weightGoal.targetWeightKg)
        XCTAssertEqual(healthContext?.trackStatus, store.gymHealthState.progress.trackStatus)
        XCTAssertEqual(healthContext?.dailyOrderTitle, store.gymHealthState.dailyOrderPlan.orders.first?.title)
        XCTAssertEqual(healthContext?.checklistItems.count, store.gymHealthState.dailyOrderPlan.orders.flatMap(\.checklist).count)
    }

    @MainActor
    func testAIAssistantMoneyContextBuilderReturnsAccountsAndTransactions() {
        let store = AppStore(currentDate: MockData.today)
        let context = AIAssistantContextBuilder.moneyContext(from: store)
        let moneyContext = context.money

        XCTAssertEqual(context.section, .money)
        XCTAssertEqual(moneyContext?.accounts.map(\.id), store.moneyState.activeAccounts.map(\.id))
        XCTAssertEqual(moneyContext?.recentTransactions.map(\.id), Array(store.moneyState.transactions.prefix(12)).map(\.id))
        XCTAssertEqual(moneyContext?.totals.arsMinorUnits, store.moneyState.totals.arsMinorUnits)
        XCTAssertEqual(moneyContext?.totals.usdtMinorUnits, store.moneyState.totals.usdtMinorUnits)
    }

    @MainActor
    func testLocalAIAssistantServiceReturnsReadOnlyStubResult() async {
        let store = AppStore(currentDate: MockData.today)
        let context = AIAssistantContextBuilder.dashboardContext(from: store)
        let request = AIAssistantRequest(section: .dashboard, text: "What should I do today?", createdAt: MockData.today)
        let service = LocalAIAssistantService()

        let result = await service.respond(to: request, context: context)

        XCTAssertEqual(result.requestID, request.id)
        XCTAssertEqual(result.intent.kind, .readOnlyQuestion)
        XCTAssertEqual(result.providerResponse, .localStub)
        XCTAssertFalse(result.requiresFollowUp)
        XCTAssertTrue(result.response.contains("Local assistant foundation"))
    }

    @MainActor
    func testStoreCapturesAICommandsInMemoryByContext() {
        let store = AppStore(currentDate: MockData.today)

        let emptyCommand = store.captureAICommand("   ", context: .dashboard, createdAt: MockData.today)
        let dashboardCommand = store.captureAICommand("Review today", context: .dashboard, createdAt: MockData.today)
        let moneyCommand = store.captureAICommand("Log income 20000", context: .money, createdAt: MockData.today)

        XCTAssertNil(emptyCommand)
        XCTAssertEqual(dashboardCommand?.text, "Review today")
        XCTAssertEqual(moneyCommand?.context, .money)
        XCTAssertEqual(store.latestCapturedAICommand(for: .dashboard)?.text, "Review today")
        XCTAssertEqual(store.latestCapturedAICommand(for: .money)?.text, "Log income 20000")
        XCTAssertEqual(store.capturedAICommands.count, 2)
    }

    func testGymHealthMockSummaries() {
        XCTAssertEqual(MockData.dailyHealthLogs.gymAttendanceCount, 4)
        XCTAssertEqual(MockData.weightLogs.latest?.weightKg, 81.8)
        XCTAssertGreaterThan(MockData.dailyHealthLogs.averageSleepHours, 7)
    }

    func testMoneySignedAmountsAndCategories() {
        let income = MockData.moneyTransactions[0]
        let expense = MockData.moneyTransactions[1]
        let transfer = MockData.moneyTransactions[2]

        XCTAssertEqual(income.signedMinorUnits, 180_000)
        XCTAssertEqual(expense.signedMinorUnits, -11_500)
        XCTAssertEqual(transfer.signedMinorUnits, 0)
        XCTAssertEqual(income.category?.label, "Trabajo")
        XCTAssertEqual(expense.category?.label, "Comida")
        XCTAssertNil(transfer.category)
    }

    @MainActor
    func testStoreAddsMoneyAccount() {
        let store = AppStore(currentDate: MockData.today)

        let account = store.addMoneyAccount(
            name: "Mercado Pago",
            currency: .ars,
            currentBalance: 25_000,
            status: .active,
            createdAt: MockData.today
        )

        XCTAssertEqual(store.moneyAccount(id: account.id)?.name, "Mercado Pago")
        XCTAssertEqual(store.moneyAccount(id: account.id)?.currentBalance.minorUnits, 25_000)
        XCTAssertEqual(store.moneyAccount(id: account.id)?.color, .money)
        XCTAssertEqual(store.moneyState.activeAccounts.count, 4)
    }

    @MainActor
    func testStoreEditsMoneyAccount() {
        let store = AppStore(currentDate: MockData.today)
        var account = store.moneyAccounts[0]

        account.name = "Efectivo diario"
        account.currentBalance = MoneyAmount(minorUnits: 90_000, currency: .ars)
        account.status = .archived
        account.color = .ai

        store.updateMoneyAccount(account, updatedAt: MockData.today)

        XCTAssertEqual(store.moneyAccount(id: account.id)?.name, "Efectivo diario")
        XCTAssertEqual(store.moneyAccount(id: account.id)?.currentBalance.minorUnits, 90_000)
        XCTAssertEqual(store.moneyAccount(id: account.id)?.status, .archived)
        XCTAssertEqual(store.moneyAccount(id: account.id)?.color, .ai)
        XCTAssertEqual(store.moneyState.activeAccounts.count, 2)
    }

    @MainActor
    func testStoreAddsIncomeAndUpdatesBalance() {
        let store = AppStore(currentDate: MockData.today)
        let accountID = MockData.accountBankARS

        let transaction = store.addIncomeTransaction(
            title: "Pago extra",
            amount: 40_000,
            toAccountID: accountID,
            category: .trabajo,
            date: MockData.today,
            notes: "  Pago con nota  "
        )

        XCTAssertEqual(store.moneyAccount(id: accountID)?.currentBalance.minorUnits, 458_900)
        XCTAssertEqual(transaction?.category?.label, "Trabajo")
        XCTAssertEqual(transaction?.fromAccountID, nil)
        XCTAssertEqual(transaction?.toAccountID, accountID)
        XCTAssertEqual(transaction?.notes, "Pago con nota")
    }

    @MainActor
    func testStoreAddsExpenseAndUpdatesBalance() {
        let store = AppStore(currentDate: MockData.today)
        let accountID = MockData.accountARS

        let transaction = store.addExpenseTransaction(
            title: "Colectivo",
            amount: 2_500,
            fromAccountID: accountID,
            category: .transporte,
            date: MockData.today,
            notes: "Saldado en efectivo"
        )

        XCTAssertEqual(store.moneyAccount(id: accountID)?.currentBalance.minorUnits, 79_900)
        XCTAssertEqual(transaction?.category?.label, "Transporte")
        XCTAssertEqual(transaction?.fromAccountID, accountID)
        XCTAssertEqual(transaction?.toAccountID, nil)
        XCTAssertEqual(transaction?.notes, "Saldado en efectivo")
    }

    @MainActor
    func testStoreTransferUpdatesBothAccounts() {
        let store = AppStore(currentDate: MockData.today)

        let transaction = store.addTransferTransaction(
            title: "Cash to bank",
            amount: 10_000,
            fromAccountID: MockData.accountARS,
            toAccountID: MockData.accountBankARS,
            date: MockData.today,
            notes: "Cash deposit"
        )

        XCTAssertEqual(store.moneyAccount(id: MockData.accountARS)?.currentBalance.minorUnits, 72_400)
        XCTAssertEqual(store.moneyAccount(id: MockData.accountBankARS)?.currentBalance.minorUnits, 428_900)
        XCTAssertNil(transaction?.category)
        XCTAssertEqual(transaction?.notes, "Cash deposit")
    }

    @MainActor
    func testStoreBalanceAdjustmentStoresDifference() {
        let store = AppStore(currentDate: MockData.today)

        let transaction = store.addBalanceAdjustmentTransaction(
            title: "Cash recount",
            accountID: MockData.accountARS,
            newBalance: 80_000,
            date: MockData.today,
            notes: "Manual recount"
        )

        XCTAssertEqual(store.moneyAccount(id: MockData.accountARS)?.currentBalance.minorUnits, 80_000)
        XCTAssertEqual(transaction?.amount.minorUnits, -2_400)
        XCTAssertEqual(transaction?.balanceBefore?.minorUnits, 82_400)
        XCTAssertEqual(transaction?.balanceAfter?.minorUnits, 80_000)
        XCTAssertNil(transaction?.category)
        XCTAssertEqual(transaction?.notes, "Manual recount")
    }

    @MainActor
    func testDashboardMoneyTotalsUpdateFromSharedState() {
        let store = AppStore(currentDate: MockData.today)

        XCTAssertEqual(store.dashboardState.moneyTotals.arsMinorUnits, 501_300)
        XCTAssertEqual(store.dashboardState.moneyTotals.usdtMinorUnits, 1_240)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsEquivalentMinorUnits, 1_741_300)
        XCTAssertEqual(store.dashboardState.moneyTotals.dashboardDisplay, "$1741K")
        XCTAssertEqual(store.dashboardState.moneyTotals.arsEquivalentDisplay, "$1.741.300 ARS")
        XCTAssertEqual(store.dashboardState.moneyTotals.usdtLabeledDisplay, "1.240 USDT")

        store.addIncomeTransaction(
            title: "Reembolso",
            amount: 1_200,
            toAccountID: MockData.accountBankARS,
            category: .reembolso,
            date: MockData.today
        )

        XCTAssertEqual(store.moneyState.totals.arsMinorUnits, 502_500)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsMinorUnits, 502_500)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsEquivalentMinorUnits, 1_742_500)
        XCTAssertEqual(store.dashboardState.moneyTotals.dashboardDisplay, "$1742K")
        XCTAssertEqual(store.dashboardState.moneyTotals.arsEquivalentDisplay, "$1.742.500 ARS")
    }

    func testMoneyTrendRangesUseDifferentSampling() {
        let dailyPoints = MoneyBalanceTrendCalculator.points(
            accounts: MockData.moneyAccounts,
            transactions: MockData.moneyTransactions,
            referenceDate: MockData.today,
            usdtToARSRate: 1_000,
            range: .daily,
            calendar: MockData.calendar
        )
        let annualPoints = MoneyBalanceTrendCalculator.points(
            accounts: MockData.moneyAccounts,
            transactions: MockData.moneyTransactions,
            referenceDate: MockData.today,
            usdtToARSRate: 1_000,
            range: .annual,
            calendar: MockData.calendar
        )

        XCTAssertGreaterThan(annualPoints.count, dailyPoints.count)
        XCTAssertTrue(dailyPoints.allSatisfy { $0.date >= MoneyTrendRange.daily.startDate(referenceDate: MockData.today, calendar: MockData.calendar) })
        XCTAssertTrue(annualPoints.contains { MockData.calendar.component(.month, from: $0.date) != MockData.calendar.component(.month, from: MockData.today) })
    }

    func testMoneyCommandParserParsesExpenseCommand() throws {
        let draft = try XCTUnwrap(parsedMoneyCommand("Gasté 12000 pesos en comida desde Efectivo ARS"))

        XCTAssertEqual(draft.kind, .expense)
        XCTAssertEqual(draft.amount.minorUnits, 12_000)
        XCTAssertEqual(draft.amount.currency, .ars)
        XCTAssertEqual(draft.fromAccountID, MockData.accountARS)
        XCTAssertEqual(draft.expenseCategory, .comida)
    }

    func testMoneyCommandParserParsesIncomeCommand() throws {
        let draft = try XCTUnwrap(parsedMoneyCommand("Me entraron 500000 pesos en Banco ARS por trabajo"))

        XCTAssertEqual(draft.kind, .income)
        XCTAssertEqual(draft.amount.minorUnits, 500_000)
        XCTAssertEqual(draft.amount.currency, .ars)
        XCTAssertEqual(draft.toAccountID, MockData.accountBankARS)
        XCTAssertEqual(draft.incomeCategory, .trabajo)
    }

    func testMoneyCommandParserParsesTransferCommand() throws {
        let draft = try XCTUnwrap(parsedMoneyCommand("Transferí 50 USDT de Binance a Wallet"))

        XCTAssertEqual(draft.kind, .transfer)
        XCTAssertEqual(draft.amount.minorUnits, 50)
        XCTAssertEqual(draft.amount.currency, .usdt)
        XCTAssertNil(draft.fromAccountID)
        XCTAssertEqual(draft.detectedFromAccountName, "Binance")
        XCTAssertEqual(draft.toAccountID, MockData.accountUSDT)
    }

    func testMoneyCommandParserParsesBalanceAdjustmentCommand() throws {
        let draft = try XCTUnwrap(parsedMoneyCommand("Mi saldo real en Efectivo ARS es 82500 pesos"))

        XCTAssertEqual(draft.kind, .balanceAdjustment)
        XCTAssertEqual(draft.amount.minorUnits, 82_500)
        XCTAssertEqual(draft.amount.currency, .ars)
        XCTAssertEqual(draft.fromAccountID, MockData.accountARS)
    }

    func testMoneyCommandParserLeavesMissingAccountForReview() throws {
        let draft = try XCTUnwrap(parsedMoneyCommand("Gasté 12000 pesos en comida"))

        XCTAssertEqual(draft.kind, .expense)
        XCTAssertNil(draft.fromAccountID)
        XCTAssertNil(draft.detectedFromAccountName)
        XCTAssertTrue(draft.requiresFromAccount)
    }

    func testMoneyCommandParserKeepsUnknownAccountForReview() throws {
        let draft = try XCTUnwrap(parsedMoneyCommand("Pagué 8500 ARS de transporte con BBVA"))

        XCTAssertEqual(draft.kind, .expense)
        XCTAssertEqual(draft.amount.minorUnits, 8_500)
        XCTAssertEqual(draft.expenseCategory, .transporte)
        XCTAssertNil(draft.fromAccountID)
        XCTAssertEqual(draft.detectedFromAccountName, "BBVA")
    }

    @MainActor
    func testConfirmedMoneyCommandDraftUsesExistingStoreWorkflow() throws {
        let store = AppStore(currentDate: MockData.today)
        let draft = try XCTUnwrap(parsedMoneyCommand("Gasté 12000 pesos en comida desde Efectivo ARS"))
        guard case .expense(let category) = draft.category else {
            return XCTFail("Expected expense category")
        }

        let transaction = store.addExpenseTransaction(
            title: draft.title,
            amount: draft.amount.minorUnits,
            fromAccountID: try XCTUnwrap(draft.fromAccountID),
            category: category,
            date: draft.date,
            notes: draft.note
        )

        XCTAssertEqual(transaction?.kind, .expense)
        XCTAssertEqual(transaction?.category?.label, "Comida")
        XCTAssertEqual(store.moneyAccount(id: MockData.accountARS)?.currentBalance.minorUnits, 70_400)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsMinorUnits, 489_300)
    }

    func testMoneyConversationStateStartsWithoutInlineResponse() {
        let conversation = MoneyConversationState()

        XCTAssertNil(conversation.latestAssistantResponse)
    }

    func testMoneyConversationStateExposesLatestAssistantResponseOnly() {
        let conversation = MoneyConversationState(messages: [
            AIChatMessage(role: .assistant, text: "Primera respuesta", createdAt: MockData.today),
            AIChatMessage(role: .user, text: "ok", createdAt: MockData.today),
            AIChatMessage(role: .assistant, text: "Última respuesta", createdAt: MockData.today)
        ])

        XCTAssertEqual(conversation.latestAssistantResponse, "Última respuesta")
    }

    @MainActor
    func testMoneyConversationUnknownAccountPromptsAccountCreation() {
        let store = AppStore(currentDate: MockData.today)
        var conversation = MoneyConversationState(messages: [])

        MoneyConversationEngine.handle("Gasté 1000 pesos en Ualá", state: &conversation, store: store, date: MockData.today)

        XCTAssertEqual(store.moneyTransactions.count, MockData.moneyTransactions.count)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("No tenés ninguna cuenta llamada Ualá"))

        guard case .createAccountConfirmation(.from, "Ualá") = conversation.pendingCommand?.step else {
            return XCTFail("Expected create-account confirmation step")
        }
    }

    @MainActor
    func testMoneyConversationUserAgreesToCreateAccountThenAsksForInitialBalance() {
        let store = AppStore(currentDate: MockData.today)
        var conversation = MoneyConversationState(messages: [])

        MoneyConversationEngine.handle("Gasté 1000 pesos en Ualá", state: &conversation, store: store, date: MockData.today)
        MoneyConversationEngine.handle("Sí, creala", state: &conversation, store: store, date: MockData.today)

        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("saldo inicial"))

        guard case .initialBalance(.from, "Ualá") = conversation.pendingCommand?.step else {
            return XCTFail("Expected initial-balance step")
        }
    }

    @MainActor
    func testMoneyConversationInitialBalanceCreatesAccountAndCompletesPendingExpense() throws {
        let store = AppStore(currentDate: MockData.today)
        var conversation = MoneyConversationState(messages: [])

        MoneyConversationEngine.handle("Gasté 1000 pesos en Ualá", state: &conversation, store: store, date: MockData.today)
        MoneyConversationEngine.handle("Sí, creala", state: &conversation, store: store, date: MockData.today)
        MoneyConversationEngine.handle("50000 pesos", state: &conversation, store: store, date: MockData.today)

        let account = try XCTUnwrap(store.moneyAccounts.first { $0.name == "Ualá" })
        XCTAssertEqual(account.currentBalance.minorUnits, 49_000)
        XCTAssertEqual(store.moneyTransactions.first?.kind, .expense)
        XCTAssertEqual(store.moneyTransactions.first?.fromAccountID, account.id)
        XCTAssertNil(conversation.pendingCommand)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("registré el gasto"))
        XCTAssertEqual(store.dashboardState.moneyTotals.arsMinorUnits, 550_300)
    }

    @MainActor
    func testMoneyConversationParserFailureReturnsClarifyingAssistantMessage() {
        let store = AppStore(currentDate: MockData.today)
        var conversation = MoneyConversationState(messages: [])

        MoneyConversationEngine.handle("anotá esto después", state: &conversation, store: store, date: MockData.today)

        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("No lo entendí"))
        XCTAssertNil(conversation.pendingCommand)
        XCTAssertEqual(store.moneyTransactions.count, MockData.moneyTransactions.count)
    }

    @MainActor
    func testMoneyConversationExpenseSuccessResponse() {
        let store = AppStore(currentDate: MockData.today)
        var conversation = MoneyConversationState(messages: [])

        MoneyConversationEngine.handle("Gasté 1000 pesos en comida desde Efectivo ARS", state: &conversation, store: store, date: MockData.today)

        XCTAssertEqual(store.moneyTransactions.first?.kind, .expense)
        XCTAssertEqual(store.moneyAccount(id: MockData.accountARS)?.currentBalance.minorUnits, 81_400)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("registré el gasto"))
    }

    @MainActor
    func testMoneyConversationIncomeSuccessResponse() {
        let store = AppStore(currentDate: MockData.today)
        var conversation = MoneyConversationState(messages: [])

        MoneyConversationEngine.handle("Me entraron 500000 pesos en Banco ARS por trabajo", state: &conversation, store: store, date: MockData.today)

        XCTAssertEqual(store.moneyTransactions.first?.kind, .income)
        XCTAssertEqual(store.moneyAccount(id: MockData.accountBankARS)?.currentBalance.minorUnits, 918_900)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("registré el ingreso"))
    }

    @MainActor
    func testMoneyConversationTransferSuccessResponse() {
        let store = AppStore(currentDate: MockData.today)
        var conversation = MoneyConversationState(messages: [])

        MoneyConversationEngine.handle("Transferí 10000 pesos de Efectivo ARS a Banco ARS", state: &conversation, store: store, date: MockData.today)

        XCTAssertEqual(store.moneyTransactions.first?.kind, .transfer)
        XCTAssertEqual(store.moneyAccount(id: MockData.accountARS)?.currentBalance.minorUnits, 72_400)
        XCTAssertEqual(store.moneyAccount(id: MockData.accountBankARS)?.currentBalance.minorUnits, 428_900)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("Transferí"))
    }

    @MainActor
    func testMoneyConversationBalanceAdjustmentSuccessResponse() {
        let store = AppStore(currentDate: MockData.today)
        var conversation = MoneyConversationState(messages: [])

        MoneyConversationEngine.handle("Mi saldo real en Efectivo ARS es 90000 pesos", state: &conversation, store: store, date: MockData.today)

        XCTAssertEqual(store.moneyTransactions.first?.kind, .balanceAdjustment)
        XCTAssertEqual(store.moneyAccount(id: MockData.accountARS)?.currentBalance.minorUnits, 90_000)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("Ajusté"))
    }

    @MainActor
    func testQAMoneyAIExpenseWithExistingAccountUpdatesStatePersistenceAndChart() throws {
        let persistence = InMemoryAppStatePersistence(state: nil)
        let store = AppStore(currentDate: MockData.today, persistence: persistence)
        var conversation = MoneyConversationState()

        MoneyConversationEngine.handle("Gasté 12000 pesos en comida desde Banco ARS", state: &conversation, store: store, date: MockData.today)

        let transaction = try XCTUnwrap(store.moneyTransactions.first)
        XCTAssertEqual(transaction.kind, .expense)
        XCTAssertEqual(transaction.amount.minorUnits, 12_000)
        XCTAssertEqual(transaction.amount.currency, .ars)
        XCTAssertEqual(transaction.fromAccountID, MockData.accountBankARS)
        XCTAssertEqual(transaction.category?.label, "Comida")
        XCTAssertEqual(store.moneyAccount(id: MockData.accountBankARS)?.currentBalance.minorUnits, 406_900)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsMinorUnits, 489_300)
        XCTAssertEqual(conversation.latestAssistantResponse, lastAssistantMessage(in: conversation))
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("registré el gasto"))
        XCTAssertEqual(persistence.savedStates.last?.moneyAccounts.first { $0.id == MockData.accountBankARS }?.currentBalance.minorUnits, 406_900)
        XCTAssertEqual(todayTrendBalance(for: MockData.accountBankARS, in: store), 406_900)
    }

    @MainActor
    func testQAMoneyAIIncomeWithExistingAccountUpdatesBalances() throws {
        let store = AppStore(currentDate: MockData.today)
        var conversation = MoneyConversationState()

        MoneyConversationEngine.handle("Me entraron 500000 pesos en Banco ARS por trabajo", state: &conversation, store: store, date: MockData.today)

        let transaction = try XCTUnwrap(store.moneyTransactions.first)
        XCTAssertEqual(transaction.kind, .income)
        XCTAssertEqual(transaction.amount.minorUnits, 500_000)
        XCTAssertEqual(transaction.toAccountID, MockData.accountBankARS)
        XCTAssertEqual(transaction.category?.label, "Trabajo")
        XCTAssertEqual(store.moneyAccount(id: MockData.accountBankARS)?.currentBalance.minorUnits, 918_900)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsMinorUnits, 1_001_300)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("registré el ingreso"))
    }

    @MainActor
    func testQAMoneyAITransferWithExistingAccountsUpdatesBalancesDashboardAndChart() throws {
        let persistence = InMemoryAppStatePersistence(state: nil)
        let store = AppStore(currentDate: MockData.today, persistence: persistence)
        var conversation = MoneyConversationState()

        MoneyConversationEngine.handle("Transferí 50 USDT de USDT Wallet a Banco ARS", state: &conversation, store: store, date: MockData.today)

        let transaction = try XCTUnwrap(store.moneyTransactions.first)
        XCTAssertEqual(transaction.kind, .transfer)
        XCTAssertEqual(transaction.amount.minorUnits, 50)
        XCTAssertEqual(transaction.amount.currency, .usdt)
        XCTAssertEqual(transaction.fromAccountID, MockData.accountUSDT)
        XCTAssertEqual(transaction.toAccountID, MockData.accountBankARS)
        XCTAssertEqual(store.moneyAccount(id: MockData.accountUSDT)?.currentBalance.minorUnits, 1_190)
        XCTAssertEqual(store.moneyAccount(id: MockData.accountBankARS)?.currentBalance.minorUnits, 468_900)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsMinorUnits, 551_300)
        XCTAssertEqual(store.dashboardState.moneyTotals.usdtMinorUnits, 1_190)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsEquivalentMinorUnits, 1_741_300)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("Transferí"))
        XCTAssertEqual(persistence.savedStates.last?.moneyTransactions.first?.kind, .transfer)
        XCTAssertEqual(todayTrendBalance(for: MockData.accountUSDT, in: store), 1_190)
        XCTAssertEqual(todayTrendBalance(for: MockData.accountBankARS, in: store), 468_900)
    }

    @MainActor
    func testQAMoneyAIBalanceAdjustmentUpdatesDifferenceAndPersistence() throws {
        let persistence = InMemoryAppStatePersistence(state: nil)
        let store = AppStore(currentDate: MockData.today, persistence: persistence)
        var conversation = MoneyConversationState()

        MoneyConversationEngine.handle("Mi saldo real en Banco ARS es 82500 pesos", state: &conversation, store: store, date: MockData.today)

        let transaction = try XCTUnwrap(store.moneyTransactions.first)
        XCTAssertEqual(transaction.kind, .balanceAdjustment)
        XCTAssertEqual(transaction.amount.minorUnits, -336_400)
        XCTAssertEqual(transaction.balanceBefore?.minorUnits, 418_900)
        XCTAssertEqual(transaction.balanceAfter?.minorUnits, 82_500)
        XCTAssertEqual(store.moneyAccount(id: MockData.accountBankARS)?.currentBalance.minorUnits, 82_500)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsMinorUnits, 164_900)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("Ajusté"))
        XCTAssertEqual(persistence.savedStates.last?.moneyAccounts.first { $0.id == MockData.accountBankARS }?.currentBalance.minorUnits, 82_500)
    }

    @MainActor
    func testQAMoneyAIUnknownAccountFollowUpCreatesAccountCompletesPendingExpenseAndPersists() throws {
        let persistence = InMemoryAppStatePersistence(state: nil)
        let store = AppStore(currentDate: MockData.today, persistence: persistence)
        var conversation = MoneyConversationState()

        MoneyConversationEngine.handle("Gasté 1000 pesos en Ualá", state: &conversation, store: store, date: MockData.today)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("¿Querés crearla?"))
        guard case .createAccountConfirmation(.from, "Ualá") = conversation.pendingCommand?.step else {
            return XCTFail("Expected unknown account confirmation")
        }

        MoneyConversationEngine.handle("sí, creala", state: &conversation, store: store, date: MockData.today)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("saldo inicial"))
        guard case .initialBalance(.from, "Ualá") = conversation.pendingCommand?.step else {
            return XCTFail("Expected initial balance prompt")
        }

        MoneyConversationEngine.handle("50000 pesos", state: &conversation, store: store, date: MockData.today)

        let account = try XCTUnwrap(store.moneyAccounts.first { $0.name == "Ualá" })
        XCTAssertEqual(account.currentBalance.minorUnits, 49_000)
        XCTAssertEqual(store.moneyTransactions.first?.kind, .expense)
        XCTAssertEqual(store.moneyTransactions.first?.fromAccountID, account.id)
        XCTAssertNil(conversation.pendingCommand)
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("Creé Ualá"))
        XCTAssertTrue(lastAssistantMessage(in: conversation).contains("registré el gasto"))
        XCTAssertEqual(conversation.latestAssistantResponse, lastAssistantMessage(in: conversation))
        XCTAssertEqual(store.dashboardState.moneyTotals.arsMinorUnits, 550_300)
        XCTAssertEqual(persistence.savedStates.last?.moneyAccounts.first { $0.name == "Ualá" }?.currentBalance.minorUnits, 49_000)
        XCTAssertEqual(todayTrendBalance(for: account.id, in: store), 49_000)
    }

    func testDailyOrderCompletionRatio() {
        XCTAssertEqual(MockData.dailyOrderPlan.completionRatio, 0)
        XCTAssertEqual(MockData.dailyOrderPlan.orders.first?.checklist.count, 3)
    }

    func testPersistedAppStateEncodesAndDecodes() throws {
        var plan = MockData.dailyOrderPlan
        plan.orders[0].checklist[0].status = .done

        let state = PersistedAppState(
            weightGoal: MockData.weightGoal,
            weightLogs: MockData.weightLogs,
            dailyHealthLogs: MockData.dailyHealthLogs,
            dailyOrderPlan: plan,
            criticalTasks: MockData.criticalTasks,
            upcomingDeadlines: MockData.upcomingDeadlines,
            waitingResponses: MockData.waitingResponses,
            timeline: MockData.timeline,
            universityClasses: MockData.universityClasses,
            universityScheduleSessions: MockData.universityScheduleSessions,
            moneyAccounts: MockData.moneyAccounts,
            moneyTransactions: MockData.moneyTransactions
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(state)
        let decoded = try decoder.decode(PersistedAppState.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, state.schemaVersion)
        XCTAssertEqual(decoded.weightGoal.targetWeightKg, state.weightGoal.targetWeightKg)
        XCTAssertEqual(decoded.weightLogs.map(\.id), state.weightLogs.map(\.id))
        XCTAssertEqual(decoded.dailyHealthLogs.count, state.dailyHealthLogs.count)
        XCTAssertEqual(decoded.dailyOrderPlan.orders[0].checklist[0].status, .done)
        XCTAssertEqual(decoded.criticalTasks.map(\.title), state.criticalTasks.map(\.title))
        XCTAssertEqual(decoded.universityClasses.map(\.id), state.universityClasses.map(\.id))
        XCTAssertEqual(decoded.universityScheduleSessions.map(\.id), state.universityScheduleSessions.map(\.id))
        XCTAssertEqual(decoded.universityScheduleSessions.map(\.weekday), state.universityScheduleSessions.map(\.weekday))
        XCTAssertEqual(decoded.moneyAccounts.map(\.name), state.moneyAccounts.map(\.name))
        XCTAssertEqual(decoded.moneyAccounts.map(\.color), state.moneyAccounts.map(\.color))
        XCTAssertEqual(decoded.moneyTransactions.map(\.title), state.moneyTransactions.map(\.title))
        XCTAssertEqual(decoded.moneyTransactions.map(\.notes), state.moneyTransactions.map(\.notes))
    }

    func testMoneyAccountDecodesLegacyJSONWithDefaultColor() throws {
        let legacyJSON = """
        {
          "metadata": {
            "id": "00000000-0000-0000-0000-000000000778",
            "createdAt": "2026-06-01T03:00:00Z",
            "updatedAt": "2026-06-01T03:00:00Z"
          },
          "name": "Legacy cash",
          "currency": "ARS",
          "currentBalance": {
            "minorUnits": 50000,
            "currency": "ARS"
          },
          "kind": "Cash",
          "status": "Active"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let account = try decoder.decode(MoneyAccount.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(account.name, "Legacy cash")
        XCTAssertEqual(account.color, .money)
    }

    func testSeedMoneyAccountDecodesLegacyJSONWithStableDefaultColor() throws {
        let legacyJSON = """
        {
          "metadata": {
            "id": "00000000-0000-0000-0000-000000000201",
            "createdAt": "2026-06-01T03:00:00Z",
            "updatedAt": "2026-06-01T03:00:00Z"
          },
          "name": "Efectivo ARS",
          "currency": "ARS",
          "currentBalance": {
            "minorUnits": 82400,
            "currency": "ARS"
          },
          "kind": "Cash",
          "status": "Active"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let account = try decoder.decode(MoneyAccount.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(account.name, "Efectivo ARS")
        XCTAssertEqual(account.color, .warning)
    }

    func testWeightGoalDecodesLegacyJSONWithDefaultHealthConfig() throws {
        let legacyJSON = """
        {
          "metadata": {
            "id": "00000000-0000-0000-0000-000000000777",
            "createdAt": "2026-06-01T03:00:00Z",
            "updatedAt": "2026-06-01T03:00:00Z"
          },
          "targetWeightKg": 78,
          "startWeightKg": 84,
          "startDate": "2026-06-01T03:00:00Z",
          "targetDate": "2026-09-01T03:00:00Z",
          "isActive": true
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let goal = try decoder.decode(WeightGoal.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(goal.gymDayCalorieTarget, 2_300)
        XCTAssertEqual(goal.restDayCalorieTarget, 2_000)
        XCTAssertEqual(goal.targetWorkoutsPerWeek, 5)
        XCTAssertEqual(goal.idealGymWeekdays, [2, 3, 4, 5, 6])
    }

    @MainActor
    func testStoreUsesSeedDataWhenNoSavedStateExists() {
        let persistence = InMemoryAppStatePersistence(state: nil)

        let store = AppStore(currentDate: MockData.today, persistence: persistence)

        XCTAssertEqual(store.weightGoal.targetWeightKg, MockData.weightGoal.targetWeightKg)
        XCTAssertEqual(store.weightLogs.count, MockData.weightLogs.count)
        XCTAssertEqual(store.criticalTasks.count, MockData.criticalTasks.count)
        XCTAssertEqual(store.moneyAccounts.count, MockData.moneyAccounts.count)
        XCTAssertEqual(store.dailyOrdersState.completedItems, 0)
    }

    @MainActor
    func testStoreRestoresSavedState() {
        let generatedPlan = makeGeneratedHealthOrderPlan()
        var plan = generatedPlan
        plan.orders[0].checklist[0].status = .done

        var task = MockData.criticalTasks[0]
        task.status = .completed
        task.completedAt = MockData.today

        var account = MockData.moneyAccounts[0]
        account.name = "Saved cash"
        account.currentBalance = MoneyAmount(minorUnits: 123_456, currency: .ars)

        let savedState = PersistedAppState(
            weightGoal: WeightGoal(
                metadata: MockData.weightGoal.metadata,
                targetWeightKg: 76,
                startWeightKg: MockData.weightGoal.startWeightKg,
                startDate: MockData.weightGoal.startDate,
                targetDate: MockData.weightGoal.targetDate,
                isActive: true
            ),
            weightLogs: [
                WeightLog(
                    metadata: BaseMetadata(createdAt: MockData.today, updatedAt: MockData.today),
                    date: MockData.today,
                    weightKg: 79.9,
                    source: MockData.healthSource
                )
            ],
            dailyHealthLogs: MockData.dailyHealthLogs,
            dailyOrderPlan: plan,
            criticalTasks: [task],
            upcomingDeadlines: MockData.upcomingDeadlines,
            waitingResponses: MockData.waitingResponses,
            timeline: MockData.timeline,
            moneyAccounts: [account],
            moneyTransactions: MockData.moneyTransactions
        )
        let persistence = InMemoryAppStatePersistence(state: savedState)

        let store = AppStore(currentDate: MockData.today, persistence: persistence)

        XCTAssertEqual(store.weightGoal.targetWeightKg, 76)
        XCTAssertEqual(store.weightLogs.first?.weightKg, 79.9)
        XCTAssertEqual(store.dailyOrdersState.completedItems, 1)
        XCTAssertEqual(store.criticalTasks.first?.status, .completed)
        XCTAssertEqual(store.moneyAccounts.first?.name, "Saved cash")
        XCTAssertEqual(store.moneyAccounts.first?.currentBalance.minorUnits, 123_456)
    }

    @MainActor
    func testStoreSavesAfterWorkflowMutation() {
        let persistence = InMemoryAppStatePersistence(state: nil)
        let store = AppStore(currentDate: MockData.today, persistence: persistence)

        store.upsertWeightLog(date: MockData.today, weightKg: 80.2, enteredAt: MockData.today)

        XCTAssertEqual(persistence.savedStates.count, 1)
        XCTAssertEqual(persistence.savedStates.last?.weightLogs.latest?.weightKg, 80.2)
    }

    func testGymHealthV1ChoiceSets() {
        XCTAssertEqual(WorkoutType.allCases.map(\.rawValue), ["Push", "Pull", "Legs", "Full Body", "Cardio", "Other"])
        XCTAssertEqual(SleepQuality.allCases.map(\.rawValue), ["Good", "Normal", "Bad"])
    }

    func testGymHealthSevenDayMovingAverage() {
        let engine = GymHealthEngine(calendar: MockData.calendar)
        let referenceDate = MockData.today
        let logs = [
            WeightLog(metadata: BaseMetadata(), date: MockData.makeDate(year: 2026, month: 6, day: 21), weightKg: 95, source: MockData.healthSource),
            WeightLog(metadata: BaseMetadata(), date: MockData.makeDate(year: 2026, month: 6, day: 22), weightKg: 82, source: MockData.healthSource),
            WeightLog(metadata: BaseMetadata(), date: MockData.makeDate(year: 2026, month: 6, day: 25), weightKg: 81, source: MockData.healthSource),
            WeightLog(metadata: BaseMetadata(), date: referenceDate, weightKg: 80, source: MockData.healthSource)
        ]

        XCTAssertEqual(engine.sevenDayMovingAverageWeight(from: logs, referenceDate: referenceDate) ?? 0, 81, accuracy: 0.001)
    }

    func testGymHealthDailyCalorieDelta() {
        let engine = GymHealthEngine(calendar: MockData.calendar)
        let todayLog = MockData.dailyHealthLogs.first { MockData.calendar.isDate($0.date, inSameDayAs: MockData.today) }
        let target = engine.dailyCalorieTarget(for: MockData.today, log: todayLog, goal: MockData.weightGoal)

        XCTAssertEqual(target, 2_000)
        XCTAssertEqual(engine.dailyCalorieDelta(consumed: todayLog?.totalCalories, target: target), -160)
    }

    func testGymHealthWeeklyCalorieDelta() {
        let engine = GymHealthEngine(calendar: MockData.calendar)
        let target = engine.weeklyCalorieTarget(
            goal: MockData.weightGoal,
            dailyHealthLogs: MockData.dailyHealthLogs,
            referenceDate: MockData.today
        )
        let consumed = engine.weeklyCaloriesConsumed(from: MockData.dailyHealthLogs, referenceDate: MockData.today)

        XCTAssertEqual(target, 15_500)
        XCTAssertEqual(consumed, 13_790)
        XCTAssertEqual(engine.weeklyCalorieDelta(consumed: consumed, target: target), -1_710)
    }

    func testGymHealthGymProgressAndWeightRemaining() {
        let engine = GymHealthEngine(calendar: MockData.calendar)
        let progress = engine.progress(
            weightGoal: MockData.weightGoal,
            weightLogs: MockData.weightLogs,
            dailyHealthLogs: MockData.dailyHealthLogs,
            referenceDate: MockData.today
        )

        XCTAssertEqual(progress.currentWeightKg, 81.8)
        XCTAssertEqual(progress.weightRemainingKg ?? 0, 3.8, accuracy: 0.001)
        XCTAssertEqual(progress.completedWorkouts, 4)
        XCTAssertEqual(progress.targetWorkouts, 5)
    }

    func testGymHealthEstimatedImpactFromCalorieDelta() {
        let engine = GymHealthEngine(calendar: MockData.calendar)

        XCTAssertEqual(engine.estimatedWeightImpactKg(fromCalorieDelta: -1_710), -0.222, accuracy: 0.001)
    }

    func testGymHealthTrackStatusStates() {
        let engine = GymHealthEngine(calendar: MockData.calendar)

        XCTAssertEqual(
            engine.trackStatus(
                currentWeightKg: 82,
                targetWeightKg: 78,
                targetDate: nil,
                estimatedTargetDate: nil,
                weeklyCalorieDelta: -100,
                completedWorkouts: 5,
                targetWorkouts: 5
            ),
            .onTrack
        )
        XCTAssertEqual(
            engine.trackStatus(
                currentWeightKg: 82,
                targetWeightKg: 78,
                targetDate: nil,
                estimatedTargetDate: nil,
                weeklyCalorieDelta: -1_000,
                completedWorkouts: 5,
                targetWorkouts: 5
            ),
            .ahead
        )
        XCTAssertEqual(
            engine.trackStatus(
                currentWeightKg: 82,
                targetWeightKg: 78,
                targetDate: nil,
                estimatedTargetDate: nil,
                weeklyCalorieDelta: 1_000,
                completedWorkouts: 5,
                targetWorkouts: 5
            ),
            .behind
        )
    }

    func testGymHealthOrderGeneratorBehindStateCreatesStrictCorrection() {
        let generator = GymHealthDailyOrderGenerator(calendar: MockData.calendar)
        let plan = generator.generate(
            progress: makeProgress(trackStatus: .behind, weeklyCalorieDelta: 900, completedWorkouts: 2, targetWorkouts: 5),
            date: MockData.today,
            todayHealth: nil,
            hasWeightLogToday: true,
            existingPlan: nil
        )

        XCTAssertEqual(plan.orders.first?.title, "Correct the plan today.")
        XCTAssertEqual(plan.orders.first?.priority, .urgent)
        XCTAssertTrue(plan.summary?.contains("You are behind") == true)
    }

    func testGymHealthOrderGeneratorOnTrackMaintainsPlan() {
        let generator = GymHealthDailyOrderGenerator(calendar: MockData.calendar)
        let plan = generator.generate(
            progress: makeProgress(trackStatus: .onTrack, weeklyCalorieDelta: -100, completedWorkouts: 5, targetWorkouts: 5),
            date: MockData.today,
            todayHealth: DailyHealthLog(metadata: BaseMetadata(), date: MockData.today, totalCalories: 2_000, gymAttended: true, sleepHours: 7.4, sleepQuality: .good, source: MockData.healthSource),
            hasWeightLogToday: true,
            existingPlan: nil
        )

        XCTAssertEqual(plan.orders.first?.title, "Hold the plan today.")
        XCTAssertTrue(plan.summary?.contains("You are on track") == true)
        XCTAssertTrue(plan.orders.first?.checklist.contains { $0.title.contains("Maintain calories") } == true)
    }

    func testGymHealthOrderGeneratorOverCalorieDayCreatesCalorieItem() {
        let generator = GymHealthDailyOrderGenerator(calendar: MockData.calendar)
        let plan = generator.generate(
            progress: makeProgress(trackStatus: .behind, dailyCalorieDelta: 450, weeklyCalorieDelta: 900),
            date: MockData.today,
            todayHealth: DailyHealthLog(metadata: BaseMetadata(), date: MockData.today, totalCalories: 2_450, gymAttended: false, sleepHours: 7, sleepQuality: .normal, source: MockData.healthSource),
            hasWeightLogToday: true,
            existingPlan: nil
        )

        XCTAssertTrue(plan.orders.first?.checklist.contains { $0.title.contains("Correct calories by 450") } == true)
    }

    func testGymHealthOrderGeneratorMissingWeightCreatesWeightItem() {
        let generator = GymHealthDailyOrderGenerator(calendar: MockData.calendar)
        let plan = generator.generate(
            progress: makeProgress(trackStatus: .onTrack),
            date: MockData.today,
            todayHealth: DailyHealthLog(metadata: BaseMetadata(), date: MockData.today, totalCalories: 2_000, gymAttended: true, sleepHours: 7, sleepQuality: .good, source: MockData.healthSource),
            hasWeightLogToday: false,
            existingPlan: nil
        )

        XCTAssertTrue(plan.orders.first?.checklist.contains { $0.title == "Log today's weight. No guessing." } == true)
    }

    func testGymHealthOrderGeneratorGymAtRiskCreatesGymItem() {
        let generator = GymHealthDailyOrderGenerator(calendar: MockData.calendar)
        let plan = generator.generate(
            progress: makeProgress(trackStatus: .behind, completedWorkouts: 3, targetWorkouts: 5),
            date: MockData.today,
            todayHealth: DailyHealthLog(metadata: BaseMetadata(), date: MockData.today, totalCalories: 2_000, gymAttended: false, sleepHours: 7, sleepQuality: .good, source: MockData.healthSource),
            hasWeightLogToday: true,
            existingPlan: nil
        )

        XCTAssertTrue(plan.orders.first?.checklist.contains { $0.title.contains("Train today") } == true)
    }

    @MainActor
    func testGeneratedChecklistPersistsThroughAppStorePersistence() {
        let persistence = InMemoryAppStatePersistence(state: nil)
        let store = AppStore(currentDate: MockData.today, persistence: persistence)
        let itemID = store.dailyOrderPlan.orders[0].checklist[0].id

        store.toggleDailyChecklistItem(itemID)

        let savedState = persistence.savedStates.last
        let restoredPersistence = InMemoryAppStatePersistence(state: savedState)
        let restoredStore = AppStore(currentDate: MockData.today, persistence: restoredPersistence)

        XCTAssertEqual(restoredStore.dailyOrderPlan.orders[0].checklist.first { $0.id == itemID }?.status, .done)
    }

    @MainActor
    func testQAGymHealthWorkflowRecalculatesOrderAndRestoresChecklist() {
        let persistence = InMemoryAppStatePersistence(state: nil)
        let store = AppStore(currentDate: MockData.today, persistence: persistence)

        store.upsertWeightLog(date: MockData.today, weightKg: 80.4, enteredAt: MockData.today)
        store.upsertDailyHealthLog(
            date: MockData.today,
            totalCalories: 2_600,
            gymAttended: false,
            workoutDurationMinutes: nil,
            workoutType: nil,
            sleepHours: 5.8,
            sleepQuality: .bad,
            enteredAt: MockData.today
        )

        XCTAssertEqual(store.gymHealthState.progress.currentWeightKg, 80.4)
        XCTAssertEqual(store.gymHealthState.progress.dailyCalorieDelta, 600)
        XCTAssertTrue(store.dailyOrderPlan.orders[0].checklist.contains { $0.title.contains("Correct calories by 600") })
        XCTAssertTrue(store.dailyOrderPlan.orders[0].checklist.contains { $0.title.contains("Train today") })
        XCTAssertTrue(store.dailyOrderPlan.orders[0].checklist.contains { $0.title.contains("Protect sleep") })

        let itemID = store.dailyOrderPlan.orders[0].checklist[0].id
        store.toggleDailyChecklistItem(itemID)

        let restoredStore = AppStore(
            currentDate: MockData.today,
            persistence: InMemoryAppStatePersistence(state: persistence.savedStates.last)
        )

        XCTAssertEqual(restoredStore.weightLog(on: MockData.today)?.weightKg, 80.4)
        XCTAssertEqual(restoredStore.dailyHealthLog(on: MockData.today)?.totalCalories, 2_600)
        XCTAssertEqual(restoredStore.dailyOrderPlan.orders[0].checklist.first { $0.id == itemID }?.status, .done)
    }

    @MainActor
    func testQAUniversityWorkflowUpdatesDashboardAndWaitingState() {
        let store = AppStore(currentDate: MockData.today)

        let task = store.addUniversityTask(
            title: "QA Certificado",
            category: .document,
            status: .pending,
            priority: .critical,
            dueDate: MockData.today,
            notes: "Original",
            waitingSince: nil,
            createdAt: MockData.today
        )

        XCTAssertEqual(store.dashboardState.activeCriticalTasks.count, 3)

        var editedTask = task
        editedTask.title = "QA Certificado final"
        editedTask.notes = "Edited"
        editedTask.priority = .high
        store.updateUniversityTask(editedTask, updatedAt: MockData.today)

        XCTAssertEqual(store.universityTask(id: task.id)?.title, "QA Certificado final")
        XCTAssertEqual(store.dashboardState.activeCriticalTasks.count, 2)

        let waitingSince = MockData.makeDate(year: 2026, month: 6, day: 27)
        store.updateAcademicTaskStatus(task.id, status: .waitingResponse, waitingSince: waitingSince, updatedAt: MockData.today)

        XCTAssertEqual(store.universityTask(id: task.id)?.waitingSince, waitingSince)
        XCTAssertTrue(store.universityState.waitingResponses.contains { $0.title == "QA Certificado final" })

        store.markAcademicTaskCompleted(task.id)

        XCTAssertEqual(store.universityTask(id: task.id)?.status, .completed)
        XCTAssertEqual(store.dashboardState.activeCriticalTasks.count, 2)
    }

    @MainActor
    func testQAMoneyWorkflowUpdatesBalancesDashboardAndRestore() {
        let persistence = InMemoryAppStatePersistence(state: nil)
        let store = AppStore(currentDate: MockData.today, persistence: persistence)
        let initialDashboardTotal = store.dashboardState.moneyTotals.arsEquivalentMinorUnits

        let account = store.addMoneyAccount(
            name: "QA Wallet",
            currency: .ars,
            currentBalance: 10_000,
            createdAt: MockData.today
        )
        var editedAccount = account
        editedAccount.name = "QA Wallet edited"
        editedAccount.currentBalance = MoneyAmount(minorUnits: 15_000, currency: .ars)
        store.updateMoneyAccount(editedAccount, updatedAt: MockData.today)

        let usdtAccount = store.addMoneyAccount(
            name: "QA USDT",
            currency: .usdt,
            currentBalance: 10,
            createdAt: MockData.today
        )

        store.addIncomeTransaction(title: "QA income", amount: 500, toAccountID: account.id, category: .otro, date: MockData.today)
        store.addExpenseTransaction(title: "QA expense", amount: 300, fromAccountID: account.id, category: .otro, date: MockData.today)
        store.addTransferTransaction(title: "QA transfer", amount: 200, fromAccountID: account.id, toAccountID: MockData.accountBankARS, date: MockData.today)
        let adjustment = store.addBalanceAdjustmentTransaction(title: "QA adjustment", accountID: account.id, newBalance: 20_000, date: MockData.today)

        XCTAssertEqual(store.moneyAccount(id: account.id)?.name, "QA Wallet edited")
        XCTAssertEqual(store.moneyAccount(id: account.id)?.currentBalance.minorUnits, 20_000)
        XCTAssertEqual(store.moneyAccount(id: usdtAccount.id)?.currentBalance.minorUnits, 10)
        XCTAssertEqual(adjustment?.amount.minorUnits, 5_000)
        XCTAssertGreaterThan(store.dashboardState.moneyTotals.arsEquivalentMinorUnits, initialDashboardTotal)

        let restoredStore = AppStore(
            currentDate: MockData.today,
            persistence: InMemoryAppStatePersistence(state: persistence.savedStates.last)
        )

        XCTAssertEqual(restoredStore.moneyAccount(id: account.id)?.currentBalance.minorUnits, 20_000)
        XCTAssertTrue(restoredStore.moneyTransactions.contains { $0.title == "QA adjustment" })
        XCTAssertEqual(restoredStore.dashboardState.moneyTotals.arsEquivalentMinorUnits, store.dashboardState.moneyTotals.arsEquivalentMinorUnits)
    }

    func testUniversityV1ChoiceSets() {
        XCTAssertEqual(AcademicTaskCategory.allCases.map(\.rawValue), ["Académico", "Trámite", "Documento", "Deadline", "Email", "Otro"])
        XCTAssertEqual(AcademicTaskPriority.allCases.map(\.rawValue), ["Crítica", "Alta", "Media", "Baja"])
        XCTAssertEqual(AcademicTaskStatus.allCases.map(\.rawValue), ["Pendiente", "En progreso", "Esperando respuesta", "Completada"])
    }

    @MainActor
    func testStoreTogglesDailyChecklistItems() {
        let store = AppStore()
        let itemID = store.dailyOrderPlan.orders[0].checklist[0].id

        XCTAssertEqual(store.dailyOrdersState.completedItems, 0)

        store.toggleDailyChecklistItem(itemID)

        XCTAssertEqual(store.dailyOrderPlan.orders[0].checklist[0].status, .done)
        XCTAssertEqual(store.dailyOrdersState.completedItems, 1)
        XCTAssertGreaterThan(store.dashboardState.dailyOrderPlan.completionRatio, 0)
    }

    @MainActor
    func testStoreMarksAcademicTasksCompleted() {
        let store = AppStore()
        let taskID = store.criticalTasks[0].id

        XCTAssertEqual(store.dashboardState.activeCriticalTasks.count, 2)

        store.markAcademicTaskCompleted(taskID)

        XCTAssertEqual(store.criticalTasks[0].status, .completed)
        XCTAssertEqual(store.dashboardState.activeCriticalTasks.count, 1)
        XCTAssertEqual(store.universityState.activeCriticalTasks.count, 1)
    }

    @MainActor
    func testStoreAddsUniversityTask() {
        let store = AppStore(currentDate: MockData.today)

        let task = store.addUniversityTask(
            title: "Enviar certificado",
            category: .document,
            status: .pending,
            priority: .medium,
            dueDate: MockData.makeDate(year: 2026, month: 7, day: 8),
            notes: "Subir PDF",
            waitingSince: nil,
            createdAt: MockData.today
        )

        XCTAssertEqual(store.universityTask(id: task.id)?.title, "Enviar certificado")
        XCTAssertEqual(store.universityState.upcomingDeadlines.last?.category, .document)
    }

    @MainActor
    func testStoreEditsUniversityTask() {
        let store = AppStore(currentDate: MockData.today)
        var task = store.upcomingDeadlines[0]

        task.title = "Lectura Economia final"
        task.category = .academic
        task.priority = .high
        task.notes = "Leer capitulos 2 y 3"

        store.updateUniversityTask(task, updatedAt: MockData.today)

        let updatedTask = store.universityTask(id: task.id)
        XCTAssertEqual(updatedTask?.title, "Lectura Economia final")
        XCTAssertEqual(updatedTask?.priority, .high)
        XCTAssertEqual(updatedTask?.notes, "Leer capitulos 2 y 3")
    }

    @MainActor
    func testStoreChangesUniversityTaskStatus() {
        let store = AppStore(currentDate: MockData.today)
        let taskID = store.upcomingDeadlines[0].id

        store.updateAcademicTaskStatus(taskID, status: .inProgress, updatedAt: MockData.today)

        XCTAssertEqual(store.universityTask(id: taskID)?.status, .inProgress)
        XCTAssertNil(store.universityTask(id: taskID)?.completedAt)
    }

    @MainActor
    func testStoreChangesUniversityTaskPriorityAndDashboardCriticalCount() {
        let store = AppStore(currentDate: MockData.today)
        let taskID = store.upcomingDeadlines[0].id

        XCTAssertEqual(store.dashboardState.activeCriticalTasks.count, 2)

        store.updateAcademicTaskPriority(taskID, priority: .critical, updatedAt: MockData.today)

        XCTAssertEqual(store.universityTask(id: taskID)?.priority, .critical)
        XCTAssertEqual(store.dashboardState.activeCriticalTasks.count, 3)
        XCTAssertEqual(store.universityState.activeCriticalTasks.count, 3)
    }

    @MainActor
    func testStoreSetsWaitingResponseDate() {
        let store = AppStore(currentDate: MockData.today)
        let taskID = store.upcomingDeadlines[0].id
        let waitingSince = MockData.makeDate(year: 2026, month: 6, day: 25)

        store.updateAcademicTaskStatus(taskID, status: .waitingResponse, waitingSince: waitingSince, updatedAt: MockData.today)

        XCTAssertEqual(store.universityTask(id: taskID)?.status, .waitingResponse)
        XCTAssertEqual(store.universityTask(id: taskID)?.waitingSince, waitingSince)
        XCTAssertEqual(store.universityState.waitingResponses.first?.title, "Lectura Economia")
    }

    @MainActor
    func testStoreAddsUniversityClass() {
        let store = AppStore(currentDate: MockData.today)

        let universityClass = store.addUniversityClass(
            name: "  Analisis Matematico  ",
            shortName: "  ANA  ",
            instructor: "  Prof. Ruiz  ",
            location: "  Aula 7  ",
            color: .primary,
            notes: "  Integrales  ",
            createdAt: MockData.today
        )

        let storedClass = store.universityClass(id: universityClass.id)
        XCTAssertEqual(storedClass?.name, "Analisis Matematico")
        XCTAssertEqual(storedClass?.shortName, "ANA")
        XCTAssertEqual(storedClass?.instructor, "Prof. Ruiz")
        XCTAssertEqual(storedClass?.location, "Aula 7")
        XCTAssertEqual(storedClass?.color, .primary)
        XCTAssertEqual(storedClass?.notes, "Integrales")
        XCTAssertEqual(store.universityState.classes.count, MockData.universityClasses.count + 1)
    }

    @MainActor
    func testStoreAddsUniversityScheduleSession() throws {
        let store = AppStore(currentDate: MockData.today)
        let universityClass = store.addUniversityClass(name: "Fisica", shortName: "FIS", createdAt: MockData.today)

        let session = try XCTUnwrap(
            store.addUniversityScheduleSession(
                classID: universityClass.id,
                weekday: .monday,
                startMinuteOfDay: 9 * 60,
                endMinuteOfDay: 10 * 60 + 30,
                locationOverride: "  Lab 4  ",
                createdAt: MockData.today
            )
        )

        XCTAssertEqual(session.classID, universityClass.id)
        XCTAssertEqual(session.weekday, .monday)
        XCTAssertEqual(session.locationOverride, "Lab 4")
        XCTAssertTrue(store.upcomingClassesThisWeek(from: MockData.today).contains { $0.session.id == session.id })
    }

    @MainActor
    func testStoreComputesTodaysClasses() {
        let store = AppStore(currentDate: MockData.today)

        let todaysClasses = store.todayClasses(on: MockData.today)

        XCTAssertTrue(todaysClasses.contains { $0.universityClass.id == MockData.algebraClassID })
        XCTAssertTrue(todaysClasses.allSatisfy { $0.session.weekday == .sunday })
    }

    @MainActor
    func testStoreComputesUpcomingClassesThisWeek() {
        let store = AppStore(currentDate: MockData.today)

        let upcomingClasses = store.upcomingClassesThisWeek(from: MockData.today)
        let upcomingIDs = Set(upcomingClasses.map(\.universityClass.id))

        XCTAssertTrue(upcomingIDs.isSuperset(of: [MockData.algebraClassID, MockData.programmingClassID, MockData.economicsClassID]))
        XCTAssertEqual(upcomingClasses.first?.universityClass.id, MockData.algebraClassID)
        XCTAssertTrue(upcomingClasses.allSatisfy { scheduledClass in
            let days = MockData.calendar.dateComponents(
                [.day],
                from: MockData.calendar.startOfDay(for: MockData.today),
                to: MockData.calendar.startOfDay(for: scheduledClass.occurrenceDate)
            ).day ?? -1

            return days >= 0 && days < 7
        })
    }

    @MainActor
    func testUniversitySchedulePersistsAndRestores() throws {
        let persistence = InMemoryAppStatePersistence(state: nil)
        let store = AppStore(currentDate: MockData.today, persistence: persistence)
        let universityClass = store.addUniversityClass(name: "Historia", shortName: "HIS", location: "Aula 12", createdAt: MockData.today)
        let session = try XCTUnwrap(
            store.addUniversityScheduleSession(
                classID: universityClass.id,
                weekday: .tuesday,
                startMinuteOfDay: 16 * 60,
                endMinuteOfDay: 18 * 60,
                createdAt: MockData.today
            )
        )

        let restoredStore = AppStore(
            currentDate: MockData.today,
            persistence: InMemoryAppStatePersistence(state: persistence.savedStates.last)
        )

        XCTAssertEqual(restoredStore.universityClass(id: universityClass.id)?.name, "Historia")
        XCTAssertTrue(restoredStore.universityScheduleSessions.contains { $0.id == session.id })
        XCTAssertTrue(restoredStore.upcomingClassesThisWeek(from: MockData.today).contains { $0.session.id == session.id })
    }

    @MainActor
    func testStoreUpdatesTodaysWeight() {
        let store = AppStore(currentDate: MockData.today)

        store.upsertWeightLog(date: MockData.today, weightKg: 80.4, enteredAt: MockData.today)

        XCTAssertEqual(store.weightLog(on: MockData.today)?.weightKg, 80.4)
        XCTAssertEqual(store.dashboardState.latestWeight?.weightKg, 80.4)
        XCTAssertEqual(store.gymHealthState.latestWeight?.weightKg, 80.4)
    }

    @MainActor
    func testStoreUpdatesTodaysCalories() {
        let store = AppStore(currentDate: MockData.today)

        store.upsertDailyHealthLog(
            date: MockData.today,
            totalCalories: 2150,
            gymAttended: false,
            workoutDurationMinutes: nil,
            workoutType: nil,
            sleepHours: nil,
            sleepQuality: nil,
            enteredAt: MockData.today
        )

        XCTAssertEqual(store.dashboardState.todayHealth?.totalCalories, 2150)
        XCTAssertEqual(store.gymHealthState.todayHealth?.totalCalories, 2150)
    }

    @MainActor
    func testStoreUpdatesTodaysGymAttendance() {
        let store = AppStore(currentDate: MockData.today)

        store.upsertDailyHealthLog(
            date: MockData.today,
            totalCalories: nil,
            gymAttended: true,
            workoutDurationMinutes: 46,
            workoutType: .fullBody,
            sleepHours: nil,
            sleepQuality: nil,
            enteredAt: MockData.today
        )

        XCTAssertEqual(store.dashboardState.todayHealth?.gymAttended, true)
        XCTAssertEqual(store.gymHealthState.todayHealth?.workoutDurationMinutes, 46)
        XCTAssertEqual(store.gymHealthState.todayHealth?.workoutType, .fullBody)
        XCTAssertNil(store.dashboardState.todayHealth?.lateEntry)
    }

    @MainActor
    func testStoreUpdatesTodaysSleep() {
        let store = AppStore(currentDate: MockData.today)

        store.upsertDailyHealthLog(
            date: MockData.today,
            totalCalories: nil,
            gymAttended: false,
            workoutDurationMinutes: nil,
            workoutType: nil,
            sleepHours: 8.0,
            sleepQuality: .normal,
            enteredAt: MockData.today
        )

        XCTAssertEqual(store.dashboardState.todayHealth?.sleepHours, 8.0)
        XCTAssertEqual(store.gymHealthState.todayHealth?.sleepQuality, .normal)
        XCTAssertNil(store.dashboardState.todayHealth?.lateEntry)
    }

    @MainActor
    func testStoreMarksPreviousDayHealthEntriesAsLate() {
        let previousDate = MockData.makeDate(year: 2026, month: 6, day: 20)
        let store = AppStore(currentDate: MockData.today)

        store.upsertWeightLog(date: previousDate, weightKg: 83.1, enteredAt: MockData.today)
        store.upsertDailyHealthLog(
            date: previousDate,
            totalCalories: 2400,
            gymAttended: false,
            workoutDurationMinutes: nil,
            workoutType: nil,
            sleepHours: 6.5,
            sleepQuality: .bad,
            enteredAt: MockData.today
        )

        XCTAssertTrue(store.weightLog(on: previousDate)?.lateEntry?.isLateEntry == true)
        XCTAssertTrue(store.dailyHealthLog(on: previousDate)?.lateEntry?.isLateEntry == true)
        XCTAssertEqual(store.dailyHealthLog(on: previousDate)?.sleepQuality, .bad)
    }

    @MainActor
    func testWeeklyHealthSummariesUseRecentSevenDays() {
        let oldDate = MockData.makeDate(year: 2026, month: 6, day: 20)
        let store = AppStore(currentDate: MockData.today)

        store.upsertDailyHealthLog(
            date: oldDate,
            totalCalories: 9_999,
            gymAttended: true,
            workoutDurationMinutes: 60,
            workoutType: .push,
            sleepHours: 10,
            sleepQuality: .good,
            enteredAt: MockData.today
        )

        XCTAssertEqual(store.dashboardState.weeklyGymCount, 4)
        XCTAssertEqual(store.gymHealthState.gymAttendance, 4)
        XCTAssertEqual(store.gymHealthState.weeklyCalories, 13_790)
    }
}

private func parsedMoneyCommand(_ text: String) -> MoneyCommandDraft? {
    switch MoneyCommandParser.parse(text, accounts: MockData.moneyAccounts, date: MockData.today) {
    case .success(let draft):
        return draft
    case .failure:
        return nil
    }
}

private func lastAssistantMessage(in conversation: MoneyConversationState) -> String {
    conversation.messages.last { $0.role == .assistant }?.text ?? ""
}

@MainActor
private func todayTrendBalance(for accountID: EntityID, in store: AppStore) -> Int? {
    MoneyBalanceTrendCalculator.points(
        accounts: store.moneyState.activeAccounts,
        transactions: store.moneyState.transactions,
        referenceDate: store.currentDate,
        usdtToARSRate: store.moneyState.totals.mockUSDTToARSRate,
        range: .daily,
        calendar: MockData.calendar
    )
    .filter { $0.accountID == accountID && MockData.calendar.isDate($0.date, inSameDayAs: MockData.today) }
    .last?
    .balanceMinorUnits
}

private extension MoneyCommandDraft {
    var incomeCategory: IncomeCategory? {
        guard case .income(let category) = category else { return nil }
        return category
    }

    var expenseCategory: ExpenseCategory? {
        guard case .expense(let category) = category else { return nil }
        return category
    }
}

private func makeProgress(
    trackStatus: GymHealthTrackStatus,
    dailyCalorieDelta: Int? = nil,
    weeklyCalorieDelta: Int = 0,
    completedWorkouts: Int = 5,
    targetWorkouts: Int = 5
) -> GymHealthProgress {
    GymHealthProgress(
        currentWeightKg: 82,
        sevenDayAverageWeightKg: 82.2,
        weightRemainingKg: 4,
        dailyCalorieTarget: 2_000,
        weeklyCalorieTarget: 14_000,
        weeklyCaloriesConsumed: 14_000 + weeklyCalorieDelta,
        dailyCalorieDelta: dailyCalorieDelta,
        weeklyCalorieDelta: weeklyCalorieDelta,
        estimatedWeightImpactKg: Double(weeklyCalorieDelta) / 7_700,
        estimatedTargetDate: nil,
        completedWorkouts: completedWorkouts,
        targetWorkouts: targetWorkouts,
        trackStatus: trackStatus
    )
}

private func makeGeneratedHealthOrderPlan() -> AIGeneratedDailyOrderPlan {
    let engine = GymHealthEngine(calendar: MockData.calendar)
    let generator = GymHealthDailyOrderGenerator(calendar: MockData.calendar)

    return generator.generate(
        progress: engine.progress(
            weightGoal: MockData.weightGoal,
            weightLogs: MockData.weightLogs,
            dailyHealthLogs: MockData.dailyHealthLogs,
            referenceDate: MockData.today
        ),
        date: MockData.today,
        todayHealth: MockData.dailyHealthLogs.first { MockData.calendar.isDate($0.date, inSameDayAs: MockData.today) },
        hasWeightLogToday: MockData.weightLogs.contains { MockData.calendar.isDate($0.date, inSameDayAs: MockData.today) },
        existingPlan: nil
    )
}

private final class InMemoryAppStatePersistence: AppStatePersisting {
    var state: PersistedAppState?
    var savedStates: [PersistedAppState] = []

    init(state: PersistedAppState?) {
        self.state = state
    }

    func load() throws -> PersistedAppState? {
        state
    }

    func save(_ state: PersistedAppState) throws {
        savedStates.append(state)
        self.state = state
    }
}
