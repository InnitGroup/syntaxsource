from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort
from app.extensions import csrf, redis_controller, get_remote_address
from app.models.user import User
from app.models.place import Place
from app.models.asset import Asset
from app.models.asset_version import AssetVersion
from app.models.gameservers import GameServer
from app.models.universe import Universe
from app.models.groups import Group, GroupRole, GroupRolePermission
from app.enums.PlaceRigChoice import PlaceRigChoice
from app.enums.PlaceYear import PlaceYear
from app.util.assetversion import GetLatestAssetVersion
from app.util.textfilter import FilterText
from app.util import auth
from app.services import economy, groups
from app.routes.asset import GenerateTempAuthToken
from config import Config
import logging
import datetime

config = Config()

ClientInfo = Blueprint('clientinfo', __name__, url_prefix='/')

@ClientInfo.route('/GetAllowedSecurityVersions/', methods=['GET'])
def GetAllowedSecurityVersions():
    return jsonify({
        "data": ["0.360.0pcplayer", "0.450.0pcplayer", "0.463.0pcplayer", "0.0.0.1", "PRAFBERQ", "39f6144dd9288912aea2df1a5a6b7b4d405d8316"]
    })

@ClientInfo.route("/GetAllowedMD5Hashes/", methods=['GET'])
def GetAllowedMD5Hashes():
    apiKey = request.args.get("apiKey", default=None, type=str)
    if apiKey == "dac86da7-a4bc-4bff-8ca4-8b54e1ac925b": # 2021
        return jsonify({
            "data": [
                "a384c8a1fa1f02b7bd4c60313d034cc1",# 2020
                "69957b53e003c89f7a24debab0b50a3a" # 2021
            ]
        }), 200
    
    return jsonify({
        "data": [
            # 2016
            "3dacdae5eebddad646e5c79378313984",
            # 2018,
            "2e9d56a875ae66f899bd18e4ef660592"
            ]
    })

@ClientInfo.route('/game/players/<userid>/', methods=['GET'])
def GetPlayerInfo(userid):
    return jsonify({
        "ChatFilter": "whitelist"
    })
@ClientInfo.route("/Game/ChatFilter.ashx", methods=["POST"])
@csrf.exempt
def ChatFilterAshx():
    try:
        RequestedFilterText = request.data.decode("utf-8")
    except:
        RequestedFilterText = str(request.data)
    
    try:
        FilterText(
            Text = RequestedFilterText,
            ReplaceWith = "#",
            ThrowException = True
        )
        return "True"
    except:
        return "False"


@ClientInfo.route("/moderation/filtertext/", methods=['POST'])
@csrf.exempt
def FilterTextAPI():
    RequestedFilterText = request.form.get("text", default="", type=str)

    FilteredText = FilterText(
        Text = RequestedFilterText,
        ReplaceWith = "#",
        ThrowException = False
    )

    return jsonify({
        "data": {
            "white": FilteredText,
            "black": ""
        }
    })

@ClientInfo.route("/v2/moderation/textfilter", methods=['POST'])
@ClientInfo.route("/moderation/v2/filtertext", methods=['POST'])
@ClientInfo.route("/moderation/v2/filtertext/", methods=['POST'])
@csrf.exempt
def FilterTextV2API():
    RequestedFilterText = request.form.get("text", default="", type=str)

    FilteredText = FilterText(
        Text = RequestedFilterText,
        ReplaceWith = "#",
        ThrowException = False
    )

    return jsonify({
        "success": True,
        "message": "",
        "data": {
            "AgeUnder13": FilteredText,
            "Age13OrOver": FilteredText
        }
    })

