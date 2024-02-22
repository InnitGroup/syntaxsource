async function initalizeComponent( memberElement ) {
    const GroupId = Number(memberElement.getAttribute('data-groupid'))
    const RoleSelectElement = memberElement.getElementsByClassName('members-select-role')[0]

    const PaginationBackBtn = memberElement.getElementsByClassName('pagination-back-btn')[0]
    const PaginationTextElement = memberElement.getElementsByClassName('pagination-page-number')[0]
    const PaginationNextBtn = memberElement.getElementsByClassName('pagination-next-btn')[0]

    const UserCardTemplate = document.getElementsByClassName('user-card-template')[0]
    const UserCardContainer = memberElement.getElementsByClassName('user-card-container')[0]

    var SelectedRoleId = 0
    var CurrentPage = 1

    if (RoleSelectElement.options.length > 0) {
        SelectedRoleId = RoleSelectElement.options[0].value
    } else {
        console.error('No role found in RoleSelectElement')
        return;
    }

    async function getPageResult( RolesetId, PageNumber ) {
        try {
            const response = await fetch(`/groups/members_json/${GroupId}?role=${RolesetId}&page=${PageNumber}`)
            const result = await response.json()
            return result
        } catch (error) {
            if (error.status == 429) {
                await new Promise(r => setTimeout(r, 5000));
                return await getPageResult( RolesetId, PageNumber )
            } else {
                console.error(error)
                alert('An error occured while trying to get the page result, please try again later. Status: ' + error.status)
                return null
            }
        }
    }

    async function CreateUserCard( UserId, Username ) {
        const UserCard = UserCardTemplate.cloneNode(true)
        const UserCardUsername = UserCard.getElementsByClassName('user-name')[0]
        const UserCardAvatar = UserCard.getElementsByClassName('avatar-img')[0]

        UserCardUsername.innerText = Username
        UserCardAvatar.src = `/Thumbs/Avatar.ashx?userId=${UserId}&x=100&y=100`

        UserCard.style.display = 'block'
        UserCard.classList.remove('user-card-template')
        UserCard.href = `/users/${UserId}/profile`
        UserCardContainer.appendChild(UserCard)
    }

    async function updatePage( RolesetId, PageNumber ) {
        PaginationNextBtn.disabled = true
        PaginationBackBtn.disabled = true
        UserCardContainer.innerHTML = ''

        const result = await getPageResult( RolesetId, PageNumber )
        const Users = result.users

        PaginationTextElement.innerText = `Page ${PageNumber}`
        if (PageNumber == 1) {
            PaginationBackBtn.disabled = true
        } else {
            PaginationBackBtn.disabled = false
        }

        if (result.nextpage) {
            PaginationNextBtn.disabled = false
        } else {
            PaginationNextBtn.disabled = true
        }
        for (let i = 0; i < Users.length; i++) {
            const User = Users[i]
            await CreateUserCard( User.userId, User.username )
        }
        if ( Users.length == 0 ) {
            const NoUsersElement = document.createElement('p')
            NoUsersElement.innerText = 'No users found'
            NoUsersElement.className = 'w-100 text-center mt-auto mb-auto'
            UserCardContainer.appendChild(NoUsersElement)
        }
    }

    RoleSelectElement.addEventListener('change', async () => {
        SelectedRoleId = RoleSelectElement.value
        CurrentPage = 1
        await updatePage( SelectedRoleId, 1 )
    })

    PaginationBackBtn.addEventListener('click', async () => {
        CurrentPage--
        await updatePage( SelectedRoleId, CurrentPage )
    })

    PaginationNextBtn.addEventListener('click', async () => {
        CurrentPage++
        await updatePage( SelectedRoleId, CurrentPage )
    })

    await updatePage( SelectedRoleId, CurrentPage )
}

document.addEventListener('DOMContentLoaded', async () => {
    const MemberElements = document.getElementsByClassName('group-member-list')
    for (let i = 0; i < MemberElements.length; i++) {
        const MemberElement = MemberElements[i]
        await initalizeComponent( MemberElement )
    }
})