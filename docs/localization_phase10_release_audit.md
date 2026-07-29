# Phase 10 localization release audit

Date: 2026-07-29

Decision: **not ready for localization release**

This document records the result of executing the Phase 10 completeness gate. It is
not a migration estimate and does not downgrade the completed architecture in phases
1–9. It distinguishes automated technical evidence from product and native-speaker
approval.

## Automated evidence

The following gates pass:

- the English, Dutch, and Brazilian Portuguese client catalogs contain 2,676 matching
  keys;
- the three launcher catalogs contain 133 matching keys;
- catalog JSON, non-empty values, key parity, and named placeholders have no errors;
- locale normalization, persistence, request headers, and English fallback pass;
- local signs, NPC metadata/dialogue contracts, canonical content overlays, item
  overlays, backend error contracts, login, migrated gameplay domains, battles, and
  the launcher pass their domain checks;
- all 141 project checks pass;
- the standalone launcher localization runtime check passes.
- the static completeness scan contains zero hardcoded player-facing candidates;
- the final scene-default surfaces pass a locale and layout matrix for English,
  Dutch, and Brazilian Portuguese at 1280×720, 1600×900, and 1920×1080.

Run the repeatable catalog and completeness audit with:

```bash
python3 tools/audit_localization_release.py
```

The strict release decision is:

```bash
python3 tools/audit_localization_release.py --strict --limit 0
```

The strict command exits with status 0.

## Completed technical text gate

The static completeness scan started at 400 candidates and now reports zero
candidates at player-facing text sinks:

```text
Hardcoded player-facing candidates: 0
RESULT: PASS
```

Phase 10A migrated the Pokémon Storage controls, search, filters, box selector,
release flow, move feedback, error feedback, and live locale switching. Its focused
runtime and storage contract checks pass, and it reduced the open list by 56
candidates.

Phase 10B migrated the ranked/private PvP launcher, team validation, queue states,
private rooms, rules and banlists, leaderboard, match history, spectator controls,
countdown and compact queue panel. Its runtime locale-switch and existing PvP
contract checks pass, and it reduced the open list by another 108 candidates.

Phase 10C migrated the private and public Trainer Card, currency wallet, role and
Gym Badge states, appearance editor, wardrobe feedback, cosmetic names, natural
color palettes, and live locale switching. Its focused runtime, layout, appearance,
and badge checks pass, and it reduced the open list by another 34 candidates.

Phase 10D migrated chat tabs and context selection, PM and Guild states, chat input
and feedback, channel prefixes, the Social launcher, personal buffs, global
community buffs, contribution feedback, and live locale switching. Its focused
runtime, chat, badge, hotbar, and layout checks pass, and it reduced the open list
by another 74 candidates.

Phase 10E migrated Item Dex navigation, metadata, effects, capture notes and source
summaries; Wild Pokémon titles, load states, encounter methods, rarity and levels;
Developer Tools defaults and search feedback; staff teleport copy; and Store
purchase announcements. Its focused runtime, Wild Pokémon, developer-tool, Store,
and layout checks pass, and it reduced the open list by another 36 candidates.

Phase 10F migrated Fishing loadout, rods and progression; Surf and other field-move
feedback; blackout, capture, Gym Badge, money, EXP, EV and level rewards; evolution
prompts and animation copy; and move-learning choices and results. Its focused
runtime and existing Fishing, field-move, blackout, boss, reward, and summary checks
pass, and it reduced the open list by another 60 candidates.

Phase 10G migrated the final Mail and location scene defaults, Trainer status
defaults, and detached Pokémon Summary title. Dynamic username and time previews now
start empty or neutral until authoritative runtime data is available, while `VS` is
classified as a non-linguistic battle marker. Its runtime check covers every
supported locale and resolution for these final surfaces, reducing the last 32
candidates to zero.

## Open technical release gate

The complete supported-resolution gate is still incomplete. Existing tests now cover
focused layouts, the 1280×720 login/settings pilot, and the final Phase 10G surfaces
in all three locales at 1280×720, 1600×900, and 1920×1080. They still do not
instantiate every supported flow and every long-text, empty, and error state across
that full matrix. Therefore the plan's full-flow layout criterion cannot yet be
certified.

## Open language-quality gates

The complete generated Dutch and Brazilian Portuguese species, move, ability, and
item catalogs are still explicitly marked as machine-generated review drafts in
`localization_content_review.md`.

- Dutch has received hands-on review for several flows, but there is no recorded
  product review of every catalog and remaining interface.
- Brazilian Portuguese has no recorded native-speaker approval.
- External registration, website, credits, and legal content require separate content
  and legal review.

These are human release approvals. Automated tests can verify coverage and mechanics,
but cannot replace them.

## Required remediation order

1. Add full-flow layout checks for all supported locales and resolutions, including
   long-text and empty/error states.
2. Review generated Dutch content and move approved entries into manual overlays.
3. Complete Brazilian Portuguese native-speaker review and record approval.
4. Re-run all project checks, the launcher runtime check, and the strict release audit.

Phase 10 may be marked complete only when full-flow layout coverage passes and both
human language approvals are recorded. The strict text-completeness audit is already
green.
