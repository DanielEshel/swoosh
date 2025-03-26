import asyncio
import psutil
from scapy.all import sniff, ARP, Ether, sendp
from socket import AF_INET
from swoosh_ports import *
from comms_crypt import CommsCrypt
import threading


PUBLISH_DOWNTIME = 5


class Comms:

    discovery_ip = "0.1.1.1"
    interfaces = psutil.net_if_addrs()

    def __init__(self, name: str, interface_name: str):
        self.name = name
        self.interface_name = interface_name
        
        self.recv_q = asyncio.Queue()
        self.send_q = asyncio.Queue()

        self.ip_address = None
        self.arp_sniffing_thread = None

        self.available_peers_lock = threading.Lock()
        self.available_peers = {}
        
        self.connected_info_peers = []
        self.connected_info_servers = []
        
        self._connected_info_peers = {}  # writers to tcp peers connected to the server
        self._connected_info_servers = {}  # writers to tcp peers' servers connected to

        self._get_ip_address()

        self.crypt = CommsCrypt()
        self.info_sessions = {}  # dict for peer info sessions (one per IP)
        self.file_sessions = {}  # dict for peer file transfer 

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

        await self._start_info_server()

        # build and satrt arp_sniffing_thread
        self.arp_sniffing_thread = threading.Thread(
            target=self._sniff_arp, args=(), daemon=True
        )
        self.arp_sniffing_thread.start()

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

    async def _start_info_server(self):
        loop = asyncio.get_running_loop()
        self.info_socket = await asyncio.start_server(
            self._handle_tcp_info, host=self.ip_address, port=SWOOSHPORT_INFO
        )

        addr = self.info_server.sockets[0].getsockname()
        print(f"TCP info server started on {addr}")

    async def _handle_tcp_info(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ):
        """
        * handles each tcp peer info connection
        """
        self.connected_info_peers[peer_ip] = writer
        peer_ip = writer.get_extra_info("peername")[0]

        print(f"TCP connection from {peer_ip}")

        try:
            session_id = await self.crypt.exchange_keys_tcp(reader, writer, peer_ip)
        except Exception as e:
            print(f"@_handle_tcp_info Key exchange error with {peer_ip} : {e}")
        else:
            self._connected_info_peers[(peer_ip, session_id)] = writer
            while True:
                try:
                    msg = self.crypt.decrypt_tcp(await reader.read(1024), peer_ip, session_id)
                except Exception as e:
                    print(f"@_handle_tcp_info Error with {peer_ip}  : {e}")
                    
                self.recv_server_q.push(msg)
                
    async def send_info(self, msg, peer_ip):
        pass

    async def server_reply(self, msg, peer_ip):
        self.connected_info_peers
    
    class DiscoveryProtocol(asyncio.DatagramProtocol):
        def __init__(self, comms):
            self.comms = comms

        def datagram_received(self, data, addr):
            peer_name = data.decode().strip()
            peer_ip = addr[0]
            print(f"Received discovery response from {addr}: {peer_name}")

            with self.comms.available_peers_lock:
                # send discovery response if peer hasn't been discovered yet
                if peer_ip not in self.comms.available_peers:
                    self.comms._send_discovery_response(peer_ip)
                print(f"at DiscoveryProtocol {self.comms.available_peers}")
                self.comms.available_peers[peer_ip] = peer_name

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

            with self.available_peers_lock:
                known = peer_ip in self.available_peers  
            if not known:
                print(f"New ARP from {peer_ip}, sending response")
                response = self.name.ljust(16)[:16].encode()
                self.discovery_socket.sendto(
                    response, (peer_ip, SWOOSHPORT_DISCOVER)
                )

        print("Starting ARP sniffer...")
        sniff(filter="arp", lfilter=discovery_filter, prn=handle_arp, store=False)

    async def start_connection_info(self, peer_ip: str):
        """
        * exchange keys, and establish connection with peer over tcp
        """
        
        try:
            reader, writer = await asyncio.open_connection(peer_ip, SWOOSHPORT_INFO)
            session_id = await self.crypt.exchange_keys_tcp(reader, writer, peer_ip)
        except Exception as e:
            print(f"@start_connection_info Key exchange error with {peer_ip} : {e}")
            
        else:
            self._connected_info_servers[(peer_ip, session_id)] = writer
            
            while True:
                try:
                    msg = self.crypt.decrypt_tcp(await reader.read(1024), peer_ip, session_id)
                except Exception as e:
                    print(f"@start_connection_info Error with {peer_ip}  : {e}")
                    
                self.recv_info_q.push(msg)


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
    await asyncio.to_thread(input, "press Enter to exit...")  # Keep running for demo


if __name__ == "__main__":
    asyncio.run(main())
