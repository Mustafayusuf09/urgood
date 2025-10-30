import SwiftUI

// MARK: - Unified Loading State Component

struct LoadingStateView: View {
    let state: LoadingState
    let message: String?
    let showProgress: Bool
    let progress: Double?
    
    init(
        state: LoadingState,
        message: String? = nil,
        showProgress: Bool = false,
        progress: Double? = nil
    ) {
        self.state = state
        self.message = message
        self.showProgress = showProgress
        self.progress = progress
    }
    
    var body: some View {
        VStack(spacing: 16) {
            switch state {
            case .loading:
                loadingView
            case .success(let successMessage):
                successView(successMessage)
            case .error(let error):
                errorView(error)
            case .empty(let emptyMessage):
                emptyView(emptyMessage)
            case .skeleton:
                skeletonView
            }
            
            if let message = message {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
    
    // MARK: - Loading Views
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            if showProgress, let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(1.2)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    .scaleEffect(1.5)
            }
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private func successView(_ successMessage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
                .scaleEffect(1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: state)
            
            Text(successMessage)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private func errorView(_ error: LoadingError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: error.iconName)
                .font(.system(size: 48))
                .foregroundColor(.red)
                .scaleEffect(1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: state)
            
            VStack(spacing: 8) {
                Text(error.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(error.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let retryAction = error.retryAction {
                Button(action: retryAction) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private func emptyView(_ emptyMessage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .scaleEffect(1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: state)
            
            Text(emptyMessage)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private var skeletonView: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonRow()
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Skeleton Loading Row

struct SkeletonRow: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.4),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isAnimating ? 100 : -100)
                        .animation(
                            .linear(duration: 1.5).repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                )
                .clipped()
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .overlay(shimmerOverlay)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 12)
                    .overlay(shimmerOverlay)
            }
            
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(0.4),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: isAnimating ? 200 : -200)
        .animation(
            .linear(duration: 1.5).repeatForever(autoreverses: false),
            value: isAnimating
        )
    }
}

// MARK: - Loading State Types

enum LoadingState: Equatable {
    case loading
    case success(String)
    case error(LoadingError)
    case empty(String)
    case skeleton
    
    static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.skeleton, .skeleton):
            return true
        case (.success(let lhsMessage), .success(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.id == rhsError.id
        case (.empty(let lhsMessage), .empty(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

struct LoadingError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let retryAction: (() -> Void)?
    
    init(
        title: String,
        description: String,
        iconName: String = "exclamationmark.triangle.fill",
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.iconName = iconName
        self.retryAction = retryAction
    }
    
    static func == (lhs: LoadingError, rhs: LoadingError) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Common error types
    static func networkError(retryAction: @escaping () -> Void) -> LoadingError {
        LoadingError(
            title: "Connection Issue",
            description: "Please check your internet connection and try again.",
            iconName: "wifi.exclamationmark",
            retryAction: retryAction
        )
    }
    
    static func serverError(retryAction: @escaping () -> Void) -> LoadingError {
        LoadingError(
            title: "Server Error",
            description: "Our servers are experiencing issues. Please try again in a moment.",
            iconName: "server.rack",
            retryAction: retryAction
        )
    }
    
    static func permissionError(action: @escaping () -> Void) -> LoadingError {
        LoadingError(
            title: "Permission Required",
            description: "This feature requires additional permissions to work properly.",
            iconName: "lock.fill",
            retryAction: action
        )
    }
    
    static func rateLimitError(resetTime: TimeInterval) -> LoadingError {
        let minutes = Int(resetTime / 60)
        let seconds = Int(resetTime.truncatingRemainder(dividingBy: 60))
        return LoadingError(
            title: "Rate Limit Reached",
            description: "Please wait \(minutes)m \(seconds)s before trying again.",
            iconName: "clock.fill"
        )
    }
}

// MARK: - Loading State Manager

@MainActor
class LoadingStateManager: ObservableObject {
    @Published var currentState: LoadingState = .loading
    @Published var progress: Double = 0.0
    
    private var timeoutTask: Task<Void, Never>?
    private let defaultTimeout: TimeInterval = 30.0
    
    func setLoading(message: String? = nil, timeout: TimeInterval? = nil) {
        currentState = .loading
        progress = 0.0
        
        // Set timeout if specified
        if let timeout = timeout ?? (message != nil ? defaultTimeout : nil) {
            timeoutTask?.cancel()
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !Task.isCancelled {
                    setError(LoadingError(
                        title: "Request Timeout",
                        description: "The request took too long to complete. Please try again.",
                        iconName: "clock.badge.exclamationmark"
                    ))
                }
            }
        }
    }
    
    func setProgress(_ newProgress: Double) {
        progress = min(1.0, max(0.0, newProgress))
    }
    
    func setSuccess(_ message: String) {
        timeoutTask?.cancel()
        currentState = .success(message)
        
        // Auto-clear success after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .success = currentState {
                currentState = .loading
            }
        }
    }
    
    func setError(_ error: LoadingError) {
        timeoutTask?.cancel()
        currentState = .error(error)
    }
    
    func setEmpty(_ message: String) {
        timeoutTask?.cancel()
        currentState = .empty(message)
    }
    
    func setSkeleton() {
        timeoutTask?.cancel()
        currentState = .skeleton
    }
    
    func reset() {
        timeoutTask?.cancel()
        currentState = .loading
        progress = 0.0
    }
    
    deinit {
        timeoutTask?.cancel()
    }
}

// MARK: - View Extensions

extension View {
    func loadingState(
        _ state: LoadingState,
        message: String? = nil,
        showProgress: Bool = false,
        progress: Double? = nil
    ) -> some View {
        ZStack {
            self
                .opacity(state == .loading || state == .skeleton ? 0.3 : 1.0)
            
            if case .loading = state {
                LoadingStateView(
                    state: state,
                    message: message,
                    showProgress: showProgress,
                    progress: progress
                )
                .background(Color(UIColor.systemBackground).opacity(0.9))
            }
        }
    }
    
    func loadingOverlay(
        isLoading: Bool,
        message: String? = nil,
        showProgress: Bool = false,
        progress: Double? = nil
    ) -> some View {
        ZStack {
            self
                .opacity(isLoading ? 0.3 : 1.0)
            
            if isLoading {
                LoadingStateView(
                    state: .loading,
                    message: message,
                    showProgress: showProgress,
                    progress: progress
                )
                .background(Color(UIColor.systemBackground).opacity(0.9))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        LoadingStateView(state: .loading, message: "Loading your data...")
        
        LoadingStateView(
            state: .success("Data loaded successfully!"),
            message: "Your information is now up to date."
        )
        
        LoadingStateView(
            state: .error(.networkError(retryAction: {})),
            message: "Please check your connection."
        )
        
        LoadingStateView(
            state: .empty("No messages yet"),
            message: "Start a conversation to see messages here."
        )
        
        LoadingStateView(state: .skeleton)
    }
    .padding()
}
