import Foundation

/// Represents a VPN exit node with location, latency, and anti-censorship capabilities
public struct VPNServer: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var country: String
    public var countryCode: String
    public var flagEmoji: String
    public var city: String
    public var endpoint: String
    public var pingMs: Int
    public var loadPercentage: Int
    public var isObfuscated: Bool
    public var configuration: TunnelConfiguration

    public init(
        id: UUID = UUID(),
        name: String,
        country: String,
        countryCode: String,
        flagEmoji: String,
        city: String,
        endpoint: String,
        pingMs: Int = 45,
        loadPercentage: Int = 32,
        isObfuscated: Bool = true,
        configuration: TunnelConfiguration
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.countryCode = countryCode
        self.flagEmoji = flagEmoji
        self.city = city
        self.endpoint = endpoint
        self.pingMs = pingMs
        self.loadPercentage = loadPercentage
        self.isObfuscated = isObfuscated
        self.configuration = configuration
    }

    /// Preset high-speed, anti-censorship server locations worldwide
    public static let sampleServers: [VPNServer] = [
        VPNServer(
            name: "Tokyo Stealth 1",
            country: "Japan",
            countryCode: "JP",
            flagEmoji: "🇯🇵",
            city: "Tokyo",
            endpoint: "jp.relay.geminivpn.net:51820",
            pingMs: 38,
            loadPercentage: 24,
            isObfuscated: true,
            configuration: TunnelConfiguration(
                name: "Japan Stealth",
                privateKey: "aGVsbG93b3JsZGhlbGxvd29ybGRoZWxsb3dvcmxkMQ==",
                addressIPv4: "10.8.1.2/24",
                addressIPv6: "fd00:1::2/64",
                peerPublicKey: "dGVzdHB1YmxpY2tleXRlc3RwdWJsaWNrZXl0ZXN0MQ==",
                endpoint: "jp.relay.geminivpn.net:51820",
                isObfuscationEnabled: true
            )
        ),
        VPNServer(
            name: "Frankfurt Ultra",
            country: "Germany",
            countryCode: "DE",
            flagEmoji: "🇩🇪",
            city: "Frankfurt",
            endpoint: "de.relay.geminivpn.net:51820",
            pingMs: 42,
            loadPercentage: 45,
            isObfuscated: true,
            configuration: TunnelConfiguration(
                name: "Germany Stealth",
                privateKey: "aGVsbG93b3JsZGhlbGxvd29ybGRoZWxsb3dvcmxkMQ==",
                addressIPv4: "10.8.2.2/24",
                addressIPv6: "fd00:2::2/64",
                peerPublicKey: "dGVzdHB1YmxpY2tleXRlc3RwdWJsaWNrZXl0ZXN0MQ==",
                endpoint: "de.relay.geminivpn.net:51820",
                isObfuscationEnabled: true
            )
        ),
        VPNServer(
            name: "US East (New York)",
            country: "United States",
            countryCode: "US",
            flagEmoji: "🇺🇸",
            city: "New York",
            endpoint: "us-east.relay.geminivpn.net:51820",
            pingMs: 85,
            loadPercentage: 58,
            isObfuscated: true,
            configuration: TunnelConfiguration(
                name: "US East Stealth",
                privateKey: "aGVsbG93b3JsZGhlbGxvd29ybGRoZWxsb3dvcmxkMQ==",
                addressIPv4: "10.8.3.2/24",
                addressIPv6: "fd00:3::2/64",
                peerPublicKey: "dGVzdHB1YmxpY2tleXRlc3RwdWJsaWNrZXl0ZXN0MQ==",
                endpoint: "us-east.relay.geminivpn.net:51820",
                isObfuscationEnabled: true
            )
        ),
        VPNServer(
            name: "Singapore Shield",
            country: "Singapore",
            countryCode: "SG",
            flagEmoji: "🇸🇬",
            city: "Singapore",
            endpoint: "sg.relay.geminivpn.net:51820",
            pingMs: 29,
            loadPercentage: 19,
            isObfuscated: true,
            configuration: TunnelConfiguration(
                name: "Singapore Stealth",
                privateKey: "aGVsbG93b3JsZGhlbGxvd29ybGRoZWxsb3dvcmxkMQ==",
                addressIPv4: "10.8.4.2/24",
                addressIPv6: "fd00:4::2/64",
                peerPublicKey: "dGVzdHB1YmxpY2tleXRlc3RwdWJsaWNrZXl0ZXN0MQ==",
                endpoint: "sg.relay.geminivpn.net:51820",
                isObfuscationEnabled: true
            )
        ),
        VPNServer(
            name: "Zurich Privacy Hub",
            country: "Switzerland",
            countryCode: "CH",
            flagEmoji: "🇨🇭",
            city: "Zurich",
            endpoint: "ch.relay.geminivpn.net:51820",
            pingMs: 48,
            loadPercentage: 15,
            isObfuscated: true,
            configuration: TunnelConfiguration(
                name: "Switzerland Stealth",
                privateKey: "aGVsbG93b3JsZGhlbGxvd29ybGRoZWxsb3dvcmxkMQ==",
                addressIPv4: "10.8.5.2/24",
                addressIPv6: "fd00:5::2/64",
                peerPublicKey: "dGVzdHB1YmxpY2tleXRlc3RwdWJsaWNrZXl0ZXN0MQ==",
                endpoint: "ch.relay.geminivpn.net:51820",
                isObfuscationEnabled: true
            )
        )
    ]
}
