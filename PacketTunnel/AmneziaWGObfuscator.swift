import Foundation

/// High-performance packet obfuscator implementing the AmneziaWG protocol
/// to defeat Deep Packet Inspection (DPI) pattern recognition.
public final class AmneziaWGObfuscator {
    private let config: ObfuscationParams
    
    // WireGuard standard message types
    private static let WG_TYPE_INITIATION: UInt32 = 1
    private static let WG_TYPE_RESPONSE: UInt32 = 2
    private static let WG_TYPE_COOKIE: UInt32 = 3
    private static let WG_TYPE_TRANSPORT: UInt32 = 4
    
    public init(config: ObfuscationParams) {
        self.config = config
    }
    
    /// Generates random junk packets sent before the cryptographic handshake
    /// to disrupt stateful DPI protocol classification.
    public func generateJunkPackets() -> [Data] {
        guard config.junkPacketCount > 0 else { return [] }
        var packets: [Data] = []
        let range = max(1, config.junkPacketMaxSize - config.junkPacketMinSize + 1)
        
        for _ in 0..<config.junkPacketCount {
            let randomSize = Int.random(in: 0..<range) + config.junkPacketMinSize
            var bytes = [UInt8](repeating: 0, count: randomSize)
            _ = SecRandomCopyBytes(kSecRandomDefault, randomSize, &bytes)
            packets.append(Data(bytes))
        }
        return packets
    }
    
    /// Obfuscates an outgoing standard WireGuard packet with custom magic headers
    /// and random padding.
    public func obfuscate(packet: Data) -> Data {
        guard packet.count >= 4 else { return packet }
        
        let messageType = packet.withUnsafeBytes { $0.load(as: UInt32.self) }
        let payload = packet.advanced(by: 4)
        
        switch messageType {
        case Self.WG_TYPE_INITIATION:
            var header = config.initPacketMagicHeader
            var obfuscated = Data(bytes: &header, count: 4)
            obfuscated.append(payload)
            // Append random padding (S1)
            if config.initPacketJunkSize > 0 {
                var junk = [UInt8](repeating: 0, count: config.initPacketJunkSize)
                _ = SecRandomCopyBytes(kSecRandomDefault, config.initPacketJunkSize, &junk)
                obfuscated.append(contentsOf: junk)
            }
            return obfuscated
            
        case Self.WG_TYPE_RESPONSE:
            var header = config.responsePacketMagicHeader
            var obfuscated = Data(bytes: &header, count: 4)
            obfuscated.append(payload)
            // Append random padding (S2)
            if config.responsePacketJunkSize > 0 {
                var junk = [UInt8](repeating: 0, count: config.responsePacketJunkSize)
                _ = SecRandomCopyBytes(kSecRandomDefault, config.responsePacketJunkSize, &junk)
                obfuscated.append(contentsOf: junk)
            }
            return obfuscated
            
        case Self.WG_TYPE_COOKIE:
            var header = config.cookiePacketMagicHeader
            var obfuscated = Data(bytes: &header, count: 4)
            obfuscated.append(payload)
            return obfuscated
            
        case Self.WG_TYPE_TRANSPORT:
            var header = config.transportPacketMagicHeader
            var obfuscated = Data(bytes: &header, count: 4)
            obfuscated.append(payload)
            return obfuscated
            
        default:
            return packet
        }
    }
    
    /// Deobfuscates an incoming AmneziaWG packet back to standard WireGuard wire format.
    public func deobfuscate(packet: Data) -> Data? {
        guard packet.count >= 4 else { return nil }
        
        let magicHeader = packet.withUnsafeBytes { $0.load(as: UInt32.self) }
        let payload = packet.advanced(by: 4)
        
        if magicHeader == config.initPacketMagicHeader {
            // Standard WG initiation is 148 bytes (4-byte header + 144 bytes)
            guard payload.count >= 144 else { return nil }
            var origType = Self.WG_TYPE_INITIATION
            var result = Data(bytes: &origType, count: 4)
            result.append(payload.prefix(144))
            return result
        } else if magicHeader == config.responsePacketMagicHeader {
            // Standard WG response is 92 bytes (4-byte header + 88 bytes)
            guard payload.count >= 88 else { return nil }
            var origType = Self.WG_TYPE_RESPONSE
            var result = Data(bytes: &origType, count: 4)
            result.append(payload.prefix(88))
            return result
        } else if magicHeader == config.cookiePacketMagicHeader {
            var origType = Self.WG_TYPE_COOKIE
            var result = Data(bytes: &origType, count: 4)
            result.append(payload)
            return result
        } else if magicHeader == config.transportPacketMagicHeader {
            var origType = Self.WG_TYPE_TRANSPORT
            var result = Data(bytes: &origType, count: 4)
            result.append(payload)
            return result
        }
        
        return nil
    }
}
