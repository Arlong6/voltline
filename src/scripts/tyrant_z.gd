## Voltline — true final boss "TYRANT-Z" for stage 4.
##
## Inherits Boss directly (not via FinalBoss) so its overrides are
## simple. Tougher than OMEGA-X across the board: 50 HP, 0.4s shoot
## cadence, faster bullets, and a 7-bullet phase-2 spread.
class_name TyrantZ
extends "res://scripts/boss.gd"

# ---------------------------------------------------------------------------
# Visuals — bigger than OMEGA-X, dark red core with twin eyes
# ---------------------------------------------------------------------------

const _TYRANT_SIZE: Vector2 = Vector2(48.0, 48.0)
const _TYRANT_COLOR_BODY: Color = Color("#1F0A14")
const _TYRANT_COLOR_BODY_HIT: Color = Color("#FFD0E0")
const _TYRANT_COLOR_SPIKE: Color = Color("#7A2A30")
const _TYRANT_COLOR_EYE: Color = Color("#FFD24A")
const _TYRANT_COLOR_EYE_PHASE2: Color = Color("#FF3838")

# Spread half-angle (degrees) for phase 2 — 7 bullets evenly distributed
# from -spread to +spread, so it fills more of the player's escape area.
const _TYRANT_SPREAD_DEG: float = 28.0


func _ready() -> void:
	max_hp = 50
	shoot_interval = 0.4
	bullet_speed = 260.0
	bullet_initial_delay = 1.5
	hop_interval = 1.6
	hop_velocity = -280.0
	hp = max_hp
	_shoot_timer = bullet_initial_delay
	_hop_timer = hop_interval * 0.5


# Override fire pattern: phase 2 = 7-bullet spread instead of 3.
func _fire_at_player() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var direction: Vector2 = (player.global_position - global_position).normalized()
	var hp_pct: float = float(hp) / float(max_hp)
	if hp_pct < phase_2_hp_pct:
		var spread_rad: float = deg_to_rad(_TYRANT_SPREAD_DEG)
		# Evenly distribute 7 shots from -spread to +spread.
		for i in range(-3, 4):
			var angle: float = spread_rad * float(i) / 3.0
			_spawn_enemy_bullet(direction.rotated(angle))
	else:
		_spawn_enemy_bullet(direction)
	if not Game.test_mode:
		Sfx.play("shoot_enemy")


func _draw() -> void:
	var body_color: Color = _TYRANT_COLOR_BODY_HIT if _hit_flash_timer > 0.0 else _TYRANT_COLOR_BODY
	# Body — 48×48 centred.
	draw_rect(
		Rect2(-_TYRANT_SIZE.x * 0.5, -_TYRANT_SIZE.y * 0.5, _TYRANT_SIZE.x, _TYRANT_SIZE.y),
		body_color
	)
	# Four long spikes on the head — wider apart, more menacing.
	for i in range(-3, 4, 2):
		var x: float = float(i) * 8.0
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(x - 4.0, -_TYRANT_SIZE.y * 0.5),
			Vector2(x, -_TYRANT_SIZE.y * 0.5 - 12.0),
			Vector2(x + 4.0, -_TYRANT_SIZE.y * 0.5)
		])
		draw_polygon(pts, PackedColorArray([_TYRANT_COLOR_SPIKE]))
	# Two eyes — gold normally, red in phase 2.
	var hp_pct: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	var eye_color: Color = _TYRANT_COLOR_EYE_PHASE2 if hp_pct < phase_2_hp_pct else _TYRANT_COLOR_EYE
	draw_rect(Rect2(-14.0, -10.0, 8.0, 6.0), eye_color)
	draw_rect(Rect2(6.0, -10.0, 8.0, 6.0), eye_color)
