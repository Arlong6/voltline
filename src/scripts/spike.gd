## Voltline — spike hazard (instakill if walked over).
##
## Static Area2D that triggers Player.take_damage(damage) on body entry.
## Damage is set to a value far beyond max_hp so the touch always
## triggers respawn — a "don't step on me" affordance the player learns
## immediately.
class_name Spike
extends Area2D

const _SPIKE_COLOR: Color = Color("#B8B8C8")
const _SPIKE_DARK_COLOR: Color = Color("#7878A0")

@export var damage: int = 99


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode:
		return
	if body is Player:
		body.take_damage(damage)


func _draw() -> void:
	# Three triangular spikes pointing up — total span 16 wide, 8 tall.
	var top_y: float = -4.0
	var bottom_y: float = 4.0
	var spike_w: float = 5.0
	var spacing: float = 6.0
	for i in 3:
		var base_x: float = -8.0 + float(i) * spacing
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(base_x, bottom_y),
			Vector2(base_x + spike_w * 0.5, top_y),
			Vector2(base_x + spike_w, bottom_y)
		])
		draw_polygon(pts, PackedColorArray([_SPIKE_COLOR]))
		# Dark line on left edge for shape readability.
		draw_line(
			Vector2(base_x, bottom_y),
			Vector2(base_x + spike_w * 0.5, top_y),
			_SPIKE_DARK_COLOR, 1.0
		)
