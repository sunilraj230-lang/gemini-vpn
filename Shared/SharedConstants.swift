import Foundation

/// Constants shared between the main GeminiVPN app and the PacketTunnel Network Extension.
public enum SharedConstants {
    /// App Group identifier used for shared container storage and IPC
    public static let appGroupID = "group.com.geminivpn.app"
    
    /// Network Extension target bundle identifier
    public static let tunnelBundleID = "com.geminivpn.app.tunnel"
    
    /// Darwin notification name posted when tunnel status or statistics update
    public static let tunnelStatusNotification = "com.geminivpn.app.tunnel.statusUpdate"
    
    /// Keychain access group identifier
    public static let keychainAccessGroup = "group.com.geminivpn.app.keychain"
    
    /// Keys used in App Group UserDefaults
    public enum UserDefaultsKeys {
        public static let activeConfig = "gemini_active_vpn_config"
        public static let routingMode = "gemini_routing_mode" // "smart" or "global"
        public static let killSwitchEnabled = "gemini_kill_switch_enabled"
        public static let ipv6ProtectionEnabled = "gemini_ipv6_protection_enabled"
        public static let allowLocalLAN = "gemini_allow_local_lan"
        public static let customDNSServers = "gemini_custom_dns_servers"
        public static let dynamicNodePoolURL = "gemini_dynamic_node_pool_url"
        public static let bytesIn = "gemini_stats_bytes_in"
        public static let bytesOut = "gemini_stats_bytes_out"
        public static let connectionStartTime = "gemini_stats_start_time"
        public static let lastError = "gemini_last_tunnel_error"
    }
}

