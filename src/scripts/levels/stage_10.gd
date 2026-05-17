## Voltline — Stage 10 // TERMINUS.
##
## Final multi-room stage culminating in AXIS-Ω and the TRUE END clear flag.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216
const STAGE_WIDTH: int = 1600
const FLOOR_Y: int = 180
const FLOOR_HEIGHT: int = 36

const COLOR_BG: Color = Color("#02050A")
const COLOR_GROUND: Color = Color("#08101C")
const COLOR_PLATFORM: Color = Color("#2A3A56")
const COLOR_SEPARATOR: Color = Color("#4A6680")
const COLOR_GOAL: Color = Color("#FFD24A")
const COLOR_TEXT: Color = Color("#9AB4D0")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const CRUMBLING_PLATFORM_SCENE: PackedScene = preload("res://scenes/crumbling_platform.tscn")
const BRUTE_SCENE: PackedScene = preload("res://scenes/brute.tscn")
const DRONE_SCENE: PackedScene = preload("res://scenes/drone.tscn")
const SPITTER_SCENE: PackedScene = preload("res://scenes/spitter.tscn")
const SHIELDBEARER_SCENE: PackedScene = preload("res://scenes/shieldbearer.tscn")
const LANCER_SCENE: PackedScene = preload("res://scenes/lancer.tscn")
const STALKER_SCENE: PackedScene = preload("res://scenes/stalker.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/checkpoint.tscn")
const LASER_SCENE: PackedScene = preload("res://scenes/laser_beam.tscn")
const CRUSHER_SCENE: PackedScene = preload("res://scenes/crusher.tscn")
const AXIS_OMEGA_SCENE: PackedScene = preload("res://scenes/axis_omega.tscn")

const PLAYER_SPAWN: Vector2 = Vector2(50.0, 160.0)
const CHECKPOINT_POS: Vector2 = Vector2(880.0, 180.0)
const BOSS_SPAWN: Vector2 = Vector2(1450.0, 156.0)
const BOSS_ANCHORS: Array[Vector2] = [
	Vector2(1340.0, 100.0),
	Vector2(1560.0, 100.0),
	Vector2(1340.0, 156.0),
	Vector2(1560.0, 156.0),
]

# v0.70.1 — Room A redesigned as a normal corridor with overhead skill
# platforms. The original "vertical descent" geometry trapped the player
# in an unreachable spawn (no platform under x=50) and required a screen
# height the 216px viewport couldn't supply. Crumbling platforms remain
# as optional skill checks the player can jump onto and dive through.
const ROOM_A_LEFT_WALL: Rect2 = Rect2(0.0, 0.0, 8.0, 216.0)
const ROOM_A_FLOOR: Rect2 = Rect2(8.0, 180.0, 392.0, 36.0)
const SEPARATOR_AB: Rect2 = Rect2(400.0, 16.0, 8.0, 144.0)
const ROOM_A_CRUMBLE_SIZE: Vector2 = Vector2(54.0, 8.0)
const ROOM_A_CRUMBLES: Array[Vector2] = [
	Vector2(120.0, 130.0),
	Vector2(220.0, 110.0),
	Vector2(320.0, 130.0),
]

const ROOM_B_FLOOR: Rect2 = Rect2(400.0, 180.0, 500.0, 36.0)
const ROOM_B_PLATFORM: Rect2 = Rect2(560.0, 130.0, 60.0, 8.0)
const ROOM_B_BRUTE_POS: Vector2 = Vector2(440.0, 168.0)
const ROOM_B_DRONE_POS: Vector2 = Vector2(500.0, 80.0)
const ROOM_B_SPITTER_POS: Vector2 = Vector2(640.0, 170.0)
const ROOM_B_SHIELDBEARER_POS: Vector2 = Vector2(600.0, 168.0)
const ROOM_B_LANCER_POS: Vector2 = Vector2(740.0, 168.0)
const ROOM_B_STALKER_POS: Vector2 = Vector2(790.0, 70.0)
const ROOM_B_BRUTE_PATROL: Vector2 = Vector2(440.0, 560.0)
const ROOM_B_DRONE_PATROL: Vector2 = Vector2(460.0, 560.0)
const ROOM_B_SHIELD_PATROL: Vector2 = Vector2(600.0, 740.0)
const ROOM_B_LANCER_PATROL: Vector2 = Vector2(740.0, 880.0)
const ROOM_B_STALKER_PATROL: Vector2 = Vector2(700.0, 880.0)

