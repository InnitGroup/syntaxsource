"""
    Generates 3 types of keypairs required by SYNTAX backend
    
    - 1024 bit RSA key for clients that used rbxsig
    - 2048 bit RSA key for clients that used rbxsig2 and newer
    - 2048 bit RSA key for gameserver communication and authentication

    These keys will be saved in the same directory as this script
"""

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend

def generate_key( key_size : int, priv_key_name : str, pub_key_name : str ) -> None:
    """
        Generates a private key and saves it to a file

        :param key_size: The size of the key to generate
        :param key_name: The name of the file to save the key to
    """
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=key_size,
        backend=default_backend()
    )

    with open( priv_key_name, "wb" ) as f:
        f.write(
            private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
            )
        )

    with open( pub_key_name, "wb" ) as f:
        f.write(
            private_key.public_key().public_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PublicFormat.SubjectPublicKeyInfo
            )
        )

generate_key( 1024, "rsa_private_1024.pem", "rsa_public_1024.pub" )
generate_key( 2048, "rsa_private_2048.pem", "rsa_public_2048.pub")
generate_key( 2048, "rsa_private_gameserver.pem", "rsa_public_gameserver.pub")