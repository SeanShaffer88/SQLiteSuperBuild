# SQLite SuperBuild Roadmap

**v0.1 (this build)** — SQLite 3.54.1 with the curated flag set in
flags.txt, sqlite3.dll + sqlite3.exe + vec0.dll from one build, feature
harness proving every claim, pinned + hash-verified sources.

**Ongoing**
- Version bumps: change pins.txt (version + SHA-256 in one commit),
  re-run the harness, tag. The harness is the regression net.

**Candidates**
- ICU-enabled variant as a second artifact (locale collations), clearly
  separated from the drop-in build.
- ARM64 Windows artifact alongside x64.
- A `sqlite3.def` export list publication for import-lib generation
  with non-MSVC toolchains.
