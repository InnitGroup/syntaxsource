import requests
import time
import base64
import json

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

from app.models.gameservers import GameServer

from config import Config

config = Config()

def sign_content( content : bytes ) -> str:
    """
        Signs the given content using the gameserver private key

        :param content: The content to sign

        :returns: str
    """
    assert isinstance( content, bytes ), "content must be a bytes object"

    with open( config.GAMESERVER_COMM_PRIVATE_KEY_LOCATION, "rb" ) as f:
        private_key = serialization.load_pem_private_key(
            f.read(),
            password=None,
            backend=default_backend()
        )

    signature = private_key.sign(
        content,
        padding.PKCS1v15(),
        hashes.SHA256()
    )

    return base64.b64encode( signature ).decode( "utf-8" )

def perform_get(
    TargetGameserver : GameServer,
    Endpoint : str,
    AdditionalHeaders : dict = {},

    RequestTimeout : int = 10
) -> requests.Response:
    """
        Performs a GET request to the given gameserver

        :param TargetGameserver: The gameserver to send the request to
        :param Endpoint: The endpoint to send the request to
        :param AdditionalHeaders: Additional headers to send with the request
        :param RequestTimeout: The amount of time before the request times out

        :returns: requests.Response
    """
    assert isinstance( TargetGameserver, GameServer ), "TargetGameserver must be an instance of GameServer"
    assert isinstance( Endpoint, str ), "Endpoint must be a string"
    assert isinstance( AdditionalHeaders, dict ), "AdditionalHeaders must be a dictionary"

    RequestTimestamp = time.time()
    signed_content = sign_content( f'{RequestTimestamp}\nGET'.encode( 'utf-8' ) )
    ReqSignature = f"{str(RequestTimestamp)}|{ signed_content }"
    
    headers = {
        "User-Agent": "SYNTAX-Gameserver-Communication/1.0",
        "X-Syntax-Request-Signature": ReqSignature
    }

    return requests.get(
        url = f"http://{TargetGameserver.serverIP}:{TargetGameserver.serverPort}/{Endpoint}",
        headers = headers,
        timeout = RequestTimeout
    )

def perform_post(
    TargetGameserver : GameServer,
    Endpoint : str,
    JSONData : dict | list = {},
    AdditionalHeaders : dict = {},

    RequestTimeout : int = 10
) -> requests.Response:
    """
        Performs a POST request to the given gameserver

        :param TargetGameserver: The gameserver to send the request to
        :param Endpoint: The endpoint to send the request to
        :param JSONData: The JSON data to send with the request
        :param AdditionalHeaders: Additional headers to send with the request
        :param RequestTimeout: The amount of time before the request times out

        :returns: requests.Response
    """
    assert isinstance( TargetGameserver, GameServer ), "TargetGameserver must be an instance of GameServer"
    assert isinstance( Endpoint, str ), "Endpoint must be a string"
    assert isinstance( JSONData, ( dict, list ) ), "JSONData must be a dictionary or list"
    assert isinstance( AdditionalHeaders, dict ), "AdditionalHeaders must be a dictionary"

    RequestTimestamp = time.time()
    signed_content = sign_content( f"{RequestTimestamp}\nPOST\n{json.dumps(JSONData)}".encode( "utf-8" ))
    ReqSignature = f"{str(RequestTimestamp)}|{signed_content}"
    
    headers = {
        "User-Agent": "SYNTAX-Gameserver-Communication/1.0",
        "X-Syntax-Request-Signature": ReqSignature,
        "Content-Type": "application/json"
    }
    headers.update( AdditionalHeaders )

    return requests.post(
        url = f"http://{TargetGameserver.serverIP}:{TargetGameserver.serverPort}/{Endpoint}",
        headers = headers,
        data = json.dumps( JSONData ),
        timeout = RequestTimeout
    )