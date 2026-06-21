import SwiftUI

@main
struct MosshyApp: App {
    @State private var relay = RelayConnection()

    var body: some Scene {
        WindowGroup {
            AgentListView()
                .environment(relay)
                .preferredColorScheme(.dark)
        }
    }
}
