#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Explicit refresh only. Generation and ordinary builds never access the network.
mkdir -p geo/source
curl -L --fail --retry 2 --max-time 60 'https://api.openstreetmap.org/api/0.6/map?bbox=-71.546,42.124,-71.533,42.134' -o geo/source/hopedale.osm.download
python3 -c 'import xml.etree.ElementTree as E; r=E.parse("geo/source/hopedale.osm.download").getroot(); assert r.tag == "osm" and len(r.findall("way")) > 0'
mv geo/source/hopedale.osm.download geo/source/hopedale.osm
