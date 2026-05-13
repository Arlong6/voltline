## Voltline — shielded patroller (v0.66).
##
## Ground enemy that inherits Enemy's patrol / HP / drop pipeline but
## carries a front-facing riot shield. Bullets that strike the shield
## (i.e. come from the side the enemy currently faces, at roughly body
## height) are DEFLECTED — zero damage, a metallic ping, a spark flash.
## The counter: flank it (a dash gets you behind), or wait for it to
## reverse at a wall / patrol bound and shoot its exposed back.
##
## Splash damage (sub-weapons, which call take_damage with no origin)
## bypasses the shield entirely — explosives don't care which way the
## shield faces.
class_name Shieldbearer
extends "res://scripts/enemy.gd"

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Vertical half-band (px) around body centre within which a frontal hit
## counts as "blocked by the shield". Shots landing above this band sail
## over the shield — but the player can't normally arc shots, so in
## practice the band just keeps point-blank hits honest.
@export var shield_band_y: float = 11.0

# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------

const _SB_BODY: Color = Color("#3A5A6A")
const _SB_BODY_HIT: Color = Color("#FFE0E0")
const _SB_SHIELD: Color = Color("#9AC0D0")
const _SB_SHIELD_SPARK: Color = Color("#FFFFFF")
const _SB_EYE: Color = Color("#FFD24A")
const _SB_LEGS: Color = Color("#22343C")

const _DEFLECT_FLASH_DURATION: float = 0.12

var _deflect_flash_timer: float = 0.0


func _ready() -> void:
	# Spawn defaults — a touch tankier than a grunt, slightly slower.
	if max_hp == 2:  # Enemy default — spawn didn't override
		max_hp = 5
	hp = max_hp
	if walk_speed == 30.0:  # Enemy default
		walk_speed = 26.0


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	if _deflect_flash_timer > 0.0:
		_deflect_flash_timer = maxf(_deflect_flash_timer - delta, 0.0)


# Patrol identically to a base sweeper — the shield is purely a damage
# filter, not a movement change. (Enemy.tick_movement already handles
# wall + bound reversal, which is exactly the "expose the back" beat.)


## Pure-logic shield check. True when a hit originating at `from_pos`
## strikes the front face: same horizontal side as `direction`, within
## `shield_band_y` of body centre. A from_pos of Vector2.INF (no origin —
## splash damage) is never blocked.
func is_blocked_from(from_pos: Vector2) -> bool:
	if from_pos == Vector2.INF:
		return false
	var dx: float = from_pos.x - global_position.x
	if is_zero_approx(dx):
		return false
	var from_side: int = 1 if dx > 0.0 else -1
	if from_side != direction:
		return false
	return absf(from_pos.y - global_position.y) <= shield_band_y


func take_damage(amount: int, from_pos: Vector2 = Vector2.INF) -> void:
	if not is_alive:
		return
	if is_blocked_from(from_pos):
		_deflect_flash_timer = _DEFLECT_FLASH_DURATION
		if not Game.test_mode:
			Sfx.play("enemy_hit")
		return
	super.take_damage(amount, from_pos)


func _draw() -> void:
	var body_color: Color = _SB_BODY_HIT if _hit_flash_timer > 0.0 else _SB_BODY
	# Body — a bit narrower than the shield it hides behind.
	draw_rect(Rect2(-6.0, -6.0, 12.0, 10.0), body_color)
	# Single eye peeking over the body, on the facing side.
	var eye_x: float = 1.0 if direction > 0 else -4.0
	draw_rect(Rect2(eye_x, -4.0, 3.0, 2.0), _SB_EYE)
	# Legs.
	draw_rect(Rect2(-5.0, 4.0, 3.0, 4.0), _SB_LEGS)
	draw_rect(Rect2(2.0, 4.0, 3.0, 4.0), _SB_LEGS)
	# Riot shield on the facing side — a tall thin slab. Sparks white on
	# a deflected hit.
	var shield_x: float = 6.0 if direction > 0 else -9.0
	var shield_color: Color = _SB_SHIELD_SPARK if _deflect_flash_timer > 0.0 else _SB_SHIELD
	draw_rect(Rect2(shield_x, -9.0, 3.0, 16.0), shield_color)
