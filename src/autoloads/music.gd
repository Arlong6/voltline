## Voltline — background music autoload (V-013).
##
## Procedurally generated 8-bit-style looped tracks. Each track is a
## fixed melody pattern rendered to an AudioStreamWAV with LOOP_FORWARD
## set, so the AudioStreamPlayer loops it forever once started.
##
## Game.test_mode short-circuits play() so headless GUT runs stay silent.
extends Node

# ---------------------------------------------------------------------------
# Audio constants
# ---------------------------------------------------------------------------

const _SAMPLE_RATE: int = 22050
const _VOLUME_DB: float = -14.0

## Linear 0..1 multiplier applied on top of the base track volume.
## Pause-menu settings tweak this live.
var volume_scale: float = 1.0

# ---------------------------------------------------------------------------
# Note frequency table (Hz). A4 = 440. We mostly stick to A natural minor.
# ---------------------------------------------------------------------------

const A3: float = 220.0
const C4: float = 261.63
const D4: float = 293.66
const E4: float = 329.63
const F4: float = 349.23
const G4: float = 392.0
const A4: float = 440.0
const B4: float = 493.88
const C5: float = 523.25
const E5: float = 659.25
const A2: float = 110.0
const C3: float = 130.81
const E3: float = 164.81
const G3: float = 196.0
const REST: float = 0.0

# ---------------------------------------------------------------------------
# Track bank
# ---------------------------------------------------------------------------

var _tracks: Dictionary[String, AudioStreamWAV] = {}
var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = _VOLUME_DB
	add_child(_player)

	# Title — a calm rising arpeggio loop suggesting "the world before".
	_tracks["title"] = _make_loop(
		[A3, C4, E4, G4, A4, G4, E4, C4],
		0.45, 0.12
	)
	# Stage — driving 8th-note bassline + alternating thirds, urgent feel.
	_tracks["stage"] = _make_loop(
		[A3, A3, C4, E4, A3, G4, E4, C4, A3, A3, D4, F4, A3, G4, F4, D4],
		0.18, 0.14
	)
	# Boss — darker low octave with chromatic colour, intense.
	_tracks["boss"] = _make_loop(
		[A2, C3, E3, A2, A2, G3, E3, C3, A2, C3, E3, G3, A4, G4, E4, C4],
		0.16, 0.16
	)


## Plays the named track. If the same track is already playing this is
## a no-op (so re-entering the same scene doesn't re-trigger the song).
func play(track_name: String) -> void:
	if Game.test_mode:
		return
	var stream: AudioStreamWAV = _tracks.get(track_name)
	if stream == null:
		push_warning("Music.play: unknown track '%s'" % track_name)
		return
	_apply_volume()
	if _player.stream == stream and _player.playing:
		return
	_player.stop()
	_player.stream = stream
	_player.play()


## Re-applies the current volume_scale to the underlying player. Pause
## menu calls this whenever the user drags the music slider.
func apply_volume() -> void:
	if _player == null:
		return
	_apply_volume()


func _apply_volume() -> void:
	if volume_scale <= 0.001:
		_player.volume_db = -80.0
	else:
		_player.volume_db = _VOLUME_DB + linear_to_db(volume_scale)


## Stops the current track immediately.
func stop() -> void:
	if _player != null:
		_player.stop()


# ---------------------------------------------------------------------------
# Synthesis — square-wave melody loop
# ---------------------------------------------------------------------------

# Renders an array of note frequencies (Hz; 0 = rest) into a looping
# AudioStreamWAV. Each note plays for `note_duration` seconds.
func _make_loop(notes: Array, note_duration: float, amplitude: float) -> AudioStreamWAV:
	var note_samples: int = int(note_duration * float(_SAMPLE_RATE))
	var total_samples: int = note_samples * notes.size()
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var fade_samples: int = max(1, _SAMPLE_RATE / 80)
	var phase: float = 0.0

	for n in notes.size():
		var freq: float = float(notes[n])
		var note_offset: int = n * note_samples
		for i in note_samples:
			if freq <= 0.0:
				_write_sample(data, note_offset + i, 0.0)
				continue
			phase += TAU * freq / float(_SAMPLE_RATE)
			var sample: float = (1.0 if sin(phase) > 0.0 else -1.0) * amplitude
			# Per-note attack/decay so adjacent notes don't click into each other.
			var env: float = 1.0
			if i < fade_samples:
				env = float(i) / float(fade_samples)
			elif note_samples - i < fade_samples:
				env = float(note_samples - i) / float(fade_samples)
			sample *= env
			_write_sample(data, note_offset + i, sample)

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = _SAMPLE_RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	return wav


# Writes a 16-bit little-endian sample to the byte buffer at sample index i.
func _write_sample(data: PackedByteArray, i: int, sample: float) -> void:
	var amp: int = int(clampf(sample * 32767.0, -32768.0, 32767.0))
	data[i * 2]     = amp & 0xFF
	data[i * 2 + 1] = (amp >> 8) & 0xFF
