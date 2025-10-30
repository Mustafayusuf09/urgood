import Foundation

// MARK: - Chat Models
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let text: String
    let date: Date
    
    init(role: Role, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.date = Date()
    }
    
    init(id: UUID, role: Role, text: String, date: Date) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
    }
}

enum Role: String, Codable, CaseIterable {
    case user = "user"
    case assistant = "assistant"
}

// MARK: - Mood Models
struct MoodEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let mood: Int // 1-5 scale
    let tags: [MoodTag]
    
    init(mood: Int, tags: [MoodTag] = []) {
        self.id = UUID()
        self.date = Date()
        self.mood = mood
        self.tags = tags
    }
    
    init(id: UUID, date: Date, mood: Int, tags: [MoodTag]) {
        self.id = id
        self.date = date
        self.mood = mood
        self.tags = tags
    }
}

struct MoodTag: Hashable, Codable, Identifiable {
    let id: UUID
    let name: String
    
    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

// MARK: - Tool Models
struct Tool: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let kind: ToolKind
    let durationMin: Int
    let summary: String
    let premium: Bool
    
    init(title: String, kind: ToolKind, durationMin: Int, summary: String, premium: Bool = false) {
        self.id = UUID()
        self.title = title
        self.kind = kind
        self.durationMin = durationMin
        self.summary = summary
        self.premium = premium
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Tool, rhs: Tool) -> Bool {
        lhs.id == rhs.id
    }
}

enum ToolKind: String, Codable, CaseIterable {
    case breathe = "Breathe"
    case ground = "Ground"
    case reframe = "Reframe"
    case sleep = "Sleep"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Trend Models
struct TrendPoint: Identifiable, Codable {
    let id: UUID
    let date: Date
    let value: Double
    
    init(date: Date, value: Double) {
        self.id = UUID()
        self.date = date
        self.value = value
    }
}

// MARK: - Shared Types

enum RecommendationPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum CrisisSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct ChatContext {
    let userId: String
    let sessionId: String
    let timestamp: Date
    let messageHistory: [ChatMessage]
    let userProfile: UserProfile?
    
    init(userId: String, sessionId: String, messageHistory: [ChatMessage] = [], userProfile: UserProfile? = nil) {
        self.userId = userId
        self.sessionId = sessionId
        self.timestamp = Date()
        self.messageHistory = messageHistory
        self.userProfile = userProfile
    }
}

struct Experiment: Codable {
    let id: String
    let name: String
    let description: String
    let variants: [String]
    let startDate: Date
    let endDate: Date?
    let isActive: Bool
    let targetAudience: String?
    let metrics: [String]
    
    init(id: String, name: String, description: String, variants: [String], startDate: Date, endDate: Date? = nil, isActive: Bool = true, targetAudience: String? = nil, metrics: [String] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.variants = variants
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.targetAudience = targetAudience
        self.metrics = metrics
    }
}

enum ComplianceStatus: String, CaseIterable, Codable {
    case compliant = "compliant"
    case partiallyCompliant = "partially_compliant"
    case nonCompliant = "non_compliant"
}

// MARK: - Subscription Models
enum SubscriptionStatus: String, Codable, CaseIterable {
    case free = "free"
    case premium = "premium"
}

// MARK: - AI Session Models
struct SessionSummary: Identifiable, Codable {
    let id: UUID
    let title: String
    let insights: String
    let moodRating: Double
    let progressLevel: Int
    let date: Date
    
    init(title: String, insights: String, moodRating: Double, progressLevel: Int) {
        self.id = UUID()
        self.title = title
        self.insights = insights
        self.moodRating = moodRating
        self.progressLevel = progressLevel
        self.date = Date()
    }
}


// MARK: - Cultural Context

enum ConversationContext {
    case crisis
    case serious
    case casual
    case celebration
    case encouragement
    case exploration
    case goalSetting
    
    var rawValue: String {
        switch self {
        case .crisis: return "crisis"
        case .serious: return "serious"
        case .casual: return "casual"
        case .celebration: return "celebration"
        case .encouragement: return "encouragement"
        case .exploration: return "exploration"
        case .goalSetting: return "goal_setting"
        }
    }
}

// MARK: - Quiz Models
struct QuizAnswer: Identifiable, Codable {
    let id: UUID
    let questionIndex: Int
    let selectedOptionIndex: Int
    let timestamp: Date
    
