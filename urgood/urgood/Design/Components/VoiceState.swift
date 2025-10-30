import Foundation

enum VoiceState: Equatable {
    case idle
    case listening
    case processing
    case speaking
    case interrupted
    case error
}
