import os
import base64
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.backends import default_backend

def encrypt_payload(data: str, secret_key: str) -> tuple[str, str]:
    """
    Encrypts data string using AES-CBC-PKCS7.
    Returns (ciphertext_base64, iv_base64)
    """
    # Key must be 32 bytes for AES-256
    key = secret_key[:32].encode("utf-8")
    if len(key) < 32:
        key = key.ljust(32, b"\0")
        
    iv = os.urandom(16)
    
    padder = padding.PKCS7(128).padder()
    padded_data = padder.update(data.encode("utf-8")) + padder.finalize()
    
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    encryptor = cipher.encryptor()
    ciphertext = encryptor.update(padded_data) + encryptor.finalize()
    
    return base64.b64encode(ciphertext).decode("utf-8"), base64.b64encode(iv).decode("utf-8")

def decrypt_payload(ciphertext_b64: str, iv_b64: str, secret_key: str) -> str:
    """
    Decrypts base64 encoded ciphertext string using AES-CBC-PKCS7 and the base64 iv.
    """
    key = secret_key[:32].encode("utf-8")
    if len(key) < 32:
        key = key.ljust(32, b"\0")
        
    iv = base64.b64decode(iv_b64)
    ciphertext = base64.b64decode(ciphertext_b64)
    
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    decryptor = cipher.decryptor()
    padded_data = decryptor.update(ciphertext) + decryptor.finalize()
    
    unpadder = padding.PKCS7(128).unpadder()
    data = unpadder.update(padded_data) + unpadder.finalize()
    return data.decode("utf-8")
