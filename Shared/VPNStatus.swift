import Foundation
import NetworkExtension

/// High-level VPN connection status for UI and binding
public enum VPNStatus: String, Codable, CaseIterable {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case connected = "Connected"
    case reasserting = "Reconnecting..."
    case disconnecting = "Disconnecting..."
    case invalid = "Unavailable"

    public init(from neStatus: NEVPNStatus) {
        switch neStatus {
        case .disconnected:
            self = .disconnected
        case .connecting:
            self = .connecting
        case .connected:
            self = .connected
        case .reasserting:
            self = .reasserting
        case .disconnecting:
            self = .disconnecting
        case .invalid:
            self = .invalid
        @unknown default:
            self = .disconnected
        }
    }
}

/// Statistics model for transfer rates
public struct VPNStatistics: Codable {
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    public var packetsIn: UInt64
    public var packetsOut: UInt64
    public var connectionDuration: TimeInterval

    public init(
        bytesIn: UInt64 = 0,
        bytesOut: UInt64 = 0,
        packetsIn: UInt64 = 0,
        packetsOut: UInt64 = 0,
        connectionDuration: TimeInterval = 0
    ) {
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.packetsIn = packetsIn
        self.packetsOut = packetsOut
        self.connectionDuration = connectionDuration
    }
}