    init(questionIndex: Int, selectedOptionIndex: Int) {
        self.id = UUID()
        self.questionIndex = questionIndex
        self.selectedOptionIndex = selectedOptionIndex
        self.timestamp = Date()
    }
}

// MARK: - Crisis Models
enum CrisisLevel: Int, Codable, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Toast Models
struct ToastData: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
}

enum ToastType {
    case success
    case error
    case info
}

// MARK: - User Models
struct User: Codable {
    let uid: String
    let email: String?
    let displayName: String?
    var subscriptionStatus: SubscriptionStatus
    var streakCount: Int
    var totalCheckins: Int
    var messagesThisWeek: Int
    let isEmailVerified: Bool
    let metadata: UserMetadata?
    let providerData: [UserProviderData]?
    
    init() {
        self.uid = "anonymous-\(UUID().uuidString)"
        self.email = nil
        self.displayName = nil
        self.subscriptionStatus = .free
        self.streakCount = 0
        self.totalCheckins = 0
        self.messagesThisWeek = 0
        self.isEmailVerified = false
        self.metadata = nil
        self.providerData = nil
    }
    
    init(uid: String, email: String?, displayName: String?, subscriptionStatus: SubscriptionStatus = .free, streakCount: Int = 0, totalCheckins: Int = 0, messagesThisWeek: Int = 0, isEmailVerified: Bool = false, metadata: UserMetadata? = nil, providerData: [UserProviderData]? = nil) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.subscriptionStatus = subscriptionStatus
        self.streakCount = streakCount
        self.totalCheckins = totalCheckins
        self.messagesThisWeek = messagesThisWeek
        self.isEmailVerified = isEmailVerified
        self.metadata = metadata
        self.providerData = providerData
    }
}

struct UserMetadata: Codable {
    let creationDate: Date?
    let lastSignInDate: Date?
    
    init(creationDate: Date? = nil, lastSignInDate: Date? = nil) {
        self.creationDate = creationDate
        self.lastSignInDate = lastSignInDate
    }
}

struct UserProviderData: Codable {
    let providerID: String
    let uid: String
    let displayName: String?
    let email: String?
    
    init(providerID: String, uid: String, displayName: String? = nil, email: String? = nil) {
        self.providerID = providerID
        self.uid = uid
        self.displayName = displayName
        self.email = email
    }
}

struct UserProfile: Codable {
    let uid: String
    let email: String?
    let displayName: String?
    let subscriptionStatus: SubscriptionStatus
    let streakCount: Int
    let totalCheckins: Int
    let messagesThisWeek: Int
    let isEmailVerified: Bool
    let createdAt: Date
    let lastActiveAt: Date?
    let preferences: UserPreferences?
    
    init(uid: String, email: String?, displayName: String?, subscriptionStatus: SubscriptionStatus = .free, streakCount: Int = 0, totalCheckins: Int = 0, messagesThisWeek: Int = 0, isEmailVerified: Bool = false, createdAt: Date = Date(), lastActiveAt: Date? = nil, preferences: UserPreferences? = nil) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.subscriptionStatus = subscriptionStatus
        self.streakCount = streakCount
        self.totalCheckins = totalCheckins
        self.messagesThisWeek = messagesThisWeek
        self.isEmailVerified = isEmailVerified
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.preferences = preferences
    }
}

// MARK: - Onboarding Enums
enum CheckInSpark: String, CaseIterable, Codable {
    case pepTalk = "pep_talk"
    case stayConsistent = "stay_consistent"
    case getClarity = "get_clarity"
    case justCurious = "just_curious"
    
    var emoji: String {
        switch self {
        case .pepTalk: return "⚡️"
        case .stayConsistent: return "📆"
        case .getClarity: return "🧭"
        case .justCurious: return "👀"
        }
    }
    
