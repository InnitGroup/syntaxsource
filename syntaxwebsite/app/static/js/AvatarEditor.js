var AssetsCurrentlyEquipped = []
var AssetTypeDict = {}
var AvatarRules = {}
var UserBodyColors = {
    'Head': 1001,
    'Torso': 1001,
    'LeftArm': 1001,
    'RightArm': 1001,
    'LeftLeg': 1001,
    'RightLeg': 1001
}
var UserAvatarScaling = {
    'height': 1,
    'width': 1,
    'head': 1,
    'proportion': 0
}
var rigType = "R6"
var AssetCardTemplate = null
var PageNumber = 0
var SelectedAssetType = 11
var IsThisTheLastPage = false
var PaginationPreviousBtn = null
var PaginationNextBtn = null
var PaginationText = null

async function GetLimitForAssetType( AssetType ) {
    // Loop through the "wearableAssetTypes" array in avatarrules.json
    for (let i = 0; i < AvatarRules.wearableAssetTypes.length; i++) {
        if (AvatarRules.wearableAssetTypes[i].id == AssetType) {
            return AvatarRules.wearableAssetTypes[i].maxNumber
        }
    }
    return 0
}

async function GetAssetsForType( AssetType, Page = 0 ) {
    var AssetFetchResponse = await fetch('/avatar/getassets?type=' + AssetType + '&page=' + Page)
    if (AssetFetchResponse.status != 200) {
        return []
    }
    var AssetFetchResponseJSON = await AssetFetchResponse.json()
    var Assets = AssetFetchResponseJSON["assets"]
    // Insert the assets into the AssetTypeDict
    for (let i = 0; i < Assets.length; i++) {
        Assets[i].assetType = AssetType
        AssetTypeDict[Assets[i].id] = Assets[i]
    }
    IsThisTheLastPage = AssetFetchResponseJSON["lastPage"]
    return Assets
}

async function RedrawAvatar() {
    var RedrawResponse = await fetch('/avatar/forceredraw', {
        method: 'POST'
    })
    if (RedrawResponse.status == 200) {
        WaitForRenderReady()
    } else if (RedrawResponse.status == 400) {
        alert("Something went wrong!")
    } else if (RedrawResponse.status == 429) {
        alert("Slow down! You recently asked for a redraw!")
    } else {
        alert("Something went wrong!")
    }
}

async function WaitForRenderReady() {
    var RenderWaitingText = document.getElementById('render-waiting-text')
    RenderWaitingText.style.display = 'block'
    while (true) {
        var RenderReadyResponse = await fetch('/avatar/isthumbnailready')
        if (RenderReadyResponse.status == 200) {
            var RenderReadyResponseJSON = await RenderReadyResponse.json()
            if (RenderReadyResponseJSON["ready"]) {
                break
            }
        }
        await new Promise(r => setTimeout(r, 500));
    }
    RenderWaitingText.style.display = 'none'
    var AvatarImage = document.getElementById('avatar-image')
    var AvatarSource = AvatarImage.src // Unmodified src "/Thumbs/Avatar.ashx?x=420&y=420&userId=1"
    if (AvatarSource.includes('&refresh=')) {
        AvatarSource = AvatarSource.substring(0, AvatarSource.indexOf('&refresh='))
    }
    AvatarImage.src = AvatarSource + '&refresh=' + Math.random()
}

async function UpdateAvatar() {
    var SaveChangesButton = document.getElementById('savechanges-btn')
    SaveChangesButton.style.display = 'none'
    var CurrentlyEquippedArray = []
    for (let i = 0; i < AssetsCurrentlyEquipped.length; i++) {
        CurrentlyEquippedArray.push(AssetTypeDict[AssetsCurrentlyEquipped[i]].id)
    }
    var UpdateAvatarResponse = await fetch('/avatar/setavatar', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            'bodyColors': [UserBodyColors.Head, UserBodyColors.Torso, UserBodyColors.LeftArm, UserBodyColors.RightArm, UserBodyColors.LeftLeg, UserBodyColors.RightLeg],
            "assets": CurrentlyEquippedArray,
            "rigType": rigType,
            "scales": UserAvatarScaling
        })
    })
    if (UpdateAvatarResponse.status == 200) {
        WaitForRenderReady()
    } else if (UpdateAvatarResponse.status == 400) {
        alert('Something went wrong!')
    } else if (UpdateAvatarResponse.status == 429) {
        alert('Slow down! You are changing your avatar too fast!')
        SaveChangesButton.style.display = 'block'
    } else {
        alert('Something went wrong!')
    }
}

