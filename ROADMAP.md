# Roadmap

What version 0.1 leaves out, written so that a later session can pick each item up from this file. The general plan is the Manager's `docs/mod-plans/immersive-air-wing-sizes.md`; engine facts are cited by register id (`hoi4-modding-knowledge`), never restated here. Open game checks for the shipped part are in the Manager's `docs/testing-roadmap.md` (Air wings).

## 1. Carrier wings

**Goal:** a carrier's wings are squadrons too: real carrier squadrons held about 12 to 18 aircraft of one type (US Navy 1942: 18 to 27 fighters, 18 dive bombers, 12 to 18 torpedo bombers; Fleet Air Arm: 9 to 12; Imperial Japanese Navy: 18 to 27 per type; draft figures, to be checked like those of `docs/research.md`).

**What sets it:** each carrier sub-unit's `carrier_air_wing_size` (vanilla 10), `submarine_carrier_air_wing_size` (3) and `mega_carrier_air_wing_size` (5 or 10) [EQP-008]. Unverified, from the comments of vanilla's `00_defines.lua` only and not yet in the register: a carrier's capacity is its `carrier_size` stat times `NAir.CARRIER_SIZE_STAT_INCREMENT` (10; `SUBMARINE_CARRIER_SIZE_STAT_INCREMENT` 3 for submarines), and `NAir.CARRIER_PLANES_AMOUNT_FOR_POSITIONING` (50) and `NNavy.NAVAL_COMBAT_PLANE_MIN_STACKING_PENALTY` (80) count planes, not wings. Settle these with a code read or a game check and record them with `Add-HoiKnowledge.ps1` before step 1 below.

**Work:**

1. Choose sizes that divide the deck: a wing of 18 on a 20-plane hangar leaves 2 seats empty. Either sizes that divide 10 times `carrier_size` (10, 20), or a new `CARRIER_SIZE_STAT_INCREMENT` (for example 9 or 12) with sizes that divide it. Changing the increment changes every carrier's capacity, which is a balance decision for the owner.
2. Extend `tools/air-wing-sizes.json` with a `carrierSizes` map and teach `Convert-AirWingSizeText` the carrier key, with the same "stop on an unlisted sub-unit" rule and tests.
3. Compatch: Vanilla Navy Rework redefines `cv_fighter`, `cv_cas` and `cv_nav_bomber` in `x_cv_plane.txt` [VNR-002] [EQP-003]; the playset's standalone ships that file, so the compatch's copy carries the carrier sizes too.
4. Game check: a carrier with planes in reserve, "Add new Air Wing" on the carrier, the wing sizes and how many fit; a carrier task force in naval combat for a day, compared with vanilla.

**Cost:** M.

## 2. Starting order of battle wings

**Goal:** the wings a country starts with are squadrons as well. In version 0.1 they keep the `amount` the history files write, so a 1936 game opens with 100-plane wings next to new 24-plane ones.

**What sets it:** an `air_wings` block makes one wing per equipment entry with the `amount` written; `name`, `ace` and `start_experience_factor` apply to the wing written just above them [EQP-007]. Vanilla 1.19.4 has 198 `air_wings` blocks in 192 files under `history/units` (`Find-HoiUsage.ps1 air_wings -Folder history -Summary`); the playset's standalone has 225 in 225 files, most of them its own (`01_<TAG>_vnr_air*.txt`).

**Work:**

1. A generator `tools/Split-AirWings.ps1`: for each equipment entry, the size of its sub-unit from the table (the equipment's archetype decides the sub-unit, through the sub-unit's `need`), and `ceil(amount / size)` entries whose amounts add up to the original. The first entry keeps the `name`, `ace` and `start_experience_factor` lines; the others get none, or numbered names if the owner wants them.
2. Carrier locations (a word, not a state id) follow the carrier sizes of item 1; leave them alone until item 1 ships.
3. Vanilla files go in this mod under their vanilla paths [LOAD-010]; the standalone's files go in the compatch, generated from the standalone's copies.
4. Tests: total planes per country, state and equipment unchanged by the split; no `name`, `ace` or `start_experience_factor` without a wing before it.
5. Game check: a 1936 game as Germany and the United Kingdom, the air screen's wing counts and sizes, `error.log` free of `Error scripting OOB` lines [EQP-007].

**Risk:** about 200 replaced vanilla files make the mod sensitive to every game update that touches an order of battle; the generator and the tests above make the refresh one command, but it must be run.

**Cost:** L.

## 3. Kept at vanilla on purpose

- Missiles (`guided_missile`, `explosive_ammo`, `ballistic_missile`, `nuclear_missile`, `sam_missile`) and the `mothership`: they are not squadrons. They stay listed as `unchanged` in `tools/air-wing-sizes.json`, so the tool still stops on an air type it does not know.
- `NNavy.AIR_SPOTTER_NORMALIZED_AIRWING_SIZE` (100): it counts per plane, and vanilla's 10-plane patrol wings already rely on it. Revisit after the spotting check of the testing roadmap.
