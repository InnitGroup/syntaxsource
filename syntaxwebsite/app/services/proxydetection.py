import requests
import logging
import json
from app.extensions import redis_controller
from app import Config

config = Config()

class IPHubQueryFailed(Exception):
    pass
class IPHubRateLimited(Exception):
    pass

def lookup_address_info( address : str, skip_cache : bool = False, lookup_timeout : int = 10 ) -> dict:
    if not skip_cache:
        try:
            CachedResponse : str = redis_controller.get(f"iphub_lookup_{address}")
            if CachedResponse is not None:
                return json.loads(CachedResponse)
        except Exception as e:
            logging.error(f"lookup_address_info : IPHub cache lookup failed: {e}")
            redis_controller.delete(f"iphub_lookup_{address}")
    try:
        LookupResponse : requests.Response = requests.get(
            f"https://api.ipapi.is/?q={address}&key={config.IPAPI_AUTH_KEY}", # We NEED to put this in env (and not hardcode it)
            headers = { },
            timeout = lookup_timeout
        )
        if LookupResponse.status_code == 403 or LookupResponse.status_code == 429:
            logging.error("lookup_address_info : IPHub rate limited")
            raise IPHubRateLimited("IPHub rate limited")
        elif LookupResponse.status_code != 200:
            logging.error(f"lookup_address_info : IPHub query failed: {LookupResponse.status_code} {LookupResponse.text}")
            raise IPHubQueryFailed(f"IPHub query failed: {LookupResponse.status_code} {LookupResponse.text}")
        
        LookupResponseJSON : dict = LookupResponse.json()
        redis_controller.setex(
            name = f"iphub_lookup_{address}",
            time = config.IPAPI_CACHE_LIFETIME,
            value = json.dumps(LookupResponseJSON)
        )
        return LookupResponseJSON
    except requests.exceptions.Timeout:
        logging.error(f"lookup_address_info : IPHub query timed out after {lookup_timeout} seconds")
        raise IPHubQueryFailed("IPHub query timed out")
    except Exception as e:
        logging.error(f"lookup_address_info : IPHub query failed: {e}")
        raise IPHubQueryFailed(f"IPHub query failed: {e}")
    
def fetch_address_risk( address : str, skip_cache : bool = False, lookup_timeout : int = 10, fallback_on_exception : bool = True ) -> int:
    """
        :param address: The IP address to check
        :param skip_cache: Whether to skip the cache and query IPHub directly
        :param lookup_timeout: The timeout for the query
        :param fallback_on_exception: Whether to return 0 if the query fails

        :return: The risk level of the IP address (0, 1, or 2)
        
        https://iphub.info/api

        0 - Residential or business IP (i.e. safe IP)
        1 - Non-residential IP (hosting provider, proxy, etc.)
        2 - Non-residential & residential IP (warning, may flag innocent people)
    """

    try:
        LookupResponseJSON: dict = lookup_address_info(address, skip_cache, lookup_timeout)
        if LookupResponseJSON.get("is_crawler", True) \
                or LookupResponseJSON.get("is_datacenter", False) \
                or LookupResponseJSON.get("is_tor", False) \
                or LookupResponseJSON.get("is_proxy", False) \
                or LookupResponseJSON.get("is_vpn", False) \
                or LookupResponseJSON.get("is_abuser", False):
            return 1 
        else:
            return 
    except Exception as e:
        if fallback_on_exception:
            logging.error(f"fetch_address_risk : Exception raised falling back: {e}")
            return 3 # Why would we let them pass????????????
        else:
            raise e