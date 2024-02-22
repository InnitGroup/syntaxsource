import requests
from config import Config

config = Config()

def VerifyToken( token : str ) -> bool:
    """
        Verifies the provided token with Cloudflare's Turnstile API.

        :param token: The token to verify
        :returns: bool (Whether the token is valid or not)
    """
    verification_response : requests.Response = requests.post(
        "https://challenges.cloudflare.com/turnstile/v0/siteverify",
        data = {
            "response": token, 
            "secret": config.CloudflareTurnstileSecretKey
        }
    )
    if verification_response.status_code != 200:
        return False
    JSONResponse : dict = verification_response.json()
    if JSONResponse["success"] != True:
        return False
    return True