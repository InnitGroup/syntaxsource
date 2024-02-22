PermissionsDefinition = {
    'GameServerManager' : {
        'Name' : 'Server Manager',
        'Description' : 'View gameserver information and manage them',
        'route': '/admin/gameservers',
        'icon': 'bi-database'
    },
    'UpdateWebsiteMessage' : {
        'Name' : 'Website Message',
        'Description' : 'Update website wide message',
        'route': '/admin/websitemessage',
        'icon': 'bi-chat-square-text'
    },
    'ManageFFlags' : {
        'Name' : 'Feature Flags',
        'Description' : 'Manage feature flags for RCC and Clients',
        'route': '/admin/fflags',
        'icon': 'bi-flag'
    },
    'CopyAssets' : {
        'Name' : 'Asset Copier',
        'Description' : 'Copy assets from the Roblox Catalog',
        'route': '/admin/asset-copier',
        'icon': 'bi-files'
    },
    'ManageAsset' : {
        'Name' : 'Manage Asset',
        'Description' : 'Manage assets under the ROBLOX account',
        'route': '/admin/manage-assets',
        'icon': 'bi-file-earmark'
    },
    'CreateAsset' : {
        'Name' : 'Create Asset',
        'Description' : 'Create assets under the ROBLOX account',
        'route': '/admin/create-asset',
        'icon': 'bi-file-earmark-plus'
    },
    'AssetModeration' : {
        'Name' : 'Pending Assets',
        'Description' : 'View and moderate pending assets',
        'route': '/admin/pending-assets',
        'icon': 'bi-hourglass-split'
    },
    'ManageUsers' : {
        'Name' : 'Manage Users',
        'Description' : 'Manage users and their permissions',
        'route': '/admin/manage-users',
        'icon': 'bi-people'
    },
    'ManageWebsiteFeatures' : {
        'Name' : 'Website Features',
        'Description' : 'Toggle certain features on the website',
        'route': '/admin/manage-website-features',
        'icon': 'bi-gear'
    },
    'CreateUser' : {
        'Name' : 'Create User',
        'Description' : 'Create a user on the website',
        'route': '/admin/create-user',
        'icon': 'bi-person-plus'
    },
    'CreateGiftcard' : {
        'Name' : 'Create Giftcard',
        'Description' : 'Create a giftcard on the website',
        'route': '/admin/create-giftcard',
        'icon': 'bi-gift'
    },
    'UpdateAssetFile' : {
        'Name' : 'Update RBXM',
        'Description' : 'Update the RBXM file of an asset',
        'route': '/admin/update-asset-file',
        'icon': 'bi-file-earmark-arrow-up'
    },
    'CopyBundle' : {
        'Name' : 'Copy Bundle',
        'Description' : 'Copy a bundle from the Roblox Catalog',
        'route': '/admin/copy-bundle',
        'icon': 'bi-collection'
    },
    'ModerateAsset' : {
        'Name' : 'Moderate Asset',
        'Description' : 'Change the status of a user generated asset',
        'route': '/admin/moderate-asset',
        'icon': 'bi-file-earmark-check'
    },
    'Lottery' : {
        'Name' : 'Lottery',
        'Description' : 'Give away limiteds under inactive accounts',
        'route': '/admin/lottery',
        'icon': 'bi-cash-stack'
    },
    'ManageItemReleases' : {
        'Name' : 'Item Release Pool',
        'Description' : 'Manage items in the item release pool',
        'route': '/admin/item-release-pool',
        'icon': 'bi-shuffle'
    },

    'BanUser' : {
        'Name' : 'Ban User',
        'Description' : 'Ban a user from the website',
        'Hidden' : True
    },
    'ViewUserLoginHistory' : {
        'Name' : 'View User Login History',
        'Description' : 'View the login history of a user',
        'Hidden' : True
    },
    'ViewLoginHistoryDetailed' : {
        'Name' : 'View Sensitive Login History',
        'Description' : 'Extra permission to viewing sensitive info in login history like hashed IPs and Session Tokens',
        'Hidden' : True
    },
    'ModifyLimitedAssets' : {
        'Name' : 'Modify Limited Assets',
        'Description' : 'Modify limited assets',
        'Hidden' : True
    },
    'ViewItemReleasePoolDrop' : {
        'Name' : 'View Item Release Pool Drop Time',
        'Description' : 'Able to see the next item release drop',
        'Hidden' : True
    },
    "ManageAdminPermissions" : {
        'Name' : 'Manage Admin Permissions',
        'Description' : 'Manage admin permissions',
        'Hidden' : True
    }
}