## Voltline — mid-stage checkpoint.
##
## Walked-over Area2D that updates `Player._spawn_position` so future
## respawns drop the player here instead of the level start. Becomes
## visually "active" (green flag) once triggered; subsequent walk-overs
## are no-ops.
class_name Checkpoint
extends Area2D

const _COLOR_INACTIVE: Color = Color("#7080A0")
const _COLOR_ACTIVE: Color = Color("#43D27A")
const _COLOR_POLE: Color = Color("#A0A0A0")
const _POLE_HEIGHT: float = 28.0
const _FLAG_SIZE: Vector2 = Vector2(8.0, 8.0)

var _activated: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode:
		return
	if _activated:
		return
	if body is Player:
		_activated = true
		body.set_checkpoint(global_position)
		Sfx.play("coin_pickup")  # bright pickup-like chime
		queue_redraw()


func _draw() -> void:
	# Pole rises from origin (placed at floor level by the stage).
	draw_rect(Rect2(-1.0, -_POLE_HEIGHT, 2.0, _POLE_HEIGHT), _COLOR_POLE)
	# Flag colour reflects activation state.
	var flag_color: Color = _COLOR_ACTIVE if _activated else _COLOR_INACTIVE
	draw_rect(
		Rect2(1.0, -_POLE_HEIGHT, _FLAG_SIZE.x, _FLAG_SIZE.y),
		flag_color
	)
