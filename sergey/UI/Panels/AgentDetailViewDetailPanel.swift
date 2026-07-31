import SwiftUI 

struct AgentDetailViewDetailPanel: View {
    let agentId: UUID
    let onBack: () -> Void
    
    @EnvironmentObject var statusService: AgentStatusService
    
    private var agent: AgentModel? {
        statusService.activeAgents.first(where: { $0.id == agentId })
    }

    var body: some View {
        VStack(spacing: 0) {
            
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 6) {
                    Text(agent?.name ?? "Agent")
                        .font(.system(size: 15, weight: .medium))

                    if let a = agent {
                        ZStack {
                            Circle()
                                .fill(a.state.color)
                                .frame(width: a.state == .running ? 16 : 10, height: a.state == .running ? 16 : 10)
                                .opacity(0.3)

                            Circle()
                                .fill(a.state.color)
                                .frame(width: 9, height: 9)
                        }
                    }
                }
                
                Spacer()
            }
            
            Divider()
                .padding(.top, 10)
                .opacity(0.25)
            
            if let a = agent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        HStack(spacing: 6) {
                            Image(systemName: a.state.icon)
                                .font(.caption2)
                            Text(a.state.title)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(a.state.color)

                        Divider().opacity(0.15)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Current Task")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(a.workDescription)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button("Copy") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(a.workDescription, forType: .string)
                                    }
                                }
                                .onTapGesture {
                                    SettingsRouter.shared.openHistory(for: a.id)
                                }

                            HStack(spacing: 10) {
                                Label("Open full history", systemImage: "arrow.up.right.square")
                                Spacer()
                                Label("Right-click: copy", systemImage: "doc.on.doc")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)

                        VStack(spacing: 10) {
                            if a.state != .running {
                                Button(action: {}) {
                                    Label("Resume Agent", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button(role: .destructive, action: {}) {
                                    Label("Stop Agent", systemImage: "stop.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Button(role: .destructive, action: {
                                statusService.removeAgent(id: a.id)
                                onBack()
                            }) {
                                Label("Remove Agent", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                Spacer()
                ContentUnavailableView(
                    "Agent not found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This agent is no longer active.")
                )
                .frame(maxHeight: .infinity)
                Spacer()
            }
        }
    }

}
