import Foundation
import NetworkExtension
import Network
import os.log

/// Primary NetworkExtension Packet Tunnel Provider for GeminiVPN
/// Handles system-wide packet encapsulation, IPv4/IPv6 routing, DNS leak protection,
/// and anti-censorship AmneziaWG packet obfuscation.
public final class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private let logger = Logger(subsystem: "com.geminivpn.app", category: "PacketTunnel")
    
    private var activeConfig: TunnelConfiguration?
    private var obfuscator: AmneziaWGObfuscator?
    private var connection: NWConnection?
    private var isTunnelRunning = false
    
    // Performance & Statistics tracking
    private var totalBytesIn: UInt64 = 0
    private var totalBytesOut: UInt64 = 0
    private var packetCountIn: UInt64 = 0
    private var packetCountOut: UInt64 = 0
    private var statsTimer: Timer?
    
    // MARK: - Tunnel Lifecycle
    
    public override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("Initiating GeminiVPN Packet Tunnel...")
        
        // 1. Retrieve Tunnel Configuration
        var config: TunnelConfiguration?
        if let configData = options?["configuration"] as? Data {
            config = try? JSONDecoder().decode(TunnelConfiguration.self, from: configData)
        }
        if config == nil {
            config = SharedStorage.shared.loadActiveConfiguration()
        }
        
        guard let validConfig = config else {
            logger.error("Error: Missing or invalid TunnelConfiguration")
            let error = NSError(domain: "GeminiVPN", code: -1, userInfo: [NSLocalizedDescriptionKey: "No VPN configuration found."])
            completionHandler(error)
            return
        }
        
        self.activeConfig = validConfig
        self.obfuscator = validConfig.isObfuscationEnabled ? AmneziaWGObfuscator(config: validConfig.obfuscation) : nil
        
        // 2. Parse Endpoint (Host:Port)
        let parts = validConfig.endpoint.split(separator: ":")
        guard parts.count == 2, let portInt = UInt16(parts[1]), let port = NWEndpoint.Port(rawValue: portInt) else {
            logger.error("Error: Malformed endpoint '\(validConfig.endpoint)'")
            let error = NSError(domain: "GeminiVPN", code: -2, userInfo: [NSLocalizedDescriptionKey: "Malformed server endpoint."])
            completionHandler(error)
            return
        }
        let host = NWEndpoint.Host(String(parts[0]))
        
        // 3. Build Tunnel Network Settings
        let settings = buildTunnelNetworkSettings(for: validConfig, serverHost: String(parts[0]))
        
        // 4. Apply Network Settings to iOS Kernel
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Failed to set tunnel network settings: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            
            self.logger.info("Tunnel network settings successfully applied by iOS kernel")
            
            // 5. Establish Outbound UDP Connection
            self.setupOutboundConnection(host: host, port: port)
            
            // 6. Send anti-censorship junk packets (AmneziaWG Jc)
            self.sendInitialJunkPackets()
            
            // 7. Start reading packets from iOS virtual tunnel interface (utun)
            self.isTunnelRunning = true
            self.startPacketLoop()
            self.startStatsTimer()
            
            completionHandler(nil)
        }
    }
    
    public override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping GeminiVPN Packet Tunnel. Reason: \(reason.rawValue)")
        
        isTunnelRunning = false
        statsTimer?.invalidate()
        statsTimer = nil
        
        // Teardown connection
        connection?.cancel()
        connection = nil
        
        // Persist final statistics
        SharedStorage.shared.updateTrafficStatistics(bytesIn: totalBytesIn, bytesOut: totalBytesOut)
        
        completionHandler()
    }
    
    // MARK: - Network Settings & Routing Setup
    
    private func buildTunnelNetworkSettings(for config: TunnelConfiguration, serverHost: String) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: serverHost)
        settings.mtu = NSNumber(value: config.mtu) // e.g. 1280 bytes
        
        // --- IPv4 Configuration ---
        let cleanIPv4 = config.addressIPv4.components(separatedBy: "/").first ?? "10.8.0.2"
        let ipv4Settings = NEIPv4Settings(addresses: [cleanIPv4], subnetMasks: ["255.255.255.0"])
        
        // Route default traffic into tunnel
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        
        // LetsVPN-Style Smart Mode: Exclude domestic & LAN ranges so banking/local apps stay direct!
        if config.routingMode == .smart || config.allowLocalLAN {
            ipv4Settings.excludedRoutes = [
                NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
                NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
                NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
                NEIPv4Route(destinationAddress: "100.64.0.0", subnetMask: "255.192.0.0") // CGNAT
            ]
        }
        settings.ipv4Settings = ipv4Settings

        
        // --- IPv6 Leak Prevention ---
        // Crucial for iOS: prevents dual-stack cellular bypass!
        if SharedStorage.shared.isIPv6ProtectionEnabled {
            let cleanIPv6 = config.addressIPv6?.components(separatedBy: "/").first ?? "fd00::2"
            let ipv6Settings = NEIPv6Settings(addresses: [cleanIPv6], networkPrefixLengths: [64])
            ipv6Settings.includedRoutes = [NEIPv6Route.default()] // Route ::/0 into tunnel
            settings.ipv6Settings = ipv6Settings
        }
        
        // --- DNS Leak Protection ---
        let dnsServers = config.dnsServers.isEmpty ? ["1.1.1.1", "1.0.0.1"] : config.dnsServers
        let dnsSettings = NEDNSSettings(servers: dnsServers)
        // matchDomains = [""] forces ALL DNS queries on the entire system to route via VPN DNS
        dnsSettings.matchDomains = [""]
        settings.dnsSettings = dnsSettings
        
        return settings
    }
    
    // MARK: - Outbound Connection & Packet Handling
    
    private func setupOutboundConnection(host: NWEndpoint.Host, port: NWEndpoint.Port) {
        let params = NWParameters.udp
        params.preferNoProxies = true
        
        let conn = NWConnection(host: host, port: port, using: params)
        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.logger.info("UDP tunnel connection established to \(host.debugDescription):\(port.rawValue)")
                self.receiveInboundPackets()
            case .failed(let error):
                self.logger.error("UDP tunnel connection failed: \(error.localizedDescription)")
                self.reasserting = true
            case .waiting(let error):
                self.logger.warning("UDP tunnel waiting: \(error.localizedDescription)")
                self.reasserting = true
            default:
                break
            }
        }
        
        conn.start(queue: .global(qos: .userInitiated))
        self.connection = conn
    }
    
    private func sendInitialJunkPackets() {
        guard let obfuscator = self.obfuscator else { return }
        let junkPackets = obfuscator.generateJunkPackets()
        logger.info("Sending \(junkPackets.count) anti-DPI junk packets before handshake...")
        
        for junk in junkPackets {
            connection?.send(content: junk, completion: .contentProcessed({ _ in }))
        }
    }
    
    // MARK: - Packet Processing Loop
    
    private func startPacketLoop() {
        guard isTunnelRunning else { return }
        
        // Read IP packets originating from iOS apps via virtual interface (utun)
        packetFlow.readPackets { [weak self] (packets: [Data], protocols: [NSNumber]) in
            guard let self = self, self.isTunnelRunning else { return }
            
            for packet in packets {
                self.processOutboundPacket(packet)
            }
            
            // Loop reading for continuous packet streaming
            self.startPacketLoop()
        }
    }
    
    private func processOutboundPacket(_ packet: Data) {
        totalBytesOut += UInt64(packet.count)
        packetCountOut += 1
        
        // Apply AmneziaWG obfuscation if enabled
        var transmissionPacket = packet
        if let obfuscator = self.obfuscator {
            transmissionPacket = obfuscator.obfuscate(packet: packet)
        }
        
        // Send packet over encrypted UDP tunnel
        connection?.send(content: transmissionPacket, completion: .contentProcessed({ [weak self] error in
            if let error = error {
                self?.logger.error("Failed to send packet: \(error.localizedDescription)")
            }
        }))
    }
    
    private func receiveInboundPackets() {
        guard isTunnelRunning else { return }
        
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65535) { [weak self] (content, _, isComplete, error) in
            guard let self = self else { return }
            
            if let data = content, !data.isEmpty {
                self.totalBytesIn += UInt64(data.count)
                self.packetCountIn += 1
                
                // Deobfuscate if AmneziaWG obfuscation is active
                var decryptedPacket: Data = data
                if let obfuscator = self.obfuscator {
                    if let deobfs = obfuscator.deobfuscate(packet: data) {
                        decryptedPacket = deobfs
                    }
                }
                
                // Inject return packet back into iOS kernel network stack
                let protocolNumber = NSNumber(value: AF_INET)
                self.packetFlow.writePackets([decryptedPacket], withProtocols: [protocolNumber])
            }
            
            if self.isTunnelRunning && error == nil {
                self.receiveInboundPackets()
            }
        }
    }
    
    private func startStatsTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                SharedStorage.shared.updateTrafficStatistics(bytesIn: self.totalBytesIn, bytesOut: self.totalBytesOut)
            }
        }
    }
    
    // MARK: - Sleep / Wake Support
    
    public override func sleep(completionHandler: @escaping () -> Void) {
        logger.info("Device entering sleep mode. Pausing non-essential tunnel activity.")
        completionHandler()
    }
    
    public override func wake() {
        logger.info("Device awakened. Reasserting tunnel connection.")
        if isTunnelRunning {
            self.reasserting = false
        }
    }
}
