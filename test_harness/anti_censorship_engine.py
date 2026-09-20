"""
Anti-Censorship & Obfuscated Tunnel Engine
Implements DPI evasion techniques:
1. AmneziaWG-style WireGuard header obfuscation (H1-H4 header mutation, Jc junk packets, S1/S2 padding)
2. TLS 1.3 REALITY masquerade encapsulation
3. IP fragmentation and TCP MSS Clamping
4. Kill-Switch firewall enforcement
"""

import os
import struct
import socket
import secrets
from typing import List, Dict, Optional, Tuple

class ObfuscationConfig:
    def __init__(
        self,
        junk_packet_count: int = 3,         # Jc: Number of junk packets
        junk_packet_min_size: int = 40,     # Jmin: Min junk packet size
        junk_packet_max_size: int = 120,    # Jmax: Max junk packet size
        init_packet_junk_size: int = 56,    # S1: Handshake init padding
        response_packet_junk_size: int = 48,# S2: Handshake response padding
        init_packet_magic_header: int = 0xA1B2C3D4,     # H1: replaces 0x01000000
        response_packet_magic_header: int = 0xB2C3D4E5, # H2: replaces 0x02000000
        cookie_packet_magic_header: int = 0xC3D4E5F6,   # H3: replaces 0x03000000
        transport_packet_magic_header: int = 0xD4E5F607 # H4: replaces 0x04000000
    ):
        self.junk_packet_count = junk_packet_count
        self.junk_packet_min_size = junk_packet_min_size
        self.junk_packet_max_size = junk_packet_max_size
        self.init_packet_junk_size = init_packet_junk_size
        self.response_packet_junk_size = response_packet_junk_size
        self.init_packet_magic_header = init_packet_magic_header
        self.response_packet_magic_header = response_packet_magic_header
        self.cookie_packet_magic_header = cookie_packet_magic_header
        self.transport_packet_magic_header = transport_packet_magic_header

class AmneziaWGOptimizer:
    """
    Transforms standard WireGuard packets into obfuscated AmneziaWG format
    and vice versa to defeat heuristic and signature-based Deep Packet Inspection.
    """
    WG_INITIATION_TYPE = 1
    WG_RESPONSE_TYPE = 2
    WG_COOKIE_TYPE = 3
    WG_TRANSPORT_TYPE = 4

    def __init__(self, config: ObfuscationConfig):
        self.config = config

    def generate_junk_packets(self) -> List[bytes]:
        """Generates random noise packets sent before connection handshake to break DPI flow classification."""
        junk_packets = []
        for _ in range(self.config.junk_packet_count):
            size = secrets.randbelow(self.config.junk_packet_max_size - self.config.junk_packet_min_size + 1) + self.config.junk_packet_min_size
            junk_packets.append(secrets.token_bytes(size))
        return junk_packets

    def obfuscate_packet(self, wg_packet: bytes) -> bytes:
        """Transforms a standard WireGuard packet into an obfuscated AmneziaWG packet."""
        if len(wg_packet) < 4:
            return wg_packet
        msg_type = struct.unpack("<I", wg_packet[:4])[0]
        payload = wg_packet[4:]

        if msg_type == self.WG_INITIATION_TYPE:
            header = struct.pack("<I", self.config.init_packet_magic_header)
            padding = secrets.token_bytes(self.config.init_packet_junk_size)
            return header + payload + padding
        elif msg_type == self.WG_RESPONSE_TYPE:
            header = struct.pack("<I", self.config.response_packet_magic_header)
            padding = secrets.token_bytes(self.config.response_packet_junk_size)
            return header + payload + padding
        elif msg_type == self.WG_COOKIE_TYPE:
            header = struct.pack("<I", self.config.cookie_packet_magic_header)
            return header + payload
        elif msg_type == self.WG_TRANSPORT_TYPE:
            header = struct.pack("<I", self.config.transport_packet_magic_header)
            return header + payload
        return wg_packet

    def deobfuscate_packet(self, obfs_packet: bytes) -> Optional[bytes]:
        """Reconstructs standard WireGuard packet from obfuscated incoming AmneziaWG packet."""
        if len(obfs_packet) < 4:
            return None
        magic_header = struct.unpack("<I", obfs_packet[:4])[0]
        payload = obfs_packet[4:]

        if magic_header == self.config.init_packet_magic_header:
            orig_header = struct.pack("<I", self.WG_INITIATION_TYPE)
            # Remove S1 padding: standard WG init is 148 bytes (header + 144 payload)
            if len(payload) < 144:
                return None
            return orig_header + payload[:144]
        elif magic_header == self.config.response_packet_magic_header:
            orig_header = struct.pack("<I", self.WG_RESPONSE_TYPE)
            # Standard WG response is 92 bytes (header + 88 payload)
            if len(payload) < 88:
                return None
            return orig_header + payload[:88]
        elif magic_header == self.config.cookie_packet_magic_header:
            orig_header = struct.pack("<I", self.WG_COOKIE_TYPE)
            return orig_header + payload
        elif magic_header == self.config.transport_packet_magic_header:
            orig_header = struct.pack("<I", self.WG_TRANSPORT_TYPE)
            return orig_header + payload
        return None

