/* Functions used to buy or take assets */

function buyAsset(assetId, assetName, expectedPrice, currencyType){
    const PurchaseModal = new bootstrap.Modal(document.getElementById('purchaseModal'), { keyboard: false })
    const purchaseModalContent = document.getElementById('purchase-modal-content')
    const purchaseModalTitle = document.getElementById('purchase-modal-title')
    const purchaseModalButton = document.getElementById('purchase-modal-btn')
    const purchaseModalClose = document.getElementById('purchase-modal-close')

    const csrfToken = document.getElementById('csrf_token').getAttribute('data-csrf-token')

    purchaseModalTitle.textContent = `Confirm purchase of ${assetName}`
    purchaseModalContent.textContent = `Are you sure you want to buy ${assetName} for ${expectedPrice == 0 ? 'Free' : expectedPrice}${expectedPrice != 0 ? (currencyType == 0 ? " Robux" : " Tix") : ''}?`

    purchaseModalButton.onclick = () => {
        purchaseModalButton.disabled = true
        purchaseModalClose.disabled = true
        purchaseModalContent.textContent = `Processing purchase...`
        fetch(`/catalog/api/purchase`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-TOKEN': csrfToken
            },
            body: JSON.stringify({
                assetId: Number(assetId),
                expectedPrice: Number(expectedPrice),
                currencyType: Number(currencyType)
            })
        }).then(response => response.json()).then(data => {
            if(data.success){
                window.location.reload()
            }else{
                purchaseModalContent.textContent = `There was an issue processing your purchase, please try again later. Error: ${data.message}`
            }
        }).catch(error => {
            purchaseModalContent.textContent = `There was an issue processing your purchase, please try again later. Error: ${error}`
        })
    }
    purchaseModalButton.disabled = false
    purchaseModalClose.disabled = false
    PurchaseModal.show()
}

async function PurchaseLimitedOffer( assetId, assetName, expectedPrice, expectedOwner, itemOwnershipId ) {
    const PurchaseModal = new bootstrap.Modal(document.getElementById('purchaseModal'), { keyboard: false })
    const purchaseModalContent = document.getElementById('purchase-modal-content')
    const purchaseModalTitle = document.getElementById('purchase-modal-title')
    const purchaseModalButton = document.getElementById('purchase-modal-btn')
    const purchaseModalClose = document.getElementById('purchase-modal-close')

    const csrfToken = document.getElementById('csrf_token').getAttribute('data-csrf-token')

    purchaseModalTitle.textContent = `Confirm purchase of ${assetName}`
    purchaseModalContent.textContent = `Are you sure you want to buy ${assetName} for R$${expectedPrice}?`

    purchaseModalButton.onclick = async () => {
        purchaseModalButton.disabled = true
        purchaseModalClose.disabled = true
        purchaseModalContent.textContent = `Processing purchase...`
        var LimitedPurchaseResponse = await fetch("/catalog/api/purchase-limited", {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-TOKEN': csrfToken
            },
            body: JSON.stringify({
                assetId: Number(assetId),
                expectedPrice: Number(expectedPrice),
                expectedOwner: Number(expectedOwner),
                itemOwnershipId: Number(itemOwnershipId)
            })
        })
        var LimitedPurchaseResponseJson = await LimitedPurchaseResponse.json()
        if(LimitedPurchaseResponseJson.success){
            window.location.reload()
        } else {
            purchaseModalContent.textContent = `There was an issue processing your purchase, please try again later. Error: ${LimitedPurchaseResponseJson.message}`
        }
    }
    purchaseModalButton.disabled = false
    purchaseModalClose.disabled = false
    PurchaseModal.show()
}

function updateOffsaleCountdown( offsaleAt ) {
    var offsaleElement = document.getElementById('offsale-countdown')
    if (!offsaleElement) {
        console.warn("Could not find offsale countdown element")
        return
    }
    var timeLeft = offsaleAt - new Date()
    if (timeLeft <= 0) {
        return
    }
    var hours = Math.floor(timeLeft / 1000 / 60 / 60)
    var minutes = Math.floor(timeLeft / 1000 / 60) % 60
    var seconds = Math.floor(timeLeft / 1000) % 60
    offsaleElement.textContent = `${hours}:${minutes < 10 ? '0' : ''}${minutes}:${seconds < 10 ? '0' : ''}${seconds}`
}

document.addEventListener('DOMContentLoaded', async () => {
    const AssetInfoMetaTag = document.getElementById('asset-info')
    var AssetId = null
    var DoesUserOwnAset = false
    var AssetName = ""
    var isAssetLimited = false
    var isAssetOnsale = true
    var offsaleAt = null
    if(AssetInfoMetaTag){
        AssetId = AssetInfoMetaTag.getAttribute('data-asset-id')
        AssetName = AssetInfoMetaTag.getAttribute('data-asset-name')
        DoesUserOwnAset = AssetInfoMetaTag.getAttribute('data-user-ownasset')
        DoesUserOwnAset = DoesUserOwnAset == "true" ? true : false
        isAssetLimited = AssetInfoMetaTag.getAttribute('data-islimited')
        isAssetLimited = isAssetLimited == "true" ? true : false
        isAssetOnsale = AssetInfoMetaTag.getAttribute('data-asset-onsale')
        isAssetOnsale = isAssetOnsale == "true" ? true : false
        offsaleAt = AssetInfoMetaTag.getAttribute('data-offsale')
        if(offsaleAt != null){
            offsaleAt = new Date(offsaleAt * 1000)
            //offsaleAt = Date.UTC(offsaleAt.getFullYear(), offsaleAt.getMonth(), offsaleAt.getDate(), offsaleAt.getHours(), offsaleAt.getMinutes(), offsaleAt.getSeconds())
            //offsaleAt = new Date(offsaleAt)
        }
    }

    if (offsaleAt != null ){
        updateOffsaleCountdown(offsaleAt)
        setInterval(() => {
            updateOffsaleCountdown(offsaleAt)
        }, 1000)
    }
    const PurchaseButtons = document.getElementsByClassName('purchase-button')
        for(let i = 0; i < PurchaseButtons.length; i++){
            if (!DoesUserOwnAset || (isAssetLimited && !isAssetOnsale)) {
                if (!isAssetLimited || isAssetOnsale) {
                    PurchaseButtons[i].onclick = () => {
                        if ( !AssetInfoMetaTag ) {
                            buyAsset(PurchaseButtons[i].getAttribute('data-asset-id'), PurchaseButtons[i].getAttribute('data-asset-name'), PurchaseButtons[i].getAttribute('data-expected-price'), PurchaseButtons[i].getAttribute('data-currency-type'))
                        } else {
                            buyAsset(AssetId, AssetName, PurchaseButtons[i].getAttribute('data-expected-price'), PurchaseButtons[i].getAttribute('data-currency-type'))
                        }
                    }
                } else {
                    PurchaseButtons[i].onclick = async () => {
                        await PurchaseLimitedOffer(AssetId, AssetName, PurchaseButtons[i].getAttribute('data-expected-price'), PurchaseButtons[i].getAttribute('data-expectedowner'), PurchaseButtons[i].getAttribute('data-expectedid'))
                    }
                }
            } else {
                PurchaseButtons[i].setAttribute("class", PurchaseButtons[i].getAttribute("class").replace("purchase-button", "purchase-button disabled"))
            }
        }
})