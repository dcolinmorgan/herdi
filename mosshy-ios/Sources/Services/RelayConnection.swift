import Foundation
import Network
import Observation

@Observable
final class RelayConnection {
    var agents: [Agent] = []
    var isConnected = false
    var hostAddress: String = ""

    private var task: URLSessionWebSocketTask?
    private var browser: NWBrowser?
    private let session = URLSession(configuration: .default)

    init() {
        startBrowsing()
    }

    // MARK: - Bonjour Discovery

    func startBrowsing() {
        let params = NWParameters()
        params.includePeerToPeer = true
        browser = NWBrowser(for: .bonjour(type: "_mosshy._tcp", domain: nil), using: params)
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            guard let result = results.first else { return }
            if case let .service(name, type, domain, _) = result.endpoint {
                self?.resolve(name: name, type: type, domain: domain)
            }
        }
        browser?.start(queue: .main)
    }

    private func resolve(name: String, type: String, domain: String) {
        let connection = NWConnection(to: .service(name: name, type: type, domain: domain, interface: nil), using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state,
               let endpoint = connection.currentPath?.remoteEndpoint,
               case let .hostPort(host, port) = endpoint {
                let addr = "\(host)"
                    .replacingOccurrences(of: "%.*", with: "", options: .regularExpression)
                DispatchQueue.main.async {
                    self?.connect(to: "ws://\(addr):\(port)")
                }
                connection.cancel()
            }
        }
        connection.start(queue: .global())
    }

    // MARK: - WebSocket

    func connect(to urlString: String) {
        guard let url = URL(string: urlString) else { return }
        hostAddress = urlString
        task?.cancel()
        task = session.webSocketTask(with: url)
        task?.resume()
        isConnected = true
        listen()
    }

    func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
    }

    func send(response: ResponseMessage) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        task?.send(.string(String(data: data, encoding: .utf8)!)) { _ in }
    }

    private func listen() {
        task?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handle(text)
                case .data(let data):
                    self?.handle(String(data: data, encoding: .utf8) ?? "")
                @unknown default:
                    break
                }
                self?.listen()
            case .failure:
                DispatchQueue.main.async { self?.isConnected = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if let addr = self?.hostAddress, !addr.isEmpty {
                        self?.connect(to: addr)
                    }
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let msg = try? JSONDecoder().decode(AgentMessage.self, from: data) else { return }

        DispatchQueue.main.async { [self] in
            switch msg.type {
            case "agents":
                guard let list = msg.agents else { return }
                for a in list {
                    if let existing = agents.first(where: { $0.id == a.pane_id }) {
                        existing.status = AgentStatus(rawValue: a.status) ?? .unknown
                        existing.project = a.project
                    } else {
                        agents.append(Agent(
                            id: a.pane_id, name: a.agent,
                            status: AgentStatus(rawValue: a.status) ?? .unknown,
                            project: a.project, cwd: a.cwd
                        ))
                    }
                }
                // Remove stale
                let activeIds = Set(list.map(\.pane_id))
                agents.removeAll { !activeIds.contains($0.id) }

            case "blocked":
                if let pid = msg.pane_id,
                   let agent = agents.first(where: { $0.id == pid }) {
                    agent.prompt = msg.prompt
                    agent.options = msg.options
                    agent.status = .blocked
                }
            default:
                break
            }
        }
    }
}
