## Voltline — Stage 8 // CIRCUIT (v0.67).
##
## The v0.67 endgame stage. Same multi-room structure as Stage 7 but
## the elements are remixed around the new v0.66/v0.67 toys:
##
##   Room A — LATTICE:  two Shieldbearers + a Spitter behind a switch
##                      gate. The shields force flanking; the Spitter's
##                      arcing rounds rain down on the open floor.
##   Room B — TURBINE:  pulsing laser pair + crusher + moving platform
##                      hop train. The switch lives over the laser pair
##                      so timing matters.
##   Room C — CORE:     GRID-0 rematch. Beating it sets circuit_cleared.
##
## Unlocked after Game.labyrinth_cleared; clearing flips circuit_cleared
## so the title prompt gains the v0.67 victory tier.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216
const STAGE_WIDTH: int = 1280

const FLOOR_Y: int = 180
const FLOOR_HEIGHT: int = 36

const COLOR_BG: Color = Color("#040A18")
const COLOR_GROUND: Color = Color("#10222A")
const COLOR_PLATFORM: Color = Color("#3A5C82")
const COLOR_WALL: Color = Color("#1A3040")
const COLOR_SEPARATOR: Color = Color("#3F7AAA")
const COLOR_GOAL: Color = Color("#FFD24A")
const COLOR_TEXT: Color = Color("#80E0FF")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const SHIELDBEARER_SCENE: PackedScene = preload("res://scenes/shieldbearer.tscn")
const SPITTER_SCENE: PackedScene = preload("res://scenes/spitter.tscn")
const STALKER_SCENE: PackedScene = preload("res://scenes/stalker.tscn")
const LANCER_SCENE: PackedScene = preload("res://scenes/lancer.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/checkpoint.tscn")
const LASER_SCENE: PackedScene = preload("res://scenes/laser_beam.tscn")
const CRUSHER_SCENE: PackedScene = preload("res://scenes/crusher.tscn")
const MOVING_PLATFORM_SCENE: PackedScene = preload("res://scenes/moving_platform.tscn")
const SWITCH_SCENE: PackedScene = preload("res://scenes/switch_panel.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/door_gate.tscn")
const GRID_ZERO_SCENE: PackedScene = preload("res://scenes/grid_zero.tscn")

const PLAYER_SPAWN: Vector2 = Vector2(40.0, 160.0)
const CHECKPOINT_POS: Vector2 = Vector2(720.0, 180.0)
const BOSS_SPAWN: Vector2 = Vector2(1180.0, 156.0)

# Room A — LATTICE
const ROOM_A_PLATFORM: Rect2 = Rect2(180.0, 130.0, 70.0, 8.0)
const ROOM_A_SHIELDBEARER_POS: Array = [
	# [spawn_x, min_x, max_x]
	[140.0, 100.0, 250.0],
	[340.0, 280.0, 420.0],
]
const ROOM_A_SPITTER_POS: Vector2 = Vector2(310.0, 170.0)
const ROOM_A_SWITCH_POS: Vector2 = Vector2(420.0, 100.0)
const ROOM_A_DOOR_POS: Vector2 = Vector2(450.0, 160.0)
const SEPARATOR_AB: Rect2 = Rect2(442.0, 16.0, 16.0, 144.0)

# Room B — TURBINE
const ROOM_B_LASER_1_POS: Vector2 = Vector2(540.0, 144.0)
const ROOM_B_LASER_2_POS: Vector2 = Vector2(620.0, 144.0)
const ROOM_B_CRUSHER_POS: Vector2 = Vector2(750.0, 50.0)
const ROOM_B_MOVING_PLATFORM_POS: Vector2 = Vector2(820.0, 140.0)
const ROOM_B_SWITCH_POS: Vector2 = Vector2(860.0, 96.0)
const ROOM_B_HIGH_PLATFORM: Rect2 = Rect2(820.0, 110.0, 56.0, 8.0)
const ROOM_B_DOOR_POS: Vector2 = Vector2(890.0, 160.0)
const SEPARATOR_BC: Rect2 = Rect2(882.0, 16.0, 16.0, 144.0)

const BOUNDS: Array[Rect2] = [
	Rect2(-16.0, 0.0, 16.0, 216.0),
	Rect2(float(STAGE_WIDTH), 0.0, 16.0, 216.0),
]

const STAGE_NAME: String = "SECTOR 8 // CIRCUIT"
const STAGE_INTRO_DURATION: float = 2.4
const GOAL_DELAY: float = 3.0

const FADE_IN_DURATION: float = 0.5
const FADE_OUT_DURATION: float = 1.2

var _goal_reached: bool = false
var _transitioning: bool = false
var _hud_layer: CanvasLayer
var _stage_clear_label: Label
var _stage_intro_label: Label
var _fade_rect: ColorRect
var _hp_bar: HpBar
var _player: Player
var _boss: GridZero


