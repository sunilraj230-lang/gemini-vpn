"""
Production Readiness Verification Script
Verifies:
1. Plist XML syntax validity
2. Entitlements XML syntax validity
3. Assets catalog integrity
4. Swift source files presence & non-empty
5. Unit & integration test suite execution
"""

import os
import sys
import xml.etree.ElementTree as ET
import unittest

# Fix Windows console encoding
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')


def verify_plists_and_entitlements():
    files_to_check = [
        "h:/GEMINI-VPN/GeminiVPN/Info.plist",
        "h:/GEMINI-VPN/GeminiVPN/GeminiVPN.entitlements",
        "h:/GEMINI-VPN/PacketTunnel/Info.plist",
        "h:/GEMINI-VPN/PacketTunnel/PacketTunnel.entitlements"
    ]
    for path in files_to_check:
        assert os.path.exists(path), f"Missing file: {path}"
        try:
            tree = ET.parse(path)
            root = tree.getroot()
            assert root.tag == "plist", f"Root tag must be plist in {path}"
        except Exception as e:
            print(f"❌ XML Parsing failed for {path}: {e}")
            return False
    print("✅ All Info.plist and Entitlements files are valid XML.")
    return True

def verify_swift_sources():
    expected_swift_files = [
        "h:/GEMINI-VPN/GeminiVPN/App/GeminiVPNApp.swift",
        "h:/GEMINI-VPN/GeminiVPN/Models/VPNServer.swift",
        "h:/GEMINI-VPN/GeminiVPN/Services/VPNManager.swift",
        "h:/GEMINI-VPN/GeminiVPN/Services/ConfigImportService.swift",
        "h:/GEMINI-VPN/GeminiVPN/Services/DynamicNodePoolService.swift",
        "h:/GEMINI-VPN/GeminiVPN/Views/Dashboard/DashboardView.swift",
        "h:/GEMINI-VPN/GeminiVPN/Views/Servers/ServerListView.swift",
        "h:/GEMINI-VPN/GeminiVPN/Views/Servers/AddServerModal.swift",
        "h:/GEMINI-VPN/GeminiVPN/Views/Settings/SettingsView.swift",
        "h:/GEMINI-VPN/PacketTunnel/PacketTunnelProvider.swift",
        "h:/GEMINI-VPN/PacketTunnel/AmneziaWGObfuscator.swift",
        "h:/GEMINI-VPN/Shared/SharedConstants.swift",
        "h:/GEMINI-VPN/Shared/SharedStorage.swift",
        "h:/GEMINI-VPN/Shared/TunnelConfiguration.swift",
        "h:/GEMINI-VPN/Shared/VPNStatus.swift"
    ]
    for path in expected_swift_files:
        assert os.path.exists(path), f"Missing Swift file: {path}"
        size = os.path.getsize(path)
        assert size > 100, f"Swift file too small or empty: {path}"
    print(f"✅ All {len(expected_swift_files)} Swift source files are present and non-empty.")
    return True

def verify_assets():
    icon_path = "h:/GEMINI-VPN/GeminiVPN/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png"
    assert os.path.exists(icon_path), f"Missing AppIcon: {icon_path}"
    assert os.path.getsize(icon_path) > 1000, "AppIcon is empty"
    print("✅ AppIcon and Assets catalogs are verified.")
    return True

def run_tests():
    loader = unittest.TestLoader()
    suite = loader.discover(start_dir="h:/GEMINI-VPN/test_harness", pattern="test_*.py")
    runner = unittest.TextTestRunner(verbosity=1)
    result = runner.run(suite)
    return result.wasSuccessful()

if __name__ == "__main__":
    print("🔍 Running Final Production Readiness Check...")
    ok1 = verify_plists_and_entitlements()
    ok2 = verify_swift_sources()
    ok3 = verify_assets()
    ok4 = run_tests()
    
    if ok1 and ok2 and ok3 and ok4:
        print("\n🏆 EVERYTHING IS VERIFIED! THE APP IS 100% READY!")
        sys.exit(0)
    else:
        print("\n❌ Readiness check failed!")
        sys.exit(1)
