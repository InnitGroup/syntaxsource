from app.models.asset import Asset

CatalogTypes = {
    0 : {
        "name": "Featured Items",
        "query": "SELECT * FROM asset WHERE asset_type IN ('TShirt','Hat','Shirt','Pants','Decal','Head','Face','Gear','Package','HairAccessory','FaceAccessory','NeckAccessory','ShoulderAccessory','FrontAccessory','FrontAccessory','BackAccessory','WaistAccessory') AND creator_id = 1 AND creator_type = 0 AND (is_for_sale = true OR is_limited = true)"
    },
    1 : {
        "name": "Featured Hats",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Hat','HairAccessory','FaceAccessory','NeckAccessory','ShoulderAccessory','FrontAccessory','FrontAccessory','BackAccessory','WaistAccessory') AND creator_id = 1 AND creator_type = 0 AND (is_for_sale = true OR is_limited = true)"
    },
    2 : {
        "name": "Featured Gears",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Gear') AND creator_id = 1 AND creator_type = 0 AND (is_for_sale = true OR is_limited = true)"
    },
    3 : {
        "name": "Featured Faces",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Face') AND creator_id = 1 AND creator_type = 0 AND (is_for_sale = true OR is_limited = true)"
    },
    4 : {
        "name": "Collectible Items",
        "query": "SELECT * FROM asset WHERE is_limited = true"
    },
    5 : {
        "name": "Collectible Hats",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Hat','HairAccessory','FaceAccessory','NeckAccessory','ShoulderAccessory','FrontAccessory','FrontAccessory','BackAccessory','WaistAccessory') AND is_limited = true"
    },
    6 : {
        "name": "Collectible Gears",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Gear') AND is_limited = true"
    },
    7 : {
        "name": "Collectible Faces",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Face') AND is_limited = true"
    },
    8 : {
        "name": "All Clothing",
        "query": "SELECT * FROM asset WHERE asset_type IN ('TShirt','Hat','Shirt','Pants','Package') AND is_for_sale = true"
    },
    9 : {
        "name": "Hats",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Hat','HairAccessory','FaceAccessory','NeckAccessory','ShoulderAccessory','FrontAccessory','FrontAccessory','BackAccessory','WaistAccessory') AND is_for_sale = true"
    },
    10 : {
        "name": "Shirts",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Shirt') AND is_for_sale = true"
    },
    11 : {
        "name": "T-Shirts",
        "query": "SELECT * FROM asset WHERE asset_type IN ('TShirt') AND is_for_sale = true"
    },
    12 : {
        "name": "Pants",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Pants') AND is_for_sale = true"
    },
    13 : {
        "name": "Packages",
        "query": "SELECT * FROM asset WHERE asset_type in ('Package') AND is_for_sale = true"
    },
    14 : {
        "name": "Body Parts",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Head','Face') AND is_for_sale = true"
    },
    15 : {
        "name": "Heads",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Head') AND is_for_sale = true"
    },
    16 : {
        "name": "Faces",
        "query": "SELECT * FROM asset WHERE asset_type IN ('Face') AND is_for_sale = true"
    },
    41 : {
        "name": "Hairs",
        "query": "SELECT * FROM asset WHERE asset_type IN ('HairAccessory') AND (is_for_sale = true OR is_limited = true)"
    },
}
