## Voltline — single-screen story hub.
extends Node2D

const VIEWPORT_W: int = 384
const VIEWPORT_H: int = 216
const BG_COLOR: Color = Color("#0A1428")
const GROUND_COLOR: Color = Color("#16243A")
const WALL_COLOR: Color = Color("#2A3F60")
const TERMINAL_OFF_COLOR: Color = Color("#4060A0")
const TERMINAL_ON_COLOR: Color = Color("#FFD24A")
const COLOR_TEXT: Color = Color("#A8D8FF")
const COLOR_PROMPT: Color = Color("#F2F2F2")
const COLOR_ECHO: Color = Color("#A060FF")
const COLOR_AKI: Color = Color("#FFD24A")
const COLOR_NIX: Color = Color("#43D27A")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const PLAYER_SPAWN: Vector2 = Vector2(50.0, 160.0)
const FLOOR_Y: float = 180.0
const FLOOR_HEIGHT: float = 36.0
const WALL_WIDTH: float = 8.0
const NPC_SIZE: Vector2 = Vector2(14.0, 24.0)
const NPC_COLLISION_SIZE: Vector2 = Vector2(28.0, 32.0)
const NPC_Y: float = 156.0
const ECHO_POS: Vector2 = Vector2(60.0, NPC_Y)
const AKI_POS: Vector2 = Vector2(192.0, NPC_Y)
const NIX_POS: Vector2 = Vector2(320.0, NPC_Y)
const INTERACT_RADIUS: float = 28.0
const TERMINAL_COUNT: int = 10
const TERMINAL_SIZE: Vector2 = Vector2(12.0, 12.0)
const TERMINAL_START_X: float = 64.0
const TERMINAL_Y: float = 110.0
const TERMINAL_GAP: float = 26.0
const PROMPT_OFFSET: Vector2 = Vector2(-4.0, -30.0)
const HUD_MARGIN: Vector2 = Vector2(10.0, 10.0)
const HUD_TITLE_SIZE: int = 14
const HUD_HINT_SIZE: int = 9
const LOCK_MESSAGE_DURATION: float = 1.1

const ECHO_LINES: PackedStringArray = [
	"我是 ECHO，這個基地的檔案管理員。",
	"那些失控的 boss 原本都是這個系統的子模組。",
	"R-08 是巡邏程式、OMEGA-X 管權限、GRID-0 是 AI 核心...",
	"最深處的 AXIS-Ω 才是真正出問題的東西。",
	"小心點，process。",
]

const AKI_LINES: PackedStringArray = [
	"歡迎回來。",
	"目前所有合法 process 只剩你還在跑。",
	"每清掉一個 sector，網路就能多撐一天。",
	"走那邊的終端機進入下一個 sector。",
	"我會看著你的執行緒。",
]

const NIX_LINES: PackedStringArray = [
	"嘿，process。需要換個外觀？",
	"我這邊還有些之前 dump 出來的 skin 資料。",
	"打 boss 撿到的 coin 可以用來解鎖。",
	"記得，外觀不影響你的 hitbox，純粹是給自己看的。",
	"想看看現在有什麼？按 X 切到 skin 選單。（skin shop 改建中）",
]

var _nearby_npc: String = ""
var _player: Player
var _prompt_label: Label
var _message_label: Label
var _message_timer: float = 0.0
var _nearby_terminal_index: int = -1
var _terminal_lights: Array[ColorRect] = []
var _npc_positions: Dictionary[String, Vector2] = {
	"ECHO": ECHO_POS,
	"AKI": AKI_POS,
	"NIX": NIX_POS,
}


func _ready() -> void:
	Game.current_area = "base"
	Music.play("title")
	_build_static_block(Rect2(0.0, FLOOR_Y, float(VIEWPORT_W), FLOOR_HEIGHT), &"Floor")
	_build_static_block(Rect2(0.0, 0.0, WALL_WIDTH, float(VIEWPORT_H)), &"LeftWall")
	_build_static_block(Rect2(float(VIEWPORT_W) - WALL_WIDTH, 0.0, WALL_WIDTH, float(VIEWPORT_H)), &"RightWall")
	_spawn_player()
	_build_npc("ECHO", ECHO_POS, COLOR_ECHO)
	_build_npc("AKI", AKI_POS, COLOR_AKI)
	_build_npc("NIX", NIX_POS, COLOR_NIX)
	_build_terminals()
	_build_hud()
	_process_interactions()


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer = maxf(_message_timer - delta, 0.0)
		if _message_timer <= 0.0:
			_message_label.visible = false
	_process_interactions()
	_refresh_terminal_lights()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		Game.story_mode = false
		Game.goto_level("title")
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("shoot"):
		get_viewport().set_input_as_handled()
		if _nearby_npc != "":
			_interact_with_npc(_nearby_npc)
		elif _nearby_terminal_index > 0:
			interact_with_terminal(_nearby_terminal_index)


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, float(VIEWPORT_W), float(VIEWPORT_H)), BG_COLOR)
	draw_rect(Rect2(0.0, FLOOR_Y, float(VIEWPORT_W), FLOOR_HEIGHT), GROUND_COLOR)
	draw_rect(Rect2(0.0, 0.0, WALL_WIDTH, float(VIEWPORT_H)), WALL_COLOR)
	draw_rect(Rect2(float(VIEWPORT_W) - WALL_WIDTH, 0.0, WALL_WIDTH, float(VIEWPORT_H)), WALL_COLOR)


