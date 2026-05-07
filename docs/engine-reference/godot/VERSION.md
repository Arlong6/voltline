# Godot Engine — Version Reference (Voltline)

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.6 |
| **Release Date** | January 2026 |
| **Project Pinned** | 2026-05-07 |
| **LLM Knowledge Cutoff** | Older than 4.6 |

## Knowledge Gap Warning

The LLM's training data predates Godot 4.6. Specifically risky areas
for an action platformer:

- **CharacterBody2D**: API has been stable since 4.0 but check `move_and_slide()`
  return value semantics and `floor_snap_length` defaults
- **AnimationPlayer / AnimationTree**: 4.5 introduced new state-machine helpers
- **Tweens**: `create_tween().set_parallel()` works, but check chaining order
- **Input**: `Input.is_action_just_pressed()` reliable in `_process` but NOT
  in `_unhandled_input` callbacks — pattern from night-market project applies

Always cross-reference https://docs.godotengine.org/en/stable/ when unsure.

## Action-Game-Specific APIs to Verify

- Coyote time / jump-buffer pattern
- Bullet pooling (Pool node? Just queue_free?)
- Pixel-perfect collision (Area2D vs CollisionShape2D RectangleShape2D)
- Camera2D `position_smoothing_enabled` + `drag_*` margins
