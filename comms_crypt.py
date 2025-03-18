import socket
import nacl.public
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import os
from swoosh_ports import *


class CommsCrypt:
  
  def __init__(self):
    # Generate server's key pair
    self.info_private_key = nacl.public.PrivateKey.generate()
    self.info_public_key = self.info_private_key.public_key
    
    self.shared_udp_keys = {}  # AES-256 keys
    self.shared_tcp_keys = {}  
    
    
  def exchange_keys(self, sock: socket.socket, peer_addr: tuple[str, int], public_key: bytes | None):
    """
    exchanges keys with selected peer
    """
    if peer_addr not in self.shared_udp_keys:
    
      if public_key is not None:
        peer_public_key = nacl.public.PublicKey(public_key)
        
        # Perform ECDH key exchange
        shared_key = nacl.public.Box(self.info_private_key, peer_public_key).shared_key()
        
        # Derive AES-GCM key from shared secret
        self.shared_udp_keys[peer_addr] = shared_key[:32]  # First 32 bytes for AES-256
        print(f"Shared key established with {peer_addr}")

      print(f"public key sent to {peer_addr}")
      sock.sendto(self.info_public_key.encode(), peer_addr)


  def encrypt_udp(self, plaintext, peer_addr: tuple[str, int]) -> bytes:
    if peer_addr not in self.shared_udp_keys:
      raise ValueError(f"no shared AES key with {peer_addr}")
    
    aesgcm = AESGCM(self.shared_udp_keys[peer_addr])
    nonce = os.urandom(12)
    
    # convert plaintext into bytes if not encoded yet
    if type(plaintext) is not bytes:
      plaintext = str(plaintext).encode()
    
    ciphertext = aesgcm.encrypt(nonce, plaintext, None)
    return nonce + ciphertext
      

  def decrypt_udp(self, encrypted_msg: bytes, peer_addr: tuple[str, int]) -> bytes:
    if peer_addr not in self.shared_udp_keys:
      raise ValueError(f"no shared AES key with client: {peer_addr}")
    
    aesgcm  = AESGCM(self.shared_udp_keys[peer_addr])
    nonce = encrypted_msg[:12]
    ciphertext = encrypted_msg[12:]
    return aesgcm.decrypt(nonce, ciphertext, None)