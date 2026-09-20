import Foundation
import NetworkExtension
import Combine
import SwiftUI

/// Main coordinator managing the iOS system VPN lifecycle via NETunnelProviderManager
@MainActor
public final class VPNManager: ObservableObject {
    public static let shared = VPNManager()
    
    // MARK: - Published Properties for SwiftUI Views
    
    @Published public var status: VPNStatus = .disconnected
    @Published public var selectedServer: VPNServer
    @Published public var availableServers: [VPNServer] = VPNServer.sampleServers
    @Published public var routingMode: RoutingMode = .smart
    @Published public var downloadSpeed: String = "0 KB/s"
    @Published public var uploadSpeed: String = "0 KB/s"
    @Published public var connectionDuration: String = "00:00:00"
    @Published public var errorMessage: String? = nil
    @Published public var isKillSwitchActive: Bool = true
    @Published public var isObfuscationActive: Bool = true
    @Published public var isRefreshingNodes: Bool = false
    
    // Internal State
    private var providerManager: NETunnelProviderManager?
    private var statusObserver: Any?
    private var timer: Timer?
    private var connectStartTime: Date?
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    
    private init() {
        self.selectedServer = VPNServer.sampleServers[0]
        self.routingMode = SharedStorage.shared.routingMode
        self.isKillSwitchActive = SharedStorage.shared.isKillSwitchEnabled
        self.isObfuscationActive = true
        
        loadAndCreateVPNProfile()
        setupNotificationObservers()
        
        Task {
            await refreshNodePool()
        }
    }
    
    /// LetsVPN-style Smart Connect: Picks the fastest stealth node and connects instantly
    public func smartConnect() {
        let optimalNode = DynamicNodePoolService.shared.findSmartConnectNode(from: availableServers)
        connect(server: optimalNode)
    }
    
