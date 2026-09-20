"""
National Firewall & DPI (Deep Packet Inspection) Simulator
Simulates active packet inspection, protocol fingerprinting, and censorship blocking
typical of restrictive national firewalls (e.g., GFW, RKN, etc.).
"""

import struct
from typing import Dict, List, Tuple

class DPIFirewallResult:
    def __init__(self, blocked: bool, reason: str = "", rule_matched: str = ""):
        self.blocked = blocked
        self.reason = reason
        self.rule_matched = rule_matched

class FirewallDPISimulator:
    def __init__(self):
        self.blocked_domains = [
            "instagram.com",
            "twitter.com",
            "x.com",
            "youtube.com",
            "facebook.com",
            "telegram.org",
            "whatsapp.com",
            "tiktok.com"
        ]
        self.blocked_ips = ["198.51.100.1", "203.0.113.5"]
        self.inspected_packets_count = 0
        self.blocked_packets_count = 0
        self.active_blocked_flows = set()

    def inspect_packet(self, packet: bytes, is_inside_tunnel: bool = False) -> DPIFirewallResult:
        """
        Inspects an IP or UDP packet passing through the transit network.
        If is_inside_tunnel is True, this represents traffic that was successfully encrypted
        and encapsulated before reaching the physical network adapter.
        """
        self.inspected_packets_count += 1

        # Check 1: Standard WireGuard Handshake Detection (DPI Rule)
        # Standard WireGuard initiation is exactly 148 bytes, starting with 0x01000000.
        if len(packet) == 148 and packet[:4] == b'\x01\x00\x00\x00':
            self.blocked_packets_count += 1
            return DPIFirewallResult(
                blocked=True,
                reason="Standard WireGuard Handshake Initiation Fingerprint Detected (148 bytes, Type 0x01)",
                rule_matched="DPI-RULE-WG-01"
            )

        # Check 2: Standard WireGuard Response Detection
        # Standard WireGuard response is exactly 92 bytes, starting with 0x02000000.
        if len(packet) == 92 and packet[:4] == b'\x02\x00\x00\x00':
            self.blocked_packets_count += 1
            return DPIFirewallResult(
                blocked=True,
                reason="Standard WireGuard Handshake Response Fingerprint Detected (92 bytes, Type 0x02)",
                rule_matched="DPI-RULE-WG-02"
            )

        # Check 3: Cleartext DNS Leak Inspection (Port 53 UDP)
        if not is_inside_tunnel and len(packet) >= 28:
            # Check if IPv4 UDP packet
            proto = packet[9]
            if proto == 17:  # UDP
                src_port, dst_port = struct.unpack("!HH", packet[20:24])
                if dst_port == 53:
                    # Cleartext DNS query detected outside tunnel!
                    dns_payload = packet[28:]
                    # Parse DNS wire format QNAME (starts at offset 12 in DNS payload)
                    extracted_domain = ""
                    if len(dns_payload) > 12:
                        idx = 12
                        parts = []
                        while idx < len(dns_payload):
                            length = dns_payload[idx]
                            if length == 0:
                                break
                            idx += 1
                            if idx + length <= len(dns_payload):
                                parts.append(dns_payload[idx:idx+length].decode('ascii', errors='ignore'))
                                idx += length
                            else:
                                break
                        extracted_domain = ".".join(parts).lower()

                    for domain in self.blocked_domains:
                        domain_bytes = domain.encode('ascii')
                        # Check either domain wire-format or decoded QNAME
                        if domain == extracted_domain or domain_bytes in dns_payload.lower():
                            self.blocked_packets_count += 1
                            return DPIFirewallResult(
                                blocked=True,
                                reason=f"Cleartext DNS Leak for censored domain '{domain}' intercepted",
                                rule_matched="DPI-RULE-DNS-LEAK"
                            )

        # Check 4: Cleartext HTTP / TLS SNI Inspection
        if not is_inside_tunnel and len(packet) >= 40:
            for domain in self.blocked_domains:
                if domain.encode('utf-8') in packet:
                    self.blocked_packets_count += 1
                    return DPIFirewallResult(
                        blocked=True,
                        reason=f"Censored domain '{domain}' detected in unencrypted Layer 7 payload",
                        rule_matched="DPI-RULE-SNI-FILTER"
                    )

        # If it's an obfuscated packet (e.g. AmneziaWG with custom headers and random padding):
        # DPI cannot match the signature, packet passes through!
        return DPIFirewallResult(blocked=False, reason="Traffic permitted (No censorship signature matched)")
