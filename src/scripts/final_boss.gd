## Voltline — final boss "OMEGA-X" for stage 3.
##
## Inherits Boss (which inherits Enemy). Overrides defaults for a more
## punishing fight: bigger body, more HP, faster cadence, wider spread
## in phase 2 (5 bullets ±20° instead of 3 ±15°). Player must survive a
## sustained barrage rather than the metronomic R-08 fight.
class_name FinalBoss
extends "res://scripts/boss.gd"

# ---------------------------------------------------------------------------
# Visuals — bigger purple body with spike crown
# ---------------------------------------------------------------------------

const _OMEGA_SIZE: Vector2 = Vector2(40.0, 40.0)
const _OMEGA_COLOR_BODY: Color = Color("#7028B8")
const _OMEGA_COLOR_BODY_HIT: Color = Color("#FFE0FF")
const _OMEGA_COLOR_SPIKE: Color = Color("#5A1888")
const _OMEGA_COLOR_EYE: Color = Color("#FFE066")
const _OMEGA_COLOR_EYE_PHASE2: Color = Color("#FF6040")

# Spread half-angle (degrees) used in phase 2 — wider than parent Boss's
# 15° because we fire 5 bullets, not 3.
const _OMEGA_SPREAD_DEG: float = 20.0


func _ready() -> void:
	# Override Boss + Enemy defaults BEFORE setting hp / timers so the
	# new values flow through.
	max_hp = 42
	shoot_interval = 0.5
	bullet_speed = 240.0
	bullet_initial_delay = 1.4
	hop_interval = 1.8
	hop_velocity = -260.0
	hp = max_hp
	_shoot_timer = bullet_initial_delay
	_hop_timer = hop_interval * 0.5


# Override Boss._fire_at_player: phase 1 = single tracked bullet (same
# as parent), phase 2 = 5-bullet spread at ±_OMEGA_SPREAD_DEG.
func _fire_at_player() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var direction: Vector2 = (player.global_position - global_position).normalized()
	var hp_pct: float = float(hp) / float(max_hp)
	if hp_pct < phase_2_hp_pct:
		var spread_rad: float = deg_to_rad(_OMEGA_SPREAD_DEG)
		# Five-bullet spread evenly distributed across the full ±spread.
		for i in range(-2, 3):
			var angle: float = spread_rad * float(i) * 0.5
			_spawn_enemy_bullet(direction.rotated(angle))
	else:
		_spawn_enemy_bullet(direction)
	if not Game.test_mode:
		Sfx.play("shoot_enemy")


func _draw() -> void:
	var body_color: Color = _OMEGA_COLOR_BODY_HIT if _hit_flash_timer > 0.0 else _OMEGA_COLOR_BODY
	# Body — 40×40 centred on origin.
	draw_rect(
		Rect2(-_OMEGA_SIZE.x * 0.5, -_OMEGA_SIZE.y * 0.5, _OMEGA_SIZE.x, _OMEGA_SIZE.y),
		body_color
	)
	# Spike crown on top — 5 small triangles.
	for i in range(-2, 3):
		var x: float = float(i) * 8.0
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(x - 3.0, -_OMEGA_SIZE.y * 0.5),
			Vector2(x, -_OMEGA_SIZE.y * 0.5 - 8.0),
			Vector2(x + 3.0, -_OMEGA_SIZE.y * 0.5)
		])
		draw_polygon(pts, PackedColorArray([_OMEGA_COLOR_SPIKE]))
	# Eye — bigger, turns red in phase 2 to telegraph the spread shot.
	var hp_pct: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	var eye_color: Color = _OMEGA_COLOR_EYE_PHASE2 if hp_pct < phase_2_hp_pct else _OMEGA_COLOR_EYE
	draw_rect(Rect2(-7.0, -10.0, 14.0, 6.0), eye_color)
