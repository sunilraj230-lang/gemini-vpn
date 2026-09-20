import SwiftUI

/// Modal sheet for adding a custom WireGuard / AmneziaWG server configuration
public struct AddServerModal: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var serverName = "My Custom Server"
    @State private var configText = ""
    @State private var validationError: String? = nil
    @State private var isSuccess = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.09)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Import Configuration")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Paste a standard WireGuard or AmneziaWG configuration profile (.conf). The parser will automatically extract keys, endpoints, and anti-censorship headers.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.gray)
                        
                        // Server Name Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SERVER NAME")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            
                            TextField("e.g. Frankfurt Dedicated", text: $serverName)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        }
                        
                        // Config Text Editor
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("CONFIGURATION CONTENT (.CONF)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Button("Paste Sample") {
                                    insertSampleConfig()
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.cyan)
                            }
                            
                            TextEditor(text: $configText)
                                .frame(height: 220)
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                                .foregroundColor(Color.green.opacity(0.9))
                                .font(.system(size: 12, design: .monospaced))
                        }
                        
                        // Error message if any
                        if let error = validationError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        // Import Button
                        Button(action: importConfig) {
                            HStack {
                                Image(systemName: "arrow.down.doc.fill")
                                Text("Import & Save Profile")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.cyan)
                            .foregroundColor(.black)
                            .cornerRadius(14)
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitle("Add Server", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }.foregroundColor(.gray)
            )
        }
    }
    
    private func importConfig() {
        validationError = nil
        do {
            let server = try ConfigImportService.shared.parseConfigurationText(configText, name: serverName)
            VPNManager.shared.addCustomServer(server)
            presentationMode.wrappedValue.dismiss()
        } catch {
            validationError = error.localizedDescription
        }
    }
    
    private func insertSampleConfig() {
        configText = """
        [Interface]
        PrivateKey = aGVsbG93b3JsZGhlbGxvd29ybGRoZWxsb3dvcmxkMQ==
        Address = 10.8.0.2/24
        DNS = 1.1.1.1, 8.8.8.8
        # AmneziaWG DPI bypass parameters
        Jc = 4
        Jmin = 50
        Jmax = 110
        H1 = 287454020
        H2 = 578437696

        [Peer]
        PublicKey = dGVzdHB1YmxpY2tleXRlc3RwdWJsaWNrZXl0ZXN0MQ==
        Endpoint = 198.51.100.10:51820
        AllowedIPs = 0.0.0.0/0
        """
    }
}
