import requests
from config import Config
import urllib
config = Config()

class DiscordUserInfo:
    UserId : int = None
    Username : str = None
    Discriminator : str = None
    AvatarHash : str = None
    GlobalName : str = None

    def __init__(self, UserId : int, Username : str, AvatarHash : str, GlobalName : str = None, Discriminator : str = "0000") -> None:
        self.UserId = UserId
        self.Username = Username
        self.Discriminator = Discriminator
        self.AvatarHash = AvatarHash
        self.GlobalName = GlobalName
    
    def GetAvatarURL(self) -> str:
        """
        GetAvatarURL returns the URL to the user's avatar.
        """
        if self.AvatarHash is None:
            return f"https://cdn.discordapp.com/embed/avatars/{str(int(self.Discriminator) % 5)}.png"
        return f"https://cdn.discordapp.com/avatars/{str(self.UserId)}/{self.AvatarHash}.png"
    
    def __repr__(self) -> str:
        return f"<DiscordUserInfo {self.UserId} {self.Username}#{self.Discriminator}>"

class UnexpectedStatusCode(Exception):
    pass
class MissingScope(Exception):
    pass
def ExchangeCodeForToken( AccessCode : str ) -> dict:
    """
    ExchangeCodeForToken exchanges a Discord OAuth2 access code for a Discord OAuth2 token.
    """
    DiscordOAuth2TokenExchangeURL = "https://discord.com/api/oauth2/token"
    DiscordOAuth2TokenExchangeHeaders = {
        "Content-Type": "application/x-www-form-urlencoded"
    }
    DiscordOAuth2TokenExchangeData = {
        "client_id": config.DISCORD_CLIENT_ID,
        "client_secret": config.DISCORD_CLIENT_SECRET,
        "grant_type": "authorization_code",
        "code": AccessCode,
        "redirect_uri": config.DISCORD_REDIRECT_URI,
        "scope": "identify"
    }
    DiscordOAuth2TokenExchangeResponse = requests.post(DiscordOAuth2TokenExchangeURL, headers=DiscordOAuth2TokenExchangeHeaders, data=DiscordOAuth2TokenExchangeData)
    DiscordOAuth2TokenExchangeResponseJSON = DiscordOAuth2TokenExchangeResponse.json()

    if DiscordOAuth2TokenExchangeResponse.status_code != 200:
        raise UnexpectedStatusCode(f"Unexpected status code {DiscordOAuth2TokenExchangeResponse.status_code} when exchanging code for token.")
    # Make sure "identify" is in the scope
    if "identify" not in DiscordOAuth2TokenExchangeResponseJSON["scope"]:
        raise MissingScope("Missing scope 'identify' when exchanging code for token.")
    if "guilds.join" not in DiscordOAuth2TokenExchangeResponseJSON["scope"]:
        raise MissingScope("Missing scope 'guilds.join' when refreshing token.")
    return DiscordOAuth2TokenExchangeResponseJSON

def GetUserInfoFromToken( AccessToken : str ) -> DiscordUserInfo:
    """
    GetUserInfoFromToken gets a user's Discord user info from their access token.
    """
    DiscordOAuth2GetUserInfoURL = "https://discord.com/api/users/@me"
    DiscordOAuth2GetUserInfoHeaders = {
        "Authorization": f"Bearer {AccessToken}"
    }
    DiscordOAuth2GetUserInfoResponse = requests.get(DiscordOAuth2GetUserInfoURL, headers=DiscordOAuth2GetUserInfoHeaders)
    DiscordOAuth2GetUserInfoResponseJSON = DiscordOAuth2GetUserInfoResponse.json()

    if DiscordOAuth2GetUserInfoResponse.status_code != 200:
        raise UnexpectedStatusCode(f"Unexpected status code {DiscordOAuth2GetUserInfoResponse.status_code} when getting user info from token.")
    return DiscordUserInfo(
        UserId = DiscordOAuth2GetUserInfoResponseJSON["id"],
        Username = DiscordOAuth2GetUserInfoResponseJSON["username"],
        Discriminator = DiscordOAuth2GetUserInfoResponseJSON["discriminator"],
        AvatarHash = DiscordOAuth2GetUserInfoResponseJSON["avatar"],
        GlobalName = DiscordOAuth2GetUserInfoResponseJSON["global_name"]
    )

def GenerateAuthorizationURL( State : str ) -> str:
    """
    GenerateAuthorizationURL generates a Discord OAuth2 authorization URL.
    """
    DiscordOAuth2AuthorizationURL = config.DISCORD_AUTHORIZATION_BASE_URL
    DiscordOAuth2AuthorizationURLParams = {
        "client_id": config.DISCORD_CLIENT_ID,
        "redirect_uri": config.DISCORD_REDIRECT_URI,
        "response_type": "code",
        "scope": "identify guilds.join",
        "state": State
    }
    # Format the URL
    DiscordOAuth2AuthorizationURL = f"{DiscordOAuth2AuthorizationURL}?{urllib.parse.urlencode(DiscordOAuth2AuthorizationURLParams)}"
    return DiscordOAuth2AuthorizationURL

def RefreshAccessToken( RefreshToken : str ) -> dict:
    """
    RefreshAccessToken refreshes a Discord OAuth2 access token from a refresh token.
    """
    DiscordOAuth2TokenRefreshData = {
        "client_id": config.DISCORD_CLIENT_ID,
        "client_secret": config.DISCORD_CLIENT_SECRET,
        "grant_type": "refresh_token",
        "refresh_token": RefreshToken
    }
    DiscordOAuth2TokenRefreshURL = "https://discord.com/api/oauth2/token"
    DiscordOAuth2TokenRefreshHeaders = {
        "Content-Type": "application/x-www-form-urlencoded"
    }
    DiscordOAuth2TokenRefreshResponse = requests.post(DiscordOAuth2TokenRefreshURL, headers=DiscordOAuth2TokenRefreshHeaders, data=DiscordOAuth2TokenRefreshData)
    DiscordOAuth2TokenRefreshResponseJSON = DiscordOAuth2TokenRefreshResponse.json()
    if DiscordOAuth2TokenRefreshResponse.status_code != 200:
        raise UnexpectedStatusCode(f"Unexpected status code {DiscordOAuth2TokenRefreshResponse.status_code} when refreshing token.")
    if "identify" not in DiscordOAuth2TokenRefreshResponseJSON["scope"]:
        raise MissingScope("Missing scope 'identify' when refreshing token.")
    if "guilds.join" not in DiscordOAuth2TokenRefreshResponseJSON["scope"]:
        raise MissingScope("Missing scope 'guilds.join' when refreshing token.")
    return DiscordOAuth2TokenRefreshResponseJSON