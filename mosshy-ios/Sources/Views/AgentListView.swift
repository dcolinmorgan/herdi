import SwiftUI

struct AgentListView: View {
    @Environment(RelayConnection.self) private var relay
    @State private var selectedAgent: Agent?
    @State private var showSettings = false

    private var blocked: [Agent] { relay.agents.filter { $0.status == .blocked } }
    private var working: [Agent] { relay.agents.filter { $0.status == .working } }
    private var idle: [Agent] { relay.agents.filter { $0.status == .idle || $0.status == .unknown } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if !blocked.isEmpty {
                        Section { agentCards(blocked) } header: { sectionHeader("Needs You", color: .red) }
                    }
                    if !working.isEmpty {
                        Section { agentCards(working) } header: { sectionHeader("Working", color: .green) }
                    }
                    if !idle.isEmpty {
                        Section { agentCards(idle) } header: { sectionHeader("Idle", color: .gray) }
                    }
                    if relay.agents.isEmpty {
                        ContentUnavailableView("No Agents", systemImage: "antenna.radiowaves.left.and.right",
                            description: Text(relay.isConnected ? "Waiting for herdr agents…" : "Not connected to relay"))
                    }
                }
                .padding()
            }
            .navigationTitle("mosshy")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Circle()
                        .fill(relay.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                }
            }
            .sheet(item: $selectedAgent) { agent in
                ApprovalView(agent: agent)
                    .environment(relay)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environment(relay)
            }
        }
    }

    private func agentCards(_ agents: [Agent]) -> some View {
        ForEach(agents) { agent in
            AgentCard(agent: agent)
                .onTapGesture {
                    if agent.status == .blocked { selectedAgent = agent }
                }
        }
    }

    private func sectionHeader(_ title: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.headline).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct AgentCard: View {
    let agent: Agent

    private var statusColor: Color {
        switch agent.status {
        case .blocked: .red
        case .working: .green
        case .idle, .unknown: .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.project.isEmpty ? agent.name : agent.project)
                    .font(.body.weight(.medium))
                Text(agent.name)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if agent.status == .blocked {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
