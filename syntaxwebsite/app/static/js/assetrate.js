async function initVoteContainer( containerElement ) {
    const assetId = containerElement.getAttribute('data-assetid')
    const XCSRFToken = document.getElementById('X-CSRF-TOKEN').getAttribute('data-xcsrf')
    if ( XCSRFToken == null ) {
        console.log('XCSRFToken is null, cannot continue')
        return
    }
    var AssetLikesCount = Number(containerElement.getAttribute("data-likes"))
    var AssetDislikesCount = Number(containerElement.getAttribute("data-dislikes"))
    var UserVoteStatus = containerElement.getAttribute("data-uservote-status") // 2 = Dislike, 0 = No vote, 1 = Like

    const LikeButton = containerElement.getElementsByClassName('icon-like')[0]
    const DislikeButton = containerElement.getElementsByClassName('icon-dislike')[0]
    const VotePercentageElement = containerElement.getElementsByClassName('votepercentage')[0]
    const LikesElementText = containerElement.getElementsByClassName('vote-up-text')[0]
    const DislikesElementText = containerElement.getElementsByClassName('vote-down-text')[0]

    const VoteFeedbackText = containerElement.getElementsByClassName('vote-feedback-text')[0]

    const UpdateVoteCount = async () => {
        LikesElementText.textContent = AssetLikesCount
        LikesElementText.setAttribute("title", AssetLikesCount)
        DislikesElementText.textContent = AssetDislikesCount
        DislikesElementText.setAttribute("title", AssetDislikesCount)

        const TotalVotes = AssetLikesCount + AssetDislikesCount
        var LikePercentage = Math.round((AssetLikesCount / TotalVotes) * 100)
        if ( TotalVotes == 0 ) {
            LikePercentage = 50
        } else if ( TotalVotes == 1 ) { // AssetLikesCount / TotalVotes may be Infinity
            LikePercentage = AssetLikesCount == 1 ? 100 : 0
        }
        VotePercentageElement.style.width = `${LikePercentage}%`
    }
    const UpdateVoteButtons = async () => {
        // Check if the "selected" className is present, if so, remove it if it's not the correct one
        if ( LikeButton.classList.contains('selected') ) {
            if ( UserVoteStatus != 1 ) {
                LikeButton.classList.remove('selected')
            }
        } else if ( UserVoteStatus == 1 ) {
            LikeButton.classList.add('selected')
        }
        if ( DislikeButton.classList.contains('selected') ) {
            if ( UserVoteStatus != 2 ) {
                DislikeButton.classList.remove('selected')
            }
        } else if ( UserVoteStatus == 2 ) {
            DislikeButton.classList.add('selected')
        }
    }
    const UpdateUserVoteStatus = async ( newVoteStatus ) => {
        var OriginalVoteStatus = UserVoteStatus;
        var OriginalLikesCount = AssetLikesCount;
        var OriginalDislikesCount = AssetDislikesCount;
        let ServerVoteResponse;
        if ( newVoteStatus == UserVoteStatus ) {
            return;
        }
        UserVoteStatus = newVoteStatus
        if ( newVoteStatus == 1 ) {
            AssetLikesCount++
            if ( OriginalVoteStatus == 2 ) {
                AssetDislikesCount--
            }
        }
        if ( newVoteStatus == 2 ) {
            AssetDislikesCount++
            if ( OriginalVoteStatus == 1 ) {
                AssetLikesCount--
            }
        }
        if ( newVoteStatus == 0 ) {
            if ( OriginalVoteStatus == 1 ) {
                AssetLikesCount--
            }
            if ( OriginalVoteStatus == 2 ) {
                AssetDislikesCount--
            }
        }
        await UpdateVoteButtons()
        await UpdateVoteCount()

        try {
            ServerVoteResponse = await fetch(`/vote/${assetId}/${newVoteStatus}`,{
                method: 'POST',
                headers: {
                    'X-CSRF-TOKEN': XCSRFToken
                }
            })
        } catch (error) {
            console.log(`Error occured while trying to update user vote: ${error}`)
            return
        }
        if ( ServerVoteResponse.status != 200 ) {
            console.log(`Server responded with status code ${ServerVoteResponse.status} while trying to update user vote`)
            UserVoteStatus = OriginalVoteStatus
            AssetLikesCount = OriginalLikesCount
            AssetDislikesCount = OriginalDislikesCount
            VoteFeedbackText.textContent = `Error while trying to update vote, Status: ${ServerVoteResponse.status}`
            VoteFeedbackText.style.display = 'block'
            await UpdateVoteButtons()
            await UpdateVoteCount()
            return
        }
        return;
    }
    await UpdateVoteCount()
    await UpdateVoteButtons()

    LikeButton.addEventListener('click', async () => {
        // Check if its already selected, if so, remove the vote
        if ( LikeButton.classList.contains('selected') ) {
            await UpdateUserVoteStatus(0)
            return
        }
        await UpdateUserVoteStatus(1)
    })
    DislikeButton.addEventListener('click', async () => {
        // Check if its already selected, if so, remove the vote
        if ( DislikeButton.classList.contains('selected') ) {
            await UpdateUserVoteStatus(0)
            return
        }
        await UpdateUserVoteStatus(2)
    })
}

