import SwiftUI

/// Server selection list allowing users to switch countries, filter by latency, and import custom servers
public struct ServerListView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var vpnManager = VPNManager.shared
    
    @State private var searchText = ""
    @State private var selectedFilter: ServerFilter = .all
    @State private var showingAddServerModal = false
    
    enum ServerFilter: String, CaseIterable {
        case all = "All"
        case fastest = "Fastest"
        case stealth = "Stealth (DPI)"
    }
    
    public init() {}
    
    var filteredServers: [VPNServer] {
        var list = vpnManager.availableServers
        
        if selectedFilter == .fastest {
            list = list.sorted(by: { $0.pingMs < $1.pingMs })
        } else if selectedFilter == .stealth {
            list = list.filter { $0.isObfuscated }
        }
        
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.country.localizedCaseInsensitiveContains(searchText) ||
                $0.city.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return list
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.09)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Filter Segmented Control
                    filterPicker
                    
                    // Servers List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredServers) { server in
                                ServerRow(
                                    server: server,
                                    isSelected: vpnManager.selectedServer.id == server.id,
                                    onSelect: {
                                        selectServer(server)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 4)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitle("Select Location", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }.foregroundColor(.cyan),
                trailing: Button(action: {
                    showingAddServerModal = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.cyan)
                }
            )
            .sheet(isPresented: $showingAddServerModal) {
                AddServerModal()
            }
        }
    }
    
    private var filterPicker: some View {
        HStack(spacing: 8) {
            ForEach(ServerFilter.allCases, id: \.self) { filter in
                Button(action: {
                    selectedFilter = filter
                }) {
                    Text(filter.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? Color.cyan : Color.white.opacity(0.06))
                        .foregroundColor(selectedFilter == filter ? .black : .white.opacity(0.8))
                        .cornerRadius(20)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }
    
    private func selectServer(_ server: VPNServer) {
        vpnManager.selectedServer = server
        if vpnManager.status == .connected {
            // Smoothly switch connection
            vpnManager.connect(server: server)
        }
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Server Row Component

struct ServerRow: View {
    let server: VPNServer
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Text(server.flagEmoji)
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(server.country)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        if server.isObfuscated {
                            Image(systemName: "bolt.shield.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.cyan)
                        }
                    }
                    Text("\(server.city) • \(server.loadPercentage)% load")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Ping pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(pingDotColor)
                        .frame(width: 6, height: 6)
                    Text("\(server.pingMs) ms")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color.cyan.opacity(0.12) : Color.white.opacity(0.04))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var pingDotColor: Color {
        if server.pingMs < 50 { return .green }
        if server.pingMs < 100 { return .yellow }
        return .orange
    }
}