## Recomputes the nearest NPC/terminal prompt target from the player position.
func _process_interactions() -> void:
	_nearby_npc = ""
	_nearby_terminal_index = -1
	if _player == null:
		return
	var best_npc_distance: float = INTERACT_RADIUS
	for npc_name in _npc_positions.keys():
		var dist: float = _player.position.distance_to(_npc_positions[String(npc_name)])
		if dist <= best_npc_distance:
			best_npc_distance = dist
			_nearby_npc = String(npc_name)
	var best_terminal_distance: float = INTERACT_RADIUS
	for index in range(1, TERMINAL_COUNT + 1):
		var terminal_pos: Vector2 = _terminal_position(index)
		var dist: float = _player.position.distance_to(terminal_pos)
		if dist <= best_terminal_distance:
			best_terminal_distance = dist
			_nearby_terminal_index = index
	if _nearby_npc != "":
		_show_prompt(_npc_positions[_nearby_npc])
	elif _nearby_terminal_index > 0:
		_show_prompt(_terminal_position(_nearby_terminal_index))
	else:
		_prompt_label.visible = false


## Attempts to enter the numbered stage terminal. Locked terminals stay in base.
func interact_with_terminal(index: int) -> void:
	if index < 1 or index > TERMINAL_COUNT:
		return
	var stage_key: String = "stage_%d" % index
	if not Game.is_stage_unlocked(stage_key):
		_show_message("LOCKED")
		Sfx.play("enemy_hit")
		return
	Game.reset_run()
	Game.goto_level(stage_key)


func _interact_with_npc(npc_name: String) -> void:
	if Game.npcs_seen.find(npc_name) < 0:
		Game.npcs_seen.append(npc_name)
	match npc_name:
		"ECHO":
			Game.play_cutscene("ECHO // ARCHIVE", ECHO_LINES, "base")
		"AKI":
			Game.play_cutscene("AKI // COMMAND", AKI_LINES, "base")
		"NIX":
			Game.play_cutscene("NIX // TECH", NIX_LINES, "skin_shop")


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = PLAYER_SPAWN
	Game.apply_upgrades_to(_player)
	add_child(_player)
	var camera: Camera2D = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = VIEWPORT_W
	camera.limit_top = 0
	camera.limit_bottom = VIEWPORT_H
	_player.add_child(camera)
	camera.make_current()


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


func _build_npc(npc_name: String, npc_pos: Vector2, color: Color) -> void:
	var area: Area2D = Area2D.new()
	area.name = StringName(npc_name)
	area.position = npc_pos
	area.collision_layer = 0
	area.collision_mask = 2
	add_child(area)
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = NPC_COLLISION_SIZE
	collider.shape = shape
	area.add_child(collider)
	var body: ColorRect = ColorRect.new()
	body.color = color
	body.position = -NPC_SIZE * 0.5
	body.size = NPC_SIZE
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(body)


func _build_terminals() -> void:
	for index in range(1, TERMINAL_COUNT + 1):
		var light: ColorRect = ColorRect.new()
		light.name = "Terminal_%d" % index
		light.position = _terminal_position(index) - TERMINAL_SIZE * 0.5
		light.size = TERMINAL_SIZE
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(light)
		_terminal_lights.append(light)
	_refresh_terminal_lights()


func _build_hud() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var title: Label = Label.new()
	title.text = "BASE"
	title.add_theme_font_size_override("font_size", HUD_TITLE_SIZE)
	title.add_theme_color_override("font_color", TERMINAL_ON_COLOR)
	title.position = HUD_MARGIN
	title.size = Vector2(100.0, 18.0)
	hud.add_child(title)
	var hint: Label = Label.new()
	hint.text = "X = INTERACT / R = TITLE"
	hint.add_theme_font_size_override("font_size", HUD_HINT_SIZE)
	hint.add_theme_color_override("font_color", COLOR_TEXT)
	hint.position = Vector2(HUD_MARGIN.x, HUD_MARGIN.y + 16.0)
	hint.size = Vector2(180.0, 14.0)
	hud.add_child(hint)
	_prompt_label = Label.new()
	_prompt_label.text = "X"
	_prompt_label.add_theme_font_size_override("font_size", HUD_TITLE_SIZE)
	_prompt_label.add_theme_color_override("font_color", COLOR_PROMPT)
	_prompt_label.size = Vector2(24.0, 18.0)
	_prompt_label.visible = false
	hud.add_child(_prompt_label)
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", HUD_TITLE_SIZE)
	_message_label.add_theme_color_override("font_color", COLOR_PROMPT)
	_message_label.position = Vector2(0.0, 76.0)
	_message_label.size = Vector2(float(VIEWPORT_W), 24.0)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.visible = false
	hud.add_child(_message_label)


func _show_prompt(world_pos: Vector2) -> void:
	_prompt_label.position = world_pos + PROMPT_OFFSET
	_prompt_label.visible = true


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = true
	_message_timer = LOCK_MESSAGE_DURATION


func _refresh_terminal_lights() -> void:
	for i in _terminal_lights.size():
		var stage_key: String = "stage_%d" % (i + 1)
		_terminal_lights[i].color = TERMINAL_ON_COLOR if Game.is_stage_unlocked(stage_key) else TERMINAL_OFF_COLOR


func _terminal_position(index: int) -> Vector2:
	return Vector2(TERMINAL_START_X + float(index - 1) * TERMINAL_GAP, TERMINAL_Y)