async function ConvertBodyColortoHex( bodycolor ) {
    for (let i = 0; i < AvatarRules.bodyColorsPalette.length; i++) {
        if (AvatarRules.bodyColorsPalette[i].brickColorId == bodycolor) {
            return AvatarRules.bodyColorsPalette[i].hexColor
        }
    }
    return '#FFFFFF'
}

async function UpdateAssetCards( assetId ) {
    var AssetCards = document.getElementsByClassName(`asset-card-${assetId}`)
    var IsAssetEquipped = AssetsCurrentlyEquipped.includes(assetId)
    for (let i = 0; i < AssetCards.length; i++) {
        var ToggleWearButton = AssetCards[i].getElementsByClassName('asset-card-button')[0]
        if (IsAssetEquipped) {
            ToggleWearButton.innerHTML = 'Remove'
        } else {
            ToggleWearButton.innerHTML = 'Wear'
            if (AssetCards[i].getAttribute("data-isundercurrentwearing") == "true") {
                AssetCards[i].remove()
            }
        }
    }
}

async function WearAsset( assetId ) {
    if (AssetsCurrentlyEquipped.includes(assetId)) {
        return
    }
    assetType = AssetTypeDict[assetId].assetType
    var LimitForAssetType = await GetLimitForAssetType(assetType)
    var CountForAssetType = 0
    for (let i = 0; i < AssetsCurrentlyEquipped.length; i++) {
        if (AssetTypeDict[AssetsCurrentlyEquipped[i]].assetType == assetType) {
            CountForAssetType++
        }
    }
    if (CountForAssetType >= LimitForAssetType) {
        for (let i = 0; i < AssetsCurrentlyEquipped.length; i++) {
            if (AssetTypeDict[AssetsCurrentlyEquipped[i]].assetType == assetType) {
                var AssetId = AssetsCurrentlyEquipped[i]
                AssetsCurrentlyEquipped.splice(i, 1)
                UpdateAssetCards(AssetId)
                break
            }
        }
    }
    if (LimitForAssetType > 0) {
        AssetsCurrentlyEquipped.push(assetId)
        var CurrentlyWearingCardHolder = document.getElementById('currentlywearing-card-holder')
        var NewAssetCard = await CreateNewAssetCard(assetId, AssetTypeDict[assetId].name)
        CurrentlyWearingCardHolder.appendChild(NewAssetCard)
        NewAssetCard.setAttribute("data-isundercurrentwearing", "true")
    }
    UpdateAssetCards(assetId)
    document.getElementById('savechanges-btn').style.display = 'block'
}

async function RemoveAsset( assetId ) {
    for (let i = 0; i < AssetsCurrentlyEquipped.length; i++) {
        if (AssetsCurrentlyEquipped[i] == assetId) {
            AssetsCurrentlyEquipped.splice(i, 1)
            break
        }
    }
    UpdateAssetCards(assetId)
    document.getElementById('savechanges-btn').style.display = 'block'
}

async function CreateNewAssetCard( AssetId, Name ) {
    var NewAssetCard = AssetCardTemplate.cloneNode(true)
    NewAssetCard.setAttribute("class", NewAssetCard.getAttribute("class").replace("template", AssetId))
    NewAssetCard.style.display = 'block'
    var AssetImage = NewAssetCard.getElementsByClassName('asset-card-img')[0]
    var AssetName = NewAssetCard.getElementsByClassName('asset-card-assetname')[0]
    var AssetToggleButton = NewAssetCard.getElementsByClassName('asset-card-button')[0]
    AssetImage.src = `/Thumbs/Asset.ashx?x=150&y=150&assetId=${AssetId}`
    AssetName.innerText = Name
    AssetName.href = `/catalog/${AssetId}/`
    
    //var AssetsCardHolder = document.getElementById('assets-card-holder')
    //AssetsCardHolder.appendChild(NewAssetCard)

    if (AssetsCurrentlyEquipped.includes(AssetId)) {
        AssetToggleButton.innerText = 'Remove'
    }
    if ( AssetTypeDict[AssetId].moderation_status == 0 ) {
        AssetToggleButton.addEventListener('click', async () => {
            if (AssetToggleButton.innerText == 'Wear') {
                AssetToggleButton.innerText = 'Remove'
                WearAsset(AssetId)
            } else if (AssetToggleButton.innerText == 'Remove') {
                AssetToggleButton.innerText = 'Wear'
                RemoveAsset(AssetId)
            }
        })
    } else {
        AssetToggleButton.disabled = true
        if ( AssetTypeDict[AssetId].moderation_status == 1 ) {
            AssetToggleButton.innerText = 'Pending'
        } else if ( AssetTypeDict[AssetId].moderation_status == 2 ) {
            AssetToggleButton.innerText = 'Deleted'
        }
    }

    return NewAssetCard
}

