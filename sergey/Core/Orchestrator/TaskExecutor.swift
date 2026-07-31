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
                        // Pass the user's request as "focus" so tools that analyze
                        // the screen (screen_capture) concentrate on what matters.
                        var params = parameters
                        params["focus"] = task.prompt
                        let observation = try await tool.execute(parameters: params)
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
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' HH:mm (local time)"
        let nowText = formatter.string(from: now)

        return """
        You are Sergey, a macOS automation assistant. Complete the user's request by reasoning step by step, using the available tools when they help.

        Current date and time (authoritative, from the system): \(nowText).
        Use this as the correct time. Clocks or timestamps read from screenshots may be misread by the vision model — ignore them for time-based decisions.

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
        - NEVER end with a Final Answer that merely promises to use a tool. First emit the Action, wait for the [Observation], then emit the Final Answer with the actual result.
        - If an observation is insufficient, unclear, or shows an error (e.g. a partially loaded page), do NOT give up — take another action (screen_capture again, a different search query) to obtain better information. Only conclude once you have enough evidence.
        - VISUAL / SCREEN QUESTIONS: for any request about what is on the screen (e.g. "what do you see", "what's on my screen", "find text on the screen", "check what is displayed"), you MUST call screen_capture first. Its observation includes "Visual analysis: <text description>" — base your answer on that text. Do not claim you cannot see the screen; screen_capture returns a text description you can read.
        - AFTER OPENING A PAGE: if the task requires knowing what a page contains (search results, lists, opening hours, etc.), do NOT stop after open_url — follow up with screen_capture and read the "Visual analysis" to extract the actual information, then answer from it.
        - SAFETY: NEVER use insert_text unless the user explicitly asks you to type text into an application. Typing into the frontmost app on your own initiative can corrupt the user's work (e.g. source code in an editor). Never modify or type into an app without being told to.
        - HONESTY: NEVER invent content. If an observation explicitly says content is obscured, blocked or unavailable (e.g. a privacy popup covering a page), report that honestly in the Final Answer instead of fabricating titles, numbers or names. If the request cannot be fulfilled with the available tools, say so plainly. Do NOT improvise with a tool to fake a result.
        - TIME QUESTIONS: for questions about the current time or date, answer directly from the provided "Current date and time" — do NOT use screen_capture for this.
        """
    }
}
