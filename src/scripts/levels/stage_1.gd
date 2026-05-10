## Voltline — Stage 1 (V-002 + V-003 + V-004 + V-005 build).
##
## 1152-px-wide scrolling stage = 3 viewport widths laid out left-to-right:
##   • Section A (0..384):  Tutorial bay — flat floor + 2 stepped platforms
##   • Section B (384..768): Wall-jump shaft — 2 facing walls and an upper
##     reward platform reachable only by wall-jumping
##   • Section C (768..1152): Stepped descent + a goal flag at the right
##
## A Camera2D parented to the player follows horizontally with smoothing
## and is clamped to the stage bounds. Boundary walls at x=0 and x=1152
## stop the player from leaving the stage. All static bodies are built
## programmatically in _ready so the .tscn stays a minimal script-attach.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216
const STAGE_WIDTH: int = 1152      # 3 × viewport_width

const FLOOR_Y: int = 180
const FLOOR_HEIGHT: int = 36

const COLOR_BG: Color = Color("#1A1230")
const COLOR_GROUND: Color = Color("#3A2A50")
const COLOR_PLATFORM: Color = Color("#5A4A78")
const COLOR_WALL: Color = Color("#4A3068")
const COLOR_GOAL: Color = Color("#FFD24A")
const COLOR_GOAL_POLE: Color = Color("#A0A0A0")
const COLOR_TEXT: Color = Color("#7AC8FF")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/checkpoint.tscn")
const PLAYER_SPAWN: Vector2 = Vector2(48.0, 160.0)
const CHECKPOINT_POS: Vector2 = Vector2(620.0, 180.0)

# Enemy patrol setup: spawn position + bounds. Each entry is
# (spawn_x, patrol_min_x, patrol_max_x). Y is fixed to the floor surface.
const ENEMY_PATROLS: Array = [
	# Section A — guards the entry to the wall-jump shaft.
	[340.0, 280.0, 410.0],
	# Section C — patrols between the descending platforms.
	[880.0, 820.0, 990.0],
]
const ENEMY_FLOOR_Y: float = 168.0  # enemy centre y when standing on floor

const STAGE_NAME: String = "SECTOR 1 // JUNKYARD"
const STAGE_INTRO_DURATION: float = 2.0

# Stage-1 enemies — bumped to 4 HP / 50 speed in v0.53 difficulty pass.
const ENEMY_HP: int = 4
const ENEMY_SPEED: float = 50.0

const FADE_IN_DURATION: float = 0.5
const FADE_OUT_DURATION: float = 1.0

# All collidable rectangles in world space (top-left + size). Drawn in the
# same loop as their colliders so visuals and collision can never drift.
const PLATFORMS: Array[Rect2] = [
	# Section A — tutorial steps.
	Rect2(140.0, 152.0, 48.0, 8.0),
	Rect2(240.0, 124.0, 48.0, 8.0),
	# Section B — top of the wall-jump shaft (96 wide, spans both wall tops).
	Rect2(440.0, 116.0, 96.0, 8.0),
	# Section C — descending stepping stones.
	Rect2(820.0, 156.0, 48.0, 8.0),
	Rect2(920.0, 132.0, 48.0, 8.0),
	Rect2(1040.0, 108.0, 48.0, 8.0),
]

const WALLS: Array[Rect2] = [
	# Section B — wall-jump shaft uprights. 64 px gap between inner edges,
	# 56 px tall (down from 80) so the shaft clears in 1-2 wall-jumps.
	Rect2(440.0, 124.0, 16.0, 56.0),
	Rect2(520.0, 124.0, 16.0, 56.0),
]

# Boundary walls at x<0 and x>STAGE_WIDTH so the player can never leave the
# stage. Drawn as 0-width / off-screen rects (no visual).
const BOUNDS: Array[Rect2] = [
	Rect2(-16.0, 0.0, 16.0, 216.0),
	Rect2(float(STAGE_WIDTH), 0.0, 16.0, 216.0),
]

# Goal flag visual marker at the far right.
const GOAL_POS: Vector2 = Vector2(1100.0, 132.0)
const GOAL_SIZE: Vector2 = Vector2(8.0, 16.0)
const GOAL_POLE_SIZE: Vector2 = Vector2(2.0, 48.0)
# Trigger area is wider than the visual flag — forgive players who jump
# past or land slightly short of the banner itself.
const GOAL_TRIGGER_SIZE: Vector2 = Vector2(32.0, 48.0)
# Seconds the "STAGE CLEAR" banner stays up before kicking back to title.
const GOAL_DELAY: float = 2.5

