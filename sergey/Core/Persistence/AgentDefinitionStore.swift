import Foundation
import Combine
import SwiftUI

class AgentDefinitionStore: ObservableObject {
    static let shared = AgentDefinitionStore()

    private let definitionsURL: URL
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var definitions: [AgentDefinitionModel] = []
    @Published private(set) var availableModels: [String] = []

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("sergey")
        self.definitionsURL = appFolder.appendingPathComponent("agent_definitions.json")

        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        load()
        fetchOllamaModels()
    }

    // MARK: - CRUD

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

    // MARK: - Persistence

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

    // MARK: - Ollama Models

    func fetchOllamaModels() {
        Task {
            guard let url = URL(string: SettingsStore.shared.ollamaURL.appending("/tags")) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 5

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [[String: Any]] {
                    let names = models.compactMap { $0["name"] as? String }
                    await MainActor.run {
                        self.availableModels = names.sorted()
                    }
                }
            } catch {
                // If Ollama is not reachable, just leave the list empty
            }
        }
    }

    func reloadModels() {
        fetchOllamaModels()
    }
}