@ClientInfo.route("/users/<userid>/canmanage/<placeid>", methods=['GET'])
def CanManage(userid, placeid):
    AssetObj : Asset = Asset.query.filter_by(id=placeid).first()
    if AssetObj is None:
        return jsonify({
            "CanManage": False,
            "Success": True
        })
    if AssetObj.creator_type == 0 and AssetObj.creator_id == int(userid):
        return jsonify({
            "CanManage": True,
            "Success": True
        })
    elif AssetObj.creator_type == 1:
        GroupObj : Group = Group.query.filter_by(id=AssetObj.creator_id).first()
        UserGroupRole : GroupRole = groups.GetUserRolesetInGroup(userid, GroupObj)
        if UserGroupRole is not None:
            UserRolePermissions : GroupRolePermission = groups.GetRolesetPermission( UserGroupRole )
            if UserRolePermissions.manage_group_games:
                return jsonify({
                    "CanManage": True,
                    "Success": True
                })
    return jsonify({
        "CanManage": False,
        "Success": True
    })

@ClientInfo.route('/game/report-stats', methods=['POST'])
@csrf.exempt
def reportgamestats():
    # TODO: Implement this
    return jsonify({"status": "success"}),200

@ClientInfo.route("/userblock/getblockedusers", methods=['GET'])
def GetBlockedUsers():
    # TODO: Implement this
    return jsonify({
        "success": True,
        "userList": [],
        "total": 0
    })

@ClientInfo.route("/user/multi-following-exists", methods=['POST'])
@csrf.exempt
def MultiFollowingExists():
    # TODO: Implement this
    return jsonify({
        "followings": [],
    })

from app.util.signscript import signUTF8
@ClientInfo.route("/game/visit.ashx", methods=['GET'])
def Visit():
    IsPlaySolo = request.args.get('IsPlaySolo', default=1, type=int)
    UserID = request.args.get('UserID', default=5973, type=int) # default == guest
    PlaceID = request.args.get('PlaceID', default=0, type=int)
    UniverseId = request.args.get('UniverseId', default=0, type=int)

    with open("./app/files/Visit.lua", "r") as f:
        VisitLua = f.read()
    VisitLua = VisitLua.format(
        PlaceId = str(PlaceID),
        UniverseId = str(UniverseId),
        UserId = str(UserID)
    )
    VisitLua = signUTF8(VisitLua)
    Resposne = make_response(VisitLua)
    Resposne.headers['Content-Type'] = 'text/plain'
    return Resposne

@ClientInfo.route("/Error/Dmp.ashx", methods=['POST'])
@csrf.exempt
def DmpAshx():
        return ""
@ClientInfo.route("/Error/Grid.ashx", methods=['POST'])
@csrf.exempt
def ErrorGrid():
    return "OK"

@ClientInfo.route("/game/load-place-info", methods=['GET', 'POST'])
@csrf.exempt
def load_place_info():
    placeId = request.headers.get("Roblox-Place-Id", default=1, type=int)
    AssetObj : Asset = Asset.query.filter_by(id=placeId).first()
    if AssetObj is None:
        return jsonify({
            "success": False,
            "message": "Place not found",
        }), 404
    if AssetObj.asset_type.value != 9:
        return jsonify({
            "success": False,
            "message": "Place not found",
        }), 404
    LatestAssetVersion : AssetVersion = GetLatestAssetVersion(AssetObj)
    return jsonify({
        "CreatorId": AssetObj.creator_id,
        "CreatorType": "User" if AssetObj.creator_type == 0 else "Group",
        "PlaceVersion": LatestAssetVersion.version,
        "GameId": placeId,
        "IsRobloxPlace": True if AssetObj.creator_id == 1 and AssetObj.creator_type == 0 else False
    })

@ClientInfo.route("/v1/player-policies-client", methods=["POST", "GET"])
def playerpolicies():
    return jsonify({
        "isSubjectToChinaPolicies":False,
        "arePaidRandomItemsRestricted":False,
        "isPaidItemTradingAllowed":True,
        "allowedExternalLinkReferences":[
            "Discord",
            "YouTube",
            "Twitch",
            "Facebook"
        ]
    })

EnumTogameAvatarType = {
    PlaceRigChoice.UserChoice: "PlayerChoice",
    PlaceRigChoice.ForceR6: "MorphToR6",
    PlaceRigChoice.ForceR15: "MorphToR15"
}

