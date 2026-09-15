#!/usr/bin/env bash
# Optional CLI testing tools. Leaves rokit.toml and system tools untouched.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tools
curl -fL --retry 2 https://github.com/luau-lang/luau/releases/download/0.738/luau-ubuntu.zip -o .tools/luau-ubuntu.zip
curl -fL --retry 2 https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.69.0/scripts/globalTypes.d.luau -o .tools/globalTypes.d.luau
python3 - <<'PY'
import hashlib
import zipfile
from pathlib import Path

for name, expected in {
    'luau-ubuntu.zip': 'e967efb6c2a74e691637a82b0fd54de9ae43a2ec9f7be895eee51c1efb84363a',
    'globalTypes.d.luau': '7db9cd4fe55a4d26f3f7d5a39b6279a376f95a6c055c71d5591c26a1d525aaf2',
}.items():
    actual = hashlib.sha256(Path('.tools', name).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f'Checksum mismatch: {name}. Refusing to install.')
with zipfile.ZipFile('.tools/luau-ubuntu.zip') as archive:
    archive.extractall('.tools/luau')
for path in Path('.tools/luau').iterdir():
    path.chmod(0o755)
print('Project-local Luau 0.738 and Roblox definitions verified.')
PY