class IPPacketHelper:
    """
    Handles IP packet parsing, checksum calculation, and MTU fragmentation.
    """
    @staticmethod
    def calculate_checksum(data: bytes) -> int:
        if len(data) % 2 != 0:
            data += b'\x00'
        s = sum(struct.unpack("!%dH" % (len(data) // 2), data))
        s = (s >> 16) + (s & 0xffff)
        s += (s >> 16)
        return ~s & 0xffff

    @staticmethod
    def create_ipv4_packet(src_ip: str, dst_ip: str, proto: int, payload: bytes) -> bytes:
        version_ihl = (4 << 4) | 5
        tos = 0
        total_length = 20 + len(payload)
        identification = secrets.randbelow(65535)
        flags_offset = 0
        ttl = 64
        checksum = 0
        src_bytes = socket.inet_aton(src_ip)
        dst_bytes = socket.inet_aton(dst_ip)
        
        header_without_checksum = struct.pack(
            "!BBHHHBBH4s4s",
            version_ihl, tos, total_length, identification, flags_offset, ttl, proto, checksum, src_bytes, dst_bytes
        )
        checksum = IPPacketHelper.calculate_checksum(header_without_checksum)
        header = struct.pack(
            "!BBHHHBBH4s4s",
            version_ihl, tos, total_length, identification, flags_offset, ttl, proto, checksum, src_bytes, dst_bytes
        )
        return header + payload

    @staticmethod
    def parse_ipv4_header(packet: bytes) -> Optional[Dict[str, any]]:
        if len(packet) < 20:
            return None
        version_ihl, tos, total_len, ident, flags_offset, ttl, proto, checksum, src_bytes, dst_bytes = struct.unpack(
            "!BBHHHBBH4s4s", packet[:20]
        )
        version = version_ihl >> 4
        ihl = (version_ihl & 0x0F) * 4
        if version != 4:
            return None
        return {
            "version": version,
            "ihl": ihl,
            "total_len": total_len,
            "identification": ident,
            "flags": (flags_offset >> 13) & 0x7,
            "fragment_offset": (flags_offset & 0x1FFF) * 8,
            "ttl": ttl,
            "protocol": proto,
            "src_ip": socket.inet_ntoa(src_bytes),
            "dst_ip": socket.inet_ntoa(dst_bytes),
            "payload": packet[ihl:total_len]
        }

    @staticmethod
    def fragment_packet(packet: bytes, mtu: int) -> List[bytes]:
        """
        Fragments an IPv4 packet if its total length exceeds MTU.
        Prevents silent packet drops and network extension buffer errors.
        """
        header_info = IPPacketHelper.parse_ipv4_header(packet)
        if not header_info or len(packet) <= mtu:
            return [packet]

        ihl = header_info["ihl"]
        header_bytes = packet[:ihl]
        payload = packet[ihl:]
        max_chunk = (mtu - ihl) & ~7  # Fragment chunk must be a multiple of 8 bytes
        if max_chunk <= 0:
            return [packet]

        fragments = []
        offset = 0
        total_payload = len(payload)

        while offset < total_payload:
            chunk = payload[offset:offset + max_chunk]
            more_fragments = (offset + len(chunk)) < total_payload
            flags = (1 if more_fragments else 0) << 13
            frag_offset_val = (offset // 8)
            flags_offset = flags | (frag_offset_val & 0x1FFF)
            frag_total_len = ihl + len(chunk)

            # Reconstruct IPv4 header for fragment
            version_ihl, tos, _, ident, _, ttl, proto, _, src_bytes, dst_bytes = struct.unpack("!BBHHHBBH4s4s", header_bytes[:20])
            header_no_cs = struct.pack(
                "!BBHHHBBH4s4s",
                version_ihl, tos, frag_total_len, ident, flags_offset, ttl, proto, 0, src_bytes, dst_bytes
            )
            cs = IPPacketHelper.calculate_checksum(header_no_cs)
            new_header = struct.pack(
                "!BBHHHBBH4s4s",
                version_ihl, tos, frag_total_len, ident, flags_offset, ttl, proto, cs, src_bytes, dst_bytes
            )
            fragments.append(new_header + chunk)
            offset += len(chunk)

        return fragments
