# SQLiteSuperBuild — agent notes

- This repo is a BUILD system, not a fork: upstream sources are never committed. They are pinned in pins.txt and fetched + SHA-256-verified by fetch.sh / fetch.ps1 into vendor/ (gitignored).
- flags.txt is the single source of truth for compile flags; both build scripts read it. Never add a flag to one script directly.
- The feature harness (test/test_superbuild.c) defines what may be claimed: README/docs feature lists must not exceed what it checks. Add a check before adding a claim.
- Drop-in rule: no behavior-changing defaults vs stock SQLite (no DQS=0, no page/cache overrides). Feature-enabling flags only.
- The canonical WinDevKit ci.yml is cargo-based and does NOT apply here; this repo's ci.yml is a custom fetch/build/test workflow. CI must run the harness against the built artifacts on Windows AND Linux.
- Gate equivalent for this repo: fetch (hash verify) -> build -> harness 0 failures -> shell smoke (`sqlite3 --version` matches pins.txt).
