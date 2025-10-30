import XCTest

class UrGoodUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testAppLaunch() throws {
        // Verify the app launches successfully
        XCTAssertTrue(app.waitForExistence(timeout: 5))
    }
    
    func testOnboardingFlow() throws {
        // Test the onboarding flow
        let onboardingView = app.otherElements["OnboardingFlowView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Test welcome screen
        let welcomeText = app.staticTexts["Welcome to UrGood"]
        XCTAssertTrue(welcomeText.exists)
        
        // Test continue button
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        continueButton.tap()
        
        // Test privacy screen
        let privacyText = app.staticTexts["Privacy & Data"]
        XCTAssertTrue(privacyText.exists)
        
        // Test get started button
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.exists)
        getStartedButton.tap()
    }
    
    func testChatFlow() throws {
        throw XCTSkip("Keyboard chat UI has been removed in favor of voice-only conversations.")
    }
    
    func testMoodCheckin() throws {
        // Navigate to checkin
        let checkinTab = app.tabBars.buttons["Check-in"]
        XCTAssertTrue(checkinTab.exists)
        checkinTab.tap()
        
        // Test mood slider
        let moodSlider = app.sliders["MoodSlider"]
        XCTAssertTrue(moodSlider.exists)
        moodSlider.adjust(toNormalizedSliderPosition: 0.7)
        
        // Test mood tags
        let happyTag = app.buttons["Happy"]
        XCTAssertTrue(happyTag.exists)
        happyTag.tap()
        
        let energeticTag = app.buttons["Energetic"]
        XCTAssertTrue(energeticTag.exists)
        energeticTag.tap()
        
        // Test save button
        let saveButton = app.buttons["Save Check-in"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        
        // Verify success message
        let successMessage = app.staticTexts["Check-in saved!"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 5))
    }
    
    func testInsightsView() throws {
        // Navigate to insights
        let insightsTab = app.tabBars.buttons["Insights"]
        XCTAssertTrue(insightsTab.exists)
        insightsTab.tap()
        
        // Test insights content
        let insightsTitle = app.staticTexts["Your Insights"]
        XCTAssertTrue(insightsTitle.exists)
        
        // Test mood chart
        let moodChart = app.otherElements["MoodChart"]
        XCTAssertTrue(moodChart.exists)
        
        // Test insights list
        let insightsList = app.otherElements["InsightsList"]
        XCTAssertTrue(insightsList.exists)
    }
    
    func testStreaksView() throws {
        // Navigate to streaks
        let streaksTab = app.tabBars.buttons["Streaks"]
        XCTAssertTrue(streaksTab.exists)
        streaksTab.tap()
        
        // Test streaks content
        let streaksTitle = app.staticTexts["Your Streaks"]
        XCTAssertTrue(streaksTitle.exists)
        
        // Test current streak
        let currentStreak = app.staticTexts["Current Streak"]
        XCTAssertTrue(currentStreak.exists)
        
        // Test streak counter
        let streakCounter = app.staticTexts.matching(identifier: "StreakCounter")
        XCTAssertTrue(streakCounter.firstMatch.exists)
    }
    
    func testSettingsView() throws {
        // Navigate to settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
        
        // Test settings content
        let settingsTitle = app.staticTexts["Settings"]
        XCTAssertTrue(settingsTitle.exists)
        
        // Test profile section
        let profileSection = app.otherElements["ProfileSection"]
        XCTAssertTrue(profileSection.exists)
        
        // Test preferences section
        let preferencesSection = app.otherElements["PreferencesSection"]
        XCTAssertTrue(preferencesSection.exists)
        
        // Test about section
        let aboutSection = app.otherElements["AboutSection"]
        XCTAssertTrue(aboutSection.exists)
    }
    
    func testVoiceChat() throws {
        // Voice chat is the primary experience, so it should be visible on launch
        let voiceChatScreen = app.otherElements["VoiceChatScreen"]
        XCTAssertTrue(voiceChatScreen.waitForExistence(timeout: 5))
        
        // Ensure the immersive voice chat UI is rendered
        let voiceChatView = app.otherElements["VoiceChatView"]
        XCTAssertTrue(voiceChatView.exists)
        
        // Crisis disclaimer should be available for safety context
        let crisisDisclaimer = app.staticTexts["Not an emergency service"]
        XCTAssertTrue(crisisDisclaimer.exists)
        
        // Close button should allow ending the session
        let closeButton = app.buttons["Close voice chat"]
        XCTAssertTrue(closeButton.exists)
    }
    
    func testCrisisSupport() throws {
        throw XCTSkip("Keyboard crisis prompts removed; escalation now happens during voice-only sessions.")
    }
    
    func testPaywallFlow() throws {
        // Navigate to settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
        
        // Test upgrade button
        let upgradeButton = app.buttons["Upgrade to Premium"]
        XCTAssertTrue(upgradeButton.exists)
        upgradeButton.tap()
        
        // Test paywall view
        let paywallView = app.otherElements["PaywallView"]
        XCTAssertTrue(paywallView.waitForExistence(timeout: 5))
        
        // Test premium features
        let premiumFeatures = app.otherElements["PremiumFeatures"]
        XCTAssertTrue(premiumFeatures.exists)
        
        // Test purchase button
        let purchaseButton = app.buttons["Start Free Trial"]
        XCTAssertTrue(purchaseButton.exists)
        
        // Test close button
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.exists)
        closeButton.tap()
    }
    
    func testAccessibility() throws {
        // Test accessibility labels
        let chatTab = app.tabBars.buttons["Chat"]
        XCTAssertTrue(chatTab.label.contains("Chat"))
        
        let checkinTab = app.tabBars.buttons["Check-in"]
        XCTAssertTrue(checkinTab.label.contains("Check-in"))
        
        let insightsTab = app.tabBars.buttons["Insights"]
        XCTAssertTrue(insightsTab.label.contains("Insights"))
        
        let streaksTab = app.tabBars.buttons["Streaks"]
        XCTAssertTrue(streaksTab.label.contains("Streaks"))
        
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.label.contains("Settings"))
    }
    
    func testPerformance() throws {
        // Test app performance
        let startTime = Date()
        
        // Navigate through main tabs
        let tabs = ["Chat", "Check-in", "Insights", "Streaks", "Settings"]
        for tab in tabs {
            let tabButton = app.tabBars.buttons[tab]
            XCTAssertTrue(tabButton.exists)
            tabButton.tap()
            
            // Wait for content to load
            XCTAssertTrue(app.waitForExistence(timeout: 2))
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Performance should be under 10 seconds for all tabs
        XCTAssertLessThan(duration, 10.0)
    }
}
