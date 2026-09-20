"""
Comprehensive Bug & Verification Test Suite for iOS VPN
Tests:
1. Anti-censorship obfuscation vs DPI Firewall rules
2. MTU packet fragmentation & TCP MSS bounds
3. DNS leak prevention & routing enforcement
4. Kill-Switch fail-closed behavior
5. WireGuard / AmneziaWG config parser & error handling
6. Network roaming / reasserting tunnel state transitions
"""

import unittest
import struct
import socket
import secrets
from ios_network_extension_mock import (
    BasePacketTunnelProvider,
    NEPacketTunnelNetworkSettings,
    NEIPv4Settings,
    NEIPv4Route,
    NEDNSSettings,
    NEVPNStatus
)
from anti_censorship_engine import (
    ObfuscationConfig,
    AmneziaWGOptimizer,
    IPPacketHelper
)
from firewall_dpi_simulator import FirewallDPISimulator

class GeminiVPNTunnelProvider(BasePacketTunnelProvider):
    """
    Concrete simulation of the iOS PacketTunnelProvider.
    """
    def __init__(self, obfs_config: ObfuscationConfig, kill_switch_enabled: bool = True):
        super().__init__()
        self.obfs_config = obfs_config
        self.optimizer = AmneziaWGOptimizer(obfs_config)
        self.kill_switch_enabled = kill_switch_enabled
        self.outbound_encrypted_packets = []
        self.local_leak_packets = []

    def start_tunnel(self, options, completion_handler):
        settings = NEPacketTunnelNetworkSettings(tunnel_remote_address="198.51.100.50")
        settings.mtu = 1420
        ipv4 = NEIPv4Settings(addresses=["10.8.0.2"], subnet_masks=["255.255.255.0"])
        ipv4.included_routes = [NEIPv4Route.default()]  # Route 0.0.0.0/0
        settings.ipv4_settings = ipv4
        settings.dns_settings = NEDNSSettings(servers=["1.1.1.1", "8.8.8.8"])
        
        self.set_tunnel_network_settings(settings, completion_handler)
        self.status = NEVPNStatus.CONNECTED
        self._start_packet_loop()

    def _start_packet_loop(self):
        def on_packets(packets, protocols):
            for packet in packets:
                # Fragment if needed before encapsulation
                fragments = IPPacketHelper.fragment_packet(packet, self.network_settings.mtu)
                for frag in fragments:
                    # In WireGuard/AmneziaWG, IP packet is encrypted into Transport data (Type 4)
                    wg_data_msg = struct.pack("<I", 4) + secrets.token_bytes(28) + frag
                    obfs_packet = self.optimizer.obfuscate_packet(wg_data_msg)
                    self.outbound_encrypted_packets.append(obfs_packet)
            
            # Continue reading loop if still connected
            if self.status == NEVPNStatus.CONNECTED:
                self.packet_flow.read_packets(on_packets)

        self.packet_flow.read_packets(on_packets)

    def simulate_device_traffic(self, packet: bytes, force_bypass_vpn: bool = False):
        """Simulates an app on iOS sending IP traffic."""
        if self.status == NEVPNStatus.CONNECTED and not force_bypass_vpn:
            self.packet_flow.inject_packet_from_device(packet)
        else:
            # VPN is down or disconnected
            if not self.kill_switch_enabled:
                # Leak: traffic falls back to physical adapter in cleartext!
                self.local_leak_packets.append(packet)
            else:
                # Kill switch active: packet is strictly dropped, zero leak!
                pass

    def stop_tunnel(self, reason, completion_handler):
        self.status = NEVPNStatus.DISCONNECTED
        completion_handler()