const ROOM_C_FLOOR: Rect2 = Rect2(900.0, 180.0, 380.0, 36.0)
const ROOM_C_LOW_CEILING: Rect2 = Rect2(1200.0, 168.0, 80.0, 8.0)
const ROOM_C_LASER_SIZE: Vector2 = Vector2(8.0, 72.0)
const ROOM_C_LASER_PERIOD: float = 1.8
const ROOM_C_LASER_DUTY: float = 0.4
const ROOM_C_LASERS: Array[Vector3] = [
	Vector3(940.0, 144.0, 0.0),
	Vector3(1020.0, 144.0, 0.9),
	Vector3(1100.0, 144.0, 1.8),
]
const ROOM_C_CRUSHER_POS: Vector2 = Vector2(1180.0, 50.0)
const CRUSHER_SIZE: Vector2 = Vector2(44.0, 24.0)
const CRUSHER_SLAM_DISTANCE: float = 110.0
const CRUSHER_IDLE_TIME: float = 1.2
const CRUSHER_SLAM_TIME: float = 0.18
const CRUSHER_HOLD_TIME: float = 0.35
const CRUSHER_RETRACT_TIME: float = 0.8

const ROOM_D_FLOOR: Rect2 = Rect2(1280.0, 180.0, 320.0, 36.0)
const SEPARATOR_BC: Rect2 = Rect2(892.0, 16.0, 16.0, 144.0)
const SEPARATOR_CD: Rect2 = Rect2(1272.0, 16.0, 16.0, 144.0)
const BOUNDS: Array[Rect2] = [
	Rect2(-16.0, 0.0, 16.0, 216.0),
	Rect2(float(STAGE_WIDTH), 0.0, 16.0, 216.0),
]

const STAGE_NAME: String = "SECTOR 10 // TERMINUS"
const STAGE_CLEAR_TEXT: String = "TERMINUS — TRUE END"
const BOSS_NAME_TEXT: String = "AXIS-Ω"
const ROOM_A_LABEL: String = "A · DESCENT"
const ROOM_B_LABEL: String = "B · GAUNTLET"
const ROOM_C_LABEL: String = "C · THRESHOLD"
const ROOM_D_LABEL: String = "D · AXIS"
const CURRENT_AREA: String = "stage_10"
const TITLE_LEVEL: String = "title"
const STAGE_KEY: String = "stage_10"
const BOSS_MUSIC: String = "boss"
const GOAL_SFX: String = "goal"

const STAGE_INTRO_DURATION: float = 2.4
const GOAL_DELAY: float = 3.0
const FADE_IN_DURATION: float = 0.5
const FADE_OUT_DURATION: float = 1.2
const CAMERA_SMOOTH_SPEED: float = 8.0
const HUD_LAYER: int = 10
const CLEAR_FONT_SIZE: int = 24
const INTRO_FONT_SIZE: int = 14
const LABEL_FONT_SIZE: int = 10
const BOSS_FONT_SIZE: int = 12
const HP_BAR_WIDTH: float = 140.0
const HP_BAR_HEIGHT: float = 12.0
const HUD_MARGIN: float = 8.0
const COIN_X: float = 320.0
const COIN_WIDTH: float = 60.0
const SPEEDRUN_Y: float = 18.0
const SPEEDRUN_HEIGHT: float = 24.0
const BUFF_Y: float = 24.0
const BUFF_WIDTH: float = 300.0
const BUFF_HEIGHT: float = 14.0
const CLEAR_LABEL_Y: float = 80.0
const CLEAR_LABEL_HEIGHT: float = 56.0
const INTRO_Y: float = 30.0
const INTRO_HEIGHT: float = 24.0
const ROOM_LABEL_Y: float = 28.0
const ROOM_LABEL_OFFSET_X: float = 36.0
const ROOM_A_LABEL_X: float = 115.0
const ROOM_B_LABEL_X: float = 620.0
const ROOM_C_LABEL_X: float = 1040.0
const ROOM_D_LABEL_X: float = 1410.0
const BOSS_LABEL_OFFSET: Vector2 = Vector2(-34.0, -56.0)

var _goal_reached: bool = false
var _transitioning: bool = false
var _hud_layer: CanvasLayer
var _stage_clear_label: Label
var _stage_intro_label: Label
var _fade_rect: ColorRect
var _hp_bar: HpBar
var _player: Player
var _boss: AxisOmega


