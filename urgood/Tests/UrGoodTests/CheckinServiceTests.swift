import XCTest
@testable import urgood

class CheckinServiceTests: XCTestCase {
    
    var checkinService: CheckinService!
    var mockLocalStore: MockLocalStore!
    
    override func setUpWithError() throws {
        mockLocalStore = MockLocalStore()
        checkinService = CheckinService(localStore: mockLocalStore)
    }
    
    override func tearDownWithError() throws {
        checkinService = nil
        mockLocalStore = nil
    }
    
    func testAddMoodEntry() {
        // Given
        let mood = 7
        let tags = [MoodTag.happy, MoodTag.energetic]
        
        // When
        checkinService.addMoodEntry(mood: mood, tags: tags)
        
        // Then
        XCTAssertTrue(mockLocalStore.addMoodEntryCalled)
        XCTAssertEqual(mockLocalStore.lastMoodEntry?.mood, mood)
        XCTAssertEqual(mockLocalStore.lastMoodEntry?.tags, tags)
    }
    
    func testGetMoodEntries() {
        // Given
        let mockEntries = [
            MoodEntry(mood: 5, tags: [MoodTag.sad]),
            MoodEntry(mood: 8, tags: [MoodTag.happy])
        ]
        mockLocalStore.moodEntries = mockEntries
        
        // When
        let entries = checkinService.getMoodEntries()
        
        // Then
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].mood, 5)
        XCTAssertEqual(entries[1].mood, 8)
    }
    
    func testGetMoodEntriesForDateRange() {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let mockEntries = [
            MoodEntry(mood: 5, tags: [MoodTag.sad], date: yesterday),
            MoodEntry(mood: 8, tags: [MoodTag.happy], date: today)
        ]
        mockLocalStore.moodEntries = mockEntries
        
        // When
        let entries = checkinService.getMoodEntries(from: yesterday, to: today)
        
        // Then
        XCTAssertEqual(entries.count, 2)
    }
    
    func testGetAverageMood() {
        // Given
        let mockEntries = [
            MoodEntry(mood: 5, tags: []),
            MoodEntry(mood: 7, tags: []),
            MoodEntry(mood: 9, tags: [])
        ]
        mockLocalStore.moodEntries = mockEntries
        
        // When
        let averageMood = checkinService.getAverageMood()
        
        // Then
        XCTAssertEqual(averageMood, 7.0, accuracy: 0.1)
    }
    
    func testGetMoodTrend() {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        
        let mockEntries = [
            MoodEntry(mood: 3, tags: [], date: twoDaysAgo),
            MoodEntry(mood: 5, tags: [], date: yesterday),
            MoodEntry(mood: 7, tags: [], date: today)
        ]
        mockLocalStore.moodEntries = mockEntries
        
        // When
        let trend = checkinService.getMoodTrend(days: 3)
        
        // Then
        XCTAssertEqual(trend, .improving)
    }
    
    func testGetStreakCount() {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        
        let mockEntries = [
            MoodEntry(mood: 5, tags: [], date: twoDaysAgo),
            MoodEntry(mood: 6, tags: [], date: yesterday),
            MoodEntry(mood: 7, tags: [], date: today)
        ]
        mockLocalStore.moodEntries = mockEntries
        
        // When
        let streak = checkinService.getStreakCount()
        
        // Then
        XCTAssertEqual(streak, 3)
    }
}

// MARK: - Mock Extensions

extension MockLocalStore {
    var addMoodEntryCalled: Bool {
        return moodEntries.count > 0
    }
    
    var lastMoodEntry: MoodEntry? {
        return moodEntries.last
    }
}
