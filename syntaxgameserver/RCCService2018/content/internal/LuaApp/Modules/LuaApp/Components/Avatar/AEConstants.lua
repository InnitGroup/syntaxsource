local AEConstants = {}

AEConstants.AvatarType = {
	R6 = "R6",
	R15 = "R15",
}

AEConstants.CategoryMenuOpen = {
	CLOSED = 0,
	OPEN = 1,
	NOT_INITIALIZED = 2,
}

AEConstants.PageType = {
	AssetCards = 0,
	BodyColors = 1,
	Scale = 2,
    Animation = 3,
    CurrentlyWearing = 4,
}

AEConstants.AvatarAssetGroup = {
    Equipped = 1,
    Recent = 2,
    Owned = 3,
    None = 4,
}

AEConstants.AssetTypes = {
    TShirt          = 2,
	Hat 			= 8,
    Hair 			= 41,
    FaceAccessory 	= 42,
    Neck 			= 43,
    Shoulder 		= 44,
    Front 			= 45,
    Back 			= 46,
    Waist 			= 47,
    Shirt 			= 11,
    Pants 			= 12,
    Gear 			= 19,
    Head 			= 17,
    Face 			= 18,
    Torso 			= 27,
    RightArm 		= 28,
    LeftArm 		= 29,
    LeftLeg 		= 30,
    RightLeg 		= 31,
    ClimbAnim 		= 48,
    FallAnim 		= 50,
    IdleAnim 		= 51,
    JumpAnim 		= 52,
    RunAnim 		= 53,
    SwimAnim 		= 54,
    WalkAnim 		= 55,
}

AEConstants.AssetTypeNames = {
    [2]  = "TShirt",
    [8]  = "Hat",
    [41] = "Hair",
    [42] = "FaceAccessory",
    [43] = "Neck",
    [44] = "Shoulder",
    [45] = "Front",
    [46] = "Back",
    [47] = "Waist",
    [11] = "Shirt",
    [12] = "Pants",
    [19] = "Gear",
    [17] = "Head",
    [18] = "Face",
    [27] = "Torso",
    [28] = "RightArm",
    [29] = "LeftArm",
    [30] = "LeftLeg",
    [31] = "RightLeg",
    [48] = "ClimbAnim",
    [50] = "FallAnim",
    [51] = "IdleAnim",
    [52] = "JumpAnim",
    [53] = "RunAnim",
    [54] = "SwimAnim",
    [55] = "WalkAnim",
}

AEConstants.EquipAssetTypes = {
    AssetCard = 0,
    AssetOptionsMenu = 1,
    HatSlot = 2,
}

AEConstants.animAssetTypes = {
    climbAnim       = 48,
    fallAnim        = 50,
    idleAnim        = 51,
    jumpAnim        = 52,
    runAnim         = 53,
    swimAnim        = 54,
    walkAnim        = 55,
}

AEConstants.R15TypePartMap = {
    [AEConstants.AssetTypes.Torso] = {"LowerTorso", "UpperTorso"},
    [AEConstants.AssetTypes.RightArm] = {"RightUpperArm", "RightLowerArm", "RightHand"},
    [AEConstants.AssetTypes.LeftArm] = {"LeftUpperArm", "LeftLowerArm", "LeftHand"},
    [AEConstants.AssetTypes.LeftLeg] = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
    [AEConstants.AssetTypes.RightLeg] = {"RightUpperLeg", "RightLowerLeg", "RightFoot"},
}

AEConstants.REACHED_LAST_PAGE = "LAST_PAGE"

AEConstants.OUTFITS = "Outfits"

AEConstants.IMAGE_SHEET = "rbxasset://textures/AvatarEditorImages/Sheet.png"

AEConstants.defaultClothingAssetWebKeys = {
	SHIRT = "defaultShirtAssetIds",
	PANTS = "defaultPantAssetIds",
}

AEConstants.AvatarSettings = {
	proportionsAndBodyTypeEnabledForUser = 1,
    minDeltaBodyColorDifference = 2,
    scalesRules = 3,
}

AEConstants.WarningType = {
	CONNECTION = 1,
	DEFAULT_CLOTHING = 2,
	R6_SCALES = 3,
	R6_ANIMATIONS = 4,
}

AEConstants.recommendedItems = 4

return AEConstants