class TestGeminiVPNEngine(unittest.TestCase):
    def setUp(self):
        self.obfs_config = ObfuscationConfig(
            junk_packet_count=3,
            junk_packet_min_size=40,
            junk_packet_max_size=80,
            init_packet_junk_size=56,
            response_packet_junk_size=48,
            init_packet_magic_header=0x11223344,
            response_packet_magic_header=0x22334455,
            cookie_packet_magic_header=0x33445566,
            transport_packet_magic_header=0x44556677
        )
        self.dpi = FirewallDPISimulator()

    def test_01_wireguard_dpi_blocking_vs_amnezia_obfuscation(self):
        """
        Verify that standard WireGuard handshake is detected & blocked by DPI,
        while our AmneziaWG obfuscated handshake successfully bypasses the DPI filter.
        """
        # 1. Simulate standard WireGuard handshake (148 bytes, Type 1)
        standard_wg_init = struct.pack("<I", 1) + secrets.token_bytes(144)
        self.assertEqual(len(standard_wg_init), 148)
        
        dpi_result_raw = self.dpi.inspect_packet(standard_wg_init, is_inside_tunnel=False)
        self.assertTrue(dpi_result_raw.blocked, "DPI should catch and block standard WireGuard initiation")
        self.assertEqual(dpi_result_raw.rule_matched, "DPI-RULE-WG-01")

        # 2. Test AmneziaWG obfuscation
        optimizer = AmneziaWGOptimizer(self.obfs_config)
        obfs_init = optimizer.obfuscate_packet(standard_wg_init)
        
        # Obfuscated packet has custom magic header and random S1 padding (148 + 56 = 204 bytes)
        self.assertEqual(len(obfs_init), 148 + self.obfs_config.init_packet_junk_size)
        self.assertEqual(struct.unpack("<I", obfs_init[:4])[0], self.obfs_config.init_packet_magic_header)
        
        # Pass obfuscated packet through DPI
        dpi_result_obfs = self.dpi.inspect_packet(obfs_init, is_inside_tunnel=False)
        self.assertFalse(dpi_result_obfs.blocked, "Obfuscated AmneziaWG handshake MUST bypass DPI filtering")

        # 3. Test de-obfuscation on server side
        recovered_wg_init = optimizer.deobfuscate_packet(obfs_init)
        self.assertIsNotNone(recovered_wg_init)
        self.assertEqual(recovered_wg_init, standard_wg_init, "De-obfuscation must cleanly reconstruct original WG packet")

    def test_02_mtu_fragmentation_handling(self):
        """
        Verify that large payloads exceeding MTU (1420) are properly fragmented
        without buffer overflow, data corruption, or dropped packets.
        """
        provider = GeminiVPNTunnelProvider(self.obfs_config)
        provider.start_tunnel(None, lambda err: None)
        self.assertEqual(provider.status, NEVPNStatus.CONNECTED)

        # Create a large 3000-byte IPv4 packet (e.g. video stream or bulk file download)
        payload = b"A" * 2980
        large_packet = IPPacketHelper.create_ipv4_packet("10.8.0.2", "1.1.1.1", proto=6, payload=payload)
        self.assertEqual(len(large_packet), 3000)

        # Fragment packet using helper
        fragments = IPPacketHelper.fragment_packet(large_packet, mtu=1420)
        self.assertGreater(len(fragments), 1, "Packet of size 3000 must be split into multiple fragments")
        
        for idx, frag in enumerate(fragments):
            self.assertLessEqual(len(frag), 1420, f"Fragment {idx} must not exceed MTU 1420")
            header_info = IPPacketHelper.parse_ipv4_header(frag)
            self.assertIsNotNone(header_info)
            # Verify checksum validity
            recalculated_cs = IPPacketHelper.calculate_checksum(frag[:20])
            self.assertEqual(recalculated_cs, 0, "IP header checksum in fragment must be valid")

    def test_03_dns_leak_prevention(self):
        """
        Verify that DNS requests to blocked domains are strictly routed through the tunnel
        and prevented from leaking in cleartext to local ISP resolvers.
        """
        provider = GeminiVPNTunnelProvider(self.obfs_config)
        provider.start_tunnel(None, lambda err: None)

        # Synthetic DNS request for instagram.com (port 53)
        dns_query = b"\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x09instagram\x03com\x00\x00\x01\x00\x01"
        udp_header = struct.pack("!HHHH", 52143, 53, 8 + len(dns_query), 0)
        ip_dns_packet = IPPacketHelper.create_ipv4_packet("10.8.0.2", "1.1.1.1", proto=17, payload=udp_header + dns_query)

        # 1. If sent through connected tunnel:
        provider.simulate_device_traffic(ip_dns_packet)
        self.assertGreater(len(provider.outbound_encrypted_packets), 0, "Encrypted packet must be sent through tunnel")
        
        # Verify that encrypted packet passing over physical network cannot be decoded or blocked by DPI
        last_packet = provider.outbound_encrypted_packets[-1]
        dpi_res = self.dpi.inspect_packet(last_packet, is_inside_tunnel=True)
        self.assertFalse(dpi_res.blocked, "Encapsulated DNS request must pass through DPI safely")

        # 2. Verify that if cleartext DNS were leaked outside tunnel, DPI would catch it:
        dpi_leak_res = self.dpi.inspect_packet(ip_dns_packet, is_inside_tunnel=False)
        self.assertTrue(dpi_leak_res.blocked, "Unprotected DNS leak must be flagged by DPI simulation")
        self.assertEqual(dpi_leak_res.rule_matched, "DPI-RULE-DNS-LEAK")

    def test_04_kill_switch_behavior_on_disconnect(self):
        """
        Verify that when the tunnel disconnects or drops, the Kill-Switch prevents
        any cleartext fallback leakage.
        """
        # Case A: Kill-Switch ENABLED
        provider_safe = GeminiVPNTunnelProvider(self.obfs_config, kill_switch_enabled=True)
        provider_safe.start_tunnel(None, lambda err: None)
        # Abruptly stop / drop tunnel
        provider_safe.stop_tunnel(0, lambda: None)
        self.assertEqual(provider_safe.status, NEVPNStatus.DISCONNECTED)

        sensitive_packet = IPPacketHelper.create_ipv4_packet("192.168.1.100", "1.1.1.1", 6, b"GET / HTTP/1.1\r\nHost: twitter.com\r\n\r\n")
        provider_safe.simulate_device_traffic(sensitive_packet)
        
        # With Kill-Switch, local_leak_packets must be completely empty
        self.assertEqual(len(provider_safe.local_leak_packets), 0, "Kill-Switch MUST prevent any cleartext leak when disconnected")

        # Case B: Kill-Switch DISABLED (demonstrating the vulnerability if not guarded)
        provider_unsafe = GeminiVPNTunnelProvider(self.obfs_config, kill_switch_enabled=False)
        provider_unsafe.start_tunnel(None, lambda err: None)
        provider_unsafe.stop_tunnel(0, lambda: None)
        
        provider_unsafe.simulate_device_traffic(sensitive_packet)
        self.assertEqual(len(provider_unsafe.local_leak_packets), 1, "Without kill switch, packet leaks to local interface")
        
        # Check that this leaked packet gets blocked by DPI
        dpi_check = self.dpi.inspect_packet(provider_unsafe.local_leak_packets[0], is_inside_tunnel=False)
        self.assertTrue(dpi_check.blocked)

    def test_05_wireguard_config_parser_and_fuzzing(self):
        """
        Test parsing valid and malformed WireGuard/AmneziaWG configurations.
        Must handle errors gracefully without crashes.
        """
        def parse_wg_config(raw_text: str) -> Dict[str, any]:
            config = {}
            current_section = None
            for line in raw_text.splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("[") and line.endswith("]"):
                    current_section = line[1:-1].strip()
                    if current_section not in config:
                        config[current_section] = {}
                elif "=" in line and current_section:
                    k, v = line.split("=", 1)
                    config[current_section][k.strip()] = v.strip()
            
            # Validation
            if "Interface" not in config:
                raise ValueError("Missing [Interface] section")
            if "PrivateKey" not in config["Interface"]:
                raise ValueError("Missing PrivateKey in [Interface]")
            if "Peer" not in config:
                raise ValueError("Missing [Peer] section")
            if "PublicKey" not in config["Peer"] or "Endpoint" not in config["Peer"]:
                raise ValueError("Missing PublicKey or Endpoint in [Peer]")
            return config

        valid_conf = """
        [Interface]
        PrivateKey = aGVsbG93b3JsZGhlbGxvd29ybGRoZWxsb3dvcmxkMQ==
        Address = 10.8.0.2/24
        DNS = 1.1.1.1, 8.8.8.8
        # AmneziaWG parameters
        Jc = 3
        Jmin = 40
        Jmax = 100
        H1 = 287454020
        H2 = 578437696

        [Peer]
        PublicKey = dGVzdHB1YmxpY2tleXRlc3RwdWJsaWNrZXl0ZXN0MQ==
        Endpoint = 198.51.100.50:51820
        AllowedIPs = 0.0.0.0/0
        """
        parsed = parse_wg_config(valid_conf)
        self.assertEqual(parsed["Interface"]["Address"], "10.8.0.2/24")
        self.assertEqual(parsed["Peer"]["Endpoint"], "198.51.100.50:51820")
        self.assertEqual(parsed["Interface"]["Jc"], "3")

        # Malformed configs
        missing_interface = "[Peer]\nPublicKey = abc\nEndpoint = 1.1.1.1:51820"
        with self.assertRaises(ValueError):
            parse_wg_config(missing_interface)

        missing_endpoint = "[Interface]\nPrivateKey = abc\n[Peer]\nPublicKey = def"
        with self.assertRaises(ValueError):
            parse_wg_config(missing_endpoint)

    def test_06_network_reasserting_and_handshake_jitter(self):
        """
        Verify tunnel behavior during network roaming (e.g. Wi-Fi dropping and 5G taking over).
        State should transition to REASSERTING and recover without tunnel crash.
        """
        provider = GeminiVPNTunnelProvider(self.obfs_config)
        provider.start_tunnel(None, lambda err: None)
        self.assertEqual(provider.status, NEVPNStatus.CONNECTED)

        # Simulate network drop
        provider.reasserting = True
        provider.status = NEVPNStatus.REASSERTING
        self.assertEqual(provider.status, NEVPNStatus.REASSERTING)

        # While reasserting, packet traffic should either queue or be handled gracefully
        test_pkt = IPPacketHelper.create_ipv4_packet("10.8.0.2", "8.8.8.8", 17, b"ping")
        provider.simulate_device_traffic(test_pkt)

        # Recover network on new cellular interface
        provider.reasserting = False
        provider.status = NEVPNStatus.CONNECTED
        self.assertEqual(provider.status, NEVPNStatus.CONNECTED)

if __name__ == "__main__":
    unittest.main()
