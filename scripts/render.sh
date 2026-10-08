#!/usr/bin/env bash
# Re-export STLs (and panel templates) for every control in parts/.
# Each parts/<control>/<control>.scad lists its printable parts in the
# customizer line:  part = "..."; // [assembly, housing, shaft, ...]
#
# Usage: scripts/render.sh                 # all controls
#        scripts/render.sh parking-brake   # one control
#        PANEL=3 scripts/render.sh         # override panel thickness (mm)
set -euo pipefail
cd "$(dirname "$0")/.."

extra=()
[[ -n "${PANEL:-}" ]] && extra+=(-D "panel_thickness=${PANEL}")

controls=("$@")
[[ ${#controls[@]} -eq 0 ]] && controls=($(ls parts))

for c in "${controls[@]}"; do
  dir="parts/$c"
  scad=$(ls "$dir"/*.scad | head -1)
  list=$(grep -E '^part *=' "$scad" | sed -E 's/.*\[(.*)\].*/\1/' | tr -d ' ' | tr ',' ' ')
  mkdir -p "$dir/stl" "$dir/panel-template"
  for p in $list; do
    case "$p" in
      assembly*|exploded|section) continue ;;
      panel_cutout)
        for ext in svg dxf; do
          echo "  $c/$p.$ext"
          openscad -q "${extra[@]}" -D "part=\"$p\"" -o "$dir/panel-template/${c//-/_}_cutout.$ext" "$scad"
        done ;;
      *)
        echo "  $c/$p.stl"
        openscad -q "${extra[@]}" -D "part=\"$p\"" -o "$dir/stl/$p.stl" "$scad" ;;
    esac
  done
done
