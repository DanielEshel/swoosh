import asyncio
import psutil
from scapy.all import sniff, ARP, Ether, sendp
from socket import AF_INET
from swoosh_ports import *
from comms_crypt import CommsCrypt


class Comms:

    discovery_ip = "0.1.1.1"
    interfaces = psutil.net_if_addrs()

    def __init__(self, name: str, interface_name: str):
        self.name = name
        self.interface_name = interface_name
        
        self.recv_q = asyncio.Queue()
        self.send_q = asyncio.Queue()

        self.ip_address = None

        self.available_peers = {}
        self.live_peers = {}

        self._get_ip_address()

        self.crypt = CommsCrypt()

        # asyncio UDP socket
        self.discovery_socket = None
        
        # asyncio UDP socket
        self.info_socket = None

    def _get_ip_address(self):
        for addr in self.interfaces.get(self.interface_name, []):
            if addr.family == AF_INET:
                self.ip_address = addr.address
                print(f"IP Address: {self.ip_address}")
                return
        print(f"Couldn't get IP address for interface {self.interface_name}")
        self.ip_address = None

    async def start(self):
        if self.ip_address is None:
            print("No IP address, cannot start comms.")
            return

        # Start UDP discovery socket listener
        await self._start_discovery_socket()

        # Start ARP responder in background thread
        asyncio.create_task(asyncio.to_thread(self._sniff_arp))

        # Start periodic ARP discovery
        asyncio.create_task(self._publish_discovery())

        # Start discovery response handler
        asyncio.create_task(self._handle_discovery_responses())
        

    async def _start_discovery_socket(self):
        loop = asyncio.get_running_loop()
        self.discovery_socket, _ = await loop.create_datagram_endpoint(
            lambda: self.DiscoveryProtocol(self),
            local_addr=(self.ip_address, SWOOSHPORT_DISCOVER),
        )
        print(f"Discovery socket listening on {self.ip_address}:{SWOOSHPORT_DISCOVER}")

    class DiscoveryProtocol(asyncio.DatagramProtocol):
        def __init__(self, comms):
            self.comms = comms

        def datagram_received(self, data, addr):
            peer_name = data.decode().strip()
            print(f"Received discovery response from {addr}: {peer_name}")
            self.comms.available_peers[addr] = peer_name

    async def _publish_discovery(self):
        if self.ip_address is None:
            print("Cannot publish discovery, no IP address.")
            return

        discover_packet = Ether() / ARP(
            op="who-has", pdst=Comms.discovery_ip, psrc=self.ip_address
        )

        while True:
            sendp(discover_packet, iface=self.interface_name, verbose=False)
            print("Sent ARP discovery packet")
            await asyncio.sleep(3)

    def _sniff_arp(self):
        """
        sniffing for arp messages
        """

        def discovery_filter(p):
            return (
                ARP in p
                and p[ARP].pdst == Comms.discovery_ip
                and p[ARP].psrc != self.ip_address
            )

        def handle_arp(p):
            peer_ip = p[ARP].psrc
            if peer_ip not in self.available_peers:
                print(f"Received ARP from {peer_ip}, sending response")
                response = self.name.ljust(16)[:16].encode()
                self.discovery_socket.sendto(
                    response, (peer_ip, SWOOSHPORT_DISCOVER)
                )

        print("Starting ARP sniffer...")
        sniff(filter="arp", lfilter=discovery_filter, prn=handle_arp, store=False)

    async def _handle_discovery_responses(self):
        # Additional logic to process discovered peers if needed
        while True:
            await asyncio.sleep(1)
            # You can add peer timeout handling, logs, etc.


# ---------- Main ----------


async def main():
    print(f"{'_'*10}SELECT INTERFACE{'_'*10}")
    
    available_interfaces = {i: v for i, v in enumerate(Comms.interfaces, start=1)}
    
    for num, interface in available_interfaces.items():
        print(f"{num} - {interface}")
        
    interface_num = int(input("interface: "))
    interface_name = available_interfaces[interface_num]
    
    comms = Comms("Daniel", interface_name)
    await comms.start()
    await asyncio.sleep(60)  # Keep running for demo


if __name__ == "__main__":
    asyncio.run(main())