var _goal_reached: bool = false
var _transitioning: bool = false
var _hud_layer: CanvasLayer
var _stage_clear_label: Label
var _stage_intro_label: Label
var _fade_rect: ColorRect
var _hp_bar: HpBar
var _player: Player


func _ready() -> void:
	Game.current_area = "stage_1"
	Music.play("stage")
	_build_static_block(Rect2(0.0, FLOOR_Y, STAGE_WIDTH, FLOOR_HEIGHT), &"Floor")
	for i in PLATFORMS.size():
		_build_static_block(PLATFORMS[i], &"Platform_%d" % i)
	for i in WALLS.size():
		_build_static_block(WALLS[i], &"Wall_%d" % i)
	for i in BOUNDS.size():
		_build_static_block(BOUNDS[i], &"Bound_%d" % i)
	_spawn_player_with_camera()
	_spawn_enemies()
	_spawn_checkpoint()
	_build_goal_trigger()
	_build_hud()
	_show_stage_intro()


# Mid-stage checkpoint that updates the player's respawn position when
# walked over. Visual flag turns green on activation.
func _spawn_checkpoint() -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint.position = CHECKPOINT_POS
	add_child(checkpoint)


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_transitioning = true
		var tween: Tween = create_tween()
		tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_DURATION)
		tween.tween_callback(func() -> void:
			if is_inside_tree():
				Game.goto_level("title")
		)


func _draw() -> void:
	draw_rect(Rect2(0, 0, STAGE_WIDTH, VIEWPORT_H), COLOR_BG)
	# Floor band.
	draw_rect(Rect2(0, FLOOR_Y, STAGE_WIDTH, FLOOR_HEIGHT), COLOR_GROUND)
	for platform in PLATFORMS:
		draw_rect(platform, COLOR_PLATFORM)
	for wall in WALLS:
		draw_rect(wall, COLOR_WALL)
	# Goal flag — pole + waving banner with "GOAL" label. Pure decoration in
	# v0.2 (no trigger); V-012 (stage clear) wires reaching it to the win flow.
	draw_rect(
		Rect2(
			GOAL_POS.x - GOAL_POLE_SIZE.x * 0.5,
			GOAL_POS.y + GOAL_SIZE.y - GOAL_POLE_SIZE.y,
			GOAL_POLE_SIZE.x,
			GOAL_POLE_SIZE.y
		),
		COLOR_GOAL_POLE
	)
	draw_rect(Rect2(GOAL_POS, GOAL_SIZE), COLOR_GOAL)
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font, Vector2(GOAL_POS.x - 10.0, GOAL_POS.y - 4.0),
		"GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GOAL
	)
	# Tutorial hint — drawn in world space so it scrolls off as the player
	# leaves the start area, which is the right behaviour for "intro labels".
	_draw_hint("ARROWS / WASD  MOVE", 16.0, 24.0)
	_draw_hint("SPACE / Z  JUMP", 16.0, 38.0)
	_draw_hint("X  SHOOT", 16.0, 52.0)
	_draw_hint("C / SHIFT  DASH", 16.0, 66.0)
	_draw_hint("WALL + JUMP  WALL JUMP", 16.0, 80.0)


# ---------------------------------------------------------------------------
# Setup helpers
# ---------------------------------------------------------------------------

# Generic StaticBody2D + RectangleShape2D builder. `rect` is the world-space
# rectangle the block occupies; the collider is centred inside it. World
# layer = 1 so the player's collision_mask=1 picks it up.
func _build_static_block(rect: Rect2, body_name: StringName) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.position = rect.position + rect.size * 0.5
	body.add_child(collider)


func _spawn_enemies() -> void:
	for entry in ENEMY_PATROLS:
		var spawn_x: float = entry[0]
		var min_x: float = entry[1]
		var max_x: float = entry[2]
		var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
		enemy.position = Vector2(spawn_x, ENEMY_FLOOR_Y)
		enemy.patrol_min_x = min_x
		enemy.patrol_max_x = max_x
		enemy.max_hp = ENEMY_HP
		enemy.walk_speed = ENEMY_SPEED
		add_child(enemy)


func _spawn_player_with_camera() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = PLAYER_SPAWN
	# Apply persistent upgrades BEFORE add_child so Player._ready picks
	# them up when it copies max_hp into hp.
	Game.apply_upgrades_to(_player)
	add_child(_player)

	var camera: Camera2D = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = STAGE_WIDTH
	camera.limit_top = 0
	camera.limit_bottom = VIEWPORT_H
	# Smoothing softens horizontal scroll; vertical is locked at the
	# centre because the limits collapse the y-range to a single value.
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	_player.add_child(camera)
	camera.make_current()