async function initFavoriteContainer( containerElement ) {
    const assetId = containerElement.getAttribute('data-assetid')
    const XCSRFToken = document.getElementById('X-CSRF-TOKEN').getAttribute('data-xcsrf')
    if ( XCSRFToken == null ) {
        console.log('XCSRFToken is null, cannot continue')
        return
    }
    var FavoriteCount = Number(containerElement.getAttribute("data-favorite-count"))
    var UserFavoriteStatus = containerElement.getAttribute("data-userfavorite-status") == "True" ? true : false
    const FavoriteButton = containerElement.getElementsByClassName('icon-favorite')[0]
    const FavoriteButtonText = containerElement.getElementsByClassName('text-favorite')[0]

    const UpdateFavoriteCount = async () => {
        FavoriteButtonText.textContent = FavoriteCount
        FavoriteButtonText.setAttribute("title", FavoriteCount)
    }
    const UpdateFavoriteButton = async () => {
        if ( UserFavoriteStatus ) {
            FavoriteButton.classList.add('favorited')
        } else {
            FavoriteButton.classList.remove('favorited')
        }
    }
    const UpdateUserFavoriteStatus = async ( newFavoriteStatus ) => {
        var OriginalFavoriteStatus = UserFavoriteStatus;
        var OriginalFavoriteCount = FavoriteCount;
        let ServerFavoriteResponse;
        if ( newFavoriteStatus == UserFavoriteStatus ) {
            return;
        }
        UserFavoriteStatus = newFavoriteStatus
        if ( newFavoriteStatus ) {
            FavoriteCount++
        } else {
            FavoriteCount--
        }
        await UpdateFavoriteButton()
        await UpdateFavoriteCount()

        try {
            if ( newFavoriteStatus ) {
                ServerFavoriteResponse = await fetch(`/favorite/${assetId}`,{
                    method: 'POST',
                    headers: {
                        'X-CSRF-TOKEN': XCSRFToken
                    }
                })
            } else {
                ServerFavoriteResponse = await fetch(`/favorite/${assetId}`,{
                    method: 'DELETE',
                    headers: {
                        'X-CSRF-TOKEN': XCSRFToken
                    }
                })
            }
        } catch (error) {
            console.log(`Error occured while trying to update user favorite: ${error}`)
            return
        }
        if ( ServerFavoriteResponse.status != 200 ) {
            console.log(`Server responded with status code ${ServerFavoriteResponse.status} while trying to update user favorite`)
            UserFavoriteStatus = OriginalFavoriteStatus
            FavoriteCount = OriginalFavoriteCount
            await UpdateFavoriteButton()
            await UpdateFavoriteCount()
            return
        }
        return;
    }

    await UpdateFavoriteButton()
    await UpdateFavoriteCount()

    FavoriteButton.addEventListener('click', async () => {
        await UpdateUserFavoriteStatus(!UserFavoriteStatus)
    })
}

document.addEventListener('DOMContentLoaded', async () => {
    const assetRateContainers = document.getElementsByClassName('usersVote')
    for(let i = 0; i < assetRateContainers.length; i++){
        await initVoteContainer( assetRateContainers[i] )
    }
    const assetFavoriteContainers = document.getElementsByClassName('favorite-button-container')
    for(let i = 0; i < assetFavoriteContainers.length; i++){
        await initFavoriteContainer( assetFavoriteContainers[i] )
    }
})