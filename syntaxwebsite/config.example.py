from apscheduler.jobstores.redis import RedisJobStore
import pytz
import redis

class Config:
    FLASK_SESSION_KEY : str = "InsertRandomLongStringHere"
    AuthorizationKey : str = "ExampleKey"
    SQLALCHEMY_DATABASE_URI : str = "postgresql://ExampleUser:VerySecurePassword@localhost:5432/ProdDB"
    
    SCHEDULER_JOBSTORES = {
        'default': RedisJobStore(host='localhost', port=6379, db=0)
    }
    SCHEDULER_TIMEZONE : pytz.timezone = pytz.utc

    REDIS_CLIENT = redis.Redis(host="127.0.0.1", port=6379, db=0, decode_responses=True)

    FLASK_LIMITED_STORAGE_URI : str = "redis://localhost:6379/0"
    BaseDomain : str = "example.com"
    BaseURL : str = f"https://www.{BaseDomain}"

    CloudflareTurnstileSiteKey : str = ""
    CloudflareTurnstileSecretKey : str = ""

    DISCORD_CLIENT_ID : str = 1234567890
    DiscordBotToken : str = ""
    DISCORD_CLIENT_SECRET : str = ""
    DISCORD_REDIRECT_URI : str = f"https://www.{BaseDomain}/settings/discord_handler"
    DISCORD_AUTHORIZATION_BASE_URL : str = "https://discord.com/api/oauth2/authorize"

    DISCORD_BOT_AUTHTOKEN : str = ""
    DISCORD_BOT_AUTHORISED_IPS : list[str] = ["127.0.0.1"]

    DISCORD_ADMIN_LOGS_WEBHOOK : str = "https://discord.com/api/webhooks/1234567890/Example"

    MAILJET_APIKEY : str = ""
    MAILJET_SECRETKEY : str = ""
    MAILJET_NOREPLY_SENDER : str = "no-reply@example.com"
    MAILJET_DONATION_TEMPLATE_ID : int = 1234567
    MAILJET_EMAILVERIFY_TEMPLATE_ID : int = 7654321
    MAILJET_PASSWORDRESET_TEMPLATE_ID : int = 890765

    KOFI_VERIFICATION_TOKEN : str = ""
    KOFI_ENABLED : bool = False

    VERIFIED_EMAIL_REWARD_ASSET : int = 1

    ASSETMIGRATOR_ROBLOSECURITY : str = ""
    ASSETMIGRATOR_USE_PROXIES : bool = False
    ASSETMIGRATOR_PROXY_LIST_LOCATION = "./example_file.txt"

    RSA_PRIVATE_KEY_PATH : str = "./app/files/rsa_private.pem"
    RSA_PRIVATE_KEY_PATH2 : str = "./app/files/rsa_private2.pem"

    USE_LOCAL_STORAGE : bool = True

    AWS_ACCESS_KEY : str = ""
    AWS_SECRET_KEY : str = ""
    AWS_S3_BUCKET_NAME : str = "cdn.example.com"
    AWS_S3_DOWNLOAD_CACHE_DIR : str = "./download_cache"
    AWS_REGION_NAME : str = "ap-southeast-1"

    CDN_URL : str = f"https://cdn.{BaseDomain}" if not USE_LOCAL_STORAGE else f"{BaseURL}/cdn_local"

    SWITCH_TO_ARGON_PASSWORD_HASH : bool = True

    DISCOURSE_SSO_ENABLED : bool = False
    DISCOURSE_FORUM_BASEURL : str = "https://forums.example.com"
    DISCOURSE_SECRET_KEY : str = ""

    ADMIN_GROUP_ID : int = 1

    ITEMRELEASER_DISCORD_WEBHOOK : str = "https://discord.com/api/webhooks/1234567890/Example"
    ITEMRELEASER_ITEM_PING_ROLE_ID : int = 1234567890

    WTF_CSRF_HEADERS : list[str] = ["x-csrf-token", "X-CSRFToken", "X-CSRF-Token"]

    PROMETHEUS_ENABLED : bool = False
    PROMETHEUS_ALLOWED_IPS : list[str] = ["127.0.0.1"]

    CHEATER_REPORTS_DISCORD_WEBHOOK : str = "https://discord.com/api/webhooks/1234567890/Example"

    ROLIMONS_API_ENABLED : bool = False
    ROLIMONS_API_KEY : str = "ExampleKey"

    GAMESERVER_COMM_PRIVATE_KEY_LOCATION : str = "./app/files/rsa_private_gameserver.pem"

    CRYPTOMUS_PAYMENT_ENABLED : bool = True
    CRYPTOMUS_MERCHANT_ID : str = ""
    CRYPTOMUS_API_KEY : str = ""

    IPAPI_AUTH_KEY : str = "ExampleKey"
    IPAPI_CACHE_LIFETIME : int = 60 * 60 * 24