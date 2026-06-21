import SwiftUI

struct SettingsView: View {
    @Environment(RelayConnection.self) private var relay
    @Environment(\.dismiss) private var dismiss
    @State private var manualHost = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(relay.isConnected ? .green : .red).frame(width: 8, height: 8)
                            Text(relay.isConnected ? "Connected" : "Disconnected")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !relay.hostAddress.isEmpty {
                        HStack {
                            Text("Host")
                            Spacer()
                            Text(relay.hostAddress).foregroundStyle(.secondary).font(.caption)
                        }
                    }
                }
                Section("Manual Connect") {
                    TextField("ws://192.168.1.x:8375", text: $manualHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Connect") {
                        relay.connect(to: manualHost)
                    }
                    .disabled(manualHost.isEmpty)
                }
                Section("Discovery") {
                    Button("Scan for relay (Bonjour)") {
                        relay.startBrowsing()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
