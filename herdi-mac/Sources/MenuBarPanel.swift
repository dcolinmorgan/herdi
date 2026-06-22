import SwiftUI

struct MenuBarPanel: View {
    let relay: RelayConnection
    @Binding var launchAtLogin: Bool
    @State private var selectedAgent: Agent?
    private let updater = Updater.shared

    private var blocked: [Agent] { relay.agents.filter { $0.status == .blocked } }
    private var working: [Agent] { relay.agents.filter { $0.status == .working } }
    private var idle: [Agent] { relay.agents.filter { $0.status == .idle || $0.status == .unknown } }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle().fill(relay.isConnected ? .green : .red).frame(width: 6, height: 6)
                Text("herdi").font(.headline)
                Spacer()
                Text("\(relay.agents.count) agents").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            if let agent = selectedAgent {
                ApprovalPanel(agent: agent, relay: relay) { selectedAgent = nil }
            } else {
                // Agent list
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if !blocked.isEmpty { section("Blocked", .red, blocked) }
                        if !working.isEmpty { section("Working", .green, working) }
                        if !idle.isEmpty { section("Idle", .gray, idle) }
                        if relay.agents.isEmpty {
                            Text(relay.isConnected ? "No agents running" : "Not connected")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                    }
                    .padding(12)
                }
            }

            Divider()

            // Footer
            HStack {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.switch).controlSize(.mini)
                Spacer()
                if !relay.isConnected {
                    Button("Reconnect") { relay.connect(to: relay.hostAddress) }
                        .font(.caption)
                }
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain).font(.caption)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)

            // Update bar
            HStack(spacing: 6) {
                if let status = updater.status {
                    Text(status).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if updater.updateAvailable {
                    Button("Update") { updater.performUpdate() }
                        .font(.caption).disabled(updater.isUpdating)
                } else {
                    Button("Check") { updater.checkForUpdates() }
                        .font(.caption2).buttonStyle(.plain).disabled(updater.isChecking)
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 6)
        }
        .onAppear { updater.checkForUpdates() }
    }

    private func section(_ title: String, _ color: Color, _ agents: [Agent]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(agents) { agent in
                AgentRow(agent: agent)
                    .onTapGesture {
                        if agent.status == .blocked { selectedAgent = agent }
                    }
            }
        }
    }
}

struct AgentRow: View {
    let agent: Agent

    private var color: Color {
        switch agent.status {
        case .blocked: .red
        case .working: .green
        case .idle, .unknown: .gray
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(agent.project.isEmpty ? agent.name : agent.project)
                    .font(.body)
                HStack(spacing: 4) {
                    Text(agent.name).font(.caption2).foregroundStyle(.secondary)
                    if agent.host != "local" {
                        Text("@\(agent.host)").font(.caption2).foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            if agent.status == .blocked {
                Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(.red).font(.caption)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
}

struct ApprovalPanel: View {
    let agent: Agent
    let relay: RelayConnection
    let onDismiss: () -> Void
    @State private var customResponse = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { onDismiss() } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                Text("\(agent.name) — \(agent.project)").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 8)

            ScrollView {
                Text(agent.prompt ?? "Waiting…")
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 12)

            if let options = agent.options {
                VStack(spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        Button { respond(option) } label: {
                            Text(option).frame(maxWidth: .infinity)
                        }
                        .controlSize(.regular)
                        .buttonStyle(.borderedProminent)
                        .tint(tint(for: option))
                    }
                }
                .padding(.horizontal, 12)
            }

            HStack {
                TextField("Custom response…", text: $customResponse)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { if !customResponse.isEmpty { respond(customResponse) } }
                Button("Send") { respond(customResponse) }
                    .disabled(customResponse.isEmpty)
            }
            .padding(.horizontal, 12).padding(.bottom, 8)
        }
    }

    private func respond(_ text: String) {
        relay.send(response: ResponseMessage(pane_id: agent.id, text: text))
        agent.status = .working
        agent.prompt = nil
        agent.options = nil
        onDismiss()
    }

    private func tint(for option: String) -> Color {
        if option.contains("yes") || option.contains("approve") { return .green }
        if option.contains("no") || option.contains("exit") || option.contains("cancel") { return .red }
        return .accentColor
    }
}
