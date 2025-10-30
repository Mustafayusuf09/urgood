import Foundation

enum VoiceAgent: String, CaseIterable, Codable {
    case therapyCompanion
    case crisisSupport
    case moodTracker
    case sleepCoach
    
    var displayName: String {
        switch self {
        case .therapyCompanion: return "Therapy Companion"
        case .crisisSupport: return "Crisis Support"
        case .moodTracker: return "Mood Tracker"
        case .sleepCoach: return "Sleep Coach"
        }
    }
}

struct RealtimeTool: Codable {
    let type: String
    let function: RealtimeFunction
}

struct RealtimeFunction: Codable {
    let name: String
    let description: String
    let parameters: RealtimeFunctionParameters
}

struct RealtimeFunctionParameters: Codable {
    let type: String
    let properties: [String: RealtimeProperty]
    let required: [String]?
}

struct RealtimeProperty: Codable {
    let type: String
    let description: String
    let `enum`: [String]?
}

extension Array where Element == RealtimeTool {
    func jsonReady() -> [[String: Any]] {
        let encoder = JSONEncoder()
        return compactMap { tool in
            guard
                let data = try? encoder.encode(tool),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return nil }
            return object
        }
    }
}
