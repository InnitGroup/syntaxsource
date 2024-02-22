import requests
from app.routes.asset import migrateAsset
from app.extensions import limiter, db, redis_controller
from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response, abort

SetsRoute = Blueprint("sets", __name__, template_folder="pages")

def FetchSetData( setId : int, avoidCache : bool = False ) -> str:
    """
        Fetches the set data from sets.pizzaboxer.xyz and then caches it in redis.
    """
    if not avoidCache:
        CachedSetData = redis_controller.get(f"set:{str(setId)}:data")
        if CachedSetData is not None:
            return CachedSetData
    SetData = requests.get(f"https://sets.pizzaboxer.xyz/Game/Tools/InsertAsset.ashx?sid={str(setId)}").text
    redis_controller.set(f"set:{str(setId)}:data", SetData, ex=(60 * 60 * 24 * 31))
    return SetData

def FetchUserSetsData( nsets : int = 20, type : str = "user", userid : int = 1, avoidCache : bool = False ) -> str:
    """
        Fetches the user's sets data from sets.pizzaboxer.xyz and then caches it in redis.
    """
    if not avoidCache:
        CachedSetData = redis_controller.get(f"sets:{str(userid)}:data")
        if CachedSetData is not None:
            return CachedSetData
    SetData = requests.get(f"https://sets.pizzaboxer.xyz/Game/Tools/InsertAsset.ashx?nsets={str(nsets)}&type={type}&userid={str(userid)}").text
    redis_controller.set(f"sets:{str(userid)}:data", SetData, ex=(60 * 60 * 24 * 31))
    return SetData

@SetsRoute.route("/Game/Tools/InsertAsset.ashx", methods=["GET"])
def insert_asset():
    SetId = request.args.get( key = "sid", default = None, type = int )
    if SetId is None:
        NSets = request.args.get( key = "nsets", default = None, type = int )
        OwnerType = request.args.get( key = "type", default = None, type = str )
        UserId = request.args.get( key = "userid", default = None, type = int )

        if NSets is None or OwnerType is None or UserId is None:
            return abort(400)
        
        SetData : str = FetchUserSetsData(nsets=NSets, type=OwnerType, userid=UserId)
        DataResponse = make_response(SetData)
        DataResponse.headers["Content-Type"] = "text/xml"
        return DataResponse
    
    SetData : str = FetchSetData(SetId)
    DataResponse = make_response(SetData)
    DataResponse.headers["Content-Type"] = "text/xml"
    return DataResponse