@ClientInfo.route("/v1.1/game-start-info/")
def game_start_info():
    universeId = request.args.get("universeId", default=None, type=int)
    if universeId is None:
        return jsonify({
            "message": "Invalid request",
            "success": False
        }), 400
    UniverseObj : Universe = Universe.query.filter_by(id = universeId).first()
    if UniverseObj is None:
        return jsonify({
            "message": "Place not found",
            "success": False
        }), 404

    return jsonify({
        "gameAvatarType": "PlayerChoice", #EnumTogameAvatarType[UniverseObj.place_rig_choice], We let avatar-fetch handle this since we allow for place specific avatar types
        "allowCustomAnimations":"True",
        "universeAvatarCollisionType":"OuterBox",
        "universeAvatarBodyType":"Standard",
        "jointPositioningType":"ArtistIntent",
        "message":"",
        "universeAvatarMinScales":{
            "height":0.9,
            "width":0.7,
            "head":0.95,
            "depth":0.0,
            "proportion":0.0,
            "bodyType":0.0
        },
        "universeAvatarMaxScales":{
            "height":1.05,
            "width":1.0,
            "head":1.0,
            "depth":0.0,
            "proportion":1.0,
            "bodyType":1.0
        },
        "universeAvatarAssetOverrides":[],
        "moderationStatus":None
    })

@ClientInfo.route("/v1/name-description/games/<int:placeid>", methods=["GET"])
def name_description(placeid):
    PlaceObj : Place = Place.query.filter_by(placeid=placeid).first()
    if PlaceObj is None:
        return jsonify({
            "message": "Place not found",
            "success": False
        }), 404
    AssetObj : Asset = PlaceObj.assetObj
    return jsonify({
        "data":[
            {
                "name":AssetObj.name,
                "description":AssetObj.description,
                "languageCode":"en"
            }
        ]
    })

