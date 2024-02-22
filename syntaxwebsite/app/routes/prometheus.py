# prometheus.py
# Used for providing metrics to Prometheus
# https://prometheus.io/docs/instrumenting/writing_exporters/

import time
from flask import Blueprint, Response, abort
from datetime import datetime, timedelta
from sqlalchemy import func 

from app.models.user import User
from app.models.placeserver_players import PlaceServerPlayer
from app.models.placeservers import PlaceServer
from app.models.gameservers import GameServer
from app.models.game_session_log import GameSessionLog
from app.models.asset import Asset

from app.extensions import get_remote_address
from config import Config

config = Config()

PrometheusRoute = Blueprint('prometheus', __name__, url_prefix='/')

@PrometheusRoute.before_request
def before_request():
    if not config.PROMETHEUS_ENABLED:
        return abort( 404 )
    ClientRemoteAddress = get_remote_address()
    if ClientRemoteAddress not in config.PROMETHEUS_ALLOWED_IPS:
        return abort( 404 )
    

@PrometheusRoute.route('/metrics', methods=['GET'])
def metrics():
    StartingMeasureTime = time.time()

    UsersOnlineCount = User.query.filter(User.lastonline > (datetime.utcnow() - timedelta(minutes=1))).count()
    UsersIngame = PlaceServerPlayer.query.count()
    UsersInReservedServers = PlaceServerPlayer.query.join( PlaceServer, PlaceServerPlayer.serveruuid == PlaceServer.serveruuid ).filter(PlaceServer.reservedServerAccessCode != None).count()
    ActivePlaceServers = PlaceServer.query.count()
    ActiveReservedPlaceServers = PlaceServer.query.filter(PlaceServer.reservedServerAccessCode != None).count()
    UsersSignedUpPast24Hours = User.query.filter(User.created > (datetime.utcnow() - timedelta(days=1))).count()
    GameServersTotalMemoryUsage = GameServer.query.with_entities( func.sum(GameServer.RCCmemoryUsage) ).scalar() # Megabytes
    UniqueGameSessionsPast24Hours = GameSessionLog.query.filter(GameSessionLog.joined_at > (datetime.utcnow() - timedelta(days=1))).distinct(GameSessionLog.user_id).count()
    GameSessionsPast24Hours = GameSessionLog.query.filter(GameSessionLog.joined_at > (datetime.utcnow() - timedelta(days=1))).count()
    TotalUsersSignedUp = User.query.count()
    TotalAssets = Asset.query.count()

    TimeTaken = time.time() - StartingMeasureTime

    PROMETHEUS_RESPONSE = f"""# HELP syntaxeco_users_online The number of users currently online
# TYPE syntaxeco_users_online gauge
syntaxeco_users_online {UsersOnlineCount}

# HELP syntaxeco_users_ingame The number of users currently in a game
# TYPE syntaxeco_users_ingame gauge
syntaxeco_users_ingame {UsersIngame}

# HELP syntaxeco_active_placeservers The number of active place servers
# TYPE syntaxeco_active_placeservers gauge
syntaxeco_active_placeservers {ActivePlaceServers}

# HELP syntaxeco_active_reserved_placeservers The number of active reserved place servers
# TYPE syntaxeco_active_reserved_placeservers gauge
syntaxeco_active_reserved_placeservers {ActiveReservedPlaceServers}

# HELP syntaxeco_users_in_reserved_servers The number of users currently in reserved servers
# TYPE syntaxeco_users_in_reserved_servers gauge
syntaxeco_users_in_reserved_servers {UsersInReservedServers}

# HELP syntaxeco_users_signed_up_past_24_hours The number of users that signed up in the past 24 hours
# TYPE syntaxeco_users_signed_up_past_24_hours gauge
syntaxeco_users_signed_up_past_24_hours {UsersSignedUpPast24Hours}

# HELP syntaxeco_gameservers_total_memory_usage The total memory usage of all game servers
# TYPE syntaxeco_gameservers_total_memory_usage gauge
syntaxeco_gameservers_total_memory_usage {GameServersTotalMemoryUsage}

# HELP syntaxeco_unique_gamesessions_past_24_hours The number of unique game sessions in the past 24 hours
# TYPE syntaxeco_unique_gamesessions_past_24_hours gauge
syntaxeco_unique_gamesessions_past_24_hours {UniqueGameSessionsPast24Hours}

# HELP syntaxeco_gamesessions_past_24_hours The number of game sessions in the past 24 hours
# TYPE syntaxeco_gamesessions_past_24_hours gauge
syntaxeco_gamesessions_past_24_hours {GameSessionsPast24Hours}

# HELP syntaxeco_total_users_signed_up The total number of users that have signed up
# TYPE syntaxeco_total_users_signed_up gauge
syntaxeco_total_users_signed_up {TotalUsersSignedUp}

# HELP syntaxeco_total_assets The total number of assets
# TYPE syntaxeco_total_assets gauge
syntaxeco_total_assets {TotalAssets}

# HELP syntaxeco_prometheus_request_time The time taken to generate the Prometheus metrics
# TYPE syntaxeco_prometheus_request_time gauge
syntaxeco_prometheus_request_time {TimeTaken}
"""
    
    return Response(PROMETHEUS_RESPONSE, mimetype="text/plain")