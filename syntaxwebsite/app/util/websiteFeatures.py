from app.extensions import redis_controller

def SetWebsiteFeature(feature : str, value : bool) -> None:
    """
        :param feature: The feature to set
        :param value: The value to set the feature to
    """
    redis_controller.set("websitefeature_" + feature, str(value))

def GetWebsiteFeature(feature : str) -> bool:
    """
        :param feature: The feature to check
        :returns: bool (Whether the feature is enabled or not)
    """
    if redis_controller.get("websitefeature_" + feature) is None:
        redis_controller.set("websitefeature_" + feature, str(True))
        return True
    return redis_controller.get("websitefeature_" + feature) == "True"
