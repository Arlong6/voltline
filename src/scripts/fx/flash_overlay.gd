## Full-screen flash overlay — one-shot CanvasLayer that fades from a given
## colour to transparent, then frees itself.
##
## Usage:
##   var flash: FlashOverlay = FlashOverlay.new()
##   flash.flash_color = Color(1.0, 1.0, 1.0, 1.0)  # white
##   flash.duration = 0.30
##   parent.add_child(flash)
##
## Layer is 20 (above HUD at 10) so it overlays the whole game view.
class_name FlashOverlay
extends CanvasLayer

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Starting colour of the flash. Alpha is tweened to 0.
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Seconds for alpha to reach 0 from full strength.
@export var duration: float = 0.30

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 20

	var rect: ColorRect = ColorRect.new()
	rect.color = flash_color
	rect.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

	var tween: Tween = create_tween()
	tween.tween_property(rect, "color:a", 0.0, duration)
	tween.tween_callback(queue_free)
