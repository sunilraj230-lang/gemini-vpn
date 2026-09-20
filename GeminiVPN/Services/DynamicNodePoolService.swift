import Foundation

/// Service that discovers and refreshes unblocked relay nodes dynamically
/// over CDN-fronted bootstrap endpoints to prevent permanent IP blocks.
public final class DynamicNodePoolService {
    public static let shared = DynamicNodePoolService()
    
    /// Redundant bootstrap CDN mirror URLs (Cloudflare / CloudFront / Fastly)
    private let bootstrapMirrors = [
        "https://nodes.geminivpn.net/v1/relays.json",
        "https://cdn-mirror-a.workers.dev/relays.json",
        "https://d2345678abcdef.cloudfront.net/relays.json"
    ]
    
    private init() {}
    
    /// Fetches updated stealth nodes with fallback across redundant mirrors
    public func fetchLatestNodes() async -> [VPNServer] {
        for mirrorURLString in bootstrapMirrors {
            guard let url = URL(string: mirrorURLString) else { continue }
            
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 4.0
                request.setValue("GeminiVPN/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let decoded = try JSONDecoder().decode([VPNServer].self, from: data)
                    if !decoded.isEmpty {
                        return decoded
                    }
                }
            } catch {
                // If this mirror is blocked or unreachable, seamlessly try next mirror
                continue
            }
        }
        
        // Return default resilient preset servers if all mirrors fail
        return VPNServer.sampleServers
    }
    
    /// Finds the optimal stealth node with the lowest latency and load
    public func findSmartConnectNode(from servers: [VPNServer]) -> VPNServer {
        // Prefer obfuscated servers with ping < 100ms and load < 50%
        let candidates = servers.filter { $0.isObfuscated }
        let sorted = candidates.sorted { (s1, s2) -> Bool in
            let score1 = Double(s1.pingMs) + Double(s1.loadPercentage) * 0.5
            let score2 = Double(s2.pingMs) + Double(s2.loadPercentage) * 0.5
            return score1 < score2
        }
        return sorted.first ?? servers.first ?? VPNServer.sampleServers[0]
    }
}
