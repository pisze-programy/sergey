import Foundation
import Combine
import SwiftUI

class AgentDefinitionStore: ObservableObject {
    static let shared = AgentDefinitionStore()

    private let definitionsURL: URL
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var definitions: [AgentDefinitionModel] = []
    @Published private(set) var availableModels: [String] = []
    @Published private(set) var isLoadingModels = false
    @Published private(set) var modelsError: String?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("sergey")
        self.definitionsURL = appFolder.appendingPathComponent("agent_definitions.json")

        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        load()
        refreshModels()
    }


    func add(_ definition: AgentDefinitionModel) {
        definitions.insert(definition, at: 0)
        save()
    }

    func update(_ definition: AgentDefinitionModel) {
        if let index = definitions.firstIndex(where: { $0.id == definition.id }) {
            definitions[index] = definition
            save()
        }
    }

    func delete(id: UUID) {
        definitions.removeAll(where: { $0.id == id })
        save()
    }


    private func load() {
        if let data = try? Data(contentsOf: definitionsURL),
           let decoded = try? JSONDecoder().decode([AgentDefinitionModel].self, from: data) {
            self.definitions = decoded
        }
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(definitions) else { return }
        try? encoded.write(to: definitionsURL)
    }


    /// Fetches the list of models from the configured Ollama server.
    /// Call this whenever the Ollama URL changes or the user wants to
    /// re-sync (e.g. after pulling a new model) — no app restart needed.
    func refreshModels() {
        Task {
            await MainActor.run {
                self.isLoadingModels = true
                self.modelsError = nil
            }

            let base = SettingsStore.shared.ollamaURL
            let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
            guard let url = URL(string: trimmed + "/tags") else {
                await MainActor.run {
                    self.modelsError = "Invalid URL — check Ollama URL"
                    self.isLoadingModels = false
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 5

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    await MainActor.run {
                        self.modelsError = "No response — check Ollama URL"
                        self.isLoadingModels = false
                    }
                    return
                }
                guard http.statusCode == 200 else {
                    await MainActor.run {
                        self.modelsError = "HTTP \(http.statusCode) — check Ollama URL"
                        self.isLoadingModels = false
                    }
                    return
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [[String: Any]] {
                    let names = models.compactMap { $0["name"] as? String }
                    await MainActor.run {
                        self.availableModels = names.sorted()
                        self.modelsError = nil
                        self.isLoadingModels = false
                    }
                } else {
                    await MainActor.run {
                        self.modelsError = "Unexpected response — check Ollama URL"
                        self.isLoadingModels = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.modelsError = "\(Self.shortURLError(error)) — check Ollama URL"
                    self.isLoadingModels = false
                }
            }
        }
    }

    private static func shortURLError(_ error: Error) -> String {
        let ns = error as NSError
        switch ns.code {
            case NSURLErrorCannotConnectToHost: return "Cannot connect to host"
            case NSURLErrorTimedOut: return "Timed out"
            case NSURLErrorNetworkConnectionLost: return "Connection lost"
            case NSURLErrorNotConnectedToInternet: return "No internet"
            default: return ns.localizedDescription
        }
    }
}
