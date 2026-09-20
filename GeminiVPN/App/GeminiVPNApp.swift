import SwiftUI

@main
public struct GeminiVPNApp: App {
    @StateObject private var vpnManager = VPNManager.shared
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(.dark)
                .environmentObject(vpnManager)
        }
    }
}