    var title: String {
        switch self {
        case .pepTalk: return "I need a quick pep talk"
        case .stayConsistent: return "I want to stay consistent with my goals"
        case .getClarity: return "I'm sorting my thoughts"
        case .justCurious: return "Just checking the vibes"
        }
    }
}

enum EnergyCheck: String, CaseIterable, Codable {
    case runningOnFumes = "running_on_fumes"
    case holdingItTogether = "holding_it_together"
    case feelingSteady = "feeling_steady"
    case readyToRoll = "ready_to_roll"
    
    var emoji: String {
        switch self {
        case .runningOnFumes: return "🪫"
        case .holdingItTogether: return "😌"
        case .feelingSteady: return "🙂"
        case .readyToRoll: return "🚀"
        }
    }
    
    var title: String {
        switch self {
        case .runningOnFumes: return "Running on fumes"
        case .holdingItTogether: return "Holding it together"
        case .feelingSteady: return "Feeling steady"
        case .readyToRoll: return "Ready to roll"
        }
    }
}

enum SupportTonePreference: String, CaseIterable, Codable {
    case softSupport = "soft_support"
    case realTalk = "real_talk"
    case allOutHype = "all_out_hype"
    case reflective = "reflective"
    
    var emoji: String {
        switch self {
        case .softSupport: return "🤗"
        case .realTalk: return "🎯"
        case .allOutHype: return "📣"
        case .reflective: return "✨"
        }
    }
    
    var title: String {
        switch self {
        case .softSupport: return "Soft and supportive"
        case .realTalk: return "Real talk, no fluff"
        case .allOutHype: return "High-energy hype"
        case .reflective: return "Thoughtful and reflective"
        }
    }
}

enum FocusPriority: String, CaseIterable, Codable {
    case dailyWins = "daily_wins"
    case buildConfidence = "build_confidence"
    case findBalance = "find_balance"
    case trySomethingNew = "try_something_new"
    
    var emoji: String {
        switch self {
        case .dailyWins: return "🥇"
        case .buildConfidence: return "💪"
        case .findBalance: return "🧘"
        case .trySomethingNew: return "🌟"
        }
    }
    
    var title: String {
        switch self {
        case .dailyWins: return "Stacking daily wins"
        case .buildConfidence: return "Boosting my confidence"
        case .findBalance: return "Finding a better balance"
        case .trySomethingNew: return "Trying something new"
        }
    }
}

enum BoostMoment: String, CaseIterable, Codable {
    case morningJumpstart = "morning_jumpstart"
    case middayReset = "midday_reset"
    case nightWindDown = "night_wind_down"
    case wheneverIPing = "whenever_i_ping"
    
    var emoji: String {
        switch self {
        case .morningJumpstart: return "🌅"
        case .middayReset: return "🌞"
        case .nightWindDown: return "🌙"
        case .wheneverIPing: return "🔔"
        }
    }
    
    var title: String {
        switch self {
        case .morningJumpstart: return "Morning jumpstart"
        case .middayReset: return "Midday reset"
        case .nightWindDown: return "Night wind-down"
        case .wheneverIPing: return "Whenever I ping you"
        }
    }
}

enum CelebrationStyle: String, CaseIterable, Codable {
    case emojiHype = "emoji_hype"
    case heartfeltShoutout = "heartfelt_shoutout"
    case nextStep = "next_step"
    case surpriseMe = "surprise_me"
    
    var emoji: String {
        switch self {
        case .emojiHype: return "🎉"
        case .heartfeltShoutout: return "💖"
        case .nextStep: return "✅"
        case .surpriseMe: return "🎁"
        }
    }
    
    var title: String {
        switch self {
        case .emojiHype: return "Spam me with emoji hype"
        case .heartfeltShoutout: return "Drop a heartfelt shoutout"
        case .nextStep: return "Give me the next step"
        case .surpriseMe: return "Surprise me with something fun"
        }
    }
}

enum AccountabilityStyle: String, CaseIterable, Codable {
    case gentleNudges = "gentle_nudges"
    case keepMeOnTrack = "keep_me_on_track"
    case selfLed = "self_led"
    case tagTeamPlans = "tag_team_plans"
    
