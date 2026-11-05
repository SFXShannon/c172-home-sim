# Panel extras

![Ignition key working](../../docs/anim/ignition.gif)

| Part | What it is |
|---|---|
| `ignition_key`, `ignition_cylinder`, `ignition_escutcheon` | A real-looking key (black head with a key-ring hole, cut off at the lock face and glued in) in a lock face with a chrome-look bezel, on a 1-pole 12-position rotary switch (stop washer set to 5 positions). OFF R L BOTH START is engraved round it on the panel. |
| `knob_alt_static` | Red ALT STATIC AIR knob (look only) |
| `knob_cabin_heat`, `knob_cabin_air` | CABIN HT / CABIN AIR knobs (look only) |
| `knob_fuel_shutoff` | Red FUEL SHUTOFF knob on the pedestal (look only) |
| `knob_stem` + `stem_clip` | Holds any look-only knob in an 8.5 mm panel hole |
| `cb_strip` | A block of circuit-breaker heads; glue two on the lower panel |
| `yoke_boot` | Trim ring with a rubber-boot look round a yoke shaft hole (`yoke_hole_d`, default 60 mm); not used on the G1000 dashboard, where the AY210 sits in a window |

Print the knobs face down; their label is engraved in the face, so fill it with white paint.

**Ignition key:** the lock face (`ignition_cylinder`) presses onto the rotary switch's 6 mm shaft and turns with it (knurled shaft by default, as on the common RS26-type 1-pole 12-position switch; set `ign_shaft = "d"` for a shaft with a flat); the bezel (`ignition_escutcheon`) sits over the switch nut and stays still. The shaft goes **10 mm** into the lock, so **cut the switch shaft so it ends 14 mm in front of the panel face** (or leave it if it's shorter; the lock grips whatever reaches in). The key is cut off at the lock face and has a plain 2.5 mm stub: glue it into the keyway (CA or epoxy) with the key in line with the keyway. Print the key flat in silver and change to black filament at 2.4 mm for the head (or paint the head). Print the lock face in grey and the bezel in silver.

![Extras](images/front.png)
