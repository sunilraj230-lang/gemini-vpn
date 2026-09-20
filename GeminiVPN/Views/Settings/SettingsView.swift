import SwiftUI

/// Settings view providing granular controls over security, DPI obfuscation, DNS, and leak protection
public struct SettingsView: View {
    @ObservedObject var vpnManager = VPNManager.shared
    
    @State private var killSwitchEnabled: Bool = SharedStorage.shared.isKillSwitchEnabled
    @State private var ipv6ProtectionEnabled: Bool = SharedStorage.shared.isIPv6ProtectionEnabled
    @State private var allowLocalLAN: Bool = SharedStorage.shared.allowLocalLAN
    @State private var obfuscationActive: Bool = true
    @State private var selectedDNS: DNSOption = .cloudflare
    @State private var mtuSize: Double = 1280
    
    enum DNSOption: String, CaseIterable {
        case cloudflare = "Cloudflare (1.1.1.1)"
        case quad9 = "Quad9 (9.9.9.9)"
        case google = "Google (8.8.8.8)"
        case adguard = "AdGuard DNS (Ad-Block)"
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Anti-Censorship & DPI Bypass Group
                    antiCensorshipSection
                    
                    // Core Security Group
                    coreSecuritySection
                    
                    // DNS & Privacy Group
                    dnsSection
                    
                    // Network Tuning Group
                    networkTuningSection
                    
                    // Diagnostics & System Group
                    systemDiagnosticsSection
                }
                .padding(20)
            }
        }
        .navigationBarTitle("Security & Protocols", displayMode: .inline)
        .onAppear {
            killSwitchEnabled = SharedStorage.shared.isKillSwitchEnabled
            ipv6ProtectionEnabled = SharedStorage.shared.isIPv6ProtectionEnabled
            allowLocalLAN = SharedStorage.shared.allowLocalLAN
            obfuscationActive = vpnManager.isObfuscationActive
        }
    }
    
    // MARK: - Sections
    
    private var antiCensorshipSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "ANTI-CENSORSHIP & DPI BYPASS", icon: "shield.checkered")
            
            VStack(spacing: 16) {
                Toggle(isOn: $obfuscationActive) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Anti-Censorship Obfuscation")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Mutates packet headers (H1-H4) and injects junk packets to defeat stateful Deep Packet Inspection firewalls.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .onChange(of: obfuscationActive) { value in
                    vpnManager.isObfuscationActive = value
                }
                .toggleStyle(SwitchToggleStyle(tint: .cyan))
                
                Divider().background(Color.white.opacity(0.1))
                
                // Multi-protocol auto-failover
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dynamic Protocol Failover")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Automatically switches between AmneziaWG, TLS 1.3 REALITY, and Shadowsocks if a protocol is blocked by DPI.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }

    
    private var coreSecuritySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "LEAK PROTECTION & SECURITY", icon: "lock.shield")
            
            VStack(spacing: 16) {
                // Kill-Switch
                Toggle(isOn: $killSwitchEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kill-Switch (Fail-Closed)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Strictly drops all internet traffic if the VPN tunnel drops unexpectedly, ensuring zero cleartext leakage.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .onChange(of: killSwitchEnabled) { value in
                    SharedStorage.shared.isKillSwitchEnabled = value
                    vpnManager.isKillSwitchActive = value
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                
                Divider().background(Color.white.opacity(0.1))
                
                // IPv6 Protection
                Toggle(isOn: $ipv6ProtectionEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IPv6 Leak Shield")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Forces mobile 5G/LTE dual-stack IPv6 traffic through the encrypted tunnel to prevent ISP tracking.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .onChange(of: ipv6ProtectionEnabled) { value in
                    SharedStorage.shared.isIPv6ProtectionEnabled = value
                }
                .toggleStyle(SwitchToggleStyle(tint: .cyan))
                
                Divider().background(Color.white.opacity(0.1))
                
                // Local LAN Access
                Toggle(isOn: $allowLocalLAN) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local Network Access (LAN)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Allows direct communication with local home network devices (Printers, AirPlay, Apple TV).")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .onChange(of: allowLocalLAN) { value in
                    SharedStorage.shared.allowLocalLAN = value
                }
                .toggleStyle(SwitchToggleStyle(tint: .cyan))
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    private var dnsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "DNS & PRIVACY RESOLVER", icon: "network")
            
            VStack(spacing: 12) {
                ForEach(DNSOption.allCases, id: \.self) { option in
                    Button(action: {
                        selectedDNS = option
                    }) {
                        HStack {
                            Text(option.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            if selectedDNS == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    private var networkTuningSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "PACKET TUNING & MTU", icon: "slider.horizontal.below.rectangle")
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Tunnel MTU Size")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(mtuSize)) Bytes")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                
                Slider(value: $mtuSize, in: 1280...1420, step: 20)
                    .accentColor(.cyan)
                
                Text("1280 is recommended for maximum reliability across 5G/LTE carriers with header overhead.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    private var systemDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "DIAGNOSTICS & SYSTEM INFO", icon: "info.circle")
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Core Engine")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("AmneziaWG / NetworkExtension 2.0")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                
                HStack {
                    Text("Architecture")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("ARM64 / iOS 17.0+")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                
                HStack {
                    Text("Tunnel Sandbox")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("com.geminivpn.app.tunnel")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}
