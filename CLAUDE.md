# Voltline (電光) — 2D Action Platformer

X-style action platformer in the spirit of Mega Man X / X8. Pixel art
ColorRect placeholders for v0.1, evolving toward proper sprites later.

## Technology Stack

- **Engine**: Godot 4.6
- **Language**: GDScript (static-typed)
- **Renderer**: GL Compatibility (Web HTML5 export target)
- **Physics**: Built-in 2D, CharacterBody2D for player + enemies
- **Tests**: GUT 9.6 in `src/tests/`
- **Viewport**: 384×216 widescreen pixel-art (×3 = 1152×648)

## Project Layout

```
voltline/
├── src/                  Game source (Godot project root)
│   ├── project.godot     Engine config + input map + autoloads
│   ├── addons/gut/       Test framework (verbatim)
│   ├── autoloads/        Singletons: Game (more added later)
│   ├── scripts/          Game code: player, enemies, levels, fx, menus
│   ├── scenes/           Minimal .tscn wrappers per script
│   └── tests/            unit + integration GUT tests
├── design/gdd/           Game design documents
├── production/stories/   Sprint stories (V-001 … V-NNN)
└── docs/                 Engine reference + architecture
```

## Conventions

- **Naming**: PascalCase for classes/scenes, snake_case for vars/files,
  UPPER_SNAKE for constants, snake_case past-tense for signals
- **Static typing**: All variables, parameters, returns. Use `func f() -> void:`
  even for void returns. `var x: int = 0`, never bare `var x = 0`
- **Doc comments**: Every public function + class needs `## ...` lines
- **Test-mode guard**: Time-driven systems must check `Game.test_mode`
  and short-circuit so unit tests are deterministic
- **Action gating**: Use `Input.is_action_just_pressed()` for jumps/dashes
  but track edges manually for headless-test compatibility (see night-market
  player_grid.gd for the pattern)

## Test Commands

```bash
cd src

# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Single file
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/.../test_x.gd -gexit

# Refresh class cache after adding a new class_name
godot --headless --editor --quit
```

## Forbidden Patterns

- No `MeshInstance3D` / 3D nodes (purely 2D project)
- No bare `var x = 0` — always `var x: TYPE = 0`
- No untested gameplay system going past one version commit
- No floating-point comparison with `==` — use `is_equal_approx()` or `assert_almost_eq`

## Engine Knowledge Cutoff Warning

LLM training predates Godot 4.6 (released Jan 2026). Always verify post-cutoff
APIs (CharacterBody2D state machine helpers, AnimationPlayer changes, etc.)
against `docs/engine-reference/godot/` before using.

See `docs/engine-reference/godot/VERSION.md` for the pinned version + risks.