func _ready() -> void:
	Game.current_area = "stage_8"
	Music.play("boss")
	# Continuous floor.
	_build_static_block(Rect2(0.0, FLOOR_Y, STAGE_WIDTH, FLOOR_HEIGHT), &"Floor")
	for i in BOUNDS.size():
		_build_static_block(BOUNDS[i], &"Bound_%d" % i)
	_build_separator(SEPARATOR_AB, &"SeparatorAB")
	_build_separator(SEPARATOR_BC, &"SeparatorBC")
	_build_static_block(ROOM_A_PLATFORM, &"RoomA_Platform")
	_build_static_block(ROOM_B_HIGH_PLATFORM, &"RoomB_HighPlatform")
	_spawn_player_with_camera()
	_spawn_room_a()
	_spawn_room_b()
	_spawn_checkpoint()
	_spawn_boss()
	_build_hud()
	_show_stage_intro()


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
	draw_rect(Rect2(0, FLOOR_Y, STAGE_WIDTH, FLOOR_HEIGHT), COLOR_GROUND)
	draw_rect(ROOM_A_PLATFORM, COLOR_PLATFORM)
	draw_rect(ROOM_B_HIGH_PLATFORM, COLOR_PLATFORM)
	draw_rect(SEPARATOR_AB, COLOR_SEPARATOR)
	draw_rect(SEPARATOR_BC, COLOR_SEPARATOR)
	var font: Font = ThemeDB.fallback_font
	_label("A · LATTICE", 120.0, font)
	_label("B · TURBINE", 620.0, font)
	_label("C · CORE",   1020.0, font)
	draw_string(
		font, Vector2(BOSS_SPAWN.x - 28.0, BOSS_SPAWN.y - 56.0),
		"GRID-0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GOAL
	)


