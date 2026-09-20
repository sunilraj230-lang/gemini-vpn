import Foundation
import Security

/// Thread-safe storage coordinator utilizing the App Group container and Keychain
public final class SharedStorage {
    public static let shared = SharedStorage()
    
    private let userDefaults: UserDefaults?
    
    private init() {
        self.userDefaults = UserDefaults(suiteName: SharedConstants.appGroupID)
    }
    
    // MARK: - Active Configuration Management
    
    public func saveActiveConfiguration(_ config: TunnelConfiguration) {
        guard let defaults = userDefaults else { return }
        do {
            let data = try JSONEncoder().encode(config)
            defaults.set(data, forKey: SharedConstants.UserDefaultsKeys.activeConfig)
            defaults.synchronize()
        } catch {
            print("Failed to encode configuration: \(error)")
        }
    }
    
    public func loadActiveConfiguration() -> TunnelConfiguration? {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: SharedConstants.UserDefaultsKeys.activeConfig) else {
            return nil
        }
        return try? JSONDecoder().decode(TunnelConfiguration.self, from: data)
    }
    
    // MARK: - Security & Toggles
    
    public var routingMode: RoutingMode {
        get {
            guard let raw = userDefaults?.string(forKey: SharedConstants.UserDefaultsKeys.routingMode),
                  let mode = RoutingMode(rawValue: raw) else {
                return .smart
            }
            return mode
        }
        set {
            userDefaults?.set(newValue.rawValue, forKey: SharedConstants.UserDefaultsKeys.routingMode)
        }
    }
    
    public var isKillSwitchEnabled: Bool {
        get { userDefaults?.bool(forKey: SharedConstants.UserDefaultsKeys.killSwitchEnabled) ?? true }
        set { userDefaults?.set(newValue, forKey: SharedConstants.UserDefaultsKeys.killSwitchEnabled) }
    }

    
    public var isIPv6ProtectionEnabled: Bool {
        get { userDefaults?.bool(forKey: SharedConstants.UserDefaultsKeys.ipv6ProtectionEnabled) ?? true }
        set { userDefaults?.set(newValue, forKey: SharedConstants.UserDefaultsKeys.ipv6ProtectionEnabled) }
    }
    
    public var allowLocalLAN: Bool {
        get { userDefaults?.bool(forKey: SharedConstants.UserDefaultsKeys.allowLocalLAN) ?? false }
        set { userDefaults?.set(newValue, forKey: SharedConstants.UserDefaultsKeys.allowLocalLAN) }
    }
    
    // MARK: - Statistics
    
    public func updateTrafficStatistics(bytesIn: UInt64, bytesOut: UInt64) {
        guard let defaults = userDefaults else { return }
        defaults.set(bytesIn, forKey: SharedConstants.UserDefaultsKeys.bytesIn)
        defaults.set(bytesOut, forKey: SharedConstants.UserDefaultsKeys.bytesOut)
    }
    
    public func getTrafficStatistics() -> (bytesIn: UInt64, bytesOut: UInt64) {
        guard let defaults = userDefaults else { return (0, 0) }
        let inBytes = defaults.object(forKey: SharedConstants.UserDefaultsKeys.bytesIn) as? UInt64 ?? 0
        let outBytes = defaults.object(forKey: SharedConstants.UserDefaultsKeys.bytesOut) as? UInt64 ?? 0
        return (inBytes, outBytes)
    }
    
    // MARK: - Keychain Secure Storage for Private Keys
    
    public func savePrivateKeyToKeychain(key: String, identifier: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "GeminiVPN_PrivateKey",
            kSecAttrAccessGroup as String: SharedConstants.keychainAccessGroup,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func loadPrivateKeyFromKeychain(identifier: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "GeminiVPN_PrivateKey",
            kSecAttrAccessGroup as String: SharedConstants.keychainAccessGroup,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
