import SwiftUI

// MARK: - Lazy Loading View Modifiers for UrGood

/// Apply lazy loading to views with module-based code splitting
struct LazyModuleLoader<LoadedContent: View, Placeholder: View>: ViewModifier {
    let moduleName: String
    let loadedContent: () -> LoadedContent
    let placeholder: () -> Placeholder
    
    @StateObject private var lazyService = LazyLoadingService.shared
    @State private var isModuleLoaded = false
    @State private var loadingError: Error?
    
    func body(content: Content) -> some View {
        Group {
            if isModuleLoaded {
                loadedContent()
            } else if loadingError != nil {
                ErrorView(error: loadingError!, retry: loadModule)
            } else {
                LoadingView(
                    moduleName: moduleName,
                    progress: lazyService.loadingProgress[moduleName] ?? 0.0,
                    placeholder: placeholder
                )
            }
        }
        .onAppear {
            if !lazyService.loadedModules.contains(moduleName) {
                loadModule()
            } else {
                isModuleLoaded = true
            }
        }
    }
    
    private func loadModule() {
        Task {
            do {
                let _ = try await lazyService.loadModule(moduleName, type: LazyModule.self)
                await MainActor.run {
                    isModuleLoaded = true
                    loadingError = nil
                }
            } catch {
                await MainActor.run {
                    loadingError = error
                }
            }
        }
    }
}

/// Apply progressive loading for heavy content
struct ProgressiveLoader<StageContent: View>: ViewModifier {
    let loadingStages: [LoadingStage]
    let stageContent: (Int) -> StageContent
    
    @State private var currentStage = 0
    @State private var isLoading = false
    
    func body(content: Content) -> some View {
        stageContent(currentStage)
            .onAppear {
                if !isLoading {
                    loadNextStage()
                }
            }
    }
    
    private func loadNextStage() {
        guard currentStage < loadingStages.count else { return }
        
        isLoading = true
        let stage = loadingStages[currentStage]
        
        Task {
            try await Task.sleep(nanoseconds: UInt64(stage.delay * 1_000_000_000))
            
            await MainActor.run {
                currentStage += 1
                isLoading = false
                
                if currentStage < loadingStages.count {
                    loadNextStage()
                }
            }
        }
    }
}

/// Apply conditional loading based on user interaction
struct ConditionalLoader<LoadedContent: View, TriggerContent: View>: ViewModifier {
    let condition: LoadingCondition
    let loadedContent: () -> LoadedContent
    let trigger: () -> TriggerContent
    
    @State private var shouldLoad = false
    @State private var hasLoaded = false
    
    func body(content: Content) -> some View {
        Group {
            if hasLoaded {
                loadedContent()
            } else if shouldLoad {
                LoadingIndicator()
                    .onAppear {
                        loadContent()
                    }
            } else {
                trigger()
                    .onTapGesture {
                        if condition.shouldTriggerOnTap {
                            shouldLoad = true
                        }
                    }
                    .onAppear {
                        if condition.shouldTriggerOnAppear {
                            shouldLoad = true
                        }
                    }
            }
        }
    }
    
    private func loadContent() {
        Task {
            try await Task.sleep(nanoseconds: UInt64(condition.loadDelay * 1_000_000_000))
            
            await MainActor.run {
                hasLoaded = true
            }
        }
    }
}

/// Apply memory-aware loading with automatic cleanup
struct MemoryAwareLoader<LoadedContent: View>: ViewModifier {
    let memoryThreshold: Int64
    let loadedContent: () -> LoadedContent
    
    @StateObject private var lazyService = LazyLoadingService.shared
    @State private var isContentLoaded = false
    @State private var memoryPressure = false
    
    func body(content: Content) -> some View {
        Group {
            if isContentLoaded && !memoryPressure {
                loadedContent()
            } else {
                MemoryPressureView()
            }
        }
        .onAppear {
            checkMemoryAndLoad()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            handleMemoryWarning()
        }
    }
    
    private func checkMemoryAndLoad() {
        let currentMemory = getCurrentMemoryUsage()
        
        if currentMemory < memoryThreshold {
            isContentLoaded = true
            memoryPressure = false
        } else {
            memoryPressure = true
        }
    }
    
    private func handleMemoryWarning() {
        memoryPressure = true
        isContentLoaded = false
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        // Simplified memory usage calculation
        return 50 * 1024 * 1024 // 50MB placeholder
    }
}

// MARK: - Supporting Views

struct LoadingView<Placeholder: View>: View {
    let moduleName: String
    let progress: Double
    let placeholder: () -> Placeholder
    
