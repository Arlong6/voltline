## v0.62 — SwitchPanel + DoorGate wiring tests.
extends GutTest

const SWITCH_SCRIPT: GDScript = preload("res://scripts/switch_panel.gd")
const DOOR_SCRIPT: GDScript = preload("res://scripts/door_gate.gd")

var switch_panel: SwitchPanel
var door: DoorGate


func before_each() -> void:
	Game.test_mode = true
	switch_panel = SWITCH_SCRIPT.new()
	add_child_autofree(switch_panel)
	door = DOOR_SCRIPT.new()
	add_child_autofree(door)
	switch_panel.triggered.connect(door.open)


func after_each() -> void:
	Game.test_mode = false


# ---------------------------------------------------------------------------
# Switch state
# ---------------------------------------------------------------------------

func test_switch_starts_off() -> void:
	assert_false(switch_panel.is_on,
		"new switch should start in the off state")


func test_trigger_flips_state_on() -> void:
	switch_panel.trigger()
	assert_true(switch_panel.is_on,
		"trigger() should flip the switch on")


func test_trigger_is_idempotent() -> void:
	switch_panel.trigger()
	switch_panel.trigger()
	assert_true(switch_panel.is_on,
		"a second trigger() call must not toggle the switch back off")


# ---------------------------------------------------------------------------
# Door state — driven by switch.triggered → door.open()
# ---------------------------------------------------------------------------

func test_door_starts_closed() -> void:
	assert_false(door.is_open,
		"new door should start closed")


func test_switch_trigger_opens_connected_door() -> void:
	switch_panel.trigger()
	assert_true(door.is_open,
		"connecting switch.triggered → door.open should open the door on trigger")


func test_door_open_is_idempotent() -> void:
	door.open()
	door.open()
	assert_true(door.is_open,
		"opening an already-open door should be a safe no-op")
