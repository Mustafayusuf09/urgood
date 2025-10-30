# Offline Mode Implementation

## Overview

UrGood now supports comprehensive offline functionality, allowing users to continue using the app even without an internet connection. The implementation includes intelligent network monitoring, automatic data synchronization, and seamless user experience transitions between online and offline states.

## Architecture

### Core Components

1. **NetworkMonitor** - Real-time network connectivity monitoring
2. **OfflineDataSync** - Manages offline operation queuing and synchronization
3. **OfflineAwareAPIService** - Intelligent API service with offline fallbacks
4. **OfflineStatusView** - User interface for offline status and controls
5. **Enhanced Core Data Model** - Persistent storage for offline operations

### Data Flow

```
User Action → Local Storage (Immediate) → Network Check → Online API OR Offline Queue
                     ↓                                           ↓
              UI Update (Instant)                    Background Sync (When Online)
```

## Features

### ✅ Network Monitoring
- **Real-time connectivity detection** using iOS Network framework
- **Connection quality assessment** (Poor, Fair, Good, Excellent)
- **Connection type identification** (WiFi, Cellular, Ethernet)
- **Cost and constraint awareness** (expensive/limited connections)
- **Connection stability tracking** with history

### ✅ Offline Data Management
- **Automatic operation queuing** when offline
- **Priority-based sync ordering** (Critical, High, Normal, Low)
- **Retry logic with exponential backoff**
- **Conflict resolution** for data synchronization
- **Persistent storage** using Core Data

### ✅ Smart API Integration
- **Transparent offline handling** - existing code works unchanged
- **Graceful degradation** when network is unavailable
- **Intelligent caching** of API responses
- **Background synchronization** when connection is restored

### ✅ User Experience
- **Visual offline indicators** with detailed status
- **Informative user feedback** about queued operations
- **Manual sync controls** for user-initiated synchronization
- **Offline-first chat responses** for mental health continuity

## Implementation Details

### Network Monitoring

```swift
// Automatic network status updates
@StateObject private var networkMonitor = NetworkMonitor.shared

// Check network capabilities
if networkMonitor.canPerformNetworkOperation() {
    // Perform online operation
} else {
    // Handle offline scenario
}
```

### Offline API Usage

```swift
// Transparent offline handling
let offlineAPI = OfflineAwareAPIService.shared

do {
    try await offlineAPI.sendChatMessage(message, userId: userId)
    // Success - message sent online
} catch OfflineAPIError.queuedForLater {
    // Message queued for later sync
    showUserFeedback("Message will be sent when connection is restored")
} catch {
    // Handle other errors
}
```

### Data Synchronization

```swift
// Manual sync trigger
await OfflineDataSync.shared.forcSync()

// Monitor sync status
@StateObject private var offlineSync = OfflineDataSync.shared
Text("Pending: \(offlineSync.pendingOperationsCount)")
```

## Supported Operations

### Chat Messages
- ✅ Send user messages (queued when offline)
- ✅ Receive AI responses (cached/offline fallbacks)
- ✅ Message history synchronization
- ✅ Conversation context preservation

### User Data
- ✅ Profile updates
- ✅ Preferences synchronization
- ✅ Usage statistics tracking
- ✅ Streak and progress data

### Mood Tracking
- ✅ Mood entry creation
- ✅ Notes and tags synchronization
- ✅ Historical data sync
- ✅ Analytics data collection

## User Interface

### Status Indicators
- **Compact Status**: Small indicator showing connection state
- **Detailed Status**: Expandable view with network details and sync controls
- **In-context Alerts**: Contextual feedback in chat and other features

### Offline Feedback
- **Visual Indicators**: Color-coded connection status
- **Progress Indicators**: Sync progress and pending operation counts
- **User Controls**: Manual sync triggers and operation management

## Configuration

### Sync Settings
```swift
// Sync interval (default: 5 minutes)
private let syncInterval: TimeInterval = 300

// Max retry attempts (default: 3)
private let maxRetryAttempts = 3

// Operation priorities
enum OperationPriority: Int {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}
```

