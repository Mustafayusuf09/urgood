import Foundation
import Combine
import BackgroundTasks

class BackgroundJobQueue: ObservableObject {
    static let shared = BackgroundJobQueue()
    
    // Job queue storage
    private let queue = DispatchQueue(label: "background.job.queue", qos: .background)
    private var jobQueue: [BackgroundJob] = []
    private var runningJobs: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    
    // Job processing
    private let maxConcurrentJobs = 3
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 5.0
    
    // Job types
    enum JobType: String, CaseIterable {
        case dataSync = "data_sync"
        case analytics = "analytics"
        case cleanup = "cleanup"
        case backup = "backup"
        case notification = "notification"
        case crisisCheck = "crisis_check"
        case moodAnalysis = "mood_analysis"
        case insightGeneration = "insight_generation"
    }
    
    // Job priorities
    enum JobPriority: Int, CaseIterable {
        case low = 1
        case normal = 2
        case high = 3
        case critical = 4
    }
    
    private init() {
        setupBackgroundTask()
        startJobProcessor()
    }
    
    // MARK: - Job Management
    
    func enqueueJob(_ job: BackgroundJob) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if job already exists
            if self.jobQueue.contains(where: { $0.id == job.id }) {
                print("⚠️ Job \(job.id) already exists in queue")
                return
            }
            
            // Add to queue and sort by priority
            self.jobQueue.append(job)
            self.jobQueue.sort { $0.priority.rawValue > $1.priority.rawValue }
            
            print("✅ Enqueued job: \(job.type.rawValue) (Priority: \(job.priority.rawValue))")
            
            // Process jobs if not at capacity
            self.processNextJob()
        }
    }
    
    func cancelJob(_ jobId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.jobQueue.removeAll { $0.id == jobId }
            self.runningJobs.remove(jobId)
            
            print("❌ Cancelled job: \(jobId)")
        }
    }
    
    func getJobStatus(_ jobId: String) -> JobStatus? {
        return queue.sync {
            if jobQueue.first(where: { $0.id == jobId }) != nil {
                return .queued
            } else if runningJobs.contains(jobId) {
                return .running
            } else {
                return .completed
            }
        }
    }
    
    func getQueueStatus() -> QueueStatus {
        return queue.sync {
            QueueStatus(
                totalJobs: jobQueue.count,
                runningJobs: runningJobs.count,
                completedJobs: getCompletedJobCount(),
                failedJobs: getFailedJobCount(),
                queueSize: jobQueue.count,
                isProcessing: !runningJobs.isEmpty
            )
        }
    }
    
    // MARK: - Job Processing
    
    private func startJobProcessor() {
        // Process jobs every 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processNextJob()
            }
            .store(in: &cancellables)
    }
    
    private func processNextJob() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if we can process more jobs
            guard self.runningJobs.count < self.maxConcurrentJobs else {
                return
            }
            
            // Get next job to process
            guard let job = self.jobQueue.first else {
                return
            }
            
            // Remove from queue and mark as running
            self.jobQueue.removeFirst()
            self.runningJobs.insert(job.id)
            
            // Process the job
            self.executeJob(job)
        }
    }
    
    private func executeJob(_ job: BackgroundJob) {
        print("🚀 Executing job: \(job.type.rawValue) (ID: \(job.id))")
        
        // Execute job based on type
        let jobHandler = getJobHandler(for: job.type)
        
        jobHandler.execute(job)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.handleJobCompletion(job, completion: completion)
                },
                receiveValue: { result in
                    print("✅ Job \(job.type.rawValue) completed successfully")
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleJobCompletion(_ job: BackgroundJob, completion: Subscribers.Completion<Error>) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Remove from running jobs
            self.runningJobs.remove(job.id)
            
            switch completion {
            case .finished:
                print("✅ Job \(job.type.rawValue) completed successfully")
                self.recordJobCompletion(job, success: true)
                
            case .failure(let error):
                print("❌ Job \(job.type.rawValue) failed: \(error.localizedDescription)")
                
                // Retry if under max retries
                if job.retryCount < self.maxRetries {
                    var retryJob = job
                    retryJob.retryCount += 1
                    retryJob.scheduledAt = Date().addingTimeInterval(self.retryDelay)
                    
                    // Re-queue with delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                        self.enqueueJob(retryJob)
                    }
                } else {
                    self.recordJobCompletion(job, success: false)
                }
            }
            
            // Process next job
            self.processNextJob()
        }
    }
    
    // MARK: - Job Handlers
    
    private func getJobHandler(for type: JobType) -> JobHandler {
        switch type {
        case .dataSync:
            return DataSyncJobHandler()
        case .analytics:
            return AnalyticsJobHandler()
        case .cleanup:
            return CleanupJobHandler()
        case .backup:
            return BackupJobHandler()
        case .notification:
            return NotificationJobHandler()
        case .crisisCheck:
            return CrisisCheckJobHandler()
        case .moodAnalysis:
            return MoodAnalysisJobHandler()
        case .insightGeneration:
            return InsightGenerationJobHandler()
        }
    }
    
    // MARK: - Background Task Support
    
    private func setupBackgroundTask() {
        // Register background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.urgood.background.processing",
            using: nil
        ) { task in
            self.handleBackgroundTask(task as! BGAppRefreshTask)
        }
    }
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) {
        // Schedule next background task
        scheduleBackgroundTask()
        
        // Process critical jobs
        processCriticalJobs()
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        task.setTaskCompleted(success: true)
                    case .failure:
                        task.setTaskCompleted(success: false)
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.urgood.background.processing")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("❌ Failed to schedule background task: \(error)")
        }
    }
    
    private func processCriticalJobs() -> AnyPublisher<Void, Error> {
        let criticalJobs = jobQueue.filter { $0.priority == .critical }
        
        return Publishers.Sequence(sequence: criticalJobs)
            .flatMap { job in
                self.getJobHandler(for: job.type).execute(job)
            }
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Statistics
    
    private func getCompletedJobCount() -> Int {
        // This would be stored in Core Data in a real implementation
        return UserDefaults.standard.integer(forKey: "completed_job_count")
    }
    
    private func getFailedJobCount() -> Int {
        // This would be stored in Core Data in a real implementation
        return UserDefaults.standard.integer(forKey: "failed_job_count")
    }
    
    private func recordJobCompletion(_ job: BackgroundJob, success: Bool) {
        let key = success ? "completed_job_count" : "failed_job_count"
        let currentCount = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(currentCount + 1, forKey: key)
    }
}

