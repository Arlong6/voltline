## Voltline — Stage 7 // LABYRINTH (v0.65).
##
## Multi-room stage demonstrating the new room-based structure.
## Unlocks after Game.architect_cleared. Three distinct chambers
## separated by tall floor-to-ceiling walls and switch+door gates:
##
##   Room A — combat:  clear enemies / shoot the high switch to open
##                     the gate into Room B.
##   Room B — hazards: conveyor → laser → crumbling chain → high
##                     switch on the far wall opens the gate into Room C.
##   Room C — boss:    TYRANT-Z arena. Defeating it sets stage_7_cleared
##                     and returns to title.
##
## Beating Stage 7 sets Game.labyrinth_cleared so the title-screen
## prompt gains a final tier and the achievement page tracks completion.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216
const STAGE_WIDTH: int = 1280

const FLOOR_Y: int = 180
const FLOOR_HEIGHT: int = 36

const COLOR_BG: Color = Color("#02060F")
const COLOR_GROUND: Color = Color("#0E1A2A")
const COLOR_PLATFORM: Color = Color("#2A4870")
const COLOR_WALL: Color = Color("#1A2840")
const COLOR_SEPARATOR: Color = Color("#3A5A80")
const COLOR_GOAL: Color = Color("#FFD24A")
const COLOR_TEXT: Color = Color("#7AC8FF")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const TURRET_SCENE: PackedScene = preload("res://scenes/turret.tscn")
const SHIELDBEARER_SCENE: PackedScene = preload("res://scenes/shieldbearer.tscn")
const SPITTER_SCENE: PackedScene = preload("res://scenes/spitter.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/spike.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/checkpoint.tscn")
const HEAL_STATION_SCENE: PackedScene = preload("res://scenes/heal_station.tscn")
const CONVEYOR_SCENE: PackedScene = preload("res://scenes/conveyor_belt.tscn")
const LASER_SCENE: PackedScene = preload("res://scenes/laser_beam.tscn")
const CRUMBLING_SCENE: PackedScene = preload("res://scenes/crumbling_platform.tscn")
const SWITCH_SCENE: PackedScene = preload("res://scenes/switch_panel.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/door_gate.tscn")
const TYRANT_SCENE: PackedScene = preload("res://scenes/tyrant_z.tscn")

const PLAYER_SPAWN: Vector2 = Vector2(40.0, 160.0)
const CHECKPOINT_POS: Vector2 = Vector2(700.0, 180.0)
const TYRANT_SPAWN: Vector2 = Vector2(1180.0, 156.0)

# Room A — combat
const ROOM_A_PLATFORM: Rect2 = Rect2(220.0, 124.0, 56.0, 8.0)
const ROOM_A_TURRET: Vector2 = Vector2(248.0, 110.0)
const ROOM_A_ENEMIES: Array = [
	# [spawn_x, min_x, max_x]
	[160.0, 100.0, 220.0],
	[340.0, 290.0, 410.0],
]
const ROOM_A_SWITCH_POS: Vector2 = Vector2(424.0, 132.0)
const ROOM_A_DOOR_POS: Vector2 = Vector2(450.0, 160.0)
# Separator wall between Room A and Room B — floor-to-low-ceiling.
const SEPARATOR_AB: Rect2 = Rect2(442.0, 16.0, 16.0, 144.0)

# Room B — hazards
const ROOM_B_CONVEYOR_POS: Vector2 = Vector2(540.0, 168.0)
const ROOM_B_LASER_POS: Vector2 = Vector2(640.0, 144.0)
# PackedFloat32Array constructors aren't constant expressions in GDScript,
# so this lives as a `var` even though it's treated as immutable in code.
static var ROOM_B_CRUMB_X: PackedFloat32Array = PackedFloat32Array([720.0, 776.0, 832.0])
const ROOM_B_CRUMB_Y: float = 140.0
const ROOM_B_SWITCH_POS: Vector2 = Vector2(852.0, 100.0)
const ROOM_B_DOOR_POS: Vector2 = Vector2(890.0, 160.0)
const SEPARATOR_BC: Rect2 = Rect2(882.0, 16.0, 16.0, 144.0)
# Platform inside Room B near the switch so the player has a perch.
const ROOM_B_HIGH_PLATFORM: Rect2 = Rect2(820.0, 116.0, 56.0, 8.0)

# Room C — boss
const ROOM_C_GROUND_OFFSET: float = 886.0

const BOUNDS: Array[Rect2] = [
	Rect2(-16.0, 0.0, 16.0, 216.0),
	Rect2(float(STAGE_WIDTH), 0.0, 16.0, 216.0),
]

const STAGE_NAME: String = "SECTOR 7 // LABYRINTH"
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
var _tyrant: TyrantZ


