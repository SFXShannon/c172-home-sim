# Mixture

**Download:** [mixture_files.zip](https://github.com/SFXShannon/c172-home-sim/raw/main/parts/mixture/mixture_files.zip) (STLs, panel template, source) · or [all three + test plate](https://github.com/SFXShannon/c172-home-sim/raw/main/parts/push-pull-test-plate/throttle_mixture_prop_all.zip)

Red ribbed vernier-style knob with the centre lock button, on a hex bushing nut.

![mixture working](../../docs/anim/mixture.gif)

It uses the same mechanism, parts list and assembly as the throttle; see [`../throttle/README.md`](../throttle/README.md).

| Pushed in (rich) | Pulled out (idle cut-off) | Knob |
|---|---|---|
| ![](images/assembly_in.png) | ![](images/assembly_out.png) | ![](images/knob.png) |

The button is moulded in as part of the knob, so it doesn't lock. You can use a filament change at the button layers to make it black, or paint it. Print the knob back-down.

Wire it to A1 (Y axis) in the Pro Micro sketch and bind it to *Mixture axis* in MSFS.
