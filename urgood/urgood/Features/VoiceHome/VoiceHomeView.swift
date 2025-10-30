import SwiftUI

/// Voice home screen now surfaces the live chat experience directly.
/// The dedicated VoiceChatView handles activation and audio flow.
struct VoiceHomeView: View {
    var body: some View {
        VoiceChatView()
    }
}

#Preview {
    VoiceHomeView()
}
