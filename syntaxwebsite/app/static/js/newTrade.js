document.addEventListener('DOMContentLoaded', async () => {
    const TradeInfoElement = document.getElementById('trade-info')
    if ( TradeInfoElement == null ) return

    const RequesterUserId = Number(TradeInfoElement.getAttribute('data-requester-userid'))
    const TargetUserId = Number(TradeInfoElement.getAttribute('data-target-userid'))
    const XCSRFToken = TradeInfoElement.getAttribute('data-xcsrf-token')
    const isTOTPEnabled = TradeInfoElement.getAttribute('data-totp-enabled') == 'True'

    const RequesterInventoryElement = document.getElementById('requester-inventory-container')
    const TargetInventoryElement = document.getElementById('target-inventory-container')

    const ItemCardTemplate = document.getElementById('item-card-template')
    ItemCardTemplate.id = ''

    var UAIDInfo = {}
    var RequesterOffer = []
    var TargetOffer = []

    const RequesterItemOfferContainer = document.getElementById('requester-item-offer-container')
    const TargetItemOfferContainer = document.getElementById('target-item-offer-container')

    const TargetOfferValueText = document.getElementById('target-offer-value')
    const RequesterOfferValueText = document.getElementById('requester-offer-value')
    const TargetOfferRobuxInput = document.getElementById('target-offer-robux-input')
    const RequesterOfferRobuxInput = document.getElementById('requester-offer-robux-input')

    const TradeSumbitButton = document.getElementById('trade-submit-btn')
    const TOTPInputElement = document.getElementById('otp-code-input')

    if ( isTOTPEnabled ) {
        TOTPInputElement.addEventListener('input', async () => {
            if ( TOTPInputElement.value.length > 6 ) {
                TOTPInputElement.value = TOTPInputElement.value.slice(0, 6)
            }
            await formValidation()
        })
        TOTPInputElement.style.display = 'block'
    }
    const TransparentBackgroundTop = document.getElementById('transparent-background-top')
    const SubmitButtonFeedback = document.getElementById('submit-btn-feedback')

    var isAlreadySubmitting = false
    const submitTradeRequest = async () => {
        if (TradeSumbitButton.disabled) return
        if ( isAlreadySubmitting ) return
        isAlreadySubmitting = true
        TradeSumbitButton.disabled = true
        TransparentBackgroundTop.style.display = 'block'
        SubmitButtonFeedback.style.display = 'none'

        const RequesterOfferRobux = Number(RequesterOfferRobuxInput.value) || 0
        const TargetOfferRobux = Number(TargetOfferRobuxInput.value) || 0
        const RequesterOfferUAIDs = RequesterOffer
        const TargetOfferUAIDs = TargetOffer

        const TradeRequestResponse = await fetch(`/trade/${TargetUserId}/create`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-TOKEN': XCSRFToken
            },
            body: JSON.stringify({
                "RequesterOfferRobux": RequesterOfferRobux,
                "TargetOfferRobux": TargetOfferRobux,
                "RequesterOfferUAIDs": RequesterOfferUAIDs,
                "TargetOfferUAIDs": TargetOfferUAIDs,
                "TOTPCode": isTOTPEnabled ? Number(TOTPInputElement.value) : null
            })
        })
        let TradeRequestResponseJSON
        try {
            TradeRequestResponseJSON = await TradeRequestResponse.json()
        } catch (e) {
            SubmitButtonFeedback.textContent = `${TradeRequestResponse.status}: An error occurred while submitting the trade request.`
            SubmitButtonFeedback.style.display = 'block'
            TradeSumbitButton.disabled = false
            TransparentBackgroundTop.style.display = 'none'
            isAlreadySubmitting = false
            return
        }
        if ( TradeRequestResponse.status != 200 ) {
            SubmitButtonFeedback.textContent = `${TradeRequestResponse.status}: ${TradeRequestResponseJSON.message}`
            SubmitButtonFeedback.style.display = 'block'
            TradeSumbitButton.disabled = false
            TransparentBackgroundTop.style.display = 'none'
            isAlreadySubmitting = false
            return
        }
        window.location.href = `/trade/view/${TradeRequestResponseJSON.tradeId}`
    }

    const formValidation = async () => {
        if ( RequesterOffer.length == 0 || TargetOffer.length == 0 ) {
            TradeSumbitButton.disabled = true
            return
        }
        if ( RequesterOffer.length > 4 || TargetOffer.length > 4 ) {
            TradeSumbitButton.disabled = true
            return
        }
        if ( isTOTPEnabled && TOTPInputElement.value.length != 6 ) {
            TradeSumbitButton.disabled = true
            return
        }
        TradeSumbitButton.disabled = false
    }

    const UpdateOfferValue = async () => {
        var RequesterOfferValue = 0
        var TargetOfferValue = 0

        RequesterOffer.forEach(ItemUAID => {
            RequesterOfferValue += UAIDInfo[ItemUAID].rap
        })
        TargetOffer.forEach(ItemUAID => {
            TargetOfferValue += UAIDInfo[ItemUAID].rap
        })

        RequesterOfferValue += Number(RequesterOfferRobuxInput.value)
        TargetOfferValue += Number(TargetOfferRobuxInput.value)

        TargetOfferValueText.textContent = `R$ ${TargetOfferValue}`
        RequesterOfferValueText.textContent = `R$ ${RequesterOfferValue}`
        await formValidation()
    }

    TargetOfferRobuxInput.addEventListener('input', async () => {
        if ( Number(TargetOfferRobuxInput.value) < 0 ) {
            TargetOfferRobuxInput.value = 0
        }
        if ( Number(TargetOfferRobuxInput.value) > 100000 ) {
            TargetOfferRobuxInput.value = 100000
        }
        await UpdateOfferValue()
    })
    RequesterOfferRobuxInput.addEventListener('input', async () => {
        if ( Number(RequesterOfferRobuxInput.value) < 0 ) {
            RequesterOfferRobuxInput.value = 0
        }
        if ( Number(RequesterOfferRobuxInput.value) > 100000 ) {
            RequesterOfferRobuxInput.value = 100000
        }
        await UpdateOfferValue()
    })

    const ReloadOfferImages = async () => {
        const RequesterOfferChildren = RequesterItemOfferContainer.children
        for ( let i = 0; i < RequesterOfferChildren.length; i++ ){
            const ItemCard = RequesterOfferChildren[i]
            const ItemCardImage = ItemCard.querySelector('.item-image')
            if (RequesterOffer[i] == null) {
                ItemCardImage.src = ''
                ItemCardImage.alt = ''
                ItemCardImage.style.display = 'none'
                ItemCard.style.cursor = 'default'
                ItemCardImage.onclick = null
                continue
            } else {
                if (ItemCardImage.classList.contains('d-none')) {
                    ItemCardImage.classList.remove('d-none')
                }
                ItemCard.style.cursor = 'pointer'
                ItemCardImage.style.display = 'block'
                ItemCardImage.src = `/Thumbs/Asset.ashx?x=100&y=100&assetId=${UAIDInfo[RequesterOffer[i]].assetId}`
                ItemCardImage.onclick = async () => {
                    await RemoveItemFromOffer(RequesterUserId, RequesterOffer[i])
                }
            }
        }

        const TargetOfferChildren = TargetItemOfferContainer.children
        for ( let i = 0; i < TargetOfferChildren.length; i++ ){
            const ItemCard = TargetOfferChildren[i]
            const ItemCardImage = ItemCard.querySelector('.item-image')
            if (TargetOffer[i] == null) {
                ItemCardImage.src = ''
                ItemCardImage.alt = ''
                ItemCardImage.style.display = 'none'
                ItemCard.style.cursor = 'default'
                ItemCardImage.onclick = null
                continue
            } else {
                if (ItemCardImage.classList.contains('d-none')) {
                    ItemCardImage.classList.remove('d-none')
                }
                ItemCard.style.cursor = 'pointer'
                ItemCardImage.style.display = 'block'
                ItemCardImage.src = `/Thumbs/Asset.ashx?x=100&y=100&assetId=${UAIDInfo[TargetOffer[i]].assetId}`
                ItemCardImage.onclick = async () => {
                    await RemoveItemFromOffer(TargetUserId, TargetOffer[i])
                }
            }
        }
        await UpdateOfferValue()
    }

    const AddItemToOffer = async ( UserId, ItemUAID ) => {
        if ( UserId == RequesterUserId ) {
            if ( RequesterOffer.includes(ItemUAID) ) return
            if ( RequesterOffer.length >= 4 ) {
                const RemovedItemUAID = RequesterOffer[0]
                await RemoveItemFromOffer(RequesterUserId, RemovedItemUAID)
            }
            RequesterOffer.push(ItemUAID)
        }
        if ( UserId == TargetUserId ) {
            if ( TargetOffer.includes(ItemUAID) ) return
            if ( TargetOffer.length >= 4 ) {
                const RemovedItemUAID = TargetOffer[0]
                await RemoveItemFromOffer(TargetUserId, RemovedItemUAID)
            }
            TargetOffer.push(ItemUAID)
        }
        const AllItemCards = document.querySelectorAll('.item-card')
        AllItemCards.forEach(ItemCard => {
            const ItemCardUAID = ItemCard.getAttribute('data-item-uaid')
            if ( ItemCardUAID == ItemUAID ) {
                const ItemCardImage = ItemCard.querySelector('.item-card-image')
                ItemCardImage.classList.add("border-primary")
            }
        })
        await ReloadOfferImages()
    }

    const RemoveItemFromOffer = async ( UserId, ItemUAID ) => {
        if ( UserId == RequesterUserId ) {
            if ( !RequesterOffer.includes(ItemUAID) ) return
            RequesterOffer.splice(RequesterOffer.indexOf(ItemUAID), 1)
        }
        if ( UserId == TargetUserId ) {
            if ( !TargetOffer.includes(ItemUAID) ) return
            TargetOffer.splice(TargetOffer.indexOf(ItemUAID), 1)
        }
        const AllItemCards = document.querySelectorAll('.item-card')
        AllItemCards.forEach(ItemCard => {
            const ItemCardUAID = ItemCard.getAttribute('data-item-uaid')
            if ( ItemCardUAID == ItemUAID ) {
                const ItemCardImage = ItemCard.querySelector('.item-card-image')
                if ( ItemCardImage.classList.contains("border-primary") ){
                    ItemCardImage.classList.remove("border-primary")
                }
            }
        })
        await ReloadOfferImages()
    }

    const LoadInventoryPage = async ( UserId, InventoryElement, PageNumber ) => {
        InventoryElement.innerHTML = ''
        const ParentElement = InventoryElement.parentElement
        const PaginationBackBtn = ParentElement.querySelector('.pagination-back-btn')
        const PaginationNextBtn = ParentElement.querySelector('.pagination-next-btn')
        const PaginationPageNumber = ParentElement.querySelector('.pagination-page-number')

        PaginationBackBtn.disabled = true
        PaginationNextBtn.disabled = true
        PaginationPageNumber.textContent = `Page ${PageNumber}`

        const InventoryResposne = await fetch(`/trade/${UserId}/inventory?page=${PageNumber}`)
        if ( !InventoryResposne.ok ) return
        const InventoryData = await InventoryResposne.json()

        InventoryData.data.forEach(Item => {
            const NewItemCard = ItemCardTemplate.cloneNode(true)
            NewItemCard.setAttribute('data-item-assetid', Item.id)
            NewItemCard.setAttribute('data-item-name', Item.name)
            NewItemCard.setAttribute('data-item-uaid', Item.uaid)
            NewItemCard.setAttribute('data-item-serial', Item.serialNumber)
            NewItemCard.setAttribute('data-item-rap', Item.rap)
            NewItemCard.classList.add('item-card')

            const ItemCardImage = NewItemCard.querySelector('.item-card-image')
            ItemCardImage.src = `/Thumbs/Asset.ashx?x=100&y=100&assetId=${Item.id}`
            ItemCardImage.alt = Item.name

            const ItemCardName = NewItemCard.querySelector('.item-card-name')
            ItemCardName.textContent = Item.name
            ItemCardName.href = `/catalog/${Item.id}/`

            const ItemCardSerial = NewItemCard.querySelector('.item-card-serial')
            if (Item.serialNumber != null) {
                ItemCardSerial.textContent = `#${Item.serialNumber}`
            } else {
                ItemCardSerial.remove()
            }
            NewItemCard.style.display = 'block'
            InventoryElement.appendChild(NewItemCard)

            UAIDInfo[Item.uaid] = {
                'assetId': Item.id,
                'serialNumber': Item.serialNumber,
                'rap': Item.rap,
                'name': Item.name,
                'ownerId': UserId,
            }
            if ( UserId == RequesterUserId ) {
                if ( RequesterOffer.includes(Item.uaid) ) {
                    ItemCardImage.classList.add("border-primary")
                }
            }
            if ( UserId == TargetUserId ) {
                if ( TargetOffer.includes(Item.uaid) ) {
                    ItemCardImage.classList.add("border-primary")
                }
            }
            ItemCardImage.style.cursor = 'pointer'
            ItemCardImage.addEventListener('click', () => {
                if ( ItemCardImage.classList.contains("border-primary") ){
                    RemoveItemFromOffer(UserId, Item.uaid)
                    return
                }
                AddItemToOffer(UserId, Item.uaid)
            })
        })
        if ( InventoryData.data.length == 0 ){
            const NoItemsMessage = document.createElement('p')
            NoItemsMessage.className = "text-secondary text-center mt-5 mb-5 w-100"
            NoItemsMessage.textContent = "User does not have any tradable items"
            InventoryElement.appendChild(NoItemsMessage)
        }

        PaginationBackBtn.disabled = PageNumber <= 1
        PaginationNextBtn.disabled = !InventoryData.nextPage
    }

    await LoadInventoryPage(RequesterUserId, RequesterInventoryElement, 1)
    await LoadInventoryPage(TargetUserId, TargetInventoryElement, 1)

    var RequesterPageNumber = 1
    const RequesterPaginationBackBtn = RequesterInventoryElement.parentElement.querySelector('.pagination-back-btn')
    const RequesterPaginationNextBtn = RequesterInventoryElement.parentElement.querySelector('.pagination-next-btn')

    var TargetPageNumber = 1
    const TargetPaginationBackBtn = TargetInventoryElement.parentElement.querySelector('.pagination-back-btn')
    const TargetPaginationNextBtn = TargetInventoryElement.parentElement.querySelector('.pagination-next-btn')

    RequesterPaginationBackBtn.addEventListener('click', () => {
        if ( RequesterPaginationBackBtn.disabled ) return
        if ( RequesterPageNumber <= 1 ) { RequesterPaginationBackBtn.disabled = true; return }
        RequesterPageNumber--
        LoadInventoryPage(RequesterUserId, RequesterInventoryElement, RequesterPageNumber)
    })

    RequesterPaginationNextBtn.addEventListener('click', () => {
        if ( RequesterPaginationNextBtn.disabled ) return
        RequesterPageNumber++
        LoadInventoryPage(RequesterUserId, RequesterInventoryElement, RequesterPageNumber)
    })

    TargetPaginationBackBtn.addEventListener('click', () => {
        if ( TargetPaginationBackBtn.disabled ) return
        if ( TargetPageNumber <= 1 ) { TargetPaginationBackBtn.disabled = true; return }
        TargetPageNumber--
        LoadInventoryPage(TargetUserId, TargetInventoryElement, TargetPageNumber)
    })

    TargetPaginationNextBtn.addEventListener('click', () => {
        if ( TargetPaginationNextBtn.disabled ) return
        TargetPageNumber++
        LoadInventoryPage(TargetUserId, TargetInventoryElement, TargetPageNumber)
    })

    TradeSumbitButton.addEventListener('click', async () => {
        if ( TradeSumbitButton.disabled ) return
        await submitTradeRequest()
    })

    await formValidation()
})