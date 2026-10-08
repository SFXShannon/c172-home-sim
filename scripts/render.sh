#!/usr/bin/env bash
# Re-export STLs (and panel templates) for every control in parts/.
# Each parts/<control>/<control>.scad lists its printable parts in the
# customizer line:  part = "..."; // [assembly, housing, shaft, ...]
#
# Usage: scripts/render.sh                 # all controls + the panel
#        scripts/render.sh parking-brake   # one control
#        scripts/render.sh panel           # just the printable panel (after moving controls)
#        PANEL=3 scripts/render.sh         # override panel thickness (mm)
set -euo pipefail
cd "$(dirname "$0")/.."

extra=()
[[ -n "${PANEL:-}" ]] && extra+=(-D "panel_thickness=${PANEL}")

controls=("$@")
[[ ${#controls[@]} -eq 0 ]] && controls=($(ls parts) panel)

render_panel() {
  local scad=panel/c172_panel.scad
  mkdir -p panel/stl panel/templates panel/images
  # show any layout warnings (overlapping controls, seams through a control, ...)
  openscad "${extra[@]}" -D 'part="splice"' -o /tmp/_panel_check.csg "$scad" 2>&1 | grep -E "WARNING" || true
  for p in lower_tile_1 lower_tile_2 lower_tile_3 splice pedestal floor; do
    rm -f "panel/stl/$p.stl"
    openscad -q "${extra[@]}" -D "part=\"$p\"" -o "panel/stl/$p.stl" "$scad" 2>/dev/null || true
    # tiles that don't exist (fewer splits) come out empty - drop them
    [[ -s "panel/stl/$p.stl" ]] && grep -q facet "panel/stl/$p.stl" && echo "  panel/$p.stl" || rm -f "panel/stl/$p.stl"
  done
  for p in lower pedestal floor; do for ext in svg dxf; do
    openscad -q "${extra[@]}" -D "part=\"${p}_2d\"" -o "panel/templates/${p}_panel.$ext" "$scad"
  done; done
  echo "  panel/templates/*"
  if command -v xvfb-run >/dev/null; then
    xvfb-run -a openscad -q --preview --imgsize=1600,1200 --colorscheme=Tomorrow --viewall --autocenter \
      "${extra[@]}" -D 'part="preview"' --camera=-250,420,150,0,-60,0 -o panel/images/preview.png "$scad" && echo "  panel/images/preview.png"
    xvfb-run -a openscad -q --preview --imgsize=1600,760 --colorscheme=Tomorrow --projection=o --camera=-8,48,0,0,0,0,470 \
      "${extra[@]}" -D 'part="layout_map"' -o panel/images/layout_map.png "$scad" && echo "  panel/images/layout_map.png"
  fi
}

for c in "${controls[@]}"; do
  if [[ "$c" == "panel" ]]; then render_panel; continue; fi
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
