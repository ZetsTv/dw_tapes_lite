# Changelog

## 1.0.1 – 2026-11-17

- The text on the tape was mirrored on one side, now it reads correctly from both sides
- Target zone now covers the whole tape (box zone): aim at the tape, a cone or the ground below it.
  Before, the small spheres at the ends and in the middle were hard to hit, especially on cones
- Whoever placed a tape can always pick it up again (`Config.OwnerCanRemove`). Before, a tape placed with
  `/tape` could not be removed by the same player without the matching job
- Players with `dw_tapes.bypass` could place every tape but did not see "Pick up tape" when the framework granted
  the ACE after joining (e.g. group.admin on character load). ACE changes now reach the client within 5 seconds

Updating from 1.0.0: replace the files, keep your `tapes.json`. Your old `config.lua` keeps working.

## 1.0.0 – 2026-11-16

First release of the free Lite version.

- 7 tape types: police, crime scene, caution, fire line, EMS, barrier (red/white), hazard (yellow/black)
- Placement with live preview, length limit and line-of-sight check
- Wall / object anchors or traffic cones on the ground, cones are shared between tapes
- Static tape with natural sag
- Pick up via ox_target, qb-target, qtarget or G key
- Job permissions per tape type with optional minimum grade and on-duty check, player and server limits
- Persistence across restarts (same save format as the full version)
- Support for qbx_core, qb-core, ESX Legacy, older ESX and standalone
- English and German locales, item images included