func _ready() -> void:
	Game.current_area = "stage_7"
	Music.play("boss")  # labyrinth tension
	# Continuous floor across all 3 rooms.
	_build_static_block(Rect2(0.0, FLOOR_Y, STAGE_WIDTH, FLOOR_HEIGHT), &"Floor")
	for i in BOUNDS.size():
		_build_static_block(BOUNDS[i], &"Bound_%d" % i)
	# Room separator walls (visible architectural breaks).
	_build_separator(SEPARATOR_AB, &"SeparatorAB")
	_build_separator(SEPARATOR_BC, &"SeparatorBC")
	# Room A geometry + enemies + switch + door.
	_build_static_block(ROOM_A_PLATFORM, &"RoomA_Platform")
	_spawn_player_with_camera()
	_spawn_room_a()
	# Room B geometry + hazards + switch + door.
	_build_static_block(ROOM_B_HIGH_PLATFORM, &"RoomB_HighPlatform")
	_spawn_room_b()
	# Room C — boss arena.
	_spawn_checkpoint()
	_spawn_tyrant()
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
	# Separators rendered as glowing pillars so each room visually closes off.
	draw_rect(SEPARATOR_AB, COLOR_SEPARATOR)
	draw_rect(SEPARATOR_BC, COLOR_SEPARATOR)
	# Room labels above each chamber so the player reads the structure.
	var font: Font = ThemeDB.fallback_font
	_label("A · COMBAT", 100.0, font)
	_label("B · HAZARD", 600.0, font)
	_label("C · BOSS",  1000.0, font)
	# TYRANT-Z callout.
	draw_string(
		font, Vector2(TYRANT_SPAWN.x - 36.0, TYRANT_SPAWN.y - 56.0),
		"TYRANT-Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GOAL
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


# Separators are visually distinct (drawn in _draw) but otherwise
# identical to other static blocks.
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
	# Two grunts patrolling the floor.
	for entry in ROOM_A_ENEMIES:
		var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
		enemy.position = Vector2(float(entry[0]), 168.0)
		enemy.patrol_min_x = float(entry[1])
		enemy.patrol_max_x = float(entry[2])
		enemy.max_hp = 5
		enemy.walk_speed = 70.0
		add_child(enemy)
	# Turret on the central platform.
	var turret: Turret = TURRET_SCENE.instantiate() as Turret
	turret.position = ROOM_A_TURRET
	add_child(turret)
	# Shieldbearer guarding the corridor — can't be shot from the front,
	# the player has to dash past it or catch its exposed back at a wall.
	var shieldbearer: Shieldbearer = SHIELDBEARER_SCENE.instantiate() as Shieldbearer
	shieldbearer.position = Vector2(400.0, 168.0)
	shieldbearer.patrol_min_x = 320.0
	shieldbearer.patrol_max_x = 420.0
	add_child(shieldbearer)
	# Switch panel high on the right wall + the door blocking the exit.
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
	# Conveyor pushing RIGHT — helps the player traverse to the platforms.
	var conveyor: ConveyorBelt = CONVEYOR_SCENE.instantiate() as ConveyorBelt
	conveyor.position = ROOM_B_CONVEYOR_POS
	conveyor.size = Vector2(64.0, 8.0)
	conveyor.belt_speed = 90.0
	add_child(conveyor)
	# Pulsing laser blocking the corridor mid-room.
	var laser: LaserBeam = LASER_SCENE.instantiate() as LaserBeam
	laser.position = ROOM_B_LASER_POS
	laser.size = Vector2(8.0, 72.0)
	laser.period = 2.2
	laser.on_duty = 0.30
	add_child(laser)
	# Crumbling-platform chain leading up to the switch ledge.
	for i in ROOM_B_CRUMB_X.size():
		var crumb: CrumblingPlatform = CRUMBLING_SCENE.instantiate() as CrumblingPlatform
		crumb.position = Vector2(ROOM_B_CRUMB_X[i], ROOM_B_CRUMB_Y)
		crumb.size = Vector2(48.0, 8.0)
		crumb.step_delay = 0.45
		crumb.shake_duration = 0.3
		add_child(crumb)
	# Spitter on the floor below the crumbling chain — lobs arcing rounds
	# up onto the platforms while the player is mid-climb.
	var spitter: Spitter = SPITTER_SCENE.instantiate() as Spitter
	spitter.position = Vector2(700.0, 170.0)
	add_child(spitter)
	# Switch on the high platform + door at the end of Room B.
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


func _spawn_tyrant() -> void:
	_tyrant = TYRANT_SCENE.instantiate() as TyrantZ
	_tyrant.position = TYRANT_SPAWN
	add_child(_tyrant)
	_tyrant.died.connect(_on_tyrant_defeated)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)

	_stage_clear_label = Label.new()
	_stage_clear_label.text = "LABYRINTH CLEARED"
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

	# Active buff strip (v0.64).
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


func _on_tyrant_defeated() -> void:
	if _goal_reached:
		return
	_goal_reached = true
	_transitioning = true
	Game.labyrinth_cleared = true
	var is_new_best: bool = Game.register_clear("stage_7")
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
	Game.goto_level("title")
