"""
iOS NetworkExtension Simulation Environment
Simulates Apple's NetworkExtension framework (NEPacketTunnelProvider, NEPacketTunnelFlow,
and NEPacketTunnelNetworkSettings) for testing VPN tunneling, MTU boundaries, routing,
and leak prevention.
"""

import struct
import socket
import enum
from typing import List, Dict, Optional, Callable, Tuple

class NEVPNStatus(enum.Enum):
    INVALID = 0
    DISCONNECTED = 1
    CONNECTING = 2
    CONNECTED = 3
    REASSERTING = 4
    DISCONNECTING = 5

class NEIPv4Route:
    def __init__(self, destination_address: str, subnet_mask: str):
        self.destination_address = destination_address
        self.subnet_mask = subnet_mask

    @staticmethod
    def default() -> 'NEIPv4Route':
        return NEIPv4Route("0.0.0.0", "0.0.0.0")

class NEIPv4Settings:
    def __init__(self, addresses: List[str], subnet_masks: List[str]):
        self.addresses = addresses
        self.subnet_masks = subnet_masks
        self.included_routes: List[NEIPv4Route] = []
        self.excluded_routes: List[NEIPv4Route] = []

class NEDNSSettings:
    def __init__(self, servers: List[str]):
        self.servers = servers
        self.search_domains: List[str] = []
        self.match_domains: List[str] = [""]  # Default: all domains routed to VPN DNS

class NEPacketTunnelNetworkSettings:
    def __init__(self, tunnel_remote_address: str):
        self.tunnel_remote_address = tunnel_remote_address
        self.ipv4_settings: Optional[NEIPv4Settings] = None
        self.dns_settings: Optional[NEDNSSettings] = None
        self.mtu: int = 1420

class MockPacketTunnelFlow:
    """
    Simulates iOS NEPacketTunnelFlow:
    Provides packet injection and reception to and from the virtual tunnel interface (utun).
    """
    def __init__(self, mtu: int = 1420):
        self.mtu = mtu
        self.outbound_queue: List[bytes] = []
        self.inbound_queue: List[bytes] = []
        self.dropped_packets: List[Tuple[bytes, str]] = []
        self.read_handler: Optional[Callable[[List[bytes], List[int]], None]] = None

    def write_packets(self, packets: List[bytes], protocols: List[int]) -> bool:
        """Called by NEPacketTunnelProvider to send decrypted packets into the iOS network stack."""
        for packet, proto in zip(packets, protocols):
            if len(packet) > self.mtu:
                self.dropped_packets.append((packet, f"Exceeded MTU {self.mtu} (size: {len(packet)})"))
                return False
            self.inbound_queue.append(packet)
        return True

    def inject_packet_from_device(self, packet: bytes, protocol: int = socket.AF_INET):
        """Simulates an app or the iOS system generating outbound IP traffic towards utun."""
        if len(packet) > self.mtu:
            self.dropped_packets.append((packet, f"Outbound packet exceeds MTU {self.mtu} (size: {len(packet)})"))
            return False
        self.outbound_queue.append(packet)
        if self.read_handler:
            handler = self.read_handler
            self.read_handler = None
            packets_to_read = list(self.outbound_queue)
            self.outbound_queue.clear()
            protocols = [protocol] * len(packets_to_read)
            handler(packets_to_read, protocols)
        return True

    def read_packets(self, completion_handler: Callable[[List[bytes], List[int]], None]):
        """Called by NEPacketTunnelProvider to receive raw IP packets destined for the tunnel."""
        if self.outbound_queue:
            packets_to_read = list(self.outbound_queue)
            self.outbound_queue.clear()
            protocols = [socket.AF_INET] * len(packets_to_read)
            completion_handler(packets_to_read, protocols)
        else:
            self.read_handler = completion_handler

class BasePacketTunnelProvider:
    """
    Base class mirroring Apple's NEPacketTunnelProvider.
    """
    def __init__(self):
        self.packet_flow = MockPacketTunnelFlow()
        self.network_settings: Optional[NEPacketTunnelNetworkSettings] = None
        self.status = NEVPNStatus.DISCONNECTED
        self.reasserting = False

    def set_tunnel_network_settings(self, settings: Optional[NEPacketTunnelNetworkSettings], completion_handler: Callable[[Optional[Exception]], None]):
        self.network_settings = settings
        if settings:
            self.packet_flow.mtu = settings.mtu
        completion_handler(None)

    def start_tunnel(self, options: Optional[Dict[str, any]], completion_handler: Callable[[Optional[Exception]], None]):
        raise NotImplementedError

    def stop_tunnel(self, reason: int, completion_handler: Callable[[], None]):
        raise NotImplementedError

    def cancel_tunnel_connection(self, error: Optional[Exception]):
        self.status = NEVPNStatus.DISCONNECTED
