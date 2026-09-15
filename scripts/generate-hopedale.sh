#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/bake_hopedale.py
python3 - <<'PY'
import sys
sys.path[:0]=['scripts','geo/curated']
from hopedale_geo import load
from landmarks import bake
print('Curated parts:',bake(*load()))
PY
python3 scripts/preview_hopedale.py
python3 scripts/preview_landmark.py
/home/ned/.rokit/bin/stylua src/shared/TownMap.luau src/shared/RoadGraph.luau
