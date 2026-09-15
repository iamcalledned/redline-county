# Geographic data and references — Hopedale center

Downloaded September 15, 2026. No proprietary basemap tiles, Street View textures or commercial 3D buildings are included.

## Data actually used

**© OpenStreetMap contributors.** Source extract: `source/hopedale.osm`, obtained from [OSM API 0.6](https://api.openstreetmap.org/api/0.6/map?bbox=-71.546,42.124,-71.533,42.134). Requested WGS84 bbox: west -71.546, south 42.124, east -71.533, north 42.134. The API can return complete ways extending outside its bounding box; the importer restricts the built extent separately. Snapshot SHA-256 is recorded in `generated/hopedale.json`.

OSM data is available under the [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/) with [OSM copyright/attribution terms](https://www.openstreetmap.org/copyright). The cached extract and derived geographic database (`generated/hopedale.json`, including lane graph) are distributed under ODbL 1.0. When redistributing those databases, retain attribution/license notices and the share-alike requirements. Generated map geometry, the map preview and the built places are produced works using that database; keep the attribution visible and provide access to the underlying derived database and source. This repository includes both, plus the import recipe and curated corrections. This notice does not claim ownership of contributor data or relicense unrelated game code.

The game HUD and garage planning board show map attribution. This file contains the full attribution link and data distribution path. Preserve them when distributing a place outside the repository.

Several OSM roads/buildings include MassGIS attribution and historical import tags, retained in the cached/derived data. **No separate MassGIS download was incorporated.** We reviewed [MassGIS building structures](https://www.mass.gov/info-details/massgis-data-building-structures-2-d) and [data access guidance](https://www.mass.gov/info-details/learn-about-massgis-data), but use the OSM snapshot and its license for this delivery rather than assuming every MassGIS dataset has the same terms.

## Anchor and evidence

- Historic Town Hall: OSM node **7241414065**, latitude **42.1289534**, longitude **-71.5398681**. Civic footprint **way 213631977**, tagged **78 Hopedale Street**. Street-facing orientation is inferred from that footprint and the adjacent Hopedale Street centerline; it is not a surveyed facade bearing.
- [Town administrator's official page](https://www.hopedale-ma.gov/1223/Administrator) now identifies meetings at **54 Hopedale Street**. The recognizable historic building at 78 is the chosen map landmark, not a claim that municipal offices remain there. The user was asked which building they intended; pending a correction, implementation uses the historic landmark.
- [NPS stop 6: church and Town Hall](https://www.nps.gov/blrv/planyourvisit/6-unitarian-church-and-town-hall.htm) supports the historic Town Hall and its relationship to the Unitarian Church.
- [NPS Hopedale self-guided tour](https://www.nps.gov/blrv/planyourvisit/hopedale-self-guided-tour.htm) provides local context for Ballou Park, company housing, the church, Community House and Bancroft Library. Mapped footprints/names locate supporting buildings; their facades remain approximate shells.
- [Buildings of New England, Town Hall article](https://buildingsofnewengland.com/2026/02/10/hopedale-town-hall-1886/) and its [front elevation photograph](https://buildingsofnewengland.com/wp-content/uploads/2026/01/4ad4ac3a-b167-4cc5-9479-091768a8a735.jpg?w=1024) were inspected as visual reference for the broad roof, central gable, paired chimneys, six upper window bays, sandstone trim and arched entry. The photograph is not redistributed in the repository or applied to game geometry. New geometry was authored from the visible major forms. Rear details, exact heights, stone courses and interior are not documented replicas.

## Exact versus provisional

Verified from this snapshot: street names, centerline topology and one-way tags; Town Hall address/footprint; mapped building placement; tagged crosswalk locations and mapped green-space polygons. OSM remains a community dataset, not a guarantee of current survey accuracy.

Provisional: flat elevation datum, 7.2 m paved width, 1.7 m sidewalks, painted stripe dimensions, generic facade/height, sparse street furniture, tree locations within mapped greenery, and junction right-of-way where no OSM control tag exists. These must not be advertised as exact local reconstruction. Freedom Street bridge way 1268960544 is an explicit curated exception: a flat continuous deck and stone parapets, with provisional height. Other unsupported separate levels fail import.

The garage and its landscaping are explicitly fictional. Its reserved site and driveway avoid mapped building footprints; no cadastral boundary, real property ownership, or permission to occupy actual land is asserted.

## Pond, parks and additional landmarks

The expanded 1,070 × 940 m slice includes only the southern pond shore and Parklands approach. [Hopedale’s park information](https://www.hopedale-ma.gov/1418/Hopedale-Pond-and-Parklands), [facility descriptions](https://hopedale-ma.gov/1421/Field-and-Facility-Information) and the [NPS walking tour](https://www.nps.gov/blrv/planyourvisit/hopedale-self-guided-tour.htm) support the park/memorial/library context. [NPS Little Red Shop](https://www.nps.gov/blrv/planyourvisit/3-little-red-shop.htm) and its front/side photograph informed the red clapboard walls, gabled roof, chimney and narrow window rhythm. [Bancroft Library local history](https://www.hope1842.com/bancroftlibrary-html/) supports granite/slate construction and the Hope fountain. Photographs were reference only; they are not included as textures. Facades, memorial figure and furniture are simplified authored approximations.

Hopedale Pond relation 1280760 references island way 85929288, absent from the first extract. `source/hopedale-pond-island.osm` contains the supplementary [OSM way/full response](https://api.openstreetmap.org/api/0.6/way/85929288/full), downloaded September 15, 2026 under the same ODbL terms. Both cache hashes are recorded in the generated database. Parklands polygon 29777767 and Ballou Park 657661755 locate greenery. Building 213632098 locates Bancroft Library; 213632360 locates Little Red Shop, overriding its stale OSM name using the NPS/museum reference.

## Fictional parkway addition

Redline Parkway and Parkway Access are authored game roads, identified by negative node/way IDs and `fictional` tags. They extend the playable area east to +950 m; they are not OSM observations or claims about real land use. The 1,705.48 m oval, its landscaping, lamps and signs are fictional. Original cached geography and its attribution are preserved.
