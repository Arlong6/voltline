## Voltline — switch-controlled door (v0.62).
##
## StaticBody2D wall that sinks downward into the floor when its
## connected SwitchPanel fires the `triggered` signal. Once open it
## stays open for the duration of the run (no auto-close).
##
## Stage scripts wire `switch.triggered.connect(door.open)` after
## spawning both. Multiple doors can listen on a single switch.
class_name DoorGate
extends StaticBody2D

const _COLOR_FRAME: Color = Color("#FFD24A")
const _COLOR_BODY:  Color = Color("#7A6028")
const _COLOR_BODY_DETAIL: Color = Color("#3A2818")

## Visible size — drawn as a solid bar centred on the body.
@export var size: Vector2 = Vector2(8.0, 40.0)

## Pixels the door drops on open. Should equal size.y so it disappears
## fully into the floor. Tunable per-stage if the door is in mid-air.
@export var open_drop: float = 40.0

## Seconds the door spends sliding open.
@export var open_duration: float = 0.6

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## True after open() has been called.
var is_open: bool = false

var _origin: Vector2 = Vector2.ZERO
var _open_t: float = 0.0


func _ready() -> void:
	_origin = position


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	if is_open and _open_t < open_duration:
		_open_t = minf(_open_t + delta, open_duration)
		var alpha: float = _open_t / open_duration
		# Ease-out so the door lands softly.
		alpha = 1.0 - (1.0 - alpha) * (1.0 - alpha)
		position.y = _origin.y + open_drop * alpha
		queue_redraw()
		if _open_t >= open_duration:
			# Disable collision once fully open.
			collision_layer = 0


## Public entry point — wire to SwitchPanel.triggered.
func open() -> void:
	if is_open:
		return
	is_open = true
	if not Game.test_mode:
		Sfx.play("explode")


func _draw() -> void:
	# Glowing frame border.
	draw_rect(Rect2(-size * 0.5, size), _COLOR_FRAME, false, 1.0)
	# Inner body.
	draw_rect(Rect2(-size.x * 0.5 + 1.0, -size.y * 0.5 + 1.0,
		size.x - 2.0, size.y - 2.0), _COLOR_BODY)
	# Detail strips along the door body for visual texture.
	var rows: int = int(size.y / 6.0)
	for i in rows:
		var y: float = -size.y * 0.5 + 2.0 + float(i) * 6.0
		draw_rect(Rect2(-size.x * 0.5 + 2.0, y, size.x - 4.0, 1.0),
			_COLOR_BODY_DETAIL)