    var body: some View {
        VStack(spacing: 16) {
            placeholder()
            
            VStack(spacing: 8) {
                Text("Loading \(moduleName)...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct ErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Loading Failed")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                retry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct LoadingIndicator: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct MemoryPressureView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "memorychip")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Memory Optimizing")
                .font(.headline)
            
            Text("Content temporarily unavailable to preserve performance")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Supporting Types

struct LoadingStage {
    let name: String
    let delay: TimeInterval
    let priority: LoadingPriority
}

enum LoadingPriority {
    case immediate
    case high
    case medium
    case low
    case background
}

struct LoadingCondition {
    let shouldTriggerOnAppear: Bool
    let shouldTriggerOnTap: Bool
    let loadDelay: TimeInterval
    
    static let immediate = LoadingCondition(
        shouldTriggerOnAppear: true,
        shouldTriggerOnTap: false,
        loadDelay: 0
    )
    
    static let onDemand = LoadingCondition(
        shouldTriggerOnAppear: false,
        shouldTriggerOnTap: true,
        loadDelay: 0.1
    )
    
    static let delayed = LoadingCondition(
        shouldTriggerOnAppear: true,
        shouldTriggerOnTap: false,
        loadDelay: 1.0
    )
}

// MARK: - View Extensions

extension View {
    /// Apply lazy module loading
    func lazyModule<LoadedContent: View, Placeholder: View>(
        _ moduleName: String,
        @ViewBuilder content: @escaping () -> LoadedContent,
        @ViewBuilder placeholder: @escaping () -> Placeholder = { ProgressView() }
    ) -> some View {
        modifier(LazyModuleLoader(
            moduleName: moduleName,
            loadedContent: content,
            placeholder: placeholder
        ))
    }
    
    /// Apply progressive loading
    func progressiveLoading<StageContent: View>(
        stages: [LoadingStage],
        @ViewBuilder content: @escaping (Int) -> StageContent
    ) -> some View {
        modifier(ProgressiveLoader(
            loadingStages: stages,
            stageContent: content
        ))
    }
    
    /// Apply conditional loading
    func conditionalLoading<LoadedContent: View, TriggerContent: View>(
        condition: LoadingCondition,
        @ViewBuilder content: @escaping () -> LoadedContent,
        @ViewBuilder trigger: @escaping () -> TriggerContent
    ) -> some View {
        modifier(ConditionalLoader(
            condition: condition,
            loadedContent: content,
            trigger: trigger
        ))
    }
    
    /// Apply memory-aware loading
    func memoryAwareLoading<LoadedContent: View>(
        threshold: Int64 = 100 * 1024 * 1024, // 100MB default
        @ViewBuilder content: @escaping () -> LoadedContent
    ) -> some View {
        modifier(MemoryAwareLoader(
            memoryThreshold: threshold,
            loadedContent: content
        ))
    }
    
    /// Apply lazy loading for heavy views
    func lazyLoad<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        conditionalLoading(
            condition: .onDemand,
            content: content,
            trigger: {
                Button("Load Content") { }
                    .buttonStyle(.borderedProminent)
            }
        )
    }
    
    /// Apply progressive disclosure for complex interfaces
    func progressiveDisclosure<Content: View>(
        @ViewBuilder content: @escaping (Int) -> Content
    ) -> some View {
        progressiveLoading(
            stages: [
                LoadingStage(name: "Essential", delay: 0, priority: .immediate),
                LoadingStage(name: "Important", delay: 0.5, priority: .high),
                LoadingStage(name: "Additional", delay: 1.0, priority: .medium),
                LoadingStage(name: "Optional", delay: 2.0, priority: .low)
            ],
            content: content
        )
    }
}

// MARK: - Mental Health Specific Extensions

extension View {
    /// Apply lazy loading for voice chat module
    func lazyVoiceChat<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        lazyModule("VoiceChat", content: content) {
            VStack {
                Image(systemName: "waveform")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                Text("Loading Voice Chat...")
                    .font(.caption)
            }
        }
    }
    
    /// Apply lazy loading for mood tracking module
    func lazyMoodTracking<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        lazyModule("MoodTracking", content: content) {
            VStack {
                Image(systemName: "heart")
                    .font(.largeTitle)
                    .foregroundColor(.pink)
                Text("Loading Mood Tracking...")
                    .font(.caption)
            }
        }
    }
    
    /// Apply lazy loading for therapy chat module
    func lazyTherapyChat<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        lazyModule("TherapyChat", content: content) {
            VStack {
                Image(systemName: "message")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                Text("Loading Therapy Chat...")
                    .font(.caption)
            }
        }
    }
    
    /// Apply lazy loading for crisis support module
    func lazyCrisisSupport<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        lazyModule("CrisisSupport", content: content) {
            VStack {
                Image(systemName: "cross.case")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                Text("Loading Crisis Support...")
                    .font(.caption)
            }
        }
    }
    
    /// Apply lazy loading for settings module
    func lazySettings<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        lazyModule("Settings", content: content) {
            VStack {
                Image(systemName: "gear")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("Loading Settings...")
                    .font(.caption)
            }
        }
    }
}