func _ready() -> void:
	Game.current_area = CURRENT_AREA
	Music.play(BOSS_MUSIC)
	_build_static_block(ROOM_A_LEFT_WALL, &"RoomA_LeftWall")
	_build_static_block(ROOM_A_FLOOR, &"RoomA_Floor")
	_build_static_block(ROOM_B_FLOOR, &"RoomB_Floor")
	_build_static_block(ROOM_C_FLOOR, &"RoomC_Floor")
	_build_static_block(ROOM_D_FLOOR, &"RoomD_Floor")
	_build_static_block(ROOM_B_PLATFORM, &"RoomB_Platform")
	_build_static_block(ROOM_C_LOW_CEILING, &"RoomC_LowCeiling")
	for i in BOUNDS.size():
		_build_static_block(BOUNDS[i], &"Bound_%d" % i)
	_build_separator(SEPARATOR_AB, &"SeparatorAB")
	_build_separator(SEPARATOR_BC, &"SeparatorBC")
	_build_separator(SEPARATOR_CD, &"SeparatorCD")
	_spawn_player_with_camera()
	_spawn_room_a()
	_spawn_room_b()
	_spawn_room_c()
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
				Game.goto_level(TITLE_LEVEL)
		)


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, float(STAGE_WIDTH), float(VIEWPORT_H)), COLOR_BG)
	draw_rect(ROOM_A_FLOOR, COLOR_GROUND)
	draw_rect(ROOM_B_FLOOR, COLOR_GROUND)
	draw_rect(ROOM_C_FLOOR, COLOR_GROUND)
	draw_rect(ROOM_D_FLOOR, COLOR_GROUND)
	draw_rect(ROOM_B_PLATFORM, COLOR_PLATFORM)
	draw_rect(ROOM_C_LOW_CEILING, COLOR_PLATFORM)
	draw_rect(ROOM_A_LEFT_WALL, COLOR_SEPARATOR)
	draw_rect(SEPARATOR_AB, COLOR_SEPARATOR)
	draw_rect(SEPARATOR_BC, COLOR_SEPARATOR)
	draw_rect(SEPARATOR_CD, COLOR_SEPARATOR)
	var font: Font = ThemeDB.fallback_font
	_label(ROOM_A_LABEL, ROOM_A_LABEL_X, font)
	_label(ROOM_B_LABEL, ROOM_B_LABEL_X, font)
	_label(ROOM_C_LABEL, ROOM_C_LABEL_X, font)
	_label(ROOM_D_LABEL, ROOM_D_LABEL_X, font)
	draw_string(font, BOSS_SPAWN + BOSS_LABEL_OFFSET,
		BOSS_NAME_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, BOSS_FONT_SIZE, COLOR_GOAL)


func _label(text: String, x_centre: float, font: Font) -> void:
	draw_string(font, Vector2(x_centre - ROOM_LABEL_OFFSET_X, ROOM_LABEL_Y),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, COLOR_TEXT)


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
	camera.position_smoothing_speed = CAMERA_SMOOTH_SPEED
	_player.add_child(camera)
	camera.make_current()


func _spawn_room_a() -> void:
	for platform_pos in ROOM_A_CRUMBLES:
		var crumble: CrumblingPlatform = CRUMBLING_PLATFORM_SCENE.instantiate() as CrumblingPlatform
		crumble.position = platform_pos
		crumble.size = ROOM_A_CRUMBLE_SIZE
		crumble.color = COLOR_PLATFORM
		add_child(crumble)


func _spawn_room_b() -> void:
	# v0.75 — Drone + Stalker removed. Two airborne harassers on top of
	# four ground threats made GAUNTLET feel cluttered to the playtester;
	# trimming the flying pair leaves the room readable while keeping the
	# four melee/ranged archetypes (Brute / Spitter / Shieldbearer / Lancer).
	var brute: Brute = BRUTE_SCENE.instantiate() as Brute
	brute.position = ROOM_B_BRUTE_POS
	brute.patrol_min_x = ROOM_B_BRUTE_PATROL.x
	brute.patrol_max_x = ROOM_B_BRUTE_PATROL.y
	Game.apply_difficulty_to_enemy(brute)
	add_child(brute)
	var spitter: Spitter = SPITTER_SCENE.instantiate() as Spitter
	spitter.position = ROOM_B_SPITTER_POS
	Game.apply_difficulty_to_enemy(spitter)
	add_child(spitter)
	var shield: Shieldbearer = SHIELDBEARER_SCENE.instantiate() as Shieldbearer
	shield.position = ROOM_B_SHIELDBEARER_POS
	shield.patrol_min_x = ROOM_B_SHIELD_PATROL.x
	shield.patrol_max_x = ROOM_B_SHIELD_PATROL.y
	Game.apply_difficulty_to_enemy(shield)
	add_child(shield)
	var lancer: Lancer = LANCER_SCENE.instantiate() as Lancer
	lancer.position = ROOM_B_LANCER_POS
	lancer.patrol_min_x = ROOM_B_LANCER_PATROL.x
	lancer.patrol_max_x = ROOM_B_LANCER_PATROL.y
	Game.apply_difficulty_to_enemy(lancer)
	add_child(lancer)