@ClientInfo.route("/v1/locales", methods=["GET"])
def client_locales():
    return jsonify({"data":[{"locale":{"id":1,"locale":"en_us","name":"English(US)","nativeName":"English","language":{"id":41,"name":"English","nativeName":"English","languageCode":"en"}},"isEnabledForFullExperience":True,"isEnabledForSignupAndLogin":True,"isEnabledForInGameUgc":True},{"locale":{"id":2,"locale":"es_es","name":"Spanish(Spain)","nativeName":"Español","language":{"id":148,"name":"Spanish","nativeName":"Español","languageCode":"es"}},"isEnabledForFullExperience":True,"isEnabledForSignupAndLogin":True,"isEnabledForInGameUgc":True},{"locale":{"id":3,"locale":"fr_fr","name":"French","nativeName":"Français","language":{"id":48,"name":"French","nativeName":"Français","languageCode":"fr"}},"isEnabledForFullExperience":True,"isEnabledForSignupAndLogin":True,"isEnabledForInGameUgc":True},{"locale":{"id":4,"locale":"id_id","name":"Indonesian","nativeName":"Bahasa Indonesia","language":{"id":64,"name":"Indonesian","nativeName":"Bahasa Indonesia","languageCode":"id"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":5,"locale":"it_it","name":"Italian","nativeName":"Italiano","language":{"id":71,"name":"Italian","nativeName":"Italiano","languageCode":"it"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":6,"locale":"ja_jp","name":"Japanese","nativeName":"日本語","language":{"id":73,"name":"Japanese","nativeName":"日本語 (にほんご),","languageCode":"ja"}},"isEnabledForFullExperience":True,"isEnabledForSignupAndLogin":True,"isEnabledForInGameUgc":True},{"locale":{"id":7,"locale":"ko_kr","name":"Korean","nativeName":"한국어","language":{"id":86,"name":"Korean","nativeName":"한국어","languageCode":"ko"}},"isEnabledForFullExperience":True,"isEnabledForSignupAndLogin":True,"isEnabledForInGameUgc":True},{"locale":{"id":8,"locale":"ru_ru","name":"Russian","nativeName":"Русский","language":{"id":133,"name":"Russian","nativeName":"Русский","languageCode":"ru"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":9,"locale":"th_th","name":"Thai","nativeName":"ภาษาไทย","language":{"id":156,"name":"Thai","nativeName":"ไทย","languageCode":"th"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":10,"locale":"tr_tr","name":"Turkish","nativeName":"Türkçe","language":{"id":163,"name":"Turkish","nativeName":"Türkçe","languageCode":"tr"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":11,"locale":"vi_vn","name":"Vietnamese","nativeName":"Tiếng Việt","language":{"id":173,"name":"Vietnamese","nativeName":"Tiếng Việt","languageCode":"vi"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":12,"locale":"pt_br","name":"Portuguese (Brazil)","nativeName":"Português (Brasil)","language":{"id":128,"name":"Portuguese","nativeName":"Português","languageCode":"pt"}},"isEnabledForFullExperience":True,"isEnabledForSignupAndLogin":True,"isEnabledForInGameUgc":True},{"locale":{"id":13,"locale":"de_de","name":"German","nativeName":"Deutsch","language":{"id":52,"name":"German","nativeName":"Deutsch","languageCode":"de"}},"isEnabledForFullExperience":True,"isEnabledForSignupAndLogin":True,"isEnabledForInGameUgc":True},{"locale":{"id":14,"locale":"zh_cn","name":"Chinese (Simplified)","nativeName":"中文(简体)","language":{"id":30,"name":"Chinese (Simplified)","nativeName":"简体中文","languageCode":"zh-hans"}},"isEnabledForFullExperience":True,"isEnabledForSignupAndLogin":True,"isEnabledForInGameUgc":True},{"locale":{"id":15,"locale":"zh_tw","name":"Chinese (Traditional)","nativeName":"中文(繁體)","language":{"id":189,"name":"Chinese (Traditional)","nativeName":"繁體中文","languageCode":"zh-hant"}},"isEnabledForFullExperience":True,"isEnabledForSignupAndLogin":True,"isEnabledForInGameUgc":True},{"locale":{"id":16,"locale":"bg_bg","name":"Bulgarian","nativeName":"Български","language":{"id":24,"name":"Bulgarian","nativeName":"български език","languageCode":"bg"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":17,"locale":"bn_bd","name":"Bengali","nativeName":"বাংলা","language":{"id":19,"name":"Bengali","nativeName":"বাংলা","languageCode":"bn"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":18,"locale":"cs_cz","name":"Czech","nativeName":"Čeština","language":{"id":36,"name":"Czech","nativeName":"čeština","languageCode":"cs"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":19,"locale":"da_dk","name":"Danish","nativeName":"Dansk","language":{"id":37,"name":"Danish","nativeName":"dansk","languageCode":"da"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":20,"locale":"el_gr","name":"Greek","nativeName":"Ελληνικά","language":{"id":53,"name":"Greek","nativeName":"ελληνικά","languageCode":"el"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":21,"locale":"et_ee","name":"Estonian","nativeName":"Eesti","language":{"id":43,"name":"Estonian","nativeName":"eesti, eesti keel","languageCode":"et"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":22,"locale":"fi_fi","name":"Finnish","nativeName":"Suomi","language":{"id":47,"name":"Finnish","nativeName":"suomi","languageCode":"fi"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":23,"locale":"hi_in","name":"Hindi","nativeName":"हिन्दी","language":{"id":60,"name":"Hindi","nativeName":"हिन्दी, हिंदी","languageCode":"hi"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":24,"locale":"hr_hr","name":"Croatian","nativeName":"Hrvatski","language":{"id":35,"name":"Croatian","nativeName":"hrvatski jezik","languageCode":"hr"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":25,"locale":"hu_hu","name":"Hungarian","nativeName":"Magyar","language":{"id":62,"name":"Hungarian","nativeName":"magyar","languageCode":"hu"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":26,"locale":"ka_ge","name":"Georgian","nativeName":"ქართული","language":{"id":51,"name":"Georgian","nativeName":"ქართული","languageCode":"ka"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":27,"locale":"kk_kz","name":"Kazakh","nativeName":"Қазақ Тілі","language":{"id":79,"name":"Kazakh","nativeName":"қазақ тілі","languageCode":"kk"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":28,"locale":"km_kh","name":"Khmer","nativeName":"ភាសាខ្មែរ","language":{"id":188,"name":"Khmer","nativeName":"ភាសាខ្មែរ","languageCode":"km"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":29,"locale":"lt_lt","name":"Lithuanian","nativeName":"Lietuvių","language":{"id":95,"name":"Lithuanian","nativeName":"lietuvių kalba","languageCode":"lt"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":30,"locale":"lv_lv","name":"Latvian","nativeName":"Latviešu","language":{"id":97,"name":"Latvian","nativeName":"Latviešu Valoda","languageCode":"lv"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":31,"locale":"ms_my","name":"Malay","nativeName":"Bahasa Melayu","language":{"id":101,"name":"Malay","nativeName":"بهاس ملايو‎","languageCode":"ms"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":32,"locale":"my_mm","name":"Burmese","nativeName":"ဗမာစာ","language":{"id":25,"name":"Burmese","nativeName":"ဗမာစာ","languageCode":"my"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":33,"locale":"nb_no","name":"Bokmal","nativeName":"Bokmål","language":{"id":113,"name":"Bokmal","nativeName":"Norsk Bokmål","languageCode":"nb"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":34,"locale":"nl_nl","name":"Dutch","nativeName":"Nederlands","language":{"id":39,"name":"Dutch","nativeName":"Nederlands","languageCode":"nl"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":35,"locale":"fil_ph","name":"Filipino","nativeName":"Filipino","language":{"id":190,"name":"Filipino","nativeName":"Filipino","languageCode":"fil"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":36,"locale":"pl_pl","name":"Polish","nativeName":"Polski","language":{"id":126,"name":"Polish","nativeName":"Język Polski","languageCode":"pl"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":37,"locale":"ro_ro","name":"Romanian","nativeName":"Română","language":{"id":132,"name":"Romanian","nativeName":"Română","languageCode":"ro"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":38,"locale":"uk_ua","name":"Ukrainian","nativeName":"Yкраїньска","language":{"id":169,"name":"Ukrainian","nativeName":"Українська","languageCode":"uk"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":39,"locale":"si_lk","name":"Sinhala","nativeName":"සිංහල","language":{"id":143,"name":"Sinhala","nativeName":"සිංහල","languageCode":"si"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":40,"locale":"sk_sk","name":"Slovak","nativeName":"Slovenčina","language":{"id":144,"name":"Slovak","nativeName":"Slovenčina","languageCode":"sk"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":41,"locale":"sl_sl","name":"Slovenian","nativeName":"Slovenski","language":{"id":145,"name":"Slovenian","nativeName":"Slovenščina","languageCode":"sl"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":42,"locale":"sq_al","name":"Albanian","nativeName":"Shqipe","language":{"id":5,"name":"Albanian","nativeName":"Shqip","languageCode":"sq"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":43,"locale":"bs_ba","name":"Bosnian","nativeName":"Босански","language":{"id":22,"name":"Bosnian","nativeName":"bosanski jezik","languageCode":"bs"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":44,"locale":"sr_rs","name":"Serbian","nativeName":"Cрпски","language":{"id":140,"name":"Serbian","nativeName":"српски језик","languageCode":"sr"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True},{"locale":{"id":45,"locale":"sv_se","name":"Swedish","nativeName":"Svenska","language":{"id":152,"name":"Swedish","nativeName":"Svenska","languageCode":"sv"}},"isEnabledForFullExperience":False,"isEnabledForSignupAndLogin":False,"isEnabledForInGameUgc":True}]})

@ClientInfo.route("/v2/universes/<int:universeid>/configuration", methods=["GET"])
def GetUniverseConfig( universeid : int ):
    return jsonify({
        "allowPrivateServers": False,
        "privateServerPrice": 0,
        "id": universeid,
        "name": "MrGrey",
        "universeAvatarType": "PlayerChoice",
        "universeScaleType": "AllScales",
        "universeAnimationType": "PlayerChoice",
        "universeCollisionType": "OuterBox",
        "universeBodyType": "Standard",
        "universeJointPositioningType": "ArtistIntent",
        "isArchived": False,
        "isFriendsOnly": False,
        "genre": "All",
        "playableDevices": [
            "Computer",
            "Phone",
            "Tablet"
        ],
        "permissions": {
            "IsThirdPartyTeleportAllowed": True,
            "IsThirdPartyAssetAllowed": True,
            "IsThirdPartyPurchaseAllowed": True
        },
        "isForSale": False,
        "price": 0,
        "isStudioAccessToApisAllowed": True,
        "privacyType": "Private"
    })

@ClientInfo.route("/universal-app-configuration/v1/behaviors/app-patch/content", methods=["GET"])
def GetAppConfigContent():
    return jsonify({
        "SchemaVersion": "1",
        "CanaryUserIds": [],
        "CanaryPercentage": 0
    })

@ClientInfo.route("/debu-client/im-person-ate", methods=["POST"])
@csrf.exempt
def im_person_ate():
    try:
        if not config.DEBUG_MODE:
            return abort(404)
    except:
        pass

    if not request.is_json:
        return abort(404)
    data = request.json

    try:
        assert "userId" in data, "userId not found"
        assert isinstance(data["userId"], int), "userId is not an integer"
    except AssertionError as e:
        return f"Validation failed: {str(e)}", 400
    
    req_response = make_response("OK", 200)
    req_response.headers["ImpData"] = auth.CreateToken( userid = data["userId"], expireIn = 60 * 60 * 24 * 365 )
    return req_response


@ClientInfo.route("/universal-app-configuration/v1/behaviors/app-policy/content", methods=["GET"])
def GetAppPolicyContent():
    return jsonify({
        "ChatConversationHeaderGroupDetails": True,
        "ChatHeaderSearch": True,
        "ChatHeaderCreateChatGroup": True,
        "ChatHeaderHomeButton": False,
        "ChatHeaderNotifications": True,
        "ChatPlayTogether": True,
        "ChatShareGameToChatFromChat": True,
        "ChatTapConversationThumbnail": True,
        "ChatViewProfileOption": True,
        "GamesDropDownList": True,
        "UseNewDropDown": False,
        "GameDetailsMorePage": True,
        "GameDetailsShowGlobalCounters": True,
        "GameDetailsPlayWithFriends": True,
        "GameDetailsSubtitle": True,
        "GameInfoList": True,
        "GameInfoListDeveloper": True,
        "GamePlaysAndRatings": True,
        "GameInfoShowBadges": True,
        "GameInfoShowCreated": True,
        "GameInfoShowGamepasses": True,
        "GameInfoShowGenre": True,
        "GameInfoShowMaxPlayers": True,
        "GameInfoShowServers": True,
        "GameInfoShowUpdated": True,
        "GameReportingDisabled": False,
        "GamePlayerCounts": True,
        "GiftCardsEnabled": False,
        "Notifications": True,
        "OfficialStoreEnabled": False,
        "RecommendedGames": True,
        "SearchBar": True,
        "MorePageType": "More",
        "AboutPageType": "About",
        "FriendFinder": True,
        "SocialLinks": True,
        "SocialGroupLinks": True,
        "EnableShareCaptureCTA": True,
        "SiteMessageBanner": True,
        "UseWidthBasedFormFactorRule": False,
        "UseHomePageWithAvatarAndPanel": False,
        "UseBottomBar": True,
        "AvatarHeaderIcon": "LuaApp/icons/ic-back",
        "AvatarEditorShowBuyRobuxOnTopBar": True,
        "HomeIcon": "LuaApp/icons/ic-roblox-close",
        "ShowYouTubeAgeAlert": False,
        "GameDetailsShareButton": True,
        "CatalogShareButton": True,
        "AccountProviderName": "",
        "InviteFromAccountProvider": False,
        "ShareToAccountProvider": False,
        "ShareToAccountProviderTimeout": 8,
        "ShowDisplayName": True,
        "GamesPageCreationCenterTitle": False,
        "ShowShareTargetGameCreator": True,
        "SearchAutoComplete": True,
        "CatalogShow3dView": True,
        "CatalogReportingDisabled": False,
        "CatalogCommunityCreations": True,
        "CatalogPremiumCategory": True,
        "CatalogPremiumContent": True,
        "ItemDetailsFullView": True,
        "UseAvatarExperienceLandingPage": True,
        "HomePageFriendSection": True,
        "HomePageProfileLink": True,
        "PurchasePromptIncludingWarning": False,
        "ShowVideoThumbnails": True,
        "VideoSharingTestContent": [],
        "SystemBarPlacement": "Bottom",
        "EnableInGameHomeIcon": False,
        "UseExternalBrowserForDisclaimerLinks": False,
        "ShowExitFullscreenToast": True,
        "ExitFullscreenToastEnabled": False,
        "UseLuobuAuthentication": False,
        "CheckUserAgreementsUpdatedOnLogin": True,
        "AddUserAgreementIdsToSignupRequest": True,
        "UseOmniRecommendation": True,
        "ShowAgeVerificationOverlayEnabled": False,
        "ShouldShowGroupsTile": True,
        "ShowVoiceUpsell": False,
        "ProfileShareEnabled": True,
        "ContactImporterEnabled": True,
        "FriendCodeQrCodeScannerEnabled": False,
        "RealNamesInDisplayNamesEnabled": False,
        "CsatSurveyRestrictTextInput": False,
        "RobloxCreatedItemsCreatedByLuobu": False,
        "GameInfoShowChatFeatures": True,
        "PlatformGroup": "Unknown",
        "UsePhoneSearchDiscoverEntry": False,
        "HomeLocalFeedItems": {
            "UserInfo": 1,
            "FriendCarousel": 2
        },
        "Routes": {
            "auth": {
            "connect": "v2/login",
            "login": "v2/login",
            "signup": "v2/signup"
            }
        },
        "PromotionalEmailsCheckboxEnabled": True,
        "PromotionalEmailsOptInByDefault": False,
        "EnablePremiumUserFeatures": True,
        "CanShowUnifiedChatUpsell": True,
        "RequireExplicitVoiceConsent": True,
        "RequireExplicitAvatarVideoConsent": True,
        "EnableVoiceReportAbuseMenu": True
    })

@ClientInfo.route("/game/studio.ashx", methods=['GET'])
def studio():
    StudioLua = open("./app/files/Studio.lua", "r").read()
    SignedStudioLua = signUTF8(StudioLua)
    Response = make_response(SignedStudioLua)
    Response.headers['Content-Type'] = 'text/plain'
    return Response

@ClientInfo.route("/game/gameserver2014.lua", methods=['GET'])
def gameserver_2014():
    RemoteAddress = get_remote_address()
    GameserverObj : GameServer = GameServer.query.filter_by( serverIP = RemoteAddress ).first()
    if GameserverObj is None:
        return jsonify({
            "success": False,
            "message": "Unauthorized"
        }), 401
    
    PlaceId = request.args.get( key = "placeId", default = None, type = int )
    NetworkPort = request.args.get( key = "networkPort", default = None, type = int )
    CreatorId = request.args.get( key = "creatorId", default = None, type = int )
    CreatorType = request.args.get( key = "creatorType", default = None, type = int )
    JobId = request.args.get( key = "jobId", default = None, type = str )

    if "UserRequest" in request.headers.get( key = "accesskey", default = "" ):
        return jsonify({
            "success": False,
            "message": "Invalid request"
        }), 400

    if PlaceId is None or NetworkPort is None or CreatorId is None or CreatorType is None or JobId is None:
        return jsonify({
            "success": False,
            "message": "Invalid request"
        }), 400
    
    PlaceObj : Place = Place.query.filter_by(placeid=PlaceId).first()
    if PlaceObj is None:
        return jsonify({
            "success": False,
            "message": "Place not found"
        }), 404
    
    UniverseObj : Universe = Universe.query.filter_by(id=PlaceObj.parent_universe_id).first()
    if UniverseObj is None:
        return jsonify({
            "success": False,
            "message": "Universe not found"
        }), 404
    
    if UniverseObj.place_year != PlaceYear.Fourteen:
        return jsonify({
            "success": False,
            "message": "Invalid request"
        }), 400
    
    #if not redis_controller.exists(f"gameserver2014lua:{PlaceId}:{JobId}"):
    #    return jsonify({
    #        "success": False,
    #        "message": "Invalid request"
    #    }), 400
    #redis_controller.delete(f"gameserver2014lua:{PlaceId}:{JobId}")

    TempPlaceAccessKey = GenerateTempAuthToken(
        AssetId = PlaceId,
        Expiration = 180,
        CreatorIP = get_remote_address()
    )
    GameserverLua = open("./app/files/2014Gameserver.lua", "r").read()
    GameserverLua = GameserverLua.format(
        PlaceId = PlaceId,
        NetworkPort = NetworkPort,
        CreatorId = CreatorId,
        CreatorType = CreatorType,
        JobId = JobId,
        AuthToken = GameserverObj.accessKey,
        TempPlaceAccessKey = TempPlaceAccessKey
    )

    SignedGameserverLua = signUTF8(GameserverLua)
    Response = make_response(SignedGameserverLua)
    Response.headers['Content-Type'] = 'text/plain'
    Response.set_cookie(
        key = "Roblox-Place-Id",
        value = str(PlaceId),
        expires = 60 * 60 * 24,
        domain = f".{config.BaseDomain}"
    )
    Response.set_cookie(
        key = "Temp-Place-Access-Key",
        value = TempPlaceAccessKey,
        expires = 180,
        domain = f".{config.BaseDomain}"
    )

    logging.info("2014Gameserver.lua request from %s for place %d", RemoteAddress, PlaceId)
    
    return Response

@ClientInfo.route("/game/gameserver2016.lua", methods=['GET'])
def gameserver_2016():
    RemoteAddress = get_remote_address()
    GameserverObj : GameServer = GameServer.query.filter_by( serverIP = RemoteAddress ).first()
    if GameserverObj is None:
        return jsonify({
            "success": False,
            "message": "Unauthorized"
        }), 401
    
    GameserverLua = open("./app/files/2016Gameserver.lua", "r").read()
    GameserverLua = f"-- Syntax 2016 Gameserver.lua | Signed on {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n" + GameserverLua

    SignedGameserverLua = signUTF8(GameserverLua)
    Response = make_response(SignedGameserverLua)
    Response.headers['Content-Type'] = 'text/plain'

    logging.info("2016Gameserver.lua request from %s", RemoteAddress)

    return Response

@ClientInfo.route("/game/2014Join.lua", methods=['GET'])
def join_2014():
    placeId = request.args.get("placeId", default=None, type=int)
    if placeId is None:
        return jsonify({
            "success": False,
            "message": "Invalid request"
        }), 400

    JoinLua = open("./app/files/2014Join.lua", "r").read()
    JoinLua = JoinLua.format(
        PlaceId = str(placeId)
    )
    SignedJoinLua = signUTF8(JoinLua)
    Response = make_response(SignedJoinLua)
    Response.headers['Content-Type'] = 'text/plain'
    return Response

@ClientInfo.route("/v1/users/<int:userId>/currency", methods=["GET"])
@auth.authenticated_required_api
def get_user_currency( userId : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id != userId:
        return jsonify({"success": False, "message": "Unauthorized"}),401
    UserRobuxBalance, UserTixBalance = economy.GetUserBalance(AuthenticatedUser)
    return jsonify({
        "robux": UserRobuxBalance,
        "tickets": UserTixBalance
    }),200

#followings.roblox.com/v1/users/<int:userid>/universes/<int:universeid>/status
@ClientInfo.route("/v1/users/<int:userid>/universes/<int:universeid>/status", methods=["GET"])
@auth.authenticated_required_api
def get_user_following_universe_status( userid : int, universeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id != userid:
        return jsonify({"success": False, "message": "Unauthorized"}),401
    return jsonify({
        "UniverseId": universeid,
        "UserId": userid,
        "CanFollow": False,
        "IsFollowing": False,
        "FollowingCountByType": 0,
        "FollowingLimitByType": 200
    }),200

#badges.roblox.com/v1/universes/<int:universeid>/badges
@ClientInfo.route("/v1/universes/<int:universeid>/badges", methods=["GET"])
@auth.authenticated_required_api
def get_universe_badges( universeid : int ):
    return jsonify({
        "data": [],
        "previousPageCursor": None,
        "nextPageCursor": None
    }),200
