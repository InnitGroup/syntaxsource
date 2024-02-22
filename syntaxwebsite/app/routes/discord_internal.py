"""
    All routes inside here is used to communicate internally with our Discord Bot.
"""

from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort
from app.extensions import csrf, redis_controller, get_remote_address
from sqlalchemy import func
from config import Config
from app.models.user import User
from app.models.asset import Asset
from app.models.linked_discord import LinkedDiscord
from app.models.asset_rap import AssetRap
from app.models.placeserver_players import PlaceServerPlayer
from app.enums.MembershipType import MembershipType
from app.services.economy import GetAssetRap
from app.util.membership import GetUserMembership, GiveUserMembership
import datetime
import time
import logging

DiscordInternal = Blueprint('discord_internal', __name__, url_prefix='/internal/discord_bot')

@DiscordInternal.before_request
def before_request():
    AuthorizationToken = request.headers.get("InternalAuthorizationKey", default=None, type=str)
    if AuthorizationToken != Config.DISCORD_BOT_AUTHTOKEN:
        logging.warning(f"Discord Bot Internal API: Unauthorized request from {get_remote_address()}, invalid auth token")
        return abort(404)
    UserAgent = request.headers.get("User-Agent", default=None, type=str)
    if UserAgent != "SyntaxBot/1.0":
        logging.warning(f"Discord Bot Internal API: Unauthorized request from {get_remote_address()}, invalid user agent")
        return abort(404)
    RequesterAddress = get_remote_address()
    if RequesterAddress not in Config.DISCORD_BOT_AUTHORISED_IPS:
        logging.warning(f"Discord Bot Internal API: Unauthorized request from {RequesterAddress}, not in authorised IP list")
        return abort(404)

def GetUserFromId( UserObj : User | int ) -> User | None:
    """
    Returns a User object from a User ID.
    """
    if isinstance(UserObj, User):
        return UserObj
    else:
        TargetUser : User | None = User.query.filter_by(id=UserObj).first()
        if TargetUser is None:
            raise Exception("User does not exist.")
        return TargetUser

def ReturnUserObject( UserObj : User ) -> dict:
    return {
        "id": UserObj.id,
        "username": UserObj.username,
        "last_online": time.mktime(UserObj.lastonline.timetuple()),
        "created_at": time.mktime(UserObj.created.timetuple()),
        "description": UserObj.description,
        "membership": GetUserMembership(UserObj, changeToString=True)
    }

def ReturnItemObject( AssetObj : Asset ) -> dict:
    return {
        "id": AssetObj.id,
        "name": AssetObj.name,
        "description": AssetObj.description,
        "asset_type": AssetObj.asset_type.name,
        "creator": ReturnUserObject(GetUserFromId(AssetObj.creator_id)) if AssetObj.creator_type == 0 else None,
        "creator_type": AssetObj.creator_type,
        "created_at": time.mktime(AssetObj.created_at.timetuple()),
        "updated_at": time.mktime(AssetObj.updated_at.timetuple()),
        "is_limited": AssetObj.is_limited,
        "is_limited_unique": AssetObj.is_limited_unique,
        "is_for_sale": AssetObj.is_for_sale,
        "asset_rap": GetAssetRap(AssetObj.id) if AssetObj.is_limited and not AssetObj.is_for_sale else None,
        "price_robux": AssetObj.price_robux,
        "price_tickets": AssetObj.price_tix,
        "sales": AssetObj.sale_count
    }

@DiscordInternal.route("/UsernameLookup", methods=['GET'])
def UsernameLookup():
    Username = request.args.get("username", default=None, type=str)
    if Username is None:
        return jsonify({
            "success": False,
            "message": "Invalid username"
        })
    UserObject : User = User.query.filter(func.lower(User.username) == func.lower(Username)).first()
    if UserObject is None:
        return jsonify({
            "success": False,
            "message": "User not found"
        })
    if UserObject.accountstatus in [3,4]:
        return jsonify({
            "success": False,
            "message": "User not found"
        })
    
    return jsonify({
        "success": True,
        "message": "",
        "data": ReturnUserObject(UserObject)
    })

@DiscordInternal.route("/UseridLookup", methods=['GET'])
def UseridLookup():
    Userid = request.args.get("userid", default=None, type=int)
    if Userid is None:
        return jsonify({
            "success": False,
            "message": "Invalid userid"
        })
    UserObject : User = User.query.filter_by(id=Userid).first()
    if UserObject is None:
        return jsonify({
            "success": False,
            "message": "User not found"
        })
    if UserObject.accountstatus in [3,4]:
        return jsonify({
            "success": False,
            "message": "User not found"
        })
    
    return jsonify({
        "success": True,
        "message": "",
        "data": ReturnUserObject(UserObject)
    })

