# Pokémon terminology glossary

The locale glossary is the source of truth for protected Pokémon terminology that
must match an official localization. Runtime catalogs remain optimized for their
current consumers; project and release checks require every declared target to match
the glossary exactly.

For Simplified Chinese, use this order:

1. the official Simplified Chinese Pokémon term;
2. the current official term for content that predates Chinese game releases;
3. a reviewed franchise terminology reference;
4. a documented PokeAether term when no official equivalent exists.

Do not add a literal translation while an official term is available. Add or update
the glossary entry, its sources, and every catalog target in the same change. Terms
without an accessible primary legacy source must be marked `official_legacy` and cite
the reviewed terminology index used to verify them.

`tests/localization_zh_cn_terminology_check.gd` enforces the glossary, validates its
sources and review statuses, and rejects known literal mistranslations across every
Simplified Chinese JSON catalog. `tools/check_localization_terminology.mjs` applies the
same contract in pull requests, protected-branch pushes, and desktop releases.
