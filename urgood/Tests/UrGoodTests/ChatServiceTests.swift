import XCTest
@testable import urgood

class ChatServiceTests: XCTestCase {
    
    var chatService: ChatService!
    var mockLocalStore: MockLocalStore!
    
    override func setUpWithError() throws {
        mockLocalStore = MockLocalStore()
        chatService = ChatService(localStore: mockLocalStore)
    }
    
    override func tearDownWithError() throws {
        chatService = nil
        mockLocalStore = nil
    }
    
    func testSendMessage() async {
        // Given
        let messageText = "Hello, I'm feeling anxious today"
        
        // When
        let response = await chatService.sendMessage(messageText)
        
        // Then
        XCTAssertEqual(response.role, .assistant)
        XCTAssertFalse(response.text.isEmpty)
        XCTAssertTrue(mockLocalStore.addMessageCalled)
    }
    
    func testSendMessageWithEmptyText() async {
        // Given
        let messageText = ""
        
        // When
        let response = await chatService.sendMessage(messageText)
        
        // Then
        XCTAssertEqual(response.role, .assistant)
        XCTAssertFalse(response.text.isEmpty)
    }
    
    func testSendMessageWithCrisisKeywords() async {
        // Given
        let messageText = "I want to hurt myself"
        
        // When
        let response = await chatService.sendMessage(messageText)
        
        // Then
        XCTAssertEqual(response.role, .assistant)
        XCTAssertTrue(response.text.contains("crisis") || response.text.contains("help") || response.text.contains("support"))
    }
    
    func testGetChatHistory() {
        // Given
        let mockMessages = [
            ChatMessage(role: .user, text: "Hello"),
            ChatMessage(role: .assistant, text: "Hi there!")
        ]
        mockLocalStore.chatMessages = mockMessages
        
        // When
        let history = chatService.getChatHistory()
        
        // Then
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].text, "Hello")
        XCTAssertEqual(history[1].text, "Hi there!")
    }
    
    func testClearChatHistory() {
        // Given
        mockLocalStore.chatMessages = [
            ChatMessage(role: .user, text: "Hello"),
            ChatMessage(role: .assistant, text: "Hi there!")
        ]
        
        // When
        chatService.clearChatHistory()
        
        // Then
        XCTAssertTrue(mockLocalStore.clearChatHistoryCalled)
    }
}

// MARK: - Mock Classes

class MockLocalStore: LocalStore {
    var addMessageCalled = false
    var clearChatHistoryCalled = false
    var chatMessages: [ChatMessage] = []
    
    override func addMessage(_ message: ChatMessage) {
        addMessageCalled = true
        chatMessages.append(message)
    }
    
    override func getChatHistory() -> [ChatMessage] {
        return chatMessages
    }
    
    override func clearChatHistory() {
        clearChatHistoryCalled = true
        chatMessages.removeAll()
    }
}
