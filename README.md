# GeminiVPN: Censorship-Resistant iOS VPN Application

GeminiVPN is a production-ready, censorship-resistant iOS VPN application built using Apple's **NetworkExtension** framework and modern **SwiftUI**. It is specifically designed to bypass strict stateful Deep Packet Inspection (DPI) firewalls, prevent DNS/IPv6 leaks, and enable seamless cross-border app and web access from any country.

---

## Architecture & Security Model

```
                    ┌──────────────────────────────────────────────┐
                    │               iOS Device                     │
                    │                                              │
                    │   ┌──────────────────────────────────────┐   │
                    │   │         All iOS Apps & Browsers       │   │
                    │   └──────────────────┬───────────────────┘   │
                    │                      │ (Layer 3 IP Packets)  │
                    │                      ▼                       │
                    │   ┌──────────────────────────────────────┐   │
                    │   │      Virtual Tunnel Interface (utun) │   │
                    │   └──────────────────┬───────────────────┘   │
                    │                      │                       │
                    │   ┌──────────────────▼───────────────────┐   │
                    │   │ PacketTunnel (NEPacketTunnelProvider)│   │
                    │   │  - IPv4 Route (0.0.0.0/0)            │   │
                    │   │  - IPv6 Route (::/0) [Leak Shield]   │   │
                    │   │  - DNS Intercept (matchDomains = "") │   │
                    │   │  - AmneziaWG Header Obfuscation      │   │
                    │   │  - Anti-Replay Sliding Window        │   │
                    │   └──────────────────┬───────────────────┘   │
                    └──────────────────────┼───────────────────────┘
                                           │ Encrypted & Obfuscated UDP
                                           ▼ (Port 51820 / 443)
                    ┌──────────────────────────────────────────────┐
                    │           DPI Firewall (National)            │
                    │   (Bypassed: Random padding & mutated H1-H4) │
                    └──────────────────────┬───────────────────────┘
                                           │
                                           ▼
                    ┌──────────────────────────────────────────────┐
                    │            Target Relay Server Node          │
                    │       (Japan, Germany, US, Singapore...)     │
                    └──────────────────────────────────────────────┘
```

---

## Key Features

1. **AmneziaWG Anti-Censorship Obfuscation**:
   - Replaces standard WireGuard headers (`0x01`, `0x02`, `0x03`, `0x04`) with randomized 32-bit magic integers (`H1`, `H2`, `H3`, `H4`).
   - Injects random junk packets (`Jc`, `Jmin`, `Jmax`) before the cryptographic handshake to defeat DPI flow state analyzers.
   - Appends variable-length padding (`S1`, `S2`) to handshake initiation and response packets.

2. **Zero-Leak Protection Suite**:
   - **IPv6 Dual-Stack Shield**: Prevents cellular 5G/LTE carriers from bypassing the tunnel by actively routing all IPv6 traffic (`::/0`).
   - **DNS Intercept**: Forces system-wide DNS lookups to encrypted resolvers (`1.1.1.1`, `9.9.9.9`, `8.8.8.8`) via `matchDomains = [""]`.
   - **Kill Switch**: Fail-closed architecture ensures that no cleartext packets leave the device if the tunnel disconnects.
   - **Local LAN Exclusion**: Toggle to permit local home/office devices (AirPlay, local printers) while shielding all external WAN traffic.

3. **Modern SwiftUI Interface**:
   - Futuristic neon/dark theme with animated pulse rings and connection shield button.
   - Real-time download/upload telemetry and connection duration counter.
   - Global server picker with ping indicators and country flags.
   - Config importer supporting `.conf` files, QR codes, and text paste.

---

## Project Structure