func _spawn_room_c() -> void:
	for laser_data in ROOM_C_LASERS:
		var laser: LaserBeam = LASER_SCENE.instantiate() as LaserBeam
		laser.position = Vector2(laser_data.x, laser_data.y)
		laser.size = ROOM_C_LASER_SIZE
		laser.period = ROOM_C_LASER_PERIOD
		laser.on_duty = ROOM_C_LASER_DUTY
		laser.phase = laser_data.z
		add_child(laser)
	var crusher: Crusher = CRUSHER_SCENE.instantiate() as Crusher
	crusher.position = ROOM_C_CRUSHER_POS
	crusher.size = CRUSHER_SIZE
	crusher.slam_distance = CRUSHER_SLAM_DISTANCE
	crusher.idle_time = CRUSHER_IDLE_TIME
	crusher.slam_time = CRUSHER_SLAM_TIME
	crusher.hold_time = CRUSHER_HOLD_TIME
	crusher.retract_time = CRUSHER_RETRACT_TIME
	add_child(crusher)


func _spawn_checkpoint() -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint.position = CHECKPOINT_POS
	add_child(checkpoint)


func _spawn_boss() -> void:
	_boss = AXIS_OMEGA_SCENE.instantiate() as AxisOmega
	_boss.position = BOSS_SPAWN
	_boss.teleport_anchors = BOSS_ANCHORS
	Game.apply_difficulty_to_boss(_boss)
	add_child(_boss)
	_boss.died.connect(_on_boss_defeated)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = HUD_LAYER
	add_child(_hud_layer)
	_stage_clear_label = Label.new()
	_stage_clear_label.text = STAGE_CLEAR_TEXT
	_stage_clear_label.add_theme_font_size_override("font_size", CLEAR_FONT_SIZE)
	_stage_clear_label.add_theme_color_override("font_color", COLOR_GOAL)
	_stage_clear_label.position = Vector2(0.0, CLEAR_LABEL_Y)
	_stage_clear_label.size = Vector2(float(VIEWPORT_W), CLEAR_LABEL_HEIGHT)
	_stage_clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_clear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_clear_label.visible = false
	_hud_layer.add_child(_stage_clear_label)
	_stage_intro_label = Label.new()
	_stage_intro_label.text = STAGE_NAME
	_stage_intro_label.add_theme_font_size_override("font_size", INTRO_FONT_SIZE)
	_stage_intro_label.add_theme_color_override("font_color", COLOR_TEXT)
	_stage_intro_label.position = Vector2(0.0, INTRO_Y)
	_stage_intro_label.size = Vector2(float(VIEWPORT_W), INTRO_HEIGHT)
	_stage_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_stage_intro_label)
	_hp_bar = HpBar.new()
	_hp_bar.player = _player
	_hp_bar.position = Vector2(HUD_MARGIN, HUD_MARGIN)
	_hp_bar.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hud_layer.add_child(_hp_bar)
	var coins: CoinCounter = CoinCounter.new()
	coins.position = Vector2(COIN_X, HUD_MARGIN)
	coins.size = Vector2(COIN_WIDTH, HP_BAR_HEIGHT)
	_hud_layer.add_child(coins)
	var spd_timer: SpeedrunTimer = SpeedrunTimer.new()
	spd_timer.position = Vector2(COIN_X, SPEEDRUN_Y)
	spd_timer.size = Vector2(COIN_WIDTH, SPEEDRUN_HEIGHT)
	_hud_layer.add_child(spd_timer)
	var buff_hud: BuffHud = BuffHud.new()
	buff_hud.position = Vector2(HUD_MARGIN, BUFF_Y)
	buff_hud.size = Vector2(BUFF_WIDTH, BUFF_HEIGHT)
	_hud_layer.add_child(buff_hud)
	Game.add_hard_mode_hud_label(_hud_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = Vector2(float(VIEWPORT_W), float(VIEWPORT_H))
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
	Game.terminus_cleared = true
	var is_new_best: bool = Game.register_clear(STAGE_KEY)
	_stage_clear_label.text = "%s\n%s" % [
		_stage_clear_label.text,
		Game.format_score_summary(is_new_best)
	]
	_stage_clear_label.visible = true
	Sfx.play(GOAL_SFX)
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
	if Game.story_mode:
		Game.play_cutscene("// SYSTEM RESTORED", Game.OUTRO_LINES, TITLE_LEVEL)
	else:
		Game.return_to_base_or_title(STAGE_KEY, true)
