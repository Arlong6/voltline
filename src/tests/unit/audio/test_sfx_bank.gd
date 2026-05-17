extends GutTest


func test_every_sfx_play_call_uses_a_known_sound() -> void:
	var unknown: PackedStringArray = PackedStringArray()
	_scan_for_sfx_calls("res://scripts", unknown)
	assert_eq(unknown.size(), 0,
		"Sfx.play() called with unknown sound name(s): %s" % str(unknown))


func test_every_music_play_call_uses_a_known_track() -> void:
	var unknown: PackedStringArray = PackedStringArray()
	_scan_for_music_calls("res://scripts", unknown)
	assert_eq(unknown.size(), 0,
		"Music.play() called with unknown track name(s): %s" % str(unknown))


func _scan_for_sfx_calls(path: String, unknown: PackedStringArray) -> void:
	var regex: RegEx = RegEx.new()
	regex.compile("Sfx\\.play\\(\"([^\"]+)\"\\)")
	_scan_for_calls(path, regex, Sfx._sounds.keys(), unknown)


func _scan_for_music_calls(path: String, unknown: PackedStringArray) -> void:
	var regex: RegEx = RegEx.new()
	regex.compile("Music\\.play\\(\"([^\"]+)\"\\)")
	_scan_for_calls(path, regex, Music._tracks.keys(), unknown)


func _scan_for_calls(
	path: String,
	regex: RegEx,
	known_names: Array[String],
	unknown: PackedStringArray
) -> void:
	var dir: DirAccess = DirAccess.open(path)
	assert_not_null(dir, "Expected readable script directory: %s" % path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		var entry_path: String = path.path_join(entry_name)
		if dir.current_is_dir():
			if not entry_name.begins_with("."):
				_scan_for_calls(entry_path, regex, known_names, unknown)
		elif entry_name.ends_with(".gd"):
			_scan_file_for_calls(entry_path, regex, known_names, unknown)
		entry_name = dir.get_next()
	dir.list_dir_end()


func _scan_file_for_calls(
	path: String,
	regex: RegEx,
	known_names: Array[String],
	unknown: PackedStringArray
) -> void:
	var source: String = FileAccess.get_file_as_string(path)
	for result in regex.search_all(source):
		var call_name: String = result.get_string(1)
		if not known_names.has(call_name):
			unknown.append("%s: %s" % [path, call_name])
