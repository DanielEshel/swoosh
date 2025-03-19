from socket import socket, AF_INET, SOCK_DGRAM
import psutil
from scapy.all import sniff, ARP, IP, UDP, Ether, sendp
import queue
from comms_crypt import *
import time
import threading


class Comms:
  def __init__(self, name: str):
    self.name = name
    self.recv_q = queue.Queue()
    self.send_q = queue.Queue()
    
    self.interfaces = psutil.net_if_addrs()
    self.available_peers = {}  # all available peers
    self.live_peers = {}  # peers using communiations
    
    # self.interface_name = 'Wi-Fi'
    print(self.interfaces.keys())
    self.interface_name = 'Wi-Fi'
    self.ip_address = None
    self.discovery_sock = None
    self.info_sock = None
    
    self._get_ip_address()
    self._create_discovery_socket()
    self._create_info_socket()
    
    self.crypt = CommsCrypt()
    
    self.answering = threading.Thread(target=self._answer_publish, args=(), daemon=True)
    self.answering.start()
    
    self.publish = threading.Thread(target=self._publish, args=(), daemon=True)
    self.publish.start()
    
    self.discover = threading.Thread(target=self._discover, args=(), daemon=True)
    self.discover.start()
  
  def _create_info_socket(self):
    if self.ip_address is not None:
      # set and bind udp socket (info socket)
      self.info_sock = socket.socket(AF_INET, SOCK_DGRAM)    
      self.info_sock.bind((self.ip_address, SWOOSHPORT_DATA))
    else:
      print('socket not created!')
  
  
  def _create_discovery_socket(self):
    if self.ip_address is not None:
      self.discovery_sock = socket.socket(AF_INET, SOCK_DGRAM)    
      self.discovery_sock.bind((self.ip_address, SWOOSHPORT_DISCOVER))
    else:
      print('socket not created!')
        
        
  def _handle_messages(self):
    if self.ip_address is None:
      print('_handle_messages exited, no ip address')
      return
    
    while True:
        try:
          msg, addr = self.info_sock.recvfrom(1024)
        except:
          print("got trash or error @_handle_messages")
        finally:
          # exchange keys if don't have keys yet
          if addr not in self.crypt.shared_udp_keys:
            try:
              self.crypt.exchange_keys(self.info_sock, addr, msg)
            except Exception as e:
              print(e, f"key exchange error @_handle_messages")
          else:
            try:
              msg = self.crypt.decrypt_udp(msg, addr).decode()
            except Exception as e:
              print(e, "@_handle_messages")
            self.recv_q.put(addr, msg)

    
  def _get_ip_address(self):
    # Extract the first IPv4 address from the chosen interface
    for addr in self.interfaces.get(self.interface_name, []):
        if addr.family == socket.AF_INET:  # IPv4
            self.ip_address = addr.address
            print(f"@_get_ip_address got interface ip address: {self.ip_address}")
            return
    print(f"couldn't get ip address for interface {self.interface_name}")
    self.ip_address = None
    

  def _answer_publish(self):
    """
    listens for and answers peer's publishment arp packets
    """
    if self.ip_address is None:
      print('_answer_publish exited, no ip address')
      return
    
    def discovery_packet_filter(p):
      """
      filters out publishment arp packets
      """
      return ARP in p and p[ARP].pdst == '0.1.1.1' and p[ARP].psrc != self.ip_address and p[ARP].psrc not in self.available_peers
    
    def send_response(p):
      """
      sends out udp responses to the published arp requests
      """
      peer_ip = p[ARP].psrc
      print(f"sent response to {peer_ip}")
      response = self.name.ljust(16)[:16].encode()
      self.discovery_sock.sendto(response, (peer_ip, SWOOSHPORT_DISCOVER))
      
    sniff(lfilter=discovery_packet_filter, prn=send_response)
    
    
  def _publish(self):
    """
    sends a publishment packet every 3 seconds
    """
    if self.ip_address is None:
      print('_publish exited, no ip address')
      return
    
    # ehter dst='FF:FF:FF:FF:FF:FF' , type=0x86
    discover_packet = Ether() / ARP(op='who-has', pdst='0.1.1.1', psrc=self.ip_address)
    
    while True:
      print("discovering", discover_packet)
      sendp(discover_packet, iface=self.interface_name, verbose=False)
      time.sleep(3)
       
        
  def _discover(self):
    """
    discovers peers that have answered the publishment packets we sent
    """
    if self.ip_address is None:
      print('_discover exited, no ip address')
      return
    
    peer_name = None
    while True:
      data, peer_addr = self.discovery_sock.recvfrom(16)
      peer_name = data.decode()
      print(f'found peer!!! {peer_addr}')
      self.available_peers[peer_addr] = peer_name
      
    # def discovery_packet_filter(p):
    #   return IP in p and p[IP].dst == self.ip_address and UDP in p and p[UDP].dport == SWOOSHPORT_DISCOVER
    
    # def handle_packet(p):
    #   print(f"got response from {p[IP].src}")
    #   self.live_servers.append(p[IP].src)
      
    # sniff(lfilter=discovery_packet_filter, prn=handle_packet)
    
  async def connect(self, peer_addr: tuple[str, int]):
    """
    establish connection with host
    """
    # make sure peer has been discovered
    if peer_addr not in self.available_peers:
      self.crypt.exchange_keys(self.info_sock, peer_addr, None)
      
      await peer_addr in self.crypt.shared_udp_keys
      print(f"now officially peering with {peer_addr}")
      self.live_peers[peer_addr] = None
        
        
        
def main():
  
  comms = Comms('Daniel')
  
    
  input("press enter to exit")
  
  
if __name__ == "__main__":
  main()