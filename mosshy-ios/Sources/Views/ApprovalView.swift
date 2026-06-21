import SwiftUI

struct ApprovalView: View {
    @Environment(RelayConnection.self) private var relay
    @Environment(\.dismiss) private var dismiss
    let agent: Agent

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Prompt
                ScrollView {
                    Text(agent.prompt ?? "Waiting for approval…")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                // Option buttons
                if let options = agent.options {
                    VStack(spacing: 10) {
                        ForEach(options, id: \.self) { option in
                            Button {
                                respond(option)
                            } label: {
                                Text(option)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(tint(for: option))
                        }
                    }
                }

                // Free text input
                HStack {
                    TextField("Custom response…", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                    Button("Send") { }
                        .disabled(true)
                }
            }
            .padding()
            .navigationTitle("\(agent.name) — \(agent.project)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func respond(_ text: String) {
        relay.send(response: ResponseMessage(pane_id: agent.id, text: text))
        agent.status = .working
        agent.prompt = nil
        agent.options = nil
        dismiss()
    }

    private func tint(for option: String) -> Color {
        if option.contains("yes") || option.contains("approve") { return .green }
        if option.contains("no") || option.contains("exit") || option.contains("cancel") { return .red }
        return .blue
    }
}
