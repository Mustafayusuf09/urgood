import Foundation

/// Easy way to update slang terms without overhauling the system
/// This allows for quick cultural updates as trends evolve
class SlangUpdater {
    
    // MARK: - Quick Slang Updates
    
    /// Add new slang terms to the current dictionary
    static func addSlang(_ newSlang: [String: SlangEntry]) {
        // In a real implementation, this would update the CulturalConfig
        // For now, we'll log the update
        print("🔄 Adding new slang terms: \(newSlang.keys.joined(separator: ", "))")
        
        // Example of how to add new terms:
        // CulturalConfig.currentSlang.merge(newSlang) { (_, new) in new }
    }
    
    /// Remove outdated slang terms
    static func removeSlang(_ terms: [String]) {
        print("🗑️ Removing outdated slang: \(terms.joined(separator: ", "))")
        
        // Example of how to remove terms:
        // terms.forEach { CulturalConfig.currentSlang.removeValue(forKey: $0) }
    }
    
    /// Update frequency of existing terms
    static func updateSlangFrequency(_ updates: [String: SlangFrequency]) {
        print("📊 Updating slang frequency: \(updates)")
        
        // Example of how to update frequencies:
        // updates.forEach { term, frequency in
        //     CulturalConfig.currentSlang[term]?.frequency = frequency
        // }
    }
    
    // MARK: - Seasonal Updates
    
    /// Update slang for new trends (call this periodically)
    static func updateForNewTrends() {
        // Example of adding trending terms
        let newTrends: [String: SlangEntry] = [
            "slay": SlangEntry(
                meaning: "doing something exceptionally well",
                usage: "celebration, achievement",
                example: "You absolutely slayed that presentation",
                frequency: .moderate
            ),
            "periodt": SlangEntry(
                meaning: "period, end of discussion, emphasis",
                usage: "strong validation, confidence",
                example: "You deserve better treatment, periodt",
                frequency: .low
            )
        ]
        
        addSlang(newTrends)
    }
    
    /// Remove terms that are becoming cringe or outdated
    static func removeOutdatedTerms() {
        let outdatedTerms = ["yeet", "no cap", "bet"] // Example outdated terms
        removeSlang(outdatedTerms)
    }
    
    // MARK: - Context Updates
    
    /// Update context sensitivity based on user feedback
    static func updateContextSensitivity() {
        // Example of updating when slang is appropriate
        print("🎯 Updating context sensitivity based on user feedback")
        
        // This could adjust the thresholds for when slang is appropriate
        // based on user engagement and feedback data
    }
}

// MARK: - Example Usage

extension SlangUpdater {
    
    /// Example of how to add 2025 trending terms
    static func add2025Trends() {
        let trends2025: [String: SlangEntry] = [
            "skibidi": SlangEntry(
                meaning: "something chaotic or wild",
                usage: "playful chaos, unexpected situations",
                example: "That meeting was skibidi but we handled it",
                frequency: .low
            ),
            "gabb": SlangEntry(
                meaning: "to talk or chat",
                usage: "casual conversation, socializing",
                example: "Let's gabb about your day",
                frequency: .low
            )
        ]
        
        addSlang(trends2025)
    }
    
    /// Example of seasonal cleanup
    static func seasonalCleanup() {
        // Remove terms that are becoming overused or cringe
        let overusedTerms = ["literally", "actually", "basically"]
        removeSlang(overusedTerms)
        
        // Add fresh terms
        updateForNewTrends()
    }
}
