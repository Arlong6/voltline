## Voltline — true endgame boss "TYRANT-Z²" for the post-clear stage 5.
##
## Inherits Boss directly. Tougher than TYRANT-Z across the board:
## 60 HP, 0.3s cadence, faster bullets, phase-2 = 9-bullet ±32° spread,
## and a 4-bullet radial burst on every hop apex.
class_name TyrantZ2
extends "res://scripts/boss.gd"

# ---------------------------------------------------------------------------
# Visuals — even larger, obsidian-and-gold final form
# ---------------------------------------------------------------------------

const _T2_SIZE: Vector2 = Vector2(56.0, 56.0)
const _T2_COLOR_BODY: Color = Color("#0A0610")
const _T2_COLOR_BODY_HIT: Color = Color("#FFE0E0")
const _T2_COLOR_SPIKE: Color = Color("#9A7A30")
const _T2_COLOR_EYE: Color = Color("#FFD24A")
const _T2_COLOR_EYE_PHASE2: Color = Color("#FF3A18")

const _T2_SPREAD_DEG: float = 32.0

# Cardinal radial burst fired on each hop apex (only after phase 2 starts).
const _T2_RADIAL_DIRS: Array[Vector2] = [
	Vector2.UP,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.RIGHT,
]

var _last_hop_timer: float = 0.0


func _ready() -> void:
	boss_name = "TYRANT-Z²"
	max_hp = 60
	shoot_interval = 0.3
	bullet_speed = 280.0
	bullet_initial_delay = 1.2
	hop_interval = 1.4
	hop_velocity = -300.0
	Game.apply_difficulty_to_boss(self)
	hp = max_hp
	_shoot_timer = bullet_initial_delay
	_hop_timer = hop_interval * 0.5
	_last_hop_timer = _hop_timer


func _physics_process(delta: float) -> void:
	if Game.test_mode or not is_alive:
		return
	# Detect hop edge (timer wrapped) so we can fire the radial burst
	# at the exact moment a hop starts.
	var prev: float = _last_hop_timer
	super._physics_process(delta)
	if _hop_timer > prev:
		_on_hop_started()
	_last_hop_timer = _hop_timer


func _on_hop_started() -> void:
	# Radial burst only after phase 2 — keeps phase 1 manageable.
	var hp_pct: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	if hp_pct >= phase_2_hp_pct:
		return
	for dir in _T2_RADIAL_DIRS:
		_spawn_enemy_bullet(dir)


# v0.63 — randomised picker. TYRANT-Z² is the heaviest of the spread
# bosses: phase 2 mixes huge 9-bullet spread, 8-direction radial, and
# fast 3-shot volleys. Phase 1 ramps up with 5-bullet spread + volley.
func _fire_at_player() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var direction: Vector2 = (player.global_position - global_position).normalized()
	var hp_pct: float = float(hp) / float(max_hp)

	var pool: PackedStringArray
	if hp_pct < phase_2_hp_pct:
		pool = PackedStringArray(["spread9", "spread9", "radial8", "volley", "spread5"])
	else:
		pool = PackedStringArray(["spread5", "aimed", "volley", "spread5"])

	var pattern: String = pool[randi() % pool.size()]
	match pattern:
		"aimed":   _attack_aimed_single(direction)
		"spread5": _attack_spread_n(direction, 5, _T2_SPREAD_DEG * 0.6)
		"spread9": _attack_spread_n(direction, 9, _T2_SPREAD_DEG)
		"radial8": _attack_radial_8()
		"volley":  _attack_volley_3(direction)

	_shoot_timer = randf_range(0.25, 0.55)

	if not Game.test_mode:
		Sfx.play("shoot_enemy")


func _draw() -> void:
	var body_color: Color = _T2_COLOR_BODY_HIT if _hit_flash_timer > 0.0 else _T2_COLOR_BODY
	# Body — 56×56 centred.
	draw_rect(
		Rect2(-_T2_SIZE.x * 0.5, -_T2_SIZE.y * 0.5, _T2_SIZE.x, _T2_SIZE.y),
		body_color
	)
	# Five tall gold spikes — the crown of the true final boss.
	for i in range(-4, 5, 2):
		var x: float = float(i) * 7.0
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(x - 4.0, -_T2_SIZE.y * 0.5),
			Vector2(x, -_T2_SIZE.y * 0.5 - 16.0),
			Vector2(x + 4.0, -_T2_SIZE.y * 0.5)
		])
		draw_polygon(pts, PackedColorArray([_T2_COLOR_SPIKE]))
	# Twin eyes — gold normally, blood-red in phase 2.
	var hp_pct: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	var eye_color: Color = _T2_COLOR_EYE_PHASE2 if hp_pct < phase_2_hp_pct else _T2_COLOR_EYE
	draw_rect(Rect2(-16.0, -12.0, 9.0, 7.0), eye_color)
	draw_rect(Rect2(7.0, -12.0, 9.0, 7.0), eye_color)
	# Chest sigil — diamond mark.
	var sigil: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 4.0),
		Vector2(6.0, 12.0),
		Vector2(0.0, 20.0),
		Vector2(-6.0, 12.0),
	])
	draw_polygon(sigil, PackedColorArray([_T2_COLOR_SPIKE]))