### Network Thresholds
```swift
// Connection quality thresholds
private let noiseGateThreshold: Float = -40.0 // dB
private let maxHistorySize = 50 // connection events
private let rateLimitWindow: TimeInterval = 60.0 // seconds
```

## Testing

### Manual Testing Scenarios

1. **Network Disconnection**
   - Disable WiFi/cellular during chat
   - Verify messages are queued
   - Re-enable network and verify sync

2. **Poor Connection**
   - Use network link conditioner
   - Test with high latency/packet loss
   - Verify graceful handling

3. **App Backgrounding**
   - Send app to background during sync
   - Verify operations continue
   - Test foreground restoration

### Automated Testing
```swift
// Unit tests for offline operations
func testOfflineMessageQueuing() {
    // Test implementation
}

// Integration tests for sync
func testSyncAfterNetworkRestoration() {
    // Test implementation
}
```

## Performance Considerations

### Memory Management
- **Message pagination** - Only keep recent messages in memory
- **Operation cleanup** - Remove completed operations promptly
- **Cache limits** - Prevent unlimited cache growth

### Battery Optimization
- **Intelligent sync timing** - Avoid frequent network checks
- **Background processing limits** - Respect iOS background execution limits
- **Connection quality awareness** - Reduce operations on poor connections

### Storage Optimization
- **Core Data optimization** - Efficient queries and batch operations
- **Data compression** - Compress large operation payloads
- **Cleanup policies** - Remove old operations and cached data

## Error Handling

### Network Errors
```swift
enum OfflineAPIError: LocalizedError {
    case queuedForLater
    case networkUnavailable
    case operationFailed(String)
    
    var isRecoverable: Bool {
        switch self {
        case .queuedForLater, .networkUnavailable:
            return true
        case .operationFailed:
            return false
        }
    }
}
```

### Sync Errors
- **Retry logic** with exponential backoff
- **Operation removal** after max retry attempts
- **User notification** for persistent failures
- **Conflict resolution** for data inconsistencies

## Future Enhancements

### Planned Features
- [ ] **Smart sync scheduling** based on usage patterns
- [ ] **Differential sync** for large datasets
- [ ] **Peer-to-peer sync** for local network scenarios
- [ ] **Advanced conflict resolution** with user input
- [ ] **Offline AI models** for complete offline functionality

### Performance Improvements
- [ ] **Predictive caching** based on user behavior
- [ ] **Compression algorithms** for operation data
- [ ] **Background sync optimization** with iOS background tasks
- [ ] **Network usage analytics** for optimization insights

## Integration Guide

### Adding Offline Support to New Features

1. **Use OfflineAwareAPIService** instead of direct API calls
2. **Handle OfflineAPIError.queuedForLater** appropriately
3. **Provide user feedback** about offline state
4. **Test offline scenarios** thoroughly

### Example Integration
```swift
// Before (online-only)
try await APIService.shared.saveData(data)

// After (offline-aware)
do {
    try await OfflineAwareAPIService.shared.saveData(data)
} catch OfflineAPIError.queuedForLater {
    showUserMessage("Data will be saved when connection is restored")
} catch {
    handleError(error)
}
```

## Troubleshooting

### Common Issues

1. **Operations not syncing**
   - Check network connectivity
   - Verify operation queue status
   - Review error logs

2. **High memory usage**
   - Check message pagination settings
   - Review cache cleanup policies
   - Monitor Core Data performance

3. **Sync conflicts**
   - Review conflict resolution logic
   - Check data consistency
   - Verify timestamp handling

### Debug Tools
- **Network Monitor UI** - Real-time network status
- **Sync Status View** - Operation queue inspection
- **Console Logging** - Detailed operation tracking
- **Performance Metrics** - Memory and CPU usage

---

## Summary

The offline mode implementation provides a robust foundation for UrGood's offline functionality, ensuring users can continue their mental health journey even without internet connectivity. The system is designed for reliability, performance, and excellent user experience across all network conditions.

**Key Benefits:**
- ✅ Seamless offline/online transitions
- ✅ No data loss during network interruptions
- ✅ Intelligent sync management
- ✅ Excellent user feedback and control
- ✅ Performance optimized for mobile devices
- ✅ Extensible architecture for future enhancements

