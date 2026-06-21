import Foundation

enum AgentStatus: String, Codable {
    case working, blocked, idle, unknown
}

@Observable
final class Agent: Identifiable {
    let id: String // pane_id
    var name: String
    var status: AgentStatus
    var project: String
    var cwd: String
    var prompt: String?
    var options: [String]?

    init(id: String, name: String, status: AgentStatus, project: String, cwd: String) {
        self.id = id
        self.name = name
        self.status = status
        self.project = project
        self.cwd = cwd
    }
}

struct AgentMessage: Codable {
    let type: String
    let agents: [AgentData]?
    let pane_id: String?
    let agent: String?
    let project: String?
    let prompt: String?
    let options: [String]?

    struct AgentData: Codable {
        let pane_id: String
        let agent: String
        let status: String
        let cwd: String
        let project: String
    }
}

struct ResponseMessage: Codable {
    let type = "respond"
    let pane_id: String
    let text: String
}
