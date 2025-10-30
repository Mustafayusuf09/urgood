import Foundation
import Combine

class CronJobScheduler: ObservableObject {
    static let shared = CronJobScheduler()
    
    // Scheduler state
    private var timers: [String: Timer] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let jobQueue = BackgroundJobQueue.shared
    
    // Cron job definitions
    private var cronJobs: [CronJob] = []
    
    private init() {
        setupDefaultCronJobs()
        startScheduler()
    }
    
    // MARK: - Cron Job Management
    
    func addCronJob(_ cronJob: CronJob) {
        cronJobs.append(cronJob)
        scheduleJob(cronJob)
        print("✅ Added cron job: \(cronJob.name) - \(cronJob.schedule)")
    }
    
    func removeCronJob(_ name: String) {
        cronJobs.removeAll { $0.name == name }
        timers[name]?.invalidate()
        timers.removeValue(forKey: name)
        print("❌ Removed cron job: \(name)")
    }
    
    func updateCronJob(_ name: String, schedule: String) {
        if let index = cronJobs.firstIndex(where: { $0.name == name }) {
            cronJobs[index].schedule = schedule
            timers[name]?.invalidate()
            scheduleJob(cronJobs[index])
            print("🔄 Updated cron job: \(name) - \(schedule)")
        }
    }
    
    func getCronJobs() -> [CronJob] {
        return cronJobs
    }
    
    func getCronJobStatus(_ name: String) -> CronJobStatus? {
        guard let job = cronJobs.first(where: { $0.name == name }) else {
            return nil
        }
        
        let isScheduled = timers[name] != nil
        let nextRun = getNextRunTime(for: job)
        
        return CronJobStatus(
            name: name,
            isScheduled: isScheduled,
            nextRun: nextRun,
            lastRun: job.lastRun,
            runCount: job.runCount,
            isEnabled: job.isEnabled
        )
    }
    
    // MARK: - Scheduling
    
