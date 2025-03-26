import socket
import os
import asyncio
import nacl.public
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import uuid
from swoosh_ports import *


class CommsCrypt:

    def __init__(self):
        self.shared_tcp_keys = {}  # AES 256 keys

    async def exchange_keys_tcp(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter, peer_ip: str
    ) -> str:
        """
        Performs an ephemeral ECDH key exchange over a TCP stream.
        Returns a session_id tied to the derived AES key.
        """
        # Generate a new ephemeral keypair for this session
        ephemeral_private = nacl.public.PrivateKey.generate()
        ephemeral_public = ephemeral_private.public_key

        # Send our ephemeral public key
        writer.write(ephemeral_public.encode())
        await writer.drain()

        # Receive their ephemeral public key
        peer_pub_bytes = await reader.read(32)
        peer_public_key = nacl.public.PublicKey(peer_pub_bytes)

        # Derive shared key using ECDH
        shared_key = nacl.public.Box(ephemeral_private, peer_public_key).shared_key()
        aes_key = shared_key[:32]  # AES-256

        # Generate a unique session ID
        session_id = str(uuid.uuid4())
        self.shared_tcp_keys[(peer_ip, session_id)] = aes_key

        print(
            f"🔐 Ephemeral key exchange complete with {peer_ip}, session {session_id}"
        )
        return session_id

    async def encrypt_tcp(self, plaintext, peer_ip, session_id):
        if (peer_ip, session_id) not in self.shared_tcp_keys:
            raise ValueError(f"no shared tcp key for {peer_ip, session_id}")

        aesgcm = AESGCM(self.shared_tcp_keys[(peer_ip, session_id)])
        nonce = os.urandom(12)

        # convert plaintext into bytes if not encoded yet
        if type(plaintext) is not bytes:
            plaintext = str(plaintext).encode()

        ciphertext = aesgcm.encrypt(nonce, plaintext, None)
        return nonce + ciphertext

    async def decrypt_tcp(self, encrypted_msg, peer_ip, session_id):
        if (peer_ip, session_id) not in self.shared_tcp_keys:
            raise ValueError(f"no shared tcp key with client: {peer_ip, session_id}")

        aesgcm = AESGCM(self.shared_udp_keys[peer_ip])
        nonce = encrypted_msg[:12]
        ciphertext = encrypted_msg[12:]
        return aesgcm.decrypt(nonce, ciphertext, None)  # return plaintext

    # def encrypt_udp(self, plaintext, peer_addr: tuple[str, int]) -> bytes:
    #   if peer_addr not in self.shared_udp_keys:
    #     raise ValueError(f"no shared AES key with {peer_addr}")

    #   aesgcm = AESGCM(self.shared_udp_keys[peer_addr])
    #   nonce = os.urandom(12)

    #   # convert plaintext into bytes if not encoded yet
    #   if type(plaintext) is not bytes:
    #     plaintext = str(plaintext).encode()

    #   ciphertext = aesgcm.encrypt(nonce, plaintext, None)
    #   return nonce + ciphertext

    # def decrypt_udp(self, encrypted_msg: bytes, peer_addr: tuple[str, int]) -> bytes:
    #   if peer_addr not in self.shared_udp_keys:
    #     raise ValueError(f"no shared AES key with client: {peer_addr}")

    #   aesgcm  = AESGCM(self.shared_udp_keys[peer_addr])
    #   nonce = encrypted_msg[:12]
    #   ciphertext = encrypted_msg[12:]
    #   return aesgcm.decrypt(nonce, ciphertext, None)

    # def exchange_keys(self, sock: socket.socket, peer_addr: tuple[str, int], public_key: bytes | None):
    #   """
    #   exchanges keys with selected peer
    #   depretiated for project. not using socket.socket anymore. moved to asyncio
    #   """
    #   if peer_addr not in self.shared_udp_keys:

    #     if public_key is not None:
    #       peer_public_key = nacl.public.PublicKey(public_key)

    #       # Perform ECDH key exchange
    #       shared_key = nacl.public.Box(self.info_private_key, peer_public_key).shared_key()

    #       # Derive AES-GCM key from shared secret
    #       self.shared_udp_keys[peer_addr] = shared_key[:32]  # First 32 bytes for AES-256
    #       print(f"Shared key established with {peer_addr}")

    #     print(f"public key sent to {peer_addr}")
    #     sock.sendto(self.info_public_key.encode(), peer_addr)
