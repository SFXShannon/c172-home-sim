#!/usr/bin/env bash
# Re-export STLs (and panel templates) for every control in parts/.
# Each parts/<control>/<control>.scad lists its printable parts in the
# customizer line:  part = "..."; // [assembly, housing, shaft, ...]
#
# Usage: scripts/render.sh                 # all controls + the panel
#        scripts/render.sh parking-brake   # one control
#        scripts/render.sh panel           # just the simple lower panel (after moving controls)
#        scripts/render.sh dashboard       # the full G1000 dashboard tiles, glareshield, pedestal
#        PANEL=3 scripts/render.sh         # override panel thickness (mm)
set -euo pipefail
cd "$(dirname "$0")/.."

extra=()
[[ -n "${PANEL:-}" ]] && extra+=(-D "panel_thickness=${PANEL}")

controls=("$@")
[[ ${#controls[@]} -eq 0 ]] && controls=($(ls parts) panel dashboard)

# Print colour goes at the front of each panel STL name, so the files sort by colour:
# black_ / grey_ for pieces that show, hidden_ for ones behind the panel (any colour).
dash_colour() { case "$1" in tile_M*|tile_U*) echo grey;; splice*) echo hidden;; *) echo black;; esac; }
panel_colour() { case "$1" in splice*) echo hidden;; *) echo black;; esac; }
# Same idea for control parts that have a set colour (others keep their plain name)
part_file() { case "$1" in rod) echo "grey_$1";; *) echo "$1";; esac; }

render_dashboard() {
  local scad=panel/g1000_dashboard.scad out=panel/dashboard
  mkdir -p "$out/stl" "$out/templates" panel/images
  python3 scripts/place_splices.py     # find room for the splice plates on the back (writes panel/splices.scad)
  openscad "${extra[@]}" -D 'part="splice"' -o /tmp/_dash_check.csg "$scad" 2>&1 | grep -E "WARNING" || true
  rm -f "$out"/stl/*tile_*.stl "$out"/stl/*glareshield_*.stl
  # as many tiles / glareshield segments as the seams make (up to 5 per row); missing ones come out empty
  for p in tile_L{1..5} tile_M{1..5} tile_U{1..5} splice splice_small splice_narrow moza_frame glareshield_{1..5} pedestal_face pedestal_floor; do
    f="$out/stl/$(dash_colour "$p")_$p.stl"
    openscad -q "${extra[@]}" -D "part=\"$p\"" -o "$f" "$scad" 2>/dev/null || true
    if [[ -s "$f" ]] && grep -q facet "$f"; then echo "  ${f#panel/}"; else rm -f "$f"; fi
  done
  for ext in svg dxf; do openscad -q "${extra[@]}" -D 'part="panel_2d"' -o "$out/templates/dashboard_panel.$ext" "$scad"; done
  echo "  dashboard/templates/*"
  python3 scripts/make_cnc.py
}

render_panel() {
  local scad=panel/c172_panel.scad
  mkdir -p panel/stl panel/templates panel/images
  # show any layout warnings (overlapping controls, seams through a control, ...)
  openscad "${extra[@]}" -D 'part="splice"' -o /tmp/_panel_check.csg "$scad" 2>&1 | grep -E "WARNING" || true
  for p in lower_tile_1 lower_tile_2 lower_tile_3 splice pedestal floor; do
    f="panel/stl/$(panel_colour "$p")_$p.stl"
    rm -f "$f"
    openscad -q "${extra[@]}" -D "part=\"$p\"" -o "$f" "$scad" 2>/dev/null || true
    # tiles that don't exist (fewer splits) come out empty - drop them
    [[ -s "$f" ]] && grep -q facet "$f" && echo "  $f" || rm -f "$f"
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
  if [[ "$c" == "dashboard" ]]; then render_dashboard; continue; fi
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
      *_cutout)
        for ext in svg dxf; do
          echo "  $c/$p.$ext"
          openscad -q "${extra[@]}" -D "part=\"$p\"" -o "$dir/panel-template/$p.$ext" "$scad"
        done ;;
      *)
        f=$(part_file "$p")
        echo "  $c/$f.stl"
        openscad -q "${extra[@]}" -D "part=\"$p\"" -o "$dir/stl/$f.stl" "$scad" ;;
    esac
  done
done

# OpenSCAD 2021 writes ASCII STL; convert to binary (about 5x smaller)
if command -v python3 >/dev/null; then
  python3 scripts/stl2bin.py $(find parts panel -name '*.stl') >/dev/null
fi

# one-click downloads for the throttle / mixture / prop
python3 scripts/make_zips.py
