import Foundation

@MainActor
final class TaskExecutor {
    static let shared = TaskExecutor()
    private let llmService = LLMService.shared
    private let interpreter = ActionInterpreter.shared
    private let registry = ToolRegistry.shared
    private let statusService = AgentStatusService.shared
    private let queueManager = TaskQueueManager.shared
    private let maxIterations = 6
    private var lastEnqueue: (prompt: String, date: Date)?
    private init() {}

    /// Enqueues a request (e.g. from the overlay input). Interactive requests get high priority.
    func executeRequest(_ userInput: String, priority: Int = 9) {
        let text = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // Dedupe rapid identical submissions (e.g. double Enter).
        if let last = lastEnqueue, last.prompt == text, Date().timeIntervalSince(last.date) < 1.0 {
            return
        }
        let title = text.count > 60 ? String(text.prefix(60)) + "…" : text
        let task = QueuedTask(title: title, priority: priority, prompt: text)
        queueManager.enqueue(task)
        lastEnqueue = (prompt: text, date: Date())
        TaskDispatcher.shared.notifyEnqueued()
    }

    /// Executes ONE queued task with the real agent loop. Called by TaskDispatcher.
    func execute(task: QueuedTask) async {
        // 1. Create agent row named after the task; get its id
        let agentId = statusService.createAgent(name: task.title, workDescription: "🎯 " + task.prompt, state: .running, taskId: task.id)
        // The new agent is appended last, so its number equals the current count.
        let agentNumber = statusService.activeAgents.count
        queueManager.assignAgent(task.id, to: agentId)

        // 2. Build ReAct system prompt from the registry's tool descriptions
        let systemPrompt = buildSystemPrompt()
        var conversationText = "User request: \(task.prompt)\n"
        var finalAnswer = ""
        var didFinish = false

        do {
            loop: for _ in 0..<maxIterations {
                statusService.updateStatusMessage("💭 Agent \(agentNumber): thinking…")

                let response = try await llmService.generateScopedResponse(
                    systemPrompt: systemPrompt,
                    prompt: conversationText,
                    onChunk: nil
                )

                let cleaned = interpreter.cleanTextForDisplay(response.fullText)
                statusService.updateAgentUI(for: agentId, workDescription: cleaned)

                switch interpreter.interpretAction(from: response.fullText) {
                case .noAction:
                    // A turn is terminal only when it contains a "Final Answer".
                    // Otherwise it is plain chatter — show the model what it said
                    // and let the loop keep going.
                    if response.fullText.range(of: "Final Answer", options: .caseInsensitive) == nil {
                        conversationText += "\n" + response.fullText
                        continue
                    }
                    finalAnswer = cleaned
                    didFinish = true
                    break loop

                case .actionFound(let skillName, let parameters):
                    if skillName.range(of: "Final Answer", options: .caseInsensitive) != nil {
                        finalAnswer = cleaned
                        didFinish = true
                        break loop
                    }

                    guard let tool = registry.tool(named: skillName) else {
                        conversationText += "\n" + response.fullText
                        conversationText += "\n[Observation] Unknown tool: \(skillName)"
                        continue
                    }

                    statusService.updateStatusMessage("🔧 Agent \(agentNumber): \(skillName)…")
                    do {
                        let observation = try await tool.execute(parameters: parameters)
                        conversationText += "\n" + response.fullText
                        conversationText += "\n[Observation] \(observation)"
                        statusService.updateAgentState(for: agentId, workDescription: "🔧 \(skillName) → \(observation)")
                    } catch {
                        conversationText += "\n" + response.fullText
                        conversationText += "\n[Observation] Tool error: \(error.localizedDescription)"
                        statusService.updateAgentState(for: agentId, workDescription: "⚠️ \(skillName) failed")
                    }
                }
            }

            if didFinish {
                // 4. Success (final answer or normal completion) — deliver the final
                // answer first so the short "done" message wins as the last write
                // to the global ticker.
                CommunicationDispatcher.shared.dispatch(message: finalAnswer, priority: .normal)
                statusService.updateStatusMessage("✅ Agent \(agentNumber): done")
                queueManager.markCompleted(task.id)
                statusService.updateAgentState(for: agentId, state: .completed, workDescription: finalAnswer)
            } else {
                // 5. Failure — max iterations exhausted
                let reason = "Stopped after \(maxIterations) iterations without a final answer"
                if let retried = queueManager.markFailed(task.id, reason: reason) {
                    // Will run again — do not paint the agent .failed or send a critical.
                    statusService.updateStatusMessage("🔄 Agent \(agentNumber): retrying…")
                    statusService.updateAgentState(for: agentId, state: .inactive, workDescription: "Retrying (\(retried.retryCount)/\(retried.maxRetries))…")
                    CommunicationDispatcher.shared.dispatch(message: "Retrying (\(retried.retryCount)/\(retried.maxRetries)): \(task.title)", priority: .warning)
                } else {
                    // Permanent failure
                    statusService.updateStatusMessage("❌ Agent \(agentNumber): failed")
                    statusService.updateAgentState(for: agentId, state: .failed, workDescription: reason)
                    CommunicationDispatcher.shared.dispatch(message: "Task failed: \(task.title) — \(reason)", priority: .critical)
                }
            }
        } catch {
            // 5. Failure — thrown error (auto-retries via canRetry)
            let reason = error.localizedDescription
            if let retried = queueManager.markFailed(task.id, reason: reason) {
                // Will run again — do not paint the agent .failed or send a critical.
                statusService.updateStatusMessage("🔄 Agent \(agentNumber): retrying…")
                statusService.updateAgentState(for: agentId, state: .inactive, workDescription: "Retrying (\(retried.retryCount)/\(retried.maxRetries))…")
                CommunicationDispatcher.shared.dispatch(message: "Retrying (\(retried.retryCount)/\(retried.maxRetries)): \(task.title)", priority: .warning)
            } else {
                // Permanent failure
                statusService.updateStatusMessage("❌ Agent \(agentNumber): failed")
                statusService.updateAgentState(for: agentId, state: .failed, workDescription: reason)
                CommunicationDispatcher.shared.dispatch(message: "Task failed: \(task.title) — \(reason)", priority: .critical)
            }
        }
    }

    private func buildSystemPrompt() -> String {
        """
        You are Sergey, a macOS automation assistant. Complete the user's request by reasoning step by step, using the available tools when they help.

        Use this format for every turn:
        Thought: your concise reasoning
        Action: tool_name(param="value")

        Once the task is complete, respond with:
        Final Answer: your answer to the user

        Available tools:
        \(registry.toolDescriptions)

        Rules:
        - Emit at most one Action per turn. After each Action you will receive an [Observation] with the tool result; use it to decide the next step.
        - Only use tools from the list above. If you do not need a tool, respond directly with a Final Answer.
        - Always end with a Final Answer.
        - SAFETY: NEVER use insert_text unless the user explicitly asks you to type text into an application. Typing into the frontmost app on your own initiative can corrupt the user's work (e.g. source code in an editor). Never modify or type into an app without being told to.
        - HONESTY: if the request cannot be fulfilled with the available tools (e.g. web lookups are not available), say so plainly in the Final Answer. Do NOT improvise with a tool to fake a result.
        """
    }
}
