# Immersive Air Wing Sizes - Agent Rules

Shared rules for every mod in this tree (file encodings, build commands, engine knowledge, git) are in the Modding Manager's `../../AGENTS.md`. `CLAUDE.md` and `GEMINI.md` import this file.

## What this mod is
- Air wings sized as real squadrons of their type.
- Standard single-root layout: `descriptor.mod`, `build.ps1`, content folders, `tests/`, `tools/`, `wiki/` at the root; `artifacts/` and `scratch/` are git-ignored.

## Mod invariants
- `common/units/air.txt` is generated, never edited by hand: vanilla's file with only the `land_air_wing_size` lines changed, under the vanilla path so it replaces the whole file [LOAD-010] [EQP-008].
- Every size lives in `tools/air-wing-sizes.json`; an air type the table does not list stops the tool, so a new type goes into `sizes` or `unchanged`.
- Defines change single entries in `common/defines/zz_immersive_air_wing_sizes.lua`, never a copy of `00_defines.lua` [DEF-003].
- Carrier sizes, starting order of battle wings and missiles are out of scope for now: `ROADMAP.md`.
- The tests that compare `common/units/air.txt` with the installed game's file, and check the define names against vanilla's, skip without a local install, so CI checks only the table and the shipped values: run `.\build.ps1 -Test` locally before reporting a change done.

## Commands beyond build.ps1
- After a game update, regenerate from the installed game (game root from the Manager's `Get-HoiGameInfo.ps1`), then run `.\build.ps1 -Test`: `.\tools\Set-AirWingSizes.ps1 -SourcePath "<game root>\common\units\air.txt" -DestinationPath .\common\units\air.txt`.

## Read when
| Task | Read |
|---|---|
| Publishing to the Workshop | `WORKSHOP_DESCRIPTION_GUIDELINES.md` |
| Choosing or changing a size | `docs/research.md` |
| Carrier wings, starting wings, what comes next | `ROADMAP.md`, and the Manager's `docs/mod-plans/immersive-air-wing-sizes.md` |

## Engine Knowledge
- Engine facts live in the Modding Manager's register, reached through the user-level `hoi4-modding-knowledge` skill: search it before a new kind of file and before asking for a game launch, cite ids here, never write a fact into this repository.
- Topics this mod leans on: `equipment-and-units`, `defines`, `encoding-and-syntax`, `loading-and-overrides`.
- `tests/Knowledge.Tests.ps1` runs the register's audit for this repository; it is a copy the Manager keeps current.