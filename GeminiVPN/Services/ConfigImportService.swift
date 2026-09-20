import Foundation

/// Service to parse and validate WireGuard and AmneziaWG configuration profiles
public final class ConfigImportService {
    public static let shared = ConfigImportService()
    
    public enum ImportError: LocalizedError {
        case emptyContent
        case missingInterfaceSection
        case missingPeerSection
        case missingPrivateKey
        case missingPublicKey
        case missingEndpoint
        case invalidKeyFormat(String)
        
        public var errorDescription: String? {
            switch self {
            case .emptyContent:
                return "The configuration file or text is empty."
            case .missingInterfaceSection:
                return "Missing [Interface] section in configuration."
            case .missingPeerSection:
                return "Missing [Peer] section in configuration."
            case .missingPrivateKey:
                return "Missing 'PrivateKey' under [Interface]."
            case .missingPublicKey:
                return "Missing 'PublicKey' under [Peer]."
            case .missingEndpoint:
                return "Missing 'Endpoint' (host:port) under [Peer]."
            case .invalidKeyFormat(let key):
                return "Invalid WireGuard Curve25519 key format: \(key)"
            }
        }
    }
    
    /// Parses raw configuration text into a complete VPNServer entity
    public func parseConfigurationText(_ text: String, name: String = "Custom Server") throws -> VPNServer {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw ImportError.emptyContent }
        
        var sections: [String: [String: String]] = [:]
        var currentSection: String? = nil
        
        let lines = cleaned.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            
            if line.hasPrefix("[") && line.hasSuffix("]") {
                let sectionName = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                currentSection = sectionName
                if sections[sectionName] == nil {
                    sections[sectionName] = [:]
                }
            } else if let eqIdx = line.firstIndex(of: "="), let section = currentSection {
                let key = String(line[..<eqIdx]).trimmingCharacters(in: .whitespaces)
                let val = String(line[line.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
                sections[section]?[key] = val
            }
        }
        
        guard let iface = sections["Interface"] else { throw ImportError.missingInterfaceSection }
        guard let peer = sections["Peer"] else { throw ImportError.missingPeerSection }
        
        guard let privateKey = iface["PrivateKey"], !privateKey.isEmpty else {
            throw ImportError.missingPrivateKey
        }
        guard validateWireGuardKey(privateKey) else {
            throw ImportError.invalidKeyFormat("PrivateKey must be 32 bytes Base64 (44 characters)")
        }
        
        guard let publicKey = peer["PublicKey"], !publicKey.isEmpty else {
            throw ImportError.missingPublicKey
        }
        guard validateWireGuardKey(publicKey) else {
            throw ImportError.invalidKeyFormat("PublicKey must be 32 bytes Base64 (44 characters)")
        }
        
        guard let endpoint = peer["Endpoint"], !endpoint.isEmpty else {
            throw ImportError.missingEndpoint
        }
        
        let addressIPv4 = iface["Address"] ?? "10.8.0.2/24"
        let dnsServers = (iface["DNS"] ?? "1.1.1.1, 1.0.0.1")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        let mtu = Int(iface["MTU"] ?? "1280") ?? 1280
        let keepalive = Int(peer["PersistentKeepalive"] ?? "25") ?? 25
        
        // Parse AmneziaWG Obfuscation parameters if present
        let jc = Int(iface["Jc"] ?? "3") ?? 3
        let jmin = Int(iface["Jmin"] ?? "40") ?? 40
        let jmax = Int(iface["Jmax"] ?? "90") ?? 90
        let s1 = Int(iface["S1"] ?? "56") ?? 56
        let s2 = Int(iface["S2"] ?? "48") ?? 48
        let h1 = UInt32(iface["H1"] ?? "2712847316") ?? 0xA1B2C3D4
        let h2 = UInt32(iface["H2"] ?? "2999182565") ?? 0xB2C3D4E5
        let h3 = UInt32(iface["H3"] ?? "3285517814") ?? 0xC3D4E5F6
        let h4 = UInt32(iface["H4"] ?? "3571853063") ?? 0xD4E5F607
        
        let hasObfsParams = iface["Jc"] != nil || iface["H1"] != nil
        
        let obfsParams = ObfuscationParams(
            junkPacketCount: jc,
            junkPacketMinSize: jmin,
            junkPacketMaxSize: jmax,
            initPacketJunkSize: s1,
            responsePacketJunkSize: s2,
            initPacketMagicHeader: h1,
            responsePacketMagicHeader: h2,
            cookiePacketMagicHeader: h3,
            transportPacketMagicHeader: h4
        )
        
        let tunnelConfig = TunnelConfiguration(
            name: name,
            privateKey: privateKey,
            addressIPv4: addressIPv4,
            dnsServers: dnsServers,
            mtu: mtu,
            peerPublicKey: publicKey,
            endpoint: endpoint,
            persistentKeepalive: keepalive,
            isObfuscationEnabled: hasObfsParams,
            obfuscation: obfsParams
        )
        
        return VPNServer(
            name: name,
            country: "Custom",
            countryCode: "UN",
            flagEmoji: "🌐",
            city: endpoint.components(separatedBy: ":").first ?? "Unknown",
            endpoint: endpoint,
            pingMs: 50,
            loadPercentage: 10,
            isObfuscated: hasObfsParams,
            configuration: tunnelConfig
        )
    }
    
    private func validateWireGuardKey(_ key: String) -> Bool {
        guard key.count == 44, key.hasSuffix("=") else { return false }
        guard let data = Data(base64Encoded: key) else { return false }
        return data.count == 32
    }
}