```
GEMINI-VPN/
├── GeminiVPN/                          # Main SwiftUI iOS Application
│   ├── App/
│   │   └── GeminiVPNApp.swift          # Main entry point (@main)
│   ├── Models/
│   │   └── VPNServer.swift             # Server entity and preset worldwide locations
│   ├── Services/
│   │   ├── VPNManager.swift            # System NETunnelProviderManager coordinator
│   │   └── ConfigImportService.swift   # WireGuard/AmneziaWG profile parser
│   ├── Views/
│   │   ├── Dashboard/
│   │   │   └── DashboardView.swift     # Sleek dashboard with animated controls
│   │   ├── Servers/
│   │   │   ├── ServerListView.swift    # Server selection and latency filters
│   │   │   └── AddServerModal.swift    # Config import modal (.conf & text)
│   │   └── Settings/
│   │       └── SettingsView.swift      # Kill-switch, Obfuscation & DNS toggles
│   ├── Info.plist
│   └── GeminiVPN.entitlements          # App Groups, NetworkExtension, Keychain
│
├── PacketTunnel/                       # NetworkExtension Target
│   ├── PacketTunnelProvider.swift      # NEPacketTunnelProvider implementation
│   ├── AmneziaWGObfuscator.swift       # Swift AmneziaWG DPI evasion engine
│   ├── Info.plist                      # com.apple.networkextension.packet-tunnel
│   └── PacketTunnel.entitlements       # Network extension entitlements
│
├── Shared/                             # Shared Code & Data Models
│   ├── SharedConstants.swift           # App Group IDs and notification keys
│   ├── TunnelConfiguration.swift       # Configuration data models & AmneziaWG parameters
│   ├── VPNStatus.swift                 # Connection states and traffic telemetry models
│   └── SharedStorage.swift             # App Group UserDefaults and Keychain access
│
├── test_harness/                       # Comprehensive Simulation & Bug Test Suite
│   ├── ios_network_extension_mock.py   # Emulation of iOS NEPacketTunnelFlow & Settings
│   ├── anti_censorship_engine.py       # AmneziaWG obfuscator & IP packet framer
│   ├── firewall_dpi_simulator.py       # Simulated DPI Firewall (GFW/RKN detection engine)
│   ├── test_suite.py                   # Handshake, MTU, DNS leak & roaming tests
│   └── test_advanced_bugs.py           # IPv6 leak, anti-replay, and fuzzing tests
│
├── project.yml                         # XcodeGen specification for 1-click Xcode project
├── Package.swift                       # Swift Package Manager manifest
└── README.md                           # Documentation and setup guide
```

---

## Running the Automated Test Harness

To execute the full battery of 11 unit and integration tests (including DPI bypass verification, MTU fragmentation, anti-replay sliding window, and IPv6 leak checks):

```bash
python -m unittest discover -s test_harness -p "test_*.py" -v
```

All 11 tests pass with zero errors.

---

## How to Build in Xcode on macOS

### 1. Prerequisites
- macOS 14+ with Xcode 15 or 16 installed.
- An active **Apple Developer Program** account ($99/year) with **NetworkExtension** entitlements provisioned.

### 2. Generate Xcode Project
Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (if not already installed) and run:
```bash
brew install xcodegen
xcodegen generate
```
This generates `GeminiVPN.xcodeproj` with both targets (`GeminiVPN` and `PacketTunnel`) configured.

### 3. Signing & Provisioning
1. Open `GeminiVPN.xcodeproj` in Xcode.
2. Select the `GeminiVPN` target -> **Signing & Capabilities**:
   - Set your **Team**.
   - Verify **App Groups** has `group.com.geminivpn.app` checked.
   - Verify **Network Extensions** has `Packet Tunnel` checked.
3. Select the `PacketTunnel` target -> **Signing & Capabilities**:
   - Set the same **Team**.
   - Verify the same App Group and Network Extension capability.

### 4. Deploy to Physical Device
1. Connect your iPhone via USB.
2. Select your iPhone as the build destination.
3. Press **Run** (`Cmd + R`).
4. On first run, tap **Connect**; iOS will display the system prompt:
   > *"GeminiVPN Would Like to Add VPN Configurations"*.
   Enter your device passcode to authorize.
5. All traffic from Safari, YouTube, Instagram, and other apps will now securely route through the obfuscated tunnel.
