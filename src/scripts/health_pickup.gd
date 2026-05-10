## Voltline — health pickup.
##
## Area2D drop that bobs in place; on player contact, calls Player.heal()
## and queue_free's. Spawned by Enemy.die() with ~30% probability in
## place of a coin drop.
class_name HealthPickup
extends Area2D

const _COLOR_HEAL: Color = Color("#43D27A")
const _COLOR_HEAL_DIM: Color = Color("#2A8A4F")

@export var heal_amount: int = 4

var _t: float = 0.0
var _spawn_y: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_spawn_y = position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	_t += delta
	position.y = _spawn_y + sin(_t * 3.0) * 1.5
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode:
		return
	if _collected:
		return
	if body is Player:
		_collected = true
		body.heal(heal_amount)
		Sfx.play("heal")
		queue_free()


func _draw() -> void:
	# Green plus-sign cross. Two overlapping rects.
	# Vertical bar
	draw_rect(Rect2(-1.0, -3.0, 2.0, 6.0), _COLOR_HEAL)
	# Horizontal bar
	draw_rect(Rect2(-3.0, -1.0, 6.0, 2.0), _COLOR_HEAL)
	# Darker outline corners for definition.
	draw_rect(Rect2(-1.0, -3.0, 2.0, 1.0), _COLOR_HEAL_DIM)
	draw_rect(Rect2(-1.0, 2.0, 2.0, 1.0), _COLOR_HEAL_DIM)