// MARK: - Job Models

struct BackgroundJob {
    let id: String
    let type: BackgroundJobQueue.JobType
    let priority: BackgroundJobQueue.JobPriority
    let data: [String: Any]
    var scheduledAt: Date
    let maxRetries: Int
    var retryCount: Int = 0
    
    init(
        type: BackgroundJobQueue.JobType,
        priority: BackgroundJobQueue.JobPriority = .normal,
        data: [String: Any] = [:],
        scheduledAt: Date = Date(),
        maxRetries: Int = 3
    ) {
        self.id = UUID().uuidString
        self.type = type
        self.priority = priority
        self.data = data
        self.scheduledAt = scheduledAt
        self.maxRetries = maxRetries
    }
}

enum JobStatus {
    case queued
    case running
    case completed
    case failed
    case cancelled
}

struct QueueStatus {
    let totalJobs: Int
    let runningJobs: Int
    let completedJobs: Int
    let failedJobs: Int
    let queueSize: Int
    let isProcessing: Bool
}

// MARK: - Job Handler Protocol

protocol JobHandler {
    func execute(_ job: BackgroundJob) -> AnyPublisher<Void, Error>
}

// MARK: - Specific Job Handlers

class DataSyncJobHandler: JobHandler {
    func execute(_ job: BackgroundJob) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // Simulate data sync
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                print("📱 Syncing data...")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}

class AnalyticsJobHandler: JobHandler {
    func execute(_ job: BackgroundJob) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // Simulate analytics processing
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                print("📊 Processing analytics...")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}

class CleanupJobHandler: JobHandler {
    func execute(_ job: BackgroundJob) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // Simulate cleanup
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                print("🧹 Cleaning up old data...")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}

class BackupJobHandler: JobHandler {
    func execute(_ job: BackgroundJob) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // Simulate backup
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                print("💾 Creating backup...")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}

class NotificationJobHandler: JobHandler {
    func execute(_ job: BackgroundJob) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // Simulate notification processing
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                print("🔔 Processing notifications...")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}

class CrisisCheckJobHandler: JobHandler {
    func execute(_ job: BackgroundJob) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // Simulate crisis check
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                print("🚨 Checking for crisis events...")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}

class MoodAnalysisJobHandler: JobHandler {
    func execute(_ job: BackgroundJob) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // Simulate mood analysis
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                print("😊 Analyzing mood patterns...")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}

class InsightGenerationJobHandler: JobHandler {
    func execute(_ job: BackgroundJob) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // Simulate insight generation
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                print("💡 Generating insights...")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}