# Builds an invisible Area2D over the goal flag. body_entered fires once
# when the player overlaps it; we set _goal_reached and start a 2.5s
# timer back to the title screen.
func _build_goal_trigger() -> void:
	var goal_area: Area2D = Area2D.new()
	goal_area.name = &"GoalTrigger"
	goal_area.collision_layer = 0
	goal_area.collision_mask = 2  # detects the player (layer 2)
	add_child(goal_area)

	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = GOAL_TRIGGER_SIZE
	collider.shape = shape
	# Centre the trigger over the flag pole.
	collider.position = Vector2(
		GOAL_POS.x + GOAL_SIZE.x * 0.5,
		GOAL_POS.y + GOAL_SIZE.y * 0.5
	)
	goal_area.add_child(collider)
	goal_area.body_entered.connect(_on_goal_entered)


# Builds the screen-fixed CanvasLayer that hosts the "STAGE CLEAR" banner.
# Camera scrolling does not affect CanvasLayer children, so the banner
# stays centred regardless of where the player triggered the goal.
func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)

	_stage_clear_label = Label.new()
	_stage_clear_label.text = "STAGE CLEAR!"
	_stage_clear_label.add_theme_font_size_override("font_size", 32)
	_stage_clear_label.add_theme_color_override("font_color", COLOR_GOAL)
	_stage_clear_label.position = Vector2(0.0, float(VIEWPORT_H - 48) * 0.5)
	_stage_clear_label.size = Vector2(VIEWPORT_W, 48)
	_stage_clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_clear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_clear_label.visible = false
	_hud_layer.add_child(_stage_clear_label)

	# Stage intro banner — flashes in on _ready and hides after a beat.
	_stage_intro_label = Label.new()
	_stage_intro_label.text = STAGE_NAME
	_stage_intro_label.add_theme_font_size_override("font_size", 16)
	_stage_intro_label.add_theme_color_override("font_color", COLOR_TEXT)
	_stage_intro_label.position = Vector2(0.0, 30.0)
	_stage_intro_label.size = Vector2(VIEWPORT_W, 24)
	_stage_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_stage_intro_label)

	# HP bar — anchored to top-left, reads from _player every frame.
	_hp_bar = HpBar.new()
	_hp_bar.player = _player
	_hp_bar.position = Vector2(8.0, 8.0)
	_hp_bar.size = Vector2(140.0, 12.0)
	_hud_layer.add_child(_hp_bar)

	# Coin counter — anchored to top-right, reads Game.coins each frame.
	var coins: CoinCounter = CoinCounter.new()
	coins.position = Vector2(VIEWPORT_W - 64.0, 8.0)
	coins.size = Vector2(60.0, 12.0)
	_hud_layer.add_child(coins)

	# Fade overlay — added last so it sits on top of every other HUD
	# element. Starts opaque (we just transitioned in from black) and
	# tweens to transparent on entry.
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_fade_rect)
	var fade_in: Tween = create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_DURATION)


# Hides the stage-name banner after STAGE_INTRO_DURATION seconds.
func _show_stage_intro() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(STAGE_INTRO_DURATION)
	timer.timeout.connect(_hide_stage_intro)


func _hide_stage_intro() -> void:
	if not is_inside_tree() or _stage_intro_label == null:
		return
	_stage_intro_label.visible = false


func _on_goal_entered(body: Node2D) -> void:
	if _goal_reached:
		return
	if body is Player:
		_goal_reached = true
		_transitioning = true
		var is_new_best: bool = Game.register_clear("stage_1")
		_stage_clear_label.text = "%s\n%s" % [
			_stage_clear_label.text,
			Game.format_score_summary(is_new_best)
		]
		_stage_clear_label.visible = true
		Sfx.play("goal")
		# Hold the banner, then fade to black, then route to stage_2.
		var timer: SceneTreeTimer = get_tree().create_timer(GOAL_DELAY)
		timer.timeout.connect(_fade_out_to_stage_2)


func _fade_out_to_stage_2() -> void:
	if not is_inside_tree():
		return
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(_advance_to_stage_2)


func _advance_to_stage_2() -> void:
	if not is_inside_tree():
		return
	Game.play_cutscene(
		"// JUNKYARD CLEARED",
		PackedStringArray([
			"SECTOR 1 SECURED. SCRAP-BOTS NEUTRALISED.",
			"GRID INTEGRITY: 24%. THE SUBLEVEL HOLDS.",
			"SENTINEL R-08 BLOCKS THE GREEN CORRIDOR.",
			"DESCEND. BURN A PATH THROUGH.",
		]),
		"stage_2"
	)


# Draws a short hint line in the top-left of the world (scrolls with camera).
func _draw_hint(text: String, x: float, y: float) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font, Vector2(x, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_TEXT
	)
