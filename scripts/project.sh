#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/home/ned/.rokit/bin:$PATH"
case "${1:-check}" in
  serve) exec rojo serve default.project.json --address 127.0.0.1 ;;
  smoke-serve) exec rojo serve smoke.project.json --address 127.0.0.1 ;;
  sourcemap) exec rojo sourcemap default.project.json --include-non-scripts --output sourcemap.json ;;
  format) exec stylua src tests ;;
  lint) exec selene src tests ;;
  test)
    if [[ ! -x .tools/luau/luau ]]; then
      echo 'Run bash scripts/bootstrap-checks.sh first.' >&2
      exit 1
    fi
    exec .tools/luau/luau tests/logic.luau
    ;;
  typecheck)
    shopt -s nullglob
    lsp_candidates=(/home/ned/.vscode/extensions/johnnymorganz.luau-lsp-*/bin/server)
    lsp_binary="${LUAU_LSP_BIN:-${lsp_candidates[0]:-}}"
    if [[ ! -x "$lsp_binary" || ! -f .tools/globalTypes.d.luau ]]; then
      echo 'Install the Luau LSP extension and run bash scripts/bootstrap-checks.sh (or set LUAU_LSP_BIN).' >&2
      exit 1
    fi
    bash scripts/project.sh sourcemap
    "$lsp_binary" analyze --platform roblox --sourcemap sourcemap.json --definitions .tools/globalTypes.d.luau src
    .tools/luau/luau-analyze tests/logic.luau src/shared/Driving.luau src/shared/Rules.luau src/shared/Turbo.luau src/shared/HighwayMath.luau src/shared/TrafficMath.luau src/shared/CrashMath.luau src/shared/Units.luau src/shared/HeadlightMath.luau
    ;;
  build)
    mkdir -p build
    rojo build default.project.json -o build/redline-county.rbxlx
    rojo build smoke.project.json -o build/smoke.rbxlx
    ;;
  check)
    stylua --check src tests
    selene src tests
    bash scripts/project.sh test
    bash scripts/project.sh typecheck
    bash scripts/project.sh build
    ;;
  *) echo 'Usage: bash scripts/project.sh {serve|smoke-serve|sourcemap|format|lint|test|typecheck|build|check}' >&2; exit 2 ;;
esac