    var emoji: String {
        switch self {
        case .gentleNudges: return "🌬️"
        case .keepMeOnTrack: return "🏁"
        case .selfLed: return "🧭"
        case .tagTeamPlans: return "🤝"
        }
    }
    
    var title: String {
        switch self {
        case .gentleNudges: return "Just gentle nudges"
        case .keepMeOnTrack: return "Keep me on track"
        case .selfLed: return "I'll reach out when I need"
        case .tagTeamPlans: return "Let's tag-team plans"
        }
    }
}

enum WinSignal: String, CaseIterable, Codable {
    case takingBreaks = "taking_breaks"
    case kinderSelfTalk = "kinder_self_talk"
    case finishingTasks = "finishing_tasks"
    case feelingOrganized = "feeling_organized"
    
    var emoji: String {
        switch self {
        case .takingBreaks: return "🧘"
        case .kinderSelfTalk: return "💬"
        case .finishingTasks: return "📋"
        case .feelingOrganized: return "🗂️"
        }
    }
    
    var title: String {
        switch self {
        case .takingBreaks: return "I'm taking real breaks"
        case .kinderSelfTalk: return "My self-talk is kinder"
        case .finishingTasks: return "I'm finishing small tasks"
        case .feelingOrganized: return "I feel more organized"
        }
    }
}

enum EmotionState: String, CaseIterable, Codable {
    case happy = "happy"
    case sad = "sad"
    case anxious = "anxious"
    case angry = "angry"
    case confused = "confused"
    case stuck = "stuck"
    case motivated = "motivated"
    case peaceful = "peaceful"
    
    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .sad: return "Sad"
        case .anxious: return "Anxious"
        case .angry: return "Angry"
        case .confused: return "Confused"
        case .stuck: return "Stuck"
        case .motivated: return "Motivated"
        case .peaceful: return "Peaceful"
        }
    }
    
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .sad: return "😢"
        case .anxious: return "😰"
        case .angry: return "😠"
        case .confused: return "😕"
        case .stuck: return "😤"
        case .motivated: return "💪"
        case .peaceful: return "😌"
        }
    }
    
    var title: String {
        return displayName
    }
}

enum TimeCommitment: String, CaseIterable, Codable {
    case fiveMinutes = "5_minutes"
    case tenMinutes = "10_minutes"
    case twentyMinutes = "20_minutes"
    case thirtyMinutes = "30_minutes"
    case flexible = "flexible"
    
    var displayName: String {
        switch self {
        case .fiveMinutes: return "5 minutes"
        case .tenMinutes: return "10 minutes"
        case .twentyMinutes: return "20 minutes"
        case .thirtyMinutes: return "30+ minutes"
        case .flexible: return "Flexible"
        }
    }
    
    var emoji: String {
        switch self {
        case .fiveMinutes: return "⏰"
        case .tenMinutes: return "🕐"
        case .twentyMinutes: return "🕑"
        case .thirtyMinutes: return "🕒"
        case .flexible: return "🔄"
        }
    }
    
    var title: String {
        return displayName
    }
    
    var description: String {
        switch self {
        case .fiveMinutes: return "Quick daily check-ins"
        case .tenMinutes: return "Short focused sessions"
        case .twentyMinutes: return "Deeper conversations"
        case .thirtyMinutes: return "Extended support sessions"
        case .flexible: return "Adapt to your schedule"
        }
    }
}

enum FutureVision: String, CaseIterable, Codable {
    case peace = "peace"
    case confidence = "confidence"
    case happiness = "happiness"
    case balance = "balance"
    case growth = "growth"
    case connection = "connection"
    
    var displayName: String {
        switch self {
        case .peace: return "Inner Peace"
        case .confidence: return "Confidence"
        case .happiness: return "Happiness"
        case .balance: return "Life Balance"
        case .growth: return "Personal Growth"
        case .connection: return "Better Relationships"
        }
    }
    
    var emoji: String {
        switch self {
        case .peace: return "☮️"
        case .confidence: return "💪"
        case .happiness: return "😊"
        case .balance: return "⚖️"
        case .growth: return "🌱"
        case .connection: return "🤝"
        }
    }
    
    var title: String {
        return displayName
    }
}