@DiscordInternal.route("/ItemLookup", methods=['GET'])
def ItemLookup():
    AssetId = request.args.get("itemid", default=None, type=int)
    if AssetId is None:
        return jsonify({
            "success": False,
            "message": "Invalid itemid"
        })
    AssetObject : Asset = Asset.query.filter_by(id=AssetId).first()
    if AssetObject is None:
        return jsonify({
            "success": False,
            "message": "Item not found"
        })
    if AssetObject.asset_type.value not in [2, 8, 11, 12, 17, 18, 19, 27, 28, 29, 30, 31, 32, 41, 42, 43, 44, 45, 46, 47]:
        return jsonify({
            "success": False,
            "message": "Item not found"
        })
    return jsonify({
        "success": True,
        "message": "",
        "data": ReturnItemObject(AssetObject)
    })

@DiscordInternal.route("/UserLookupByDiscordId", methods=['GET'])
def UserLookupByDiscordId():
    DiscordId = request.args.get("discordid", default=None, type=int)
    if DiscordId is None:
        return jsonify({
            "success": False,
            "message": "Invalid discordid"
        })
    LinkedDiscordObject : LinkedDiscord = LinkedDiscord.query.filter_by(discord_id=DiscordId).first()
    if LinkedDiscordObject is None:
        return jsonify({
            "success": False,
            "message": "User does not have an account linked to their discord account"
        })
    UserObject : User = User.query.filter_by(id=LinkedDiscordObject.user_id).first()
    if UserObject is None:
        return jsonify({
            "success": False,
            "message": "User not found"
        })
    if UserObject.accountstatus in [3,4]:
        return jsonify({
            "success": False,
            "message": "User not found"
        })
    return jsonify({
        "success": True,
        "message": "",
        "data": ReturnUserObject(UserObject)
    })

@DiscordInternal.route("/AwardUserTurbo", methods=['POST'])
@csrf.exempt
def AwardUserTurbo():
    DiscordId = request.args.get("discordid", default=None, type=int)
    if DiscordId is None:
        return jsonify({
            "success": False,
            "message": "Invalid discordid"
        })
    LinkedDiscordObject : LinkedDiscord = LinkedDiscord.query.filter_by(discord_id=DiscordId).first()
    if LinkedDiscordObject is None:
        return jsonify({
            "success": False,
            "message": "User does not have an account linked to their discord account"
        })
    UserObject : User = User.query.filter_by(id=LinkedDiscordObject.user_id).first()
    if UserObject is None:
        return jsonify({
            "success": False,
            "message": "User not found"
        })
    if UserObject.accountstatus in [3,4]:
        return jsonify({
            "success": False,
            "message": "User is currently moderated"
        })
    UserMembershipStatus : MembershipType = GetUserMembership(UserObject)
    if UserMembershipStatus == MembershipType.TurboBuildersClub:
        return jsonify({
            "success": False,
            "message": "User already has Turbo Builders Club"
        })
    if UserMembershipStatus == MembershipType.OutrageousBuildersClub:
        return jsonify({
            "success": False,
            "message": "User has Outrageous Builders Club"
        })
    
    if redis_controller.get(f"discord_bot_award_turbo_{UserObject.id}") is not None:
        return jsonify({
            "success": False,
            "message": "Discord user has recenetly been awarded Turbo Builders Club"
        })
    GiveUserMembership(UserObject, MembershipType.TurboBuildersClub, expiration=datetime.timedelta(days=14))
    redis_controller.set(f"discord_bot_award_turbo_{UserObject.id}", "1", ex=60*60*24*14)
    return jsonify({
        "success": True,
        "message": ""
    })

@DiscordInternal.route("/Ping", methods=['GET'])
def Ping():
    return jsonify({
        "success": True,
        "message": "Pong!"
    })

@DiscordInternal.route("/VerifyOBCUsers", methods=["POST"])
@csrf.exempt
def VerifyOBCUsers():
    JSONPayload = request.get_json()
    if JSONPayload is None:
        return jsonify({
            "success": False,
            "message": "Invalid JSON payload"
        })
    if "users" not in JSONPayload:
        return jsonify({
            "success": False,
            "message": "Invalid JSON payload"
        })
    
    BadUsersIds : list[int] = []
    for UserId in JSONPayload["users"]:
        LinkedDiscordObj : LinkedDiscord = LinkedDiscord.query.filter_by(discord_id=UserId).first()
        if LinkedDiscordObj is None:
            BadUsersIds.append(UserId)
            continue

        UserObj : User = User.query.filter_by(id=LinkedDiscordObj.user_id).first()
        if UserObj is None:
            BadUsersIds.append(UserId)
            continue

        UserMembershipType : MembershipType = GetUserMembership(UserObj)
        if UserMembershipType != MembershipType.OutrageousBuildersClub:
            BadUsersIds.append(UserId)
            continue
    
    return jsonify({
        "success": True,
        "message": "",
        "bad_users": BadUsersIds
    })

@DiscordInternal.route("/GetSiteStats", methods=["GET"])
def SiteStats():
    UsersOnline = User.query.filter(User.lastonline > (datetime.datetime.utcnow() - datetime.timedelta(minutes=1))).count()
    UsersIngame = PlaceServerPlayer.query.count()

    return jsonify({
        "success": True,
        "message": "",
        "data": {
            "users_online": UsersOnline,
            "users_ingame": UsersIngame
        }
    })