func _label(text: String, x_centre: float, font: Font) -> void:
	draw_string(font, Vector2(x_centre - 30.0, 28.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_TEXT)


# ---------------------------------------------------------------------------
# Build helpers
# ---------------------------------------------------------------------------

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


func _build_separator(rect: Rect2, body_name: StringName) -> void:
	_build_static_block(rect, body_name)


func _spawn_player_with_camera() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = PLAYER_SPAWN
	Game.apply_upgrades_to(_player)
	add_child(_player)
	var camera: Camera2D = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = STAGE_WIDTH
	camera.limit_top = 0
	camera.limit_bottom = VIEWPORT_H
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	_player.add_child(camera)
	camera.make_current()


func _spawn_room_a() -> void:
	# Two shieldbearers patrolling tight corridors — flank or wait them out.
	for entry in ROOM_A_SHIELDBEARER_POS:
		var sb: Shieldbearer = SHIELDBEARER_SCENE.instantiate() as Shieldbearer
		sb.position = Vector2(float(entry[0]), 168.0)
		sb.patrol_min_x = float(entry[1])
		sb.patrol_max_x = float(entry[2])
		sb.max_hp = 6
		add_child(sb)
	# One Spitter behind them lobbing arcing fire over the platform.
	var spitter: Spitter = SPITTER_SCENE.instantiate() as Spitter
	spitter.position = ROOM_A_SPITTER_POS
	add_child(spitter)
	# v0.68 — a Lancer guards the door corner; telegraphs then commits.
	var lancer: Lancer = LANCER_SCENE.instantiate() as Lancer
	lancer.position = Vector2(400.0, 168.0)
	lancer.patrol_min_x = 340.0
	lancer.patrol_max_x = 430.0
	add_child(lancer)
	# Switch on the high wall — must be hit with a charged shot or wave.
	var switch_panel: SwitchPanel = SWITCH_SCENE.instantiate() as SwitchPanel
	switch_panel.position = ROOM_A_SWITCH_POS
	add_child(switch_panel)
	var door: DoorGate = DOOR_SCENE.instantiate() as DoorGate
	door.position = ROOM_A_DOOR_POS
	door.size = Vector2(8.0, 40.0)
	door.open_drop = 40.0
	add_child(door)
	switch_panel.triggered.connect(door.open)


func _spawn_room_b() -> void:
	# Two staggered pulsing lasers — opposite duty cycles so the player
	# has a narrow safe window only when both lapse at once.
	var laser_a: LaserBeam = LASER_SCENE.instantiate() as LaserBeam
	laser_a.position = ROOM_B_LASER_1_POS
	laser_a.size = Vector2(8.0, 72.0)
	laser_a.period = 2.0
	laser_a.on_duty = 0.35
	add_child(laser_a)
	var laser_b: LaserBeam = LASER_SCENE.instantiate() as LaserBeam
	laser_b.position = ROOM_B_LASER_2_POS
	laser_b.size = Vector2(8.0, 72.0)
	laser_b.period = 2.0
	laser_b.on_duty = 0.35
	laser_b.phase = 1.0  # 1.0s offset → opposite half of period_a
	add_child(laser_b)
	# Crusher slamming the floor between the lasers and the platform.
	var crusher: Crusher = CRUSHER_SCENE.instantiate() as Crusher
	crusher.position = ROOM_B_CRUSHER_POS
	crusher.size = Vector2(40.0, 24.0)
	crusher.slam_distance = 110.0
	crusher.idle_time = 1.4
	crusher.slam_time = 0.18
	crusher.hold_time = 0.4
	crusher.retract_time = 0.9
	add_child(crusher)
	# Moving platform shuttling a perch up to the switch ledge.
	var mp: MovingPlatform = MOVING_PLATFORM_SCENE.instantiate() as MovingPlatform
	mp.position = ROOM_B_MOVING_PLATFORM_POS
	mp.size = Vector2(48.0, 8.0)
	mp.travel = Vector2(0.0, -28.0)
	mp.period = 2.6
	add_child(mp)
	# v0.68 — a Stalker hovers in Room B harassing the laser-window run.
	var stalker: Stalker = STALKER_SCENE.instantiate() as Stalker
	stalker.position = Vector2(700.0, 80.0)
	stalker.hover_offset_y = -56.0
	add_child(stalker)
	# Switch + exit door.
	var switch_panel: SwitchPanel = SWITCH_SCENE.instantiate() as SwitchPanel
	switch_panel.position = ROOM_B_SWITCH_POS
	add_child(switch_panel)
	var door: DoorGate = DOOR_SCENE.instantiate() as DoorGate
	door.position = ROOM_B_DOOR_POS
	door.size = Vector2(8.0, 40.0)
	door.open_drop = 40.0
	add_child(door)
	switch_panel.triggered.connect(door.open)


func _spawn_checkpoint() -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint.position = CHECKPOINT_POS
	add_child(checkpoint)


func _spawn_boss() -> void:
	_boss = GRID_ZERO_SCENE.instantiate() as GridZero
	_boss.position = BOSS_SPAWN
	add_child(_boss)
	_boss.died.connect(_on_boss_defeated)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)

	_stage_clear_label = Label.new()
	_stage_clear_label.text = "CIRCUIT BROKEN"
	_stage_clear_label.add_theme_font_size_override("font_size", 24)
	_stage_clear_label.add_theme_color_override("font_color", COLOR_GOAL)
	_stage_clear_label.position = Vector2(0.0, float(VIEWPORT_H - 56) * 0.5)
	_stage_clear_label.size = Vector2(VIEWPORT_W, 56)
	_stage_clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_clear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_clear_label.visible = false
	_hud_layer.add_child(_stage_clear_label)

	_stage_intro_label = Label.new()
	_stage_intro_label.text = STAGE_NAME
	_stage_intro_label.add_theme_font_size_override("font_size", 14)
	_stage_intro_label.add_theme_color_override("font_color", COLOR_TEXT)
	_stage_intro_label.position = Vector2(0.0, 30.0)
	_stage_intro_label.size = Vector2(VIEWPORT_W, 24)
	_stage_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_stage_intro_label)

	_hp_bar = HpBar.new()
	_hp_bar.player = _player
	_hp_bar.position = Vector2(8.0, 8.0)
	_hp_bar.size = Vector2(140.0, 12.0)
	_hud_layer.add_child(_hp_bar)

	var coins: CoinCounter = CoinCounter.new()
	coins.position = Vector2(VIEWPORT_W - 64.0, 8.0)
	coins.size = Vector2(60.0, 12.0)
	_hud_layer.add_child(coins)

	# v0.68 — speedrun timer (current time vs PB) tucked under the coin counter.
	var spd_timer: SpeedrunTimer = SpeedrunTimer.new()
	spd_timer.position = Vector2(VIEWPORT_W - 64.0, 18.0)
	spd_timer.size = Vector2(60.0, 24.0)
	_hud_layer.add_child(spd_timer)

	var buff_hud: BuffHud = BuffHud.new()
	buff_hud.position = Vector2(8.0, 24.0)
	buff_hud.size = Vector2(300.0, 14.0)
	_hud_layer.add_child(buff_hud)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_fade_rect)
	var fade_in: Tween = create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_DURATION)


func _show_stage_intro() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(STAGE_INTRO_DURATION)
	timer.timeout.connect(_hide_stage_intro)


func _hide_stage_intro() -> void:
	if not is_inside_tree() or _stage_intro_label == null:
		return
	_stage_intro_label.visible = false


func _on_boss_defeated() -> void:
	if _goal_reached:
		return
	_goal_reached = true
	_transitioning = true
	Game.circuit_cleared = true
	var is_new_best: bool = Game.register_clear("stage_8")
	_stage_clear_label.text = "%s\n%s" % [
		_stage_clear_label.text,
		Game.format_score_summary(is_new_best)
	]
	_stage_clear_label.visible = true
	Sfx.play("goal")
	var timer: SceneTreeTimer = get_tree().create_timer(GOAL_DELAY)
	timer.timeout.connect(_fade_out_to_title)


func _fade_out_to_title() -> void:
	if not is_inside_tree():
		return
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(_return_to_title)


func _return_to_title() -> void:
	if not is_inside_tree():
		return
	Game.return_to_base_or_title("stage_8", true)