    /// Refreshes node pool dynamically from encrypted CDN mirrors
    public func refreshNodePool() async {
        isRefreshingNodes = true
        let latest = await DynamicNodePoolService.shared.fetchLatestNodes()
        self.availableServers = latest
        isRefreshingNodes = false
    }

    
    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        timer?.invalidate()
    }
    
    // MARK: - Profile Management
    
    /// Loads the VPN configuration from iOS system preferences or provisions a new one
    public func loadAndCreateVPNProfile() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                Task { @MainActor in
                    self.errorMessage = "Failed to load VPN preferences: \(error.localizedDescription)"
                }
                return
            }
            
            // Check if our bundle ID manager already exists
            if let existingManager = managers?.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == SharedConstants.tunnelBundleID
            }) {
                self.providerManager = existingManager
                self.updateStatus(from: existingManager.connection.status)
            } else {
                // Create a new NETunnelProviderManager
                let newManager = NETunnelProviderManager()
                let tunnelProtocol = NETunnelProviderProtocol()
                tunnelProtocol.providerBundleIdentifier = SharedConstants.tunnelBundleID
                tunnelProtocol.serverAddress = self.selectedServer.endpoint
                
                newManager.protocolConfiguration = tunnelProtocol
                newManager.localizedDescription = "GeminiVPN Anti-Censorship Shield"
                newManager.isEnabled = true
                
                newManager.saveToPreferences { [weak self] saveError in
                    guard let self = self else { return }
                    if let saveError = saveError {
                        Task { @MainActor in
                            self.errorMessage = "Failed to save VPN profile: \(saveError.localizedDescription)"
                        }
                    } else {
                        self.providerManager = newManager
                    }
                }
            }
        }
    }
    
    // MARK: - Connect & Disconnect Actions
    
    public func toggleConnection() {
        if status == .connected || status == .connecting {
            disconnect()
        } else {
            connect()
        }
    }
    
    public func connect(server: VPNServer? = nil) {
        if let server = server {
            self.selectedServer = server
        }
        
        guard let manager = providerManager else {
            errorMessage = "VPN subsystem initializing. Please retry in a moment."
            loadAndCreateVPNProfile()
            return
        }
        
        // Update configuration with current toggles
        var config = selectedServer.configuration
        config.routingMode = routingMode
        config.isObfuscationEnabled = isObfuscationActive
        config.killSwitchEnabled = isKillSwitchActive
        config.allowLocalLAN = SharedStorage.shared.allowLocalLAN
        
        // Save active configuration to shared App Group container
        SharedStorage.shared.routingMode = routingMode
        SharedStorage.shared.saveActiveConfiguration(config)

        
        // Update protocol configuration
        let tunnelProtocol = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = SharedConstants.tunnelBundleID
        tunnelProtocol.serverAddress = selectedServer.endpoint
        
        do {
            let configData = try JSONEncoder().encode(config)
            tunnelProtocol.providerConfiguration = ["configuration": configData]
        } catch {
            errorMessage = "Failed to encode configuration: \(error.localizedDescription)"
            return
        }
        
        manager.protocolConfiguration = tunnelProtocol
        manager.localizedDescription = "GeminiVPN (\(selectedServer.name))"
        manager.isEnabled = true
        
        status = .connecting
        
        manager.saveToPreferences { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                Task { @MainActor in
                    self.status = .disconnected
                    self.errorMessage = "Failed to save preferences: \(error.localizedDescription)"
                }
                return
            }
            
            manager.loadFromPreferences { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    Task { @MainActor in
                        self.status = .disconnected
                        self.errorMessage = "Failed to reload preferences: \(error.localizedDescription)"
                    }
                    return
                }
                
                do {
                    let options: [String: NSObject] = [:]
                    try manager.connection.startVPNTunnel(options: options)
                    Task { @MainActor in
                        self.connectStartTime = Date()
                        self.startMetricsTimer()
                    }
                } catch {
                    Task { @MainActor in
                        self.status = .disconnected
                        self.errorMessage = "Failed to start VPN tunnel: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    public func disconnect() {
        status = .disconnecting
        timer?.invalidate()
        timer = nil
        connectStartTime = nil
        downloadSpeed = "0 KB/s"
        uploadSpeed = "0 KB/s"
        
        providerManager?.connection.stopVPNTunnel()
    }
    
    // MARK: - Observers & Metrics
    
    private func setupNotificationObservers() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let connection = notification.object as? NEVPNConnection else { return }
            self.updateStatus(from: connection.status)
        }
    }
    
    private func updateStatus(from neStatus: NEVPNStatus) {
        let newStatus = VPNStatus(from: neStatus)
        self.status = newStatus
        
        if newStatus == .connected {
            if connectStartTime == nil {
                connectStartTime = Date()
            }
            startMetricsTimer()
        } else if newStatus == .disconnected {
            connectStartTime = nil
            timer?.invalidate()
            timer = nil
            downloadSpeed = "0 KB/s"
            uploadSpeed = "0 KB/s"
            connectionDuration = "00:00:00"
        }
    }
    
    private func startMetricsTimer() {
        timer?.invalidate()
        lastBytesIn = 0
        lastBytesOut = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Duration calculation
            if let start = self.connectStartTime {
                let duration = Date().timeIntervalSince(start)
                let hours = Int(duration) / 3600
                let minutes = (Int(duration) % 3600) / 60
                let seconds = Int(duration) % 60
                self.connectionDuration = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            }
            
            // Speed calculation
            let (bytesIn, bytesOut) = SharedStorage.shared.getTrafficStatistics()
            if self.lastBytesIn > 0 && bytesIn >= self.lastBytesIn {
                let deltaIn = bytesIn - self.lastBytesIn
                self.downloadSpeed = self.formatSpeed(bytes: deltaIn)
            }
            if self.lastBytesOut > 0 && bytesOut >= self.lastBytesOut {
                let deltaOut = bytesOut - self.lastBytesOut
                self.uploadSpeed = self.formatSpeed(bytes: deltaOut)
            }
            
            self.lastBytesIn = bytesIn
            self.lastBytesOut = bytesOut
        }
    }
    
    private func formatSpeed(bytes: UInt64) -> String {
        if bytes >= 1024 * 1024 {
            let mb = Double(bytes) / (1024.0 * 1024.0)
            return String(format: "%.1f MB/s", mb)
        } else {
            let kb = Double(bytes) / 1024.0
            return String(format: "%.0f KB/s", kb)
        }
    }
    
    // MARK: - Server Addition
    
    public func addCustomServer(_ server: VPNServer) {
        availableServers.insert(server, at: 0)
        selectedServer = server
    }
}