async function LoadPageForAsset( AssetType ) {
    var AssetsArray = await GetAssetsForType(AssetType, PageNumber)
    var AssetsCardHolder = document.getElementById('assets-card-holder')
    AssetsCardHolder.innerHTML = ''
    for (let i = 0; i < AssetsArray.length; i++) {
        var Asset = AssetsArray[i]
        var AssetCard = await CreateNewAssetCard(Asset.id, Asset.name)
        AssetsCardHolder.appendChild(AssetCard)
    }

    if (PageNumber > 0) {
        PaginationPreviousBtn.disabled = false
    } else {
        PaginationPreviousBtn.disabled = true
    }
    if (!IsThisTheLastPage) {
        PaginationNextBtn.disabled = false
    } else {
        PaginationNextBtn.disabled = true
    }
    if (AssetsArray.length == 0) {
        AssetsCardHolder.innerHTML = '<p style="text-align: center;" class="mt-3">No items found</p>'
    }
}

var ColorPickerSelectedBodyPart = -1

document.addEventListener('DOMContentLoaded', async () => {
    const ResponseAvatarRules = await fetch('/static/avatarrules.json?version=2')
    AvatarRules = await ResponseAvatarRules.json()
    AssetCardTemplate = document.getElementsByClassName('asset-card-template')[0]
    PaginationNextBtn = document.getElementById('pagination-next-btn')
    PaginationPreviousBtn = document.getElementById('pagination-back-btn')
    PaginationText = document.getElementById('pagination-page-number')
    const ResponseUserAvatar = await fetch('/avatar/getavatar')
    const UserAvatar = await ResponseUserAvatar.json() // This should respond with {"bodyColors": [headColor, torsoColor, leftArmColor, rightArmColor, leftLegColor, rightLegColor], "currentlyWearing": [assetId]}
    var CurrentlyWearingCardHolder = document.getElementById('currentlywearing-card-holder')
    for (let i = 0; i < UserAvatar.currentlyWearing.length; i++) {
        var Asset = UserAvatar.currentlyWearing[i]
        AssetTypeDict[Asset.id] = {"id": Asset.id, "assetType": Asset.type, "name": Asset.name, "moderation_status": Asset.moderation_status}
        AssetsCurrentlyEquipped.push(Asset.id)
        var AssetCard = await CreateNewAssetCard(Asset.id, Asset.name)
        CurrentlyWearingCardHolder.appendChild(AssetCard)
        AssetCard.setAttribute("data-isundercurrentwearing", "true")
    }

    UserBodyColors.Head = UserAvatar.bodyColors[0]
    UserBodyColors.Torso = UserAvatar.bodyColors[1]
    UserBodyColors.LeftArm = UserAvatar.bodyColors[2]
    UserBodyColors.RightArm = UserAvatar.bodyColors[3]
    UserBodyColors.LeftLeg = UserAvatar.bodyColors[4]
    UserBodyColors.RightLeg = UserAvatar.bodyColors[5]
    
    const SaveChangesButton = document.getElementById('savechanges-btn')

    const SelectTabInput = document.getElementById('select-tab-input')
    const EquipAssetsTab = document.getElementById('equip-assets-tab')
    const AvatarScalingTab = document.getElementById('avatar-scaling-tab')

    SelectTabInput.addEventListener('change', () => {
        var selectedTabIndex = Number(SelectTabInput.options[SelectTabInput.selectedIndex].getAttribute('data-tab'))
        if (selectedTabIndex == 1) {
            EquipAssetsTab.style.display = 'block'
            AvatarScalingTab.style.display = 'none'
        } else if (selectedTabIndex == 2) {
            EquipAssetsTab.style.display = 'none'
            AvatarScalingTab.style.display = 'block'
        }
    })

    const HeadColor = document.getElementById('head-bodycolor')
    const TorsoColor = document.getElementById('torso-bodycolor')
    const LeftArmColor = document.getElementById('leftarm-bodycolor')
    const RightArmColor = document.getElementById('rightarm-bodycolor')
    const LeftLegColor = document.getElementById('leftleg-bodycolor')
    const RightLegColor = document.getElementById('rightleg-bodycolor')

    HeadColor.style.backgroundColor = await ConvertBodyColortoHex(UserBodyColors.Head)
    TorsoColor.style.backgroundColor = await ConvertBodyColortoHex(UserBodyColors.Torso)
    LeftArmColor.style.backgroundColor = await ConvertBodyColortoHex(UserBodyColors.LeftArm)
    RightArmColor.style.backgroundColor = await ConvertBodyColortoHex(UserBodyColors.RightArm)
    LeftLegColor.style.backgroundColor = await ConvertBodyColortoHex(UserBodyColors.LeftLeg)
    RightLegColor.style.backgroundColor = await ConvertBodyColortoHex(UserBodyColors.RightLeg)

    HeadColor.addEventListener('click', () => {
        ColorPickerSelectedBodyPart = 0
        ColorPickerOverlay.style.display = 'block'
    })
    TorsoColor.addEventListener('click', () => {
        ColorPickerSelectedBodyPart = 1
        ColorPickerOverlay.style.display = 'block'
    })
    LeftArmColor.addEventListener('click', async () => {
        await new Promise(r => setTimeout(r, 100)); // This fixes an issue where the torso and left arm would be selected at the same time
        ColorPickerSelectedBodyPart = 2
        ColorPickerOverlay.style.display = 'block'
    })
    RightArmColor.addEventListener('click', async () => {
        await new Promise(r => setTimeout(r, 100));
        ColorPickerSelectedBodyPart = 3
        ColorPickerOverlay.style.display = 'block'
    })
    LeftLegColor.addEventListener('click', () => {
        ColorPickerSelectedBodyPart = 4
        ColorPickerOverlay.style.display = 'block'
    })
    RightLegColor.addEventListener('click', () => {
        ColorPickerSelectedBodyPart = 5
        ColorPickerOverlay.style.display = 'block'
    })

    const ColorPickerOverlay = document.getElementById('color-picker-overlay')
    const ColorPickerContent = document.getElementById('color-picker-content')
    const ColorPickerClose = document.getElementById('color-picker-close')

    ColorPickerClose.addEventListener('click', () => {
        ColorPickerOverlay.style.display = 'none'
    })
    // We need to add each BrickColor to the color picker content
    for (let i = 0; i < AvatarRules.bodyColorsPalette.length; i++) {
        const ColorPickerItem = document.createElement('p')
        ColorPickerItem.classList.add('color-picker-item')
        ColorPickerItem.setAttribute("title", AvatarRules.bodyColorsPalette[i].name)
        ColorPickerItem.setAttribute("data-brickcolorid", AvatarRules.bodyColorsPalette[i].brickColorId)
        ColorPickerItem.style.backgroundColor = AvatarRules.bodyColorsPalette[i].hexColor
        ColorPickerContent.appendChild(ColorPickerItem)
    }
    const ColorPickerItems = document.getElementsByClassName('color-picker-item')
    for (let i = 0; i < ColorPickerItems.length; i++) {
        ColorPickerItems[i].addEventListener('click', async () => {
            if (ColorPickerSelectedBodyPart > -1) {
                var SelectedBrickColor = ColorPickerItems[i].getAttribute('data-brickcolorid')
                if (ColorPickerSelectedBodyPart == 0) {
                    HeadColor.style.backgroundColor = await ConvertBodyColortoHex(Number(SelectedBrickColor))
                    UserBodyColors.Head = Number(SelectedBrickColor)
                } else if (ColorPickerSelectedBodyPart == 1) {
                    TorsoColor.style.backgroundColor = await ConvertBodyColortoHex(Number(SelectedBrickColor))
                    UserBodyColors.Torso = Number(SelectedBrickColor)
                } else if (ColorPickerSelectedBodyPart == 2) {
                    LeftArmColor.style.backgroundColor = await ConvertBodyColortoHex(Number(SelectedBrickColor))
                    UserBodyColors.LeftArm = Number(SelectedBrickColor)
                } else if (ColorPickerSelectedBodyPart == 3) {
                    RightArmColor.style.backgroundColor = await ConvertBodyColortoHex(Number(SelectedBrickColor))
                    UserBodyColors.RightArm = Number(SelectedBrickColor)
                } else if (ColorPickerSelectedBodyPart == 4) {
                    LeftLegColor.style.backgroundColor = await ConvertBodyColortoHex(Number(SelectedBrickColor))
                    UserBodyColors.LeftLeg = Number(SelectedBrickColor)
                } else if (ColorPickerSelectedBodyPart == 5) {
                    RightLegColor.style.backgroundColor = await ConvertBodyColortoHex(Number(SelectedBrickColor))
                    UserBodyColors.RightLeg = Number(SelectedBrickColor)
                }
            }
            SaveChangesButton.style.display = 'block'
            ColorPickerSelectedBodyPart = -1
            ColorPickerOverlay.style.display = 'none'
        })
    }

    PaginationNextBtn.addEventListener('click', () => {
        if (PaginationNextBtn.disabled){
            return
        }
        PaginationPreviousBtn.disabled = true
        PaginationNextBtn.disabled = true
        if (!IsThisTheLastPage) {
            PageNumber += 1
            LoadPageForAsset(SelectedAssetType)
        }
        PaginationText.innerText = `Page ${PageNumber+1}`
    })
    PaginationPreviousBtn.addEventListener('click', () => {
        if (PaginationPreviousBtn.disabled){
            return
        }
        PaginationPreviousBtn.disabled = true
        PaginationNextBtn.disabled = true
        if (PageNumber > 0) {
            PageNumber -= 1
            LoadPageForAsset(SelectedAssetType)
        }
        PaginationText.innerText = `Page ${PageNumber+1}`
    })
    var SelectAssetTypeElement = document.getElementById('select-asset-type')
    SelectAssetTypeElement.addEventListener('change', () => {
        // The option element has a data-assettype attribute which we can use to get the asset type
        SelectedAssetType = Number(SelectAssetTypeElement.options[SelectAssetTypeElement.selectedIndex].getAttribute('data-type'))
        PageNumber = 0
        PaginationPreviousBtn.disabled = true
        PaginationNextBtn.disabled = true
        PaginationText.innerText = `Page ${PageNumber+1}`
        LoadPageForAsset(SelectedAssetType)
    })

    const changeRigTypeBtn = document.getElementById('change-rigtype-btn')
    if ( UserAvatar.rigType == "R6" ) {
        changeRigTypeBtn.innerText = "R15"
    } else {
        changeRigTypeBtn.innerText = "R6"
    }
    rigType = UserAvatar.rigType
    changeRigTypeBtn.addEventListener('click', async () => {
        changeRigTypeBtn.innerText = rigType
        if ( rigType == "R6" ) {
            rigType = "R15"
        } else {
            rigType = "R6"
        }
        SaveChangesButton.style.display = 'block'
    })

    async function HandleScaleSlider( scaleName ) {
        UserAvatarScaling[scaleName] = UserAvatar.scales[scaleName]
        const sliderParent = document.getElementById(`${scaleName}-scale-group`)

        const SliderInput = sliderParent.getElementsByClassName("scaling-slider")[0]
        const SliderValueText = sliderParent.getElementsByClassName("scaling-value")[0]
        const ScaleRules = AvatarRules.scales[scaleName]

        SliderInput.min = ScaleRules.min * 100
        SliderInput.max = ScaleRules.max * 100
        SliderInput.step = ScaleRules.step * 100
        SliderInput.value = UserAvatar.scales[scaleName] * 100

        SliderValueText.innerText = `${UserAvatar.scales[scaleName] * 100}%`

        SliderInput.addEventListener('input', () => {
            SliderValueText.innerText = `${SliderInput.value}%`
            SaveChangesButton.style.display = 'block'
            UserAvatarScaling[scaleName] = SliderInput.value / 100
        })
    }

    await HandleScaleSlider( "height" )
    await HandleScaleSlider( "width" )
    await HandleScaleSlider( "head" )
    await HandleScaleSlider( "proportion" )

    LoadPageForAsset(11) // Default: Shirt
})