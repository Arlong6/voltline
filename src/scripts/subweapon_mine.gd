## Voltline — proximity mine sub-weapon (v0.67).
##
## Drops at the player's feet on cast. Stays inert for `arm_delay`
## seconds (so the player can't sprint over their own deployment), then
## arms — touching it from then on causes an explosion that deals
## `damage` to every Enemy inside `blast_radius`. Despawns on detonation
## or after `lifetime` seconds, whichever comes first.
##
## Spawned by Player when SHIFT fires with equipped_subweapon ==
## SUBWEAPON_MINE.
class_name SubweaponMine
extends Area2D

@export var arm_delay: float = 0.4
@export var lifetime: float = 8.0
@export var damage: int = 4
@export var blast_radius: float = 36.0

const _COLOR_BODY: Color = Color("#8090A0")
const _COLOR_BLINK: Color = Color("#FF6040")
const _COLOR_BLAST: Color = Color("#FFD040")
const _SIZE: Vector2 = Vector2(10.0, 6.0)

var _armed: bool = false
var _arm_timer: float = 0.0
var _life_timer: float = 0.0
var _detonated: bool = false


func _ready() -> void:
	_arm_timer = arm_delay
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	tick(delta)
	queue_redraw()
	if is_expired():
		queue_free()


## Pure-logic step. Tests drive directly. Tracks arming + lifetime.
func tick(delta: float) -> void:
	if _arm_timer > 0.0:
		_arm_timer = maxf(_arm_timer - delta, 0.0)
		if _arm_timer <= 0.0:
			_armed = true
	_life_timer += delta


func is_armed() -> bool:
	return _armed


func is_expired() -> bool:
	return _life_timer >= lifetime or _detonated


func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode or _detonated or not _armed:
		return
	if body is Enemy and body.is_alive:
		detonate()


## Public so the player's own piercing super-bullet (or a test) can
## trigger the explosion early. Idempotent.
func detonate() -> void:
	if _detonated:
		return
	_detonated = true
	# Apply damage to every enemy in radius. Splash damage has no
	# origin (Vector2.INF), so the Shieldbearer's directional armour
	# doesn't deflect it.
	var parent: Node = get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is Enemy and child.is_alive:
				var d2: float = (child.global_position - global_position).length_squared()
				if d2 <= blast_radius * blast_radius:
					child.take_damage(damage, Vector2.INF)
	if not Game.test_mode:
		Game.hit_stop(0.10, 0.04)
		Game.request_shake(3.0)
		Sfx.play("explode")


func _draw() -> void:
	# Mine body — squat puck shape. Red blink LED before arming, then
	# steady amber once live.
	draw_rect(Rect2(-_SIZE * 0.5, _SIZE), _COLOR_BODY)
	var led_color: Color = _COLOR_BLAST if _armed else _COLOR_BLINK
	# Blink while disarming.
	if not _armed and fmod(_arm_timer * 6.0, 1.0) < 0.5:
		led_color = Color(led_color.r, led_color.g, led_color.b, 0.3)
	draw_rect(Rect2(-1.5, -_SIZE.y * 0.5 - 2.0, 3.0, 2.0), led_color)
