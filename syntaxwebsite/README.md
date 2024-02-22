# Syntax Backend
**Last Updated: 20/2/2024**

## What you need
### Requirements 
 - Linux Server ( For Production environment )
 - PostgreSQL Server
 - Redis Server
 - NGINX
 - Cloudflare Account
 - Domain with Cloudflare protection
 - Python 3.12+
 - FFmpeg
 - Gunicorn 

> Note: These are the bare minimum needed for Syntax Backend to run, please do not attempt to host a publicly accessible version of Syntax if you do not know what you are doing

### Optional Services
 - Syntax Gameserver running on Windows Server ( Needed for rendering and games )
 - Syntax Discord Bot
 - Ko-Fi ( Please modify code if you are not going to use this )
 - Cryptomus
 - MailJet ( Email Vericiation, modification to the code is needed as email templates are not included )
 - HTTP Proxies for faster asset migration ( [webshare.io](https://webshare.io/) is recommended )
 - Amazon S3 Bucket ( **USE_LOCAL_STORAGE** must be enabled if you are not planning to use a S3 Bucket )

## Configuration
Copy `config.example.py` and name it as `config.py` then place it in the same directory as this readme file

1. **FLASK_SESSION_KEY** - Used for salting passwords and 2FA Secret Generation, please change to a random long string and never change it ever again!
~~2. **AuthorizationKey** - Added for debugging and bypassing ratelimits, please also change to a random long string~~ Removed from codebase
3. **SQLALCHEMY_DATABASE_URI** - URI for connecting to the postgres database, refer to [Documentation](https://flask-sqlalchemy.palletsprojects.com/en/2.x/config/) for creating a database URI
4. **FLASK_LIMITED_STORAGE_URI** - Redis Server URI, can leave as default if your redis server is hosted locally and does not require authorization
5. **BaseDomain** - Change to your domain *(eg. roblox.com)*, please do not host on a subdomain as it is not supported!
6. **CloudflareTurnstileSiteKey** - Please setup turnstile on the domain you are hosting and then grab the turnstile site key from there
7. **CloudflareTurnstileSecretKey** - Read above
8. **DISCORD_CLIENT_ID** - Go to the Discord Developer Portal and go to the Discord Application you are going to use, then place its ClientID here
9. **DiscordBotToken** - Use your Discord Bot Token
10. **DISCORD_CLIENT_SECRET** - Discord Application Client Secret
11. **DISCORD_BOT_AUTHTOKEN** - Authorization Token for Syntax Discord Bot, use random long string
12. **DISCORD_BOT_AUTHORISED_IPS** - List of IPs which are allowed to access Discord Bot internal APIs
13. **DISCORD_ADMIN_LOGS_WEBHOOK** - Discord Webhook for logging Moderation Actions
14. **MAILJET** - You will have to modify the code and the config for this as your email template will be different
15. **KOFI_VERIFICATION_TOKEN** - Used for verifying requests from Ko-Fi to automate donations processing, please change to a random long string if you do not plan on using this. If you do you can find the verification token in your Ko-Fi API Panel.
16. **VERIFIED_EMAIL_REWARD_ASSET** - The AssetId the user is rewarded with once they verify their email, you can change this after setting up everything
17. **ASSETMIGRATOR_ROBLOSECURITY** - Used for private audio migration
18. **ASSETMIGRATOR_USE_PROXIES** - If you want to use proxies for Asset Migration ( Which you should as it speeds up everything )
19. **ASSETMIGRATOR_PROXY_LIST_LOCATION** - The path to the file which contains the proxies
20. **RSA_PRIVATE_KEY_PATH** - The path to the private key, expects a 1024 Bit RSA private key used for signing JoinScripts and everyting else **This is required!!**
21. **RSA_PRIVATE_KEY_PATH2** - Same thing for above but expects a 2048 Bit RSA private key
22. **USE_LOCAL_STORAGE** - Uses local storage for storing and reading files, bypasses S3 and uses **AWS_S3_DOWNLOAD_CACHE_DIR** as its storage directory  ( SHOULD ONLY BE USED IN A DEVELOPMENT ENVIRONMENT )
23. **AWS_ACCESS_KEY** - Your AWS Access Key, please create one in your AWS IAM Manager
24. **AWS_SECRET_KEY** - The Secret Key for the access key
25. **AWS_S3_BUCKET_NAME** - The bucket name assets and images will be uploaded to
26. **AWS_S3_DOWNLOAD_CACHE_DIR** - Where files downloaded from S3 will be cached
27. **AWS_REGION_NAME** - The region of the bucket
28. **CDN_URL** - Change to where the CDN is
29. **DISCOURSE_SSO_ENABLED** - Allows authentication with Syntax for [Discourse](https://www.discourse.org/) Forums
30. **DISCOURSE_FORUM_BASEURL** - The location of the forum
31. **DISCOURSE_SECRET_KEY** - The secret key for signing
32. **ADMIN_GROUP_ID** - The GroupId where admins are in, used for showing the admin badges ingame
33. **ITEMRELEASER_DISCORD_WEBHOOK** - The Discord Webhook to use for announcing an item release
34. **ITEMRELEASER_ITEM_PING_ROLE_ID** - The Discord Role ID to ping for announcing an item release
35. **PROMETHEUS_ENABLED** - If the Prometheus endpoint is enabled
36. **PROMETHEUS_ALLOWED_IPS** - IPs which are allowed to query the Prometheus endpoint
37. **CHEATER_REPORTS_DISCORD_WEBHOOK** - The Discord webhook to use for cheater reports from RCCService
38. **ROLIMONS_API_ENABLED** - Used for Synmons
39. **ROLIMONS_API_KEY** - Used for Synmons
40. **GAMESERVER_COMM_PRIVATE_KEY_LOCATION** - The Private key location used for signing requests sent to gameservers
41. **CRYPTOMUS_PAYMENT_ENABLED** - If the cryptomus payment system is enabled
42. **CRYPTOMUS_MERCHANT_ID** - Your Cryptomus merchant ID
43. **CRYPTOMUS_API_KEY** - Your Cryptoumus API Key
44. **IPAPI_AUTH_KEY** - API Key for [IPAPI](https://ipapi.co/) used for VPN and proxy detection on signup

## KeyPair Generation
The SYNTAX Backend requires some keys for it to sign and communicate with gameservers, run the script below to generate those keys.
```
python tools/generate_new_keys.py
```

In the `tools` directory 6 new files should have been created, 2 key pairs are for joinscript signing which is needed by the Client and RCCService to authenticate and verify properly.
Another keypair is for signing requests to communicate with all gameservers, take the public key and place it in your gameserver directory.

## First Time Setup

First install all required dependencies by running `pip install -r requirements.txt` in this directory

Next run the command `flask shell` in the same directory as this README.md file, then in the shell run `db.create_all()`.
This will automatically create all the tables needed in your PostgreSQL database.

Next use type in the following command in your flask shell
```
from app.shell_commands import create_admin_user
create_admin_user()
```
This will create an admin user with all existing admin privileges

Now we can finally start the website, please make sure you have [gunicorn](https://gunicorn.org/) installed on your Linux Machine, gunicorn does not support Windows Machines. To start run the shell script `./start.sh` which will start a webserver on port `3003`. Please make sure you have NGINX configured as a reverse proxy to proxy the website and also have configured Cloudflare to serve your website on the main and all subdomains.

If you are running a Windows Machine and want to run in debug mode run `flask run --port 3006 --debug`, this will open the website on port 3006
