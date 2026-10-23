# Live Aligned — project instructions

Read `docs/BLENDER_GODOT_WORKFLOW.md` before scene, Blender, asset, collision, or rendering edits. This is the Godot game project, separate from the Blender MCP tooling repository.

- Preserve the existing optimized runtime map; do not blindly run `scripts/export_from_blender.py`. It is a historical exporter, not the current complete pipeline.
- Geometry edits belong in the authoritative Blender source AND the optimized companion when applicable, followed by a scoped runtime export. Godot shaders, UI, physics, and day/night behavior belong here.
- Bridges, coastal lanterns, landing banks, and North Pagoda are independently instantiated. Exclude them from a base-map export to avoid duplication.
- Preserve leaf visibility, grass anti-aliasing, cheap bust/tree collision, shared meshes, saved Visual Lab looks, and F6 graphics preferences.
- Back up only the affected files outside Git. Verify the named visual defect in Godot, and test player movement when geometry/collision changes. Reopen/check saved Blender sources and report exact saved paths.
- Keep agent-run Godot editor, game, capture, and benchmark windows off the user's active desktop. Run checks headlessly when possible; when a visible window is needed, route it to the existing `Codex Godot` KDE virtual desktop without switching the user's desktop or taking focus. Use a narrowly matched temporary KWin rule or script for the test window and remove it afterward. Do not leave a broad persistent window rule that could move the user's own Godot windows. State the expected duration before any benchmark and keep routine samples short.
- Prefer configured code knowledge graph tools for structural discovery; use literal search for config strings and logs.
- Public Git history excludes local asset binaries, caches, backups, credentials, and private settings. Review the staged files with `tools/check_public_files.py` and a secret scanner before pushing.
- Do not publish third-party asset source files until redistribution rights are verified. See `docs/ASSETS.md`.
- The product is Live Aligned. Keep legacy node/asset names and the custom user-data directory unless explicitly migrating them; they preserve working references and settings.
