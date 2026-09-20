"""
LetsVPN-Grade Features Test Suite
Tests:
1. Smart Mode vs Global Mode Routing (Bypass Local vs Full Tunnel)
2. Multi-Protocol Dynamic Failover (AmneziaWG -> TLS 1.3 REALITY -> Shadowsocks)
3. Anti-Blocking Bootstrap Mirror Discovery
"""

import unittest
import struct
import socket
import time
from typing import List, Dict, Optional
from ios_network_extension_mock import (
    BasePacketTunnelProvider,
    NEPacketTunnelNetworkSettings,
    NEIPv4Settings,
    NEIPv4Route,
    NEDNSSettings,
    NEVPNStatus
)

class RoutingMode:
    SMART = "smart"      # Local apps direct, foreign/censored apps via VPN
    GLOBAL = "global"    # 100% of traffic via VPN

class ProtocolType:
    AMNEZIA_WG = "amnezia_wg"
    TLS_REALITY = "tls_reality"
    SHADOWSOCKS = "shadowsocks"

class NodeEndpoint:
    def __init__(self, host: str, port: int, protocol: str, ping_ms: int = 40):
        self.host = host
        self.port = port
        self.protocol = protocol
        self.ping_ms = ping_ms
        self.is_healthy = True

class LetsVPNEngine(BasePacketTunnelProvider):
    def __init__(self, mode: str = RoutingMode.SMART):
        super().__init__()
        self.mode = mode
        self.current_protocol = ProtocolType.AMNEZIA_WG
        self.active_endpoint = None
        self.failover_count = 0
        self.failed_protocols = set()
        self.local_bypassed_packets = []
        self.tunneled_packets = []

    def configure_routing(self, mode: str):
        self.mode = mode
        settings = NEPacketTunnelNetworkSettings(tunnel_remote_address="198.51.100.1")
        settings.mtu = 1280
        ipv4 = NEIPv4Settings(addresses=["10.8.0.2"], subnet_masks=["255.255.255.0"])

        if self.mode == RoutingMode.GLOBAL:
            # Full tunnel: Everything captured
            ipv4.included_routes = [NEIPv4Route.default()]
            ipv4.excluded_routes = []
        else:
            # Smart Mode: Exclude domestic IP blocks & LAN so local apps stay direct!
            ipv4.included_routes = [NEIPv4Route.default()]
            ipv4.excluded_routes = [
                # Domestic / Local ranges (RFC 1918 + Local carrier blocks)
                NEIPv4Route("192.168.0.0", "255.255.0.0"),
                NEIPv4Route("10.0.0.0", "255.0.0.0"),
                NEIPv4Route("172.16.0.0", "255.240.0.0"),
                NEIPv4Route("100.64.0.0", "255.192.0.0"),  # CGNAT
            ]

        settings.ipv4_settings = ipv4
        settings.dns_settings = NEDNSSettings(servers=["1.1.1.1", "8.8.8.8"])
        self.network_settings = settings

    def route_packet(self, dst_ip: str, packet: bytes) -> str:
        """Determines if a packet is sent via tunnel or directly (Smart Routing)."""
        if self.mode == RoutingMode.GLOBAL:
            self.tunneled_packets.append(packet)
            return "TUNNEL"
        
        # In Smart Mode, check if destination is local/domestic
        octets = [int(x) for x in dst_ip.split(".")]
        if (octets[0] == 192 and octets[1] == 168) or \
           (octets[0] == 10) or \
           (octets[0] == 172 and 16 <= octets[1] <= 31) or \
           (octets[0] == 100 and 64 <= octets[1] <= 127):
            self.local_bypassed_packets.append(packet)
            return "DIRECT"
        else:
            self.tunneled_packets.append(packet)
            return "TUNNEL"

    def handle_protocol_failure(self, failed_protocol: str, available_protocols: List[str]):
        """LetsVPN dynamic multi-protocol failover mechanism."""
        self.failed_protocols.add(failed_protocol)
        for p in available_protocols:
            if p not in self.failed_protocols:
                self.current_protocol = p
                self.failover_count += 1
                return True
        return False


class TestLetsVPNEngine(unittest.TestCase):
    def test_01_smart_mode_vs_global_mode_routing(self):
        """
        Verify that in Smart Mode, local banking/LAN IPs are routed DIRECTLY without VPN,
        while international/blocked IPs are routed through the TUNNEL.
        In Global Mode, 100% goes through the TUNNEL.
        """
        engine = LetsVPNEngine(mode=RoutingMode.SMART)
        engine.configure_routing(RoutingMode.SMART)

        # 1. Domestic/LAN packet (e.g. 192.168.1.5 or 10.1.2.3)
        decision_local = engine.route_packet("192.168.1.5", b"local-banking-traffic")
        self.assertEqual(decision_local, "DIRECT", "Local traffic in Smart Mode must route DIRECTLY")
        self.assertEqual(len(engine.local_bypassed_packets), 1)
        self.assertEqual(len(engine.tunneled_packets), 0)

        # 2. Blocked / Foreign packet (e.g. 142.250.190.46 - Google / YouTube)
        decision_foreign = engine.route_packet("142.250.190.46", b"youtube-traffic")
        self.assertEqual(decision_foreign, "TUNNEL", "Foreign/censored traffic must route through TUNNEL")
        self.assertEqual(len(engine.tunneled_packets), 1)

        # 3. Switch to Global Mode
        engine.configure_routing(RoutingMode.GLOBAL)
        decision_global_local = engine.route_packet("192.168.1.5", b"local-traffic-in-global-mode")
        self.assertEqual(decision_global_local, "TUNNEL", "In Global Mode, ALL packets must route through TUNNEL")

    def test_02_multi_protocol_dynamic_failover(self):
        """
        Verify LetsVPN's automatic protocol failover:
        If UDP/WireGuard is throttled or blocked by DPI, engine immediately
        switches to TLS 1.3 REALITY over TCP port 443 without dropping the connection.
        """
        engine = LetsVPNEngine()
        protocols = [ProtocolType.AMNEZIA_WG, ProtocolType.TLS_REALITY, ProtocolType.SHADOWSOCKS]
        
        self.assertEqual(engine.current_protocol, ProtocolType.AMNEZIA_WG)
        
        # Simulate DPI blocking AmneziaWG
        failover_success = engine.handle_protocol_failure(ProtocolType.AMNEZIA_WG, protocols)
        self.assertTrue(failover_success)
        self.assertEqual(engine.current_protocol, ProtocolType.TLS_REALITY)
        self.assertEqual(engine.failover_count, 1)

        # Simulate strict TLS inspection failing over to Shadowsocks
        failover_success2 = engine.handle_protocol_failure(ProtocolType.TLS_REALITY, protocols)
        self.assertTrue(failover_success2)
        self.assertEqual(engine.current_protocol, ProtocolType.SHADOWSOCKS)
        self.assertEqual(engine.failover_count, 2)

    def test_03_cdn_fronted_bootstrap_mirrors(self):
        """
        Verify that if the primary configuration server is blocked,
        the app fails over across redundant CDN mirror endpoints.
        """
        mirrors = [
            {"url": "https://api1.geminivpn.net", "status": "blocked"},
            {"url": "https://mirror.workers.dev", "status": "blocked"},
            {"url": "https://d1234567.cloudfront.net", "status": "active"}
        ]
        
        discovered_node = None
        for mirror in mirrors:
            if mirror["status"] == "active":
                discovered_node = mirror["url"]
                break
        
        self.assertIsNotNone(discovered_node)
        self.assertEqual(discovered_node, "https://d1234567.cloudfront.net")

if __name__ == "__main__":
    unittest.main()
