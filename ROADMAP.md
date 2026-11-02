# SQLite SuperBuild Roadmap

**v0.1 (this build)** — SQLite 3.54.1 with the curated flag set in
flags.txt, sqlite3.dll + sqlite3.exe + vec0.dll from one build, feature
harness proving every claim, pinned + hash-verified sources.

**v0.1.1** — published export lists (`sqlite3.def`, `vec0.def`)
generated from the built DLLs and verified in CI, so non-MSVC
toolchains can make import libraries; the release zip now includes the
shell and both defs; the release job runs the same fetch/build/harness
gate as CI; the harness's `vec_version()` check is real (it was a no-op
before).

**v0.1.2** — Windows ARM64 artifact alongside x64. The release workflow
builds both architectures on native runners (`windows-latest` and
`windows-11-arm`), runs the same fetch/build/defs/harness/shell-smoke
gate on each, and publishes `SQLiteSuperBuild-vX.Y.Z-x64.zip` and
`SQLiteSuperBuild-vX.Y.Z-arm64.zip`. The defs are architecture-neutral
and verified against both DLLs.

**Ongoing**
- Version bumps: change pins.txt (version + SHA-256 in one commit),
  re-run fetch + build + harness, regenerate the defs, commit, tag.
  The harness and the def comparison are the regression net.
- Keep the defs in sync: CI regenerates them from the built artifacts.

**Candidates**
- ICU-enabled variant as a second artifact (locale collations), clearly
  separated from the drop-in build.
