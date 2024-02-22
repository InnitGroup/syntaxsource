from app.extensions import redis_controller, db
from app.models.place import Place
from app.models.placeservers import PlaceServer
from app.models.placeserver_players import PlaceServerPlayer
from app.models.universe import Universe

from sqlalchemy import func

def ClearPlayingCountCache( PlaceObj : Place ):
    """
        Clears the cache for the amount of players playing a place
        
        :param PlaceObj: The place to clear the cache for

        :returns: None
    """
    redis_controller.delete(f"place:{str(PlaceObj.placeid)}:playercount:placeinfo")
    redis_controller.delete(f"universe:{str(PlaceObj.parent_universe_id)}:playercount:placeinfo")

def ClearUniversePlayingCountCache( UniverseObj : Universe ):
    """
        Clears the cache for the amount of players playing in a universe

        :param UniverseObj: The universe to clear the cache for

        :returns: None
    """
    redis_controller.delete(f"universe:{str(UniverseObj.id)}:playercount:placeinfo")

def GetPlayingCount( PlaceObj : Place, IgnoreCache = False ) -> int:
    """
        Returns the amount of players playing a place
        
        :param PlaceObj: The place to get the amount of players playing
        :param IgnoreCache: Whether to ignore the cache or not

        :returns: int (The amount of players playing a place)
    """
    if not IgnoreCache:
        PlayingCount = redis_controller.get(f"place:{str(PlaceObj.placeid)}:playercount:placeinfo")
        if PlayingCount is not None:
            return int(PlayingCount)
    
    PlayingCount = 0
    # Check if there even is a place server
    PlaceServerObj : PlaceServer = PlaceServer.query.filter_by(serverPlaceId=PlaceObj.placeid).first()
    if PlaceServerObj is not None:
        # Get all place servers with the same placeid
        PlaceServerObjs = PlaceServer.query.filter_by(serverPlaceId=PlaceObj.placeid).all()
        for PlaceServerObj in PlaceServerObjs:
            PlayingCount += PlaceServerObj.playerCount
    
    redis_controller.set(f"place:{str(PlaceObj.placeid)}:playercount:placeinfo", PlayingCount, ex=60)
    return PlayingCount
    
def GetUniversePlayingCount( UniverseObj : Universe, IgnoreCache : bool = False ) -> int:
    """
        Returns the amount of players playing in a universe

        :param UniverseObj: The universe to get the amount of players playing
        :param IgnoreCache: Whether to ignore the cache or not

        :returns: int (The amount of players playing in a universe)
    """

    if not IgnoreCache:
        PlayingCount = redis_controller.get(f"universe:{str(UniverseObj.id)}:playercount:placeinfo")
        if PlayingCount is not None:
            return int(PlayingCount)
    
    PlayingCount = PlaceServer.query.join(Place, PlaceServer.serverPlaceId == Place.placeid ).filter(Place.parent_universe_id == UniverseObj.id).all()
    PlayingCount = sum([PlaceServerObj.playerCount for PlaceServerObj in PlayingCount])
    redis_controller.set(f"universe:{str(UniverseObj.id)}:playercount:placeinfo", PlayingCount, ex=60)
    return PlayingCount