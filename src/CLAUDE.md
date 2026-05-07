# Source Directory

Godot project root. Always run godot commands from this directory.

## Engine Version

Godot 4.6 / GL Compatibility renderer. The LLM's training data is older
than this — verify any unfamiliar API against `docs/engine-reference/godot/`
in the project root before using.

## Coding Standards

See `../CLAUDE.md` for the full project conventions. Quick reminders:

- Static typing on every var / param / return
- `## ...` doc comments on every public function + class
- Time-driven systems must respect `Game.test_mode`
- Tests live under `tests/`, never inline in `scripts/`

## Tests

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

After adding a new `class_name`, refresh the cache:

```bash
godot --headless --editor --quit
```
