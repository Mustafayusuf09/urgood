import Foundation
import FirebaseCore
import Combine

@MainActor
class DIContainer: ObservableObject {
    static let shared = DIContainer()
    
    // Published state for UI observation
    @Published var isAuthenticationStateChanged = false
    
    // Combine cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Multi-User Architecture
    // NEW: Unified auth service with proper user profile management
    let unifiedAuthService: UnifiedAuthService
    
    // NEW: AppSession for user-scoped state and repositories
    let appSession: AppSession
    
    // NEW: Migration service for moving legacy data
    let migrationService: DataMigrationService
    
    // MARK: - Legacy Services (being phased out)
    let chatService: ChatService
    let checkinService: CheckinService
    let billingService: any BillingServiceProtocol
    let crisisDetectionService: CrisisDetectionService
    let openAIService: OpenAIService
    let localStore: EnhancedLocalStore
    let authService: any AuthServiceProtocol
    
    // Analytics & Performance
    let analyticsService: RealAnalyticsService
    let performanceMonitor: PerformanceMonitor
    
    // API Services
    let apiService: APIService
    let apiCache: APICache
    let apiVersioning: APIVersioning
    
    // Offline Services
    let networkMonitor: NetworkMonitor
    let offlineDataSync: OfflineDataSync
    let offlineAwareAPIService: OfflineAwareAPIService
    
    // Background Processing
    let backgroundJobQueue: BackgroundJobQueue
    let cronJobScheduler: CronJobScheduler
    let remoteFeatureFlags: RemoteFeatureFlags
    
    // Audio services
    let audioRecordingService: AudioRecordingService
    let audioPlaybackService: AudioPlaybackService
    
    // Notification service
    let notificationService: NotificationService
    
    // Legal compliance service
    let legalComplianceService: LegalComplianceService
    
    // Accessibility service
    let accessibilityService: AccessibilityService
    
    // Theme service
    let themeService: ThemeService
    
    // Haptic feedback service
    let hapticService: HapticFeedbackService
    
    // Image optimization service
    let imageOptimizationService: ImageOptimizationService
    
    // Lazy loading service
    let lazyLoadingService: LazyLoadingService
    
    init() {
        print("🔧 DIContainer: Starting initialization...")
        
        // Initialize Firebase (skip if already configured)
        if FirebaseApp.app() == nil {
            print("🔥 DIContainer: Configuring Firebase...")
            FirebaseConfig.configure()
        } else {
            print("🔥 DIContainer: Firebase already configured, skipping...")
        }
        
        // MARK: - Initialize Multi-User Architecture
        print("🆕 DIContainer: Initializing multi-user architecture...")
        
        // Initialize unified auth service
        self.unifiedAuthService = UnifiedAuthService()
        print("✅ DIContainer: Unified auth service initialized")
        
        // Initialize app session with unified auth
        self.appSession = AppSession(authService: unifiedAuthService)
        print("✅ DIContainer: App session initialized")
        
        // Initialize migration service
        self.migrationService = DataMigrationService()
        print("✅ DIContainer: Migration service initialized")
        
        // MARK: - Initialize Legacy Services
        print("📦 DIContainer: Initializing legacy services...")
        self.localStore = EnhancedLocalStore.shared
        self.openAIService = OpenAIService()
        
        // Use production auth service if not in development mode (legacy)
        if DevelopmentConfig.bypassAuthentication {
            self.authService = StandaloneAuthService()
            print("🔧 DIContainer: Using standalone auth service (development mode)")
        } else {
            self.authService = ProductionAuthService()
            print("🚀 DIContainer: Using production auth service")
        }
        
        print("📦 DIContainer: Initializing audio services...")
        self.audioRecordingService = AudioRecordingService()
        self.audioPlaybackService = AudioPlaybackService()
        
        print("📦 DIContainer: Initializing app services...")
        self.notificationService = NotificationService(localStore: localStore)
        self.chatService = ChatService(localStore: localStore, openAIService: openAIService)
        self.checkinService = CheckinService(localStore: localStore, notificationService: notificationService)
        
        // Use production billing service if not in development mode
        if DevelopmentConfig.bypassPaywall {
            self.billingService = BillingService(localStore: localStore)
            print("🔧 DIContainer: Using standalone billing service (development mode)")
        } else {
            self.billingService = ProductionBillingService(localStore: localStore)
            print("🚀 DIContainer: Using production billing service")
        }
        
        self.crisisDetectionService = CrisisDetectionService()
        self.legalComplianceService = LegalComplianceService()
        
        print("📦 DIContainer: Initializing accessibility service...")
        self.accessibilityService = AccessibilityService.shared
        
        print("📦 DIContainer: Initializing theme service...")
        self.themeService = ThemeService.shared
        
        print("📦 DIContainer: Initializing haptic service...")
        self.hapticService = HapticFeedbackService.shared
        
        print("📦 DIContainer: Initializing image optimization service...")
        self.imageOptimizationService = ImageOptimizationService.shared
        
        print("📦 DIContainer: Initializing lazy loading service...")
        self.lazyLoadingService = LazyLoadingService.shared
        
        print("📦 DIContainer: Initializing analytics & performance...")
        // Initialize analytics & performance
        self.analyticsService = RealAnalyticsService.shared
        self.performanceMonitor = PerformanceMonitor.shared
        
        print("📦 DIContainer: Initializing API services...")
        // Initialize API services
        self.apiService = APIService.shared
        self.apiCache = APICache.shared
        self.apiVersioning = APIVersioning.shared
        
        print("📦 DIContainer: Initializing offline services...")
        // Initialize offline services
        self.networkMonitor = NetworkMonitor.shared
        self.offlineDataSync = OfflineDataSync.shared
        self.offlineAwareAPIService = OfflineAwareAPIService.shared
        
        print("📦 DIContainer: Initializing background processing...")
        // Initialize background processing
        self.backgroundJobQueue = BackgroundJobQueue.shared
        self.cronJobScheduler = CronJobScheduler.shared
        self.remoteFeatureFlags = RemoteFeatureFlags.shared
        
        // Track app launch
        performanceMonitor.trackAppLaunch()
        
        print("✅ DIContainer: Initialization complete!")
        print("   - Auth status: \(authService.isAuthenticated)")
        
        // Set up auth state observation to trigger UI updates
        setupAuthStateObservation()
    }
    
    private func setupAuthStateObservation() {
        // Observe unified auth service (NEW multi-user architecture)
        unifiedAuthService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isAuthenticationStateChanged.toggle()
            }
            .store(in: &cancellables)
        
        // Also observe legacy auth service for backwards compatibility
        if let productionAuth = authService as? ProductionAuthService {
            productionAuth.$isAuthenticated
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.isAuthenticationStateChanged.toggle()
                }
                .store(in: &cancellables)
        } else if let standaloneAuth = authService as? StandaloneAuthService {
            standaloneAuth.$isAuthenticated
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.isAuthenticationStateChanged.toggle()
                }
                .store(in: &cancellables)
        }
    }
}
