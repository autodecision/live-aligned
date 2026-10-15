# Public source publication review — 2026-10-14

A new repository was initialized without importing any previous Git history. The public source boundary excludes downloaded asset binaries/textures, Blender sources, MCP add-on code, Godot caches, local backups, credentials, export settings, and private saved looks. Local files were retained on disk.

Checks before publication:

- `python tools/check_public_files.py`: passed the staged-file boundary and credential-pattern checks.
- `uvx detect-secrets scan` (detect-secrets 1.5.0): 106 high-entropy findings, all SHA-256 asset checksums in `docs/local_asset_manifest.json`; no other findings. Rechecked with only exact JSON SHA-256 checksum lines excluded: zero findings. No blanket file or token-keyword exclusions were used. The final tracked-source scan also returned zero findings.
- Fresh initial history: no old commits or deleted secret versions to carry forward. Git uses the account's GitHub noreply author address; the remote is a plain HTTPS URL with no embedded authentication. Upload authenticates through the GitHub CLI credential helper.
- Local Godot 4.7.2 headless startup: successful, 48,776 plants, 91 trees, 13 animated water surfaces, 43 coastal/bridge posts, and eight pagoda lamps loaded with no runtime error messages.
- Rename assertions: application name and HUD are Live Aligned; the existing user-data directory is preserved.

The editor import completed but logged legacy EXR compression / embedded image / missing-UV tangent errors in local assets. This review does not claim a clean import or revalidate the scene's movement geometry; this publication changed the title and documentation, not that geometry. A public clone requires the separately acquired local asset pack before running the complete scene.

GitHub repository secret scanning and secret-scanning push protection are enabled.

No automated scanner can prove the absence of every possible secret. No credentials were found in the reviewed public source. The scanner baseline and machine authentication were not committed.
