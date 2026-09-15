# Bundled free Roblox vehicles

Geometry from Roblox's own [endorsed vehicle release](https://devforum.roblox.com/t/new-endorsed-models-in-toolbox/1068480), downloaded September 15, 2026 from Roblox asset delivery. These are Creator Store assets for use in Roblox, not claimed as original REDLINE COUNTY art or CC0 assets. No paid asset or purchase was used.

| Local model | Creator Store source | Included variant |
| --- | --- | --- |
| Sport | [Sports Car — Roblox, 6433323089](https://create.roblox.com/store/asset/6433323089) | Blue |
| Pickup | [Pickup Truck — Roblox, 6418225759](https://create.roblox.com/store/asset/6418225759) | Blue |
| Electric | [Sedan — Roblox, 6418239833](https://create.roblox.com/store/asset/6418239833) | Aqua; fictional electric handling |
| Police | [Police Car — Roblox, 6418230807](https://create.roblox.com/store/asset/6418230807) | Black/white cruiser |

The local `.rbxmx` files contain only visual geometry/materials and fitting metadata: 36, 41, 40 and 51 parts respectively. No downloaded scripts, seats, remotes, sounds, controllers or constraints are included. The game supplies its own seat, chassis, steering-wheel animation, four-corner wheel rig, collision, AI, drift and upgrade logic. Mesh and texture content IDs still resolve through Roblox's CDN. The visual model itself does not require an InsertService/AssetService request at Play time.

Rebuild procedure: obtain the four free source models from their listed Roblox pages/asset-delivery URLs, save them as `redline-sport.rbxm`, `redline-pickup.rbxm`, `redline-sedan.rbxm`, `redline-police.rbxm` in a temporary directory, then run `lune run scripts/import-vehicles.luau /path/to/directory`. The importer uses Lune 0.10.5 to deserialize data without running asset scripts. Review the resulting geometry and run the project checks. The raw downloaded scripts are not stored in the repository.
