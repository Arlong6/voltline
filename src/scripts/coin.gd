## Voltline — coin pickup (V-013).
##
## Area2D pickup that bobs and "spins" (visual width oscillates) until
## the player walks into it. On contact: increments Game.coins, plays
## the coin SFX, and queue_free's itself. Persists across stages — coins
## reset on a fresh run (title-screen restart).
class_name Coin
extends Area2D

# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------

const _COLOR_GOLD: Color = Color("#FFD24A")
const _COLOR_GOLD_DIM: Color = Color("#B89020")
const _SIZE: Vector2 = Vector2(6.0, 6.0)

@export var spin_speed: float = 5.0
@export var bob_amplitude: float = 1.5

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _t: float = 0.0
var _spawn_y: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_spawn_y = position.y
	body_entered.connect(_on_body_entered)


const _MAGNET_RANGE: float = 80.0
const _MAGNET_PULL_SPEED: float = 240.0


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	_t += delta
	# v0.64 — coin magnet buff pulls coins toward the player when within
	# range. Overrides the idle bob during pull.
	if Game.is_buff_active(Game.BUFF_MAGNET):
		var player: Node2D = get_tree().get_first_node_in_group("player")
		if player != null:
			var to_player: Vector2 = player.global_position - global_position
			if to_player.length() <= _MAGNET_RANGE:
				var step: Vector2 = to_player.normalized() * _MAGNET_PULL_SPEED * delta
				global_position += step
				_spawn_y = position.y  # follow drift so bob doesn't fight it
				queue_redraw()
				return
	# Gentle vertical bob.
	position.y = _spawn_y + sin(_t * 3.0) * bob_amplitude
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if Game.test_mode:
		return
	if _collected:
		return
	if body is Player:
		_collected = true
		Game.add_coin(1)
		Sfx.play("coin_pickup")
		queue_free()


func _draw() -> void:
	# Spin effect — width pulses with sin(t * spin_speed) so the rect
	# alternately goes "edge-on" and "face-on", reading as a 2D coin.
	var width_factor: float = absf(sin(_t * spin_speed))
	var draw_w: float = lerp(1.5, _SIZE.x, width_factor)
	var color: Color = _COLOR_GOLD if width_factor > 0.5 else _COLOR_GOLD_DIM
	draw_rect(
		Rect2(-draw_w * 0.5, -_SIZE.y * 0.5, draw_w, _SIZE.y),
		color
	)
