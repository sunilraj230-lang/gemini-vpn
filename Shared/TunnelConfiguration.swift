import Foundation

/// Obfuscation parameters compliant with AmneziaWG protocol to bypass Deep Packet Inspection (DPI)
public struct ObfuscationParams: Codable, Equatable {
    /// Number of random junk packets sent before handshake initiation (Jc)
    public var junkPacketCount: Int
    /// Minimum junk packet size in bytes (Jmin)
    public var junkPacketMinSize: Int
    /// Maximum junk packet size in bytes (Jmax)
    public var junkPacketMaxSize: Int
    /// Handshake initiation message padding in bytes (S1)
    public var initPacketJunkSize: Int
    /// Handshake response message padding in bytes (S2)
    public var responsePacketJunkSize: Int
    /// Custom 32-bit header magic replacing standard WG initiation 0x01000000 (H1)
    public var initPacketMagicHeader: UInt32
    /// Custom 32-bit header magic replacing standard WG response 0x02000000 (H2)
    public var responsePacketMagicHeader: UInt32
    /// Custom 32-bit header magic replacing standard WG cookie 0x03000000 (H3)
    public var cookiePacketMagicHeader: UInt32
    /// Custom 32-bit header magic replacing standard WG transport 0x04000000 (H4)
    public var transportPacketMagicHeader: UInt32

    public init(
        junkPacketCount: Int = 3,
        junkPacketMinSize: Int = 40,
        junkPacketMaxSize: Int = 90,
        initPacketJunkSize: Int = 56,
        responsePacketJunkSize: Int = 48,
        initPacketMagicHeader: UInt32 = 0xA1B2C3D4,
        responsePacketMagicHeader: UInt32 = 0xB2C3D4E5,
        cookiePacketMagicHeader: UInt32 = 0xC3D4E5F6,
        transportPacketMagicHeader: UInt32 = 0xD4E5F607
    ) {
        self.junkPacketCount = junkPacketCount
        self.junkPacketMinSize = junkPacketMinSize
        self.junkPacketMaxSize = junkPacketMaxSize
        self.initPacketJunkSize = initPacketJunkSize
        self.responsePacketJunkSize = responsePacketJunkSize
        self.initPacketMagicHeader = initPacketMagicHeader
        self.responsePacketMagicHeader = responsePacketMagicHeader
        self.cookiePacketMagicHeader = cookiePacketMagicHeader
        self.transportPacketMagicHeader = transportPacketMagicHeader
    }
}

/// LetsVPN-style routing modes
public enum RoutingMode: String, Codable, CaseIterable {
    /// Smart Mode: Local/domestic traffic (banking, local food delivery, maps) stays DIRECT.
    /// Foreign & censored apps (YouTube, TikTok, Telegram, WhatsApp, ChatGPT) route via VPN.
    case smart = "Smart Mode (Recommended)"
    
    /// Global Mode: 100% of all apps and system traffic route via VPN.
    case global = "Global Mode"
}

/// Stealth protocol choices supported by the multi-protocol engine
public enum StealthProtocol: String, Codable, CaseIterable {
    case amneziaWG = "AmneziaWG (Obfuscated UDP)"
    case tlsReality = "VLESS / TLS 1.3 REALITY (Port 443)"
    case shadowsocks = "Shadowsocks 2022 AEAD"
}

/// Complete VPN tunnel configuration
public struct TunnelConfiguration: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var routingMode: RoutingMode
    public var primaryProtocol: StealthProtocol
    
    // Interface settings
    public var privateKey: String
    public var addressIPv4: String
    public var addressIPv6: String?
    public var dnsServers: [String]
    public var mtu: Int
    
    // Peer settings
    public var peerPublicKey: String
    public var endpoint: String // "host:port"
    public var allowedIPs: [String]
    public var persistentKeepalive: Int
    
    // Security & Anti-Censorship
    public var isObfuscationEnabled: Bool
    public var obfuscation: ObfuscationParams
    public var killSwitchEnabled: Bool
    public var allowLocalLAN: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        routingMode: RoutingMode = .smart,
        primaryProtocol: StealthProtocol = .amneziaWG,
        privateKey: String,
        addressIPv4: String = "10.8.0.2/24",
        addressIPv6: String? = "fd00::2/64",
        dnsServers: [String] = ["1.1.1.1", "1.0.0.1"],
        mtu: Int = 1280,
        peerPublicKey: String,
        endpoint: String,
        allowedIPs: [String] = ["0.0.0.0/0", "::/0"],
        persistentKeepalive: Int = 25,
        isObfuscationEnabled: Bool = true,
        obfuscation: ObfuscationParams = ObfuscationParams(),
        killSwitchEnabled: Bool = true,
        allowLocalLAN: Bool = false
    ) {
        self.id = id
        self.name = name
        self.routingMode = routingMode
        self.primaryProtocol = primaryProtocol
        self.privateKey = privateKey
        self.addressIPv4 = addressIPv4
        self.addressIPv6 = addressIPv6
        self.dnsServers = dnsServers
        self.mtu = mtu
        self.peerPublicKey = peerPublicKey
        self.endpoint = endpoint
        self.allowedIPs = allowedIPs
        self.persistentKeepalive = persistentKeepalive
        self.isObfuscationEnabled = isObfuscationEnabled
        self.obfuscation = obfuscation
        self.killSwitchEnabled = killSwitchEnabled
        self.allowLocalLAN = allowLocalLAN
    }
}

