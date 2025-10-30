import SwiftUI

/// Displays network and offline sync status to users
/// Shows connection state, pending operations, and sync progress
struct OfflineStatusView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineSync = OfflineDataSync.shared
    @StateObject private var offlineAPI = OfflineAwareAPIService.shared
    
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Bar
            statusBar
            
            // Detailed Status (expandable)
            if showDetails {
                detailsView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(statusBackgroundColor)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var statusBar: some View {
        Button(action: toggleDetails) {
            HStack(spacing: 12) {
                // Connection indicator
                connectionIndicator
                
                // Status text
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(statusTextColor)
                    
                    if offlineSync.pendingOperationsCount > 0 {
                        Text("\(offlineSync.pendingOperationsCount) pending")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Sync indicator
                if offlineSync.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                }
                
                Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var connectionIndicator: some View {
        ZStack {
            Circle()
                .fill(connectionColor)
                .frame(width: 12, height: 12)
            
            if networkMonitor.isConnected {
                Image(systemName: connectionIcon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(Color.secondary.opacity(0.3))
            
            // Network details
            networkDetailsSection
            
            // Sync details
            if offlineSync.pendingOperationsCount > 0 || offlineSync.lastSyncDate != nil {
                syncDetailsSection
            }
            
            // Actions
            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private func toggleDetails() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showDetails.toggle()
        }
    }
    
    private var networkDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Network Status", systemImage: "network")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack {
                Text("Connection:")
                Spacer()
                Text(networkMonitor.connectionType.rawValue.capitalized)
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 13))
            
            HStack {
                Text("Quality:")
                Spacer()
                Text(networkMonitor.connectionQuality.description)
                    .foregroundColor(qualityColor)
            }
            .font(.system(size: 13))
            
            if networkMonitor.isExpensive || networkMonitor.isConstrained {
                HStack {
                    Text("Limitations:")
                    Spacer()
                    HStack(spacing: 4) {
                        if networkMonitor.isExpensive {
                            Text("Expensive")
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .font(.system(size: 10, weight: .medium))
                                .cornerRadius(4)
                        }
                        if networkMonitor.isConstrained {
                            Text("Limited")
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .font(.system(size: 10, weight: .medium))
                                .cornerRadius(4)
                        }
                    }
                }
                .font(.system(size: 13))
            }
        }
    }
    
    private var syncDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sync Status", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            if offlineSync.pendingOperationsCount > 0 {
                HStack {
                    Text("Pending operations:")
                    Spacer()
                    Text("\(offlineSync.pendingOperationsCount)")
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
                .font(.system(size: 13))
            }
            
            if let lastSync = offlineSync.lastSyncDate {
                HStack {
                    Text("Last sync:")
                    Spacer()
                    Text(formatSyncDate(lastSync))
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 13))
            }
            
            if let error = offlineSync.syncError {
                HStack(alignment: .top) {
                    Text("Error:")
                    Spacer()
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.trailing)
                }
                .font(.system(size: 13))
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if networkMonitor.canPerformNetworkOperation() && offlineSync.pendingOperationsCount > 0 {
                Button("Sync Now") {
                    Task {
                        await offlineSync.forcSync()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Spacer()
            
            Button("Dismiss") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showDetails = false
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        if networkMonitor.isConnected {
            if offlineSync.isSyncing {
                return "Syncing..."
            } else if offlineSync.pendingOperationsCount > 0 {
                return "Online (syncing pending)"
            } else {
                return "Online"
            }
        } else {
            return "Offline"
        }
    }
    
    private var statusTextColor: Color {
        if networkMonitor.isConnected {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private var statusBackgroundColor: Color {
        if networkMonitor.isConnected {
            if offlineSync.pendingOperationsCount > 0 {
                return Color.orange.opacity(0.1)
            } else {
                return Color.green.opacity(0.1)
            }
        } else {
            return Color.red.opacity(0.1)
        }
    }
    
    private var connectionColor: Color {
        if networkMonitor.isConnected {
            switch networkMonitor.connectionQuality {
            case .excellent:
                return .green
            case .good:
                return .blue
            case .fair:
                return .orange
            case .poor:
                return .red
            }
        } else {
            return .red
        }
    }
    
    private var connectionIcon: String {
        if networkMonitor.isConnected {
            switch networkMonitor.connectionType {
            case .wifi:
                return "wifi"
            case .cellular:
                return "antenna.radiowaves.left.and.right"
            case .ethernet:
                return "cable.connector"
            case .none:
                return "xmark"
            }
        } else {
            return "xmark"
        }
    }
    
    private var qualityColor: Color {
        switch networkMonitor.connectionQuality {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatSyncDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Compact Status View

struct CompactOfflineStatusView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineSync = OfflineDataSync.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // Connection indicator
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            
            // Status text
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            // Sync indicator
            if offlineSync.isSyncing {
                ProgressView()
                    .scaleEffect(0.6)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var statusText: String {
        if networkMonitor.isConnected {
            return offlineSync.pendingOperationsCount > 0 ? "\(offlineSync.pendingOperationsCount) pending" : "Online"
        } else {
            return "Offline"
        }
    }
    
    private var connectionColor: Color {
        networkMonitor.isConnected ? .green : .red
    }
}

// MARK: - Preview

struct OfflineStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            OfflineStatusView()
            CompactOfflineStatusView()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