    private func startScheduler() {
        // Schedule all existing jobs
        for job in cronJobs {
            scheduleJob(job)
        }
        
        // Check for missed jobs every minute
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkMissedJobs()
            }
            .store(in: &cancellables)
    }
    
    private func scheduleJob(_ job: CronJob) {
        guard job.isEnabled else { return }
        
        // Parse cron schedule
        let cronExpression = parseCronExpression(job.schedule)
        let nextRun = calculateNextRun(cronExpression)
        
        guard let nextRunDate = nextRun else {
            print("❌ Invalid cron schedule: \(job.schedule)")
            return
        }
        
        // Cancel existing timer
        timers[job.name]?.invalidate()
        
        // Schedule new timer
        let timer = Timer(fireAt: nextRunDate, interval: 0, target: self, selector: #selector(executeCronJob(_:)), userInfo: job, repeats: false)
        timers[job.name] = timer
        RunLoop.main.add(timer, forMode: .common)
        
        print("⏰ Scheduled cron job: \(job.name) - Next run: \(nextRunDate)")
    }
    
    @objc private func executeCronJob(_ timer: Timer) {
        guard let job = timer.userInfo as? CronJob else { return }
        
        print("🚀 Executing cron job: \(job.name)")
        
        // Update job stats
        if let index = cronJobs.firstIndex(where: { $0.name == job.name }) {
            cronJobs[index].lastRun = Date()
            cronJobs[index].runCount += 1
        }
        
        // Create background job
        let backgroundJob = BackgroundJob(
            type: job.jobType,
            priority: job.priority,
            data: job.data,
            scheduledAt: Date()
        )
        
        // Enqueue background job
        jobQueue.enqueueJob(backgroundJob)
        
        // Reschedule for next run
        scheduleJob(job)
    }
    
    private func checkMissedJobs() {
        let now = Date()
        
        for job in cronJobs where job.isEnabled {
            guard let lastRun = job.lastRun else { continue }
            
            let cronExpression = parseCronExpression(job.schedule)
            let expectedNextRun = calculateNextRun(cronExpression, from: lastRun)
            
            if let expectedNextRun = expectedNextRun, now > expectedNextRun {
                print("⚠️ Missed cron job: \(job.name) - Expected: \(expectedNextRun)")
                
                // Execute missed job
                let backgroundJob = BackgroundJob(
                    type: job.jobType,
                    priority: job.priority,
                    data: job.data,
                    scheduledAt: now
                )
                
                jobQueue.enqueueJob(backgroundJob)
                
                // Update last run time
                if let index = cronJobs.firstIndex(where: { $0.name == job.name }) {
                    cronJobs[index].lastRun = now
                    cronJobs[index].runCount += 1
                }
            }
        }
    }
    
    // MARK: - Cron Expression Parsing
    
    private func parseCronExpression(_ expression: String) -> CronExpression {
        let components = expression.components(separatedBy: " ")
        
        return CronExpression(
            minute: parseCronField(components[0], min: 0, max: 59),
            hour: parseCronField(components[1], min: 0, max: 23),
            dayOfMonth: parseCronField(components[2], min: 1, max: 31),
            month: parseCronField(components[3], min: 1, max: 12),
            dayOfWeek: parseCronField(components[4], min: 0, max: 6)
        )
    }
    
    private func parseCronField(_ field: String, min: Int, max: Int) -> [Int] {
        if field == "*" {
            return Array(min...max)
        }
        
        if field.contains(",") {
            return field.components(separatedBy: ",").compactMap { Int($0) }
        }
        
        if field.contains("-") {
            let range = field.components(separatedBy: "-")
            if range.count == 2,
               let start = Int(range[0]),
               let end = Int(range[1]) {
                return Array(start...end)
            }
        }
        
        if field.contains("/") {
            let parts = field.components(separatedBy: "/")
            if parts.count == 2,
               let step = Int(parts[1]) {
                return Array(stride(from: min, through: max, by: step))
            }
        }
        
        if let value = Int(field) {
            return [value]
        }
        
        return []
    }
    
    private func calculateNextRun(_ expression: CronExpression, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        var nextRun = calendar.date(byAdding: .minute, value: 1, to: date) ?? date
        
        // Find next valid time
        for _ in 0..<10080 { // Max 1 week
            let components = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: nextRun)
            
            if let minute = components.minute,
               let hour = components.hour,
               let day = components.day,
               let month = components.month,
               let weekday = components.weekday {
                
                if expression.minute.contains(minute) &&
                   expression.hour.contains(hour) &&
                   expression.dayOfMonth.contains(day) &&
                   expression.month.contains(month) &&
                   expression.dayOfWeek.contains(weekday - 1) {
                    return nextRun
                }
            }
            
            nextRun = calendar.date(byAdding: .minute, value: 1, to: nextRun) ?? nextRun
        }
        
        return nil
    }
    
    private func getNextRunTime(for job: CronJob) -> Date? {
        let cronExpression = parseCronExpression(job.schedule)
        return calculateNextRun(cronExpression)
    }
    
    // MARK: - Default Cron Jobs
    
    private func setupDefaultCronJobs() {
        // Data sync every 15 minutes
        addCronJob(CronJob(
            name: "data_sync",
            schedule: "*/15 * * * *",
            jobType: .dataSync,
            priority: .normal,
            data: [:],
            isEnabled: true
        ))
        
        // Analytics processing every hour
        addCronJob(CronJob(
            name: "analytics_processing",
            schedule: "0 * * * *",
            jobType: .analytics,
            priority: .normal,
            data: [:],
            isEnabled: true
        ))
        
        // Cleanup every day at 2 AM
        addCronJob(CronJob(
            name: "daily_cleanup",
            schedule: "0 2 * * *",
            jobType: .cleanup,
            priority: .low,
            data: [:],
            isEnabled: true
        ))
        
        // Backup every day at 3 AM
        addCronJob(CronJob(
            name: "daily_backup",
            schedule: "0 3 * * *",
            jobType: .backup,
            priority: .high,
            data: [:],
            isEnabled: true
        ))
        
        // Crisis check every 5 minutes
        addCronJob(CronJob(
            name: "crisis_check",
            schedule: "*/5 * * * *",
            jobType: .crisisCheck,
            priority: .critical,
            data: [:],
            isEnabled: true
        ))
        
        // Mood analysis every 6 hours
        addCronJob(CronJob(
            name: "mood_analysis",
            schedule: "0 */6 * * *",
            jobType: .moodAnalysis,
            priority: .normal,
            data: [:],
            isEnabled: true
        ))
        
        // Insight generation every day at 6 AM
        addCronJob(CronJob(
            name: "insight_generation",
            schedule: "0 6 * * *",
            jobType: .insightGeneration,
            priority: .normal,
            data: [:],
            isEnabled: true
        ))
    }
}

// MARK: - Cron Models

struct CronJob {
    let name: String
    var schedule: String
    let jobType: BackgroundJobQueue.JobType
    let priority: BackgroundJobQueue.JobPriority
    let data: [String: Any]
    var isEnabled: Bool
    var lastRun: Date?
    var runCount: Int = 0
    
    init(
        name: String,
        schedule: String,
        jobType: BackgroundJobQueue.JobType,
        priority: BackgroundJobQueue.JobPriority = .normal,
        data: [String: Any] = [:],
        isEnabled: Bool = true
    ) {
        self.name = name
        self.schedule = schedule
        self.jobType = jobType
        self.priority = priority
        self.data = data
        self.isEnabled = isEnabled
    }
}

struct CronExpression {
    let minute: [Int]
    let hour: [Int]
    let dayOfMonth: [Int]
    let month: [Int]
    let dayOfWeek: [Int]
}

struct CronJobStatus {
    let name: String
    let isScheduled: Bool
    let nextRun: Date?
    let lastRun: Date?
    let runCount: Int
    let isEnabled: Bool
}
