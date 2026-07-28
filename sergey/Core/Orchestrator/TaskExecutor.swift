import Foundation
import CoreGraphics
import AppKit
import SwiftUI

struct AgentInstruction {
    let op: String // "thought", "action", "output"
    let data: String? // For thought and output
    let name: String? // For action
    let params: Any? // For action
}

// MARK: - Task Executor

final class TaskExecutor {
    private let ollama = OllamaClient()

    private var isProcessing = false
    private var currentLivePrompt: String = "" 

    func resetProcessing() {
        isProcessing = false
    }

    func startListening() {
        guard !isProcessing else { return }
        // Audio recording functionality removed. Use other input methods.
    }

    func executeRequest() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        defer { isProcessing = false }

        // STT_final retrieval from audio is removed. 
        // The user request will be provided through other input mechanisms in the future.
        let STT_final = "" 
        var iteration = 1
        let maxIterations = 10

        if !STT_final.isEmpty {
            HistoryStore.shared.appendMessage(HistoryMessage(role: "user", content: STT_final))
        }

        while iteration <= maxIterations {
            print("[Agent] Iteration \(iteration)/\(maxIterations)")
            
            let condensedHistory = await HistoryManager.shared.checkAndSummarizeIfNeeded()
            let currentUserRequest = (iteration == 1) ? STT_final : ""
            
            var capturedImages: [Data] = []
            do {
                let captureExecutor = ScreenCaptureExecutor()
                if let result = try await captureExecutor.execute(params: ["mode": "primary"]) as? SkillResult, 
                   result.success, 
                   let imageData = result.data as? Data {
                    capturedImages.append(imageData)
                }
            } catch {
                print("[Agent] Failed to capture screenshot: \(error)")
            }

            let systemPrompt = PromptAssembler.shared.assembleSystemPrompt()
            let agent_prompt = PromptAssembler.shared.assembleAgentPrompt(userRequest: currentUserRequest, providedHistory: condensedHistory)
            
            ResponseOverlayManager.shared.show(text: MessagingManager.shared.thinkingPrompt, isLoading: true)
            
            do {
                var fullResponse = ""
                _ = try await LLMService.shared.generateScopedResponse(
                    systemPrompt: systemPrompt,
                    prompt: agent_prompt,
                    images: capturedImages,
                    onChunk: { chunk in
                        fullResponse += chunk
                    }
                )

                let cleanedResponse = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                                                 .replacingOccurrences(of: "```json", with: "")
                                                 .replacingOccurrences(of: "```", with: "")
                                                 .trimmingCharacters(in: .whitespacesAndNewlines)

                print("cleanedResponse \(cleanedResponse)")
                
                var instructions: [AgentInstruction] = []
                if let jsonData = cleanedResponse.data(using: .utf8) {
                    do {
                        if let jsonArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] {
                            for dict in jsonArray {
                                let op = dict["op"] as? String ?? ""
                                let dataStr = dict["data"] as? String
                                let name = dict["name"] as? String
                                let params = dict["params"] as? [String: Any]
                                instructions.append(AgentInstruction(op: op, data: dataStr, name: name, params: params))
                            }
                        }
                    } catch {
                        print("[Agent] Failed to parse JSON response: \(error)")
                    }
                }
                
                if instructions.isEmpty {
                    HistoryStore.shared.appendMessage(HistoryMessage(role: "assistant", content: fullResponse))
                    break
                } else {
                    var shouldTerminate = false
                    for instruction in instructions {
                        switch instruction.op {
                        case "thought":
                            if let data = instruction.data {
                                HistoryStore.shared.appendMessage(HistoryMessage(role: "system", content: data))
                            }
                        case "action":
                            guard let name = instruction.name else {
                                print("[Action] Error: No name provided")
                                continue
                            }
                            let params = instruction.params as? [String: Any] ?? [:]

                            Task {
                                if let result = await handleInstructionAction(name: name, params: params) {
                                    await MainActor.run {
                                        HistoryStore.shared.appendMessage(HistoryMessage(role: "assistant", content: "Action \(name) completed: \(result)"))
                                    }
                                }
                            }
                        case "output":
                            if let data = instruction.data {
                                ResponseOverlayManager.shared.show(text: data, isLoading: false)
                                HistoryStore.shared.appendMessage(HistoryMessage(role: "assistant", content: data))
                                shouldTerminate = true
                            }
                        default: break
                        }
                    }
                    if shouldTerminate { break }
                }
            } catch {
                print("[Agent] Error during LLM execution: \(error)")
                break
            }

            iteration += 1
        }
    }

    private func handleInstructionAction(name: String, params: [String: Any]) async -> String? {
        do {
            HistoryStore.shared.appendMessage(HistoryMessage(role: "system", content: "Skill: \(name) with params: \(params)"))
            guard let descriptor = SkillRegistry.shared.getSkill(name: name) else { return nil }
            let result = try await descriptor.execute(parameters: params)
            if let skillResult = result as? SkillResult, skillResult.success {
                return skillResult.data != nil ? "\(skillResult.data!)" : nil
            }
            return nil
        } catch {
            print("Error: \(name) \(params) \(error.localizedDescription)")
            return "Error: \(error.localizedDescription)"
        }
    }
}
