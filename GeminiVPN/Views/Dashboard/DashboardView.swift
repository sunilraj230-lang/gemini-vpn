import SwiftUI

/// Main dashboard view for GeminiVPN with animated connection controls and real-time network telemetry
public struct DashboardView: View {
    @ObservedObject var vpnManager = VPNManager.shared
    @State private var showingServerSheet = false
    @State private var pulseAnimation = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Background futuristic gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.05, green: 0.07, blue: 0.12),
                        Color(red: 0.02, green: 0.03, blue: 0.06)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Top App Header
                    headerBar
                    
                    // LetsVPN-Style Smart/Global Mode Bar
                    modeSelectorBar
                    
                    Spacer()

                    
                    // Central Connect Shield & Pulse Rings
                    connectionToggleSection
                    
                    // Connection Status Text
                    statusTextSection
                    
                    Spacer()
                    
                    // Real-Time Bandwidth & Telemetry Card
                    if vpnManager.status == .connected {
                        telemetryCard
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Active Server Selector Card
                    serverSelectorCard
                    
                    // Anti-Censorship Security Indicators
                    securityBadgesBar
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingServerSheet) {
                ServerListView()
            }
            .alert(isPresented: Binding<Bool>(
                get: { vpnManager.errorMessage != nil },
                set: { if !$0 { vpnManager.errorMessage = nil } }
            )) {
                Alert(
                    title: Text("VPN Notice"),
                    message: Text(vpnManager.errorMessage ?? "An error occurred."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundColor(.cyan)
                        .font(.system(size: 20))
                    Text("GEMINI VPN")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Text("LETSVPN-GRADE ANTI-CENSORSHIP")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.cyan.opacity(0.8))
            }
            Spacer()
            
            // Dynamic node pool refresh button
            Button(action: {
                Task {
                    await vpnManager.refreshNodePool()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .rotationEffect(Angle(degrees: vpnManager.isRefreshingNodes ? 360 : 0))
                    .animation(vpnManager.isRefreshingNodes ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: vpnManager.isRefreshingNodes)
            }
            
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 8)
    }
    
    private var modeSelectorBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                // Smart Mode Button
                Button(action: {
                    vpnManager.routingMode = .smart
                    SharedStorage.shared.routingMode = .smart
                    if vpnManager.status == .connected {
                        vpnManager.connect()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("Smart Mode")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(vpnManager.routingMode == .smart ? Color.cyan : Color.white.opacity(0.06))
                    .foregroundColor(vpnManager.routingMode == .smart ? .black : .white.opacity(0.7))
                    .cornerRadius(12)
                }
                
                // Global Mode Button
                Button(action: {
                    vpnManager.routingMode = .global
                    SharedStorage.shared.routingMode = .global
                    if vpnManager.status == .connected {
                        vpnManager.connect()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 12, weight: .bold))
                        Text("Global Mode")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(vpnManager.routingMode == .global ? Color.cyan : Color.white.opacity(0.06))
                    .foregroundColor(vpnManager.routingMode == .global ? .black : .white.opacity(0.7))
                    .cornerRadius(12)
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.04))
            .cornerRadius(16)
            
            // Explanatory hint
            Text(vpnManager.routingMode == .smart
                 ? "⚡ Domestic apps (banking/maps) stay direct; foreign apps route via stealth tunnel"
                 : "🔒 100% of all apps & system traffic routed through encrypted tunnel")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }

    
    private var connectionToggleSection: some View {
        ZStack {
            // Pulse rings when connected
            if vpnManager.status == .connected {
                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulseAnimation ? 1.25 : 0.95)
                    .opacity(pulseAnimation ? 0.0 : 0.8)
                    .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: pulseAnimation)
                    .onAppear { pulseAnimation = true }
            } else if vpnManager.status == .connecting {
                Circle()
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [.orange, .yellow, .clear]), center: .center),
                        lineWidth: 4
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(Angle(degrees: pulseAnimation ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)
                    .onAppear { pulseAnimation = true }
            }
            
            // Main Button
            Button(action: {
                if vpnManager.status == .connected || vpnManager.status == .connecting {
                    vpnManager.disconnect()
                } else {
                    vpnManager.smartConnect()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(buttonBackgroundColor)
                        .frame(width: 170, height: 170)
                        .shadow(color: buttonGlowColor.opacity(0.5), radius: 25, x: 0, y: 10)
                    
                    Circle()
                        .stroke(buttonStrokeColor, lineWidth: 3)
                        .frame(width: 170, height: 170)
                    
                    VStack(spacing: 8) {
                        Image(systemName: buttonIconName)
                            .font(.system(size: 54, weight: .medium))
                            .foregroundColor(buttonContentColor)
                        
                        Text(buttonActionLabel)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(buttonContentColor.opacity(0.9))
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    private var statusTextSection: some View {
        VStack(spacing: 6) {
            Text(statusHeadline)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(statusTextColor)
            
            if vpnManager.status == .connected {
                Text(vpnManager.connectionDuration)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            } else if vpnManager.status == .connecting {
                Text("Bypassing Deep Packet Inspection...")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.orange.opacity(0.9))
            } else {
                Text("Auto-selects fastest unblocked stealth node")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var statusHeadline: String {
        switch vpnManager.status {
        case .connected:
            return vpnManager.routingMode == .smart ? "PROTECTED • SMART MODE" : "PROTECTED • GLOBAL MODE"
        case .connecting:
            return "CONNECTING (OPTIMAL NODE)..."
        case .reasserting:
            return "AUTO-HEALING CONNECTION..."
        case .disconnecting:
            return "DISCONNECTING..."
        default:
            return "READY • 1-TAP SMART CONNECT"
        }
    }

    
    private var telemetryCard: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("DOWNLOAD")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(vpnManager.downloadSpeed)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .frame(height: 36)
            
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("UPLOAD")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(vpnManager.uploadSpeed)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var serverSelectorCard: some View {
        Button(action: {
            showingServerSheet = true
        }) {
            HStack(spacing: 14) {
                Text(vpnManager.selectedServer.flagEmoji)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(vpnManager.selectedServer.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(vpnManager.selectedServer.city), \(vpnManager.selectedServer.country)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Ping indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(pingColor)
                        .frame(width: 7, height: 7)
                    Text("\(vpnManager.selectedServer.pingMs) ms")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.07))
                .cornerRadius(12)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var securityBadgesBar: some View {
        HStack(spacing: 12) {
            BadgeView(
                icon: "shield.lefthalf.filled",
                text: "DPI BYPASS",
                isActive: vpnManager.isObfuscationActive
            )
            BadgeView(
                icon: "lock.shield",
                text: "KILL-SWITCH",
                isActive: vpnManager.isKillSwitchActive
            )
            BadgeView(
                icon: "network.badge.shield.half.filled",
                text: "NO LEAK",
                isActive: true
            )
        }
    }
    
    // MARK: - State Computed Properties
    
    private var buttonBackgroundColor: Color {
        switch vpnManager.status {
        case .connected:
            return Color(red: 0.05, green: 0.25, blue: 0.15)
        case .connecting, .reasserting:
            return Color(red: 0.30, green: 0.20, blue: 0.05)
        case .disconnecting:
            return Color(red: 0.25, green: 0.10, blue: 0.10)
        default:
            return Color(red: 0.08, green: 0.11, blue: 0.18)
        }
    }
    
    private var buttonGlowColor: Color {
        switch vpnManager.status {
        case .connected: return .green
        case .connecting, .reasserting: return .orange
        default: return .cyan
        }
    }
    
    private var buttonStrokeColor: Color {
        switch vpnManager.status {
        case .connected: return Color.green.opacity(0.7)
        case .connecting, .reasserting: return Color.orange.opacity(0.7)
        default: return Color.cyan.opacity(0.4)
        }
    }
    
    private var buttonContentColor: Color {
        switch vpnManager.status {
        case .connected: return .green
        case .connecting, .reasserting: return .orange
        default: return .cyan
        }
    }
    
    private var buttonIconName: String {
        switch vpnManager.status {
        case .connected: return "shield.checkered"
        case .connecting, .reasserting: return "arrow.triangle.2.circlepath"
        default: return "power"
        }
    }
    
    private var buttonActionLabel: String {
        switch vpnManager.status {
        case .connected: return "DISCONNECT"
        case .connecting: return "CONNECTING"
        case .reasserting: return "RETRYING"
        case .disconnecting: return "STOPPING"
        default: return "CONNECT"
        }
    }
    
    private var statusTextColor: Color {
        switch vpnManager.status {
        case .connected: return .green
        case .connecting, .reasserting: return .orange
        default: return .white.opacity(0.8)
        }
    }
    
    private var pingColor: Color {
        let ms = vpnManager.selectedServer.pingMs
        if ms < 50 { return .green }
        if ms < 100 { return .yellow }
        return .orange
    }
}

// MARK: - Subcomponents

struct BadgeView: View {
    let icon: String
    let text: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isActive ? .green : .gray)
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isActive ? .white.opacity(0.9) : .gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
