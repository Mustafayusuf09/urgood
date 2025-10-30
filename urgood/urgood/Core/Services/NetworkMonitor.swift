import Foundation
import Network
import Combine

/// Network connectivity monitor using iOS Network framework
/// Provides real-time network status updates and connection quality metrics
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    @Published private(set) var isConnected = false
    @Published private(set) var connectionType: ConnectionType = .none
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false
    @Published private(set) var connectionQuality: ConnectionQuality = .poor
    
    // MARK: - Private Properties
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // Connection history for quality assessment
    private var connectionHistory: [ConnectionEvent] = []
    private let maxHistorySize = 50
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start network monitoring
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateNetworkStatus(path)
            }
        }
        monitor.start(queue: queue)
        print("🌐 Network monitoring started")
    }
    
    /// Stop network monitoring
    nonisolated func stopMonitoring() {
        monitor.cancel()
        print("🌐 Network monitoring stopped")
    }
    
    /// Check if network is available for specific operations
    func canPerformNetworkOperation() -> Bool {
        return isConnected && connectionQuality != .poor
    }
    
    /// Check if network is suitable for large data transfers
    func canPerformLargeDataTransfer() -> Bool {
        return isConnected && !isExpensive && !isConstrained && connectionQuality == .excellent
    }
    
    /// Get current network status summary
    func getNetworkStatusSummary() -> NetworkStatusSummary {
        return NetworkStatusSummary(
            isConnected: isConnected,
            connectionType: connectionType,
            quality: connectionQuality,
            isExpensive: isExpensive,
            isConstrained: isConstrained
        )
    }
    
    // MARK: - Private Methods
    
    private func updateNetworkStatus(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .none
        }
        
        // Update connection quality
        updateConnectionQuality()
        
        // Record connection event
        recordConnectionEvent(wasConnected: wasConnected, isConnected: isConnected)
        
        // Log status change
        if wasConnected != isConnected {
            print("🌐 Network status changed: \(isConnected ? "Connected" : "Disconnected") (\(connectionType.rawValue))")
        }
        
        // Post notification for other services
        NotificationCenter.default.post(
            name: .networkStatusChanged,
            object: nil,
            userInfo: [
                "isConnected": isConnected,
                "connectionType": connectionType.rawValue,
                "quality": connectionQuality.rawValue
            ]
        )
    }
    
    private func updateConnectionQuality() {
        // Base quality on connection type and constraints
        if !isConnected {
            connectionQuality = .poor
            return
        }
        
        switch connectionType {
        case .wifi:
            connectionQuality = isConstrained ? .good : .excellent
        case .ethernet:
            connectionQuality = .excellent
        case .cellular:
            if isExpensive || isConstrained {
                connectionQuality = .fair
            } else {
                connectionQuality = .good
            }
        case .none:
            connectionQuality = .poor
        }
        
        // Adjust based on connection stability
        let recentDisconnections = connectionHistory
            .suffix(10)
            .filter { !$0.isConnected }
            .count
        
        if recentDisconnections > 3 {
            connectionQuality = ConnectionQuality(rawValue: max(0, connectionQuality.rawValue - 1)) ?? .poor
        }
    }
    
    private func recordConnectionEvent(wasConnected: Bool, isConnected: Bool) {
        if wasConnected != isConnected {
            let event = ConnectionEvent(
                timestamp: Date(),
                isConnected: isConnected,
                connectionType: connectionType
            )
            
            connectionHistory.append(event)
            
            // Trim history
            if connectionHistory.count > maxHistorySize {
                connectionHistory.removeFirst(connectionHistory.count - maxHistorySize)
            }
        }
    }
}

// MARK: - Supporting Types

enum ConnectionType: String, CaseIterable {
    case none = "none"
    case wifi = "wifi"
    case cellular = "cellular"
    case ethernet = "ethernet"
}

enum ConnectionQuality: Int, CaseIterable {
    case poor = 0
    case fair = 1
    case good = 2
    case excellent = 3
    
    var description: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}

struct NetworkStatusSummary {
    let isConnected: Bool
    let connectionType: ConnectionType
    let quality: ConnectionQuality
    let isExpensive: Bool
    let isConstrained: Bool
    
    var canSync: Bool {
        return isConnected && quality != .poor
    }
    
    var shouldDelayLargeOperations: Bool {
        return isExpensive || isConstrained || quality == .poor
    }
}

struct ConnectionEvent {
    let timestamp: Date
    let isConnected: Bool
    let connectionType: ConnectionType
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

