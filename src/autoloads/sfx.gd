## Voltline — sound effects autoload (V-013).
##
## All sounds are procedurally generated AudioStreamWAVs created once on
## _ready(). Using square-wave + envelope synthesis keeps the project
## self-contained — no external audio assets required for v0.2. Each
## stream is mono 16-bit PCM at 22050 Hz, baked into a PackedByteArray.
##
## Game.test_mode short-circuits play() so headless GUT runs stay silent.
extends Node

# ---------------------------------------------------------------------------
# Audio constants
# ---------------------------------------------------------------------------

const _SAMPLE_RATE: int = 22050
const _BIT_DEPTH: int = 16

# ---------------------------------------------------------------------------
# Sound bank
# ---------------------------------------------------------------------------

var _sounds: Dictionary[String, AudioStreamWAV] = {}


func _ready() -> void:
	_sounds["jump"]          = _synth_tone(220.0, 360.0, 0.10, 0.22)
	_sounds["shoot_normal"]  = _synth_tone(720.0, 720.0, 0.04, 0.18)
	_sounds["shoot_charged"] = _synth_tone(440.0, 220.0, 0.18, 0.30)
	_sounds["shoot_super"]   = _synth_tone(330.0, 130.0, 0.30, 0.32)
	_sounds["charge_ready"]  = _synth_tone(880.0, 880.0, 0.09, 0.16)
	_sounds["charge_lv2"]    = _synth_tone(1320.0, 1760.0, 0.18, 0.20)
	_sounds["dash"]          = _synth_noise(0.10, 0.20)
	_sounds["hurt"]          = _synth_tone(180.0,  90.0, 0.16, 0.30)
	_sounds["enemy_hit"]     = _synth_tone(620.0, 380.0, 0.06, 0.18)
	_sounds["enemy_die"]     = _synth_tone(440.0, 110.0, 0.22, 0.30)
	_sounds["explode"]       = _synth_noise(0.30, 0.36)
	_sounds["goal"]          = _synth_tone(523.0, 1047.0, 0.40, 0.22)
	_sounds["shoot_enemy"]   = _synth_tone(140.0, 140.0, 0.10, 0.22)
	_sounds["coin_pickup"]   = _synth_tone(1320.0, 1760.0, 0.08, 0.18)
	_sounds["heal"]          = _synth_tone(660.0, 990.0, 0.18, 0.20)
	_sounds["text_blip"]     = _synth_tone(800.0, 800.0, 0.025, 0.10)


## Linear 0..1 multiplier applied as volume_db on every play. Pause-menu
## settings tweak this live so the SFX bus is independent of music.
var volume_scale: float = 1.0


## Plays a named sound. Silent in test mode. Unknown names are logged and
## ignored — they should be caught by reviewers, not crash gameplay.
func play(sound_name: String) -> void:
	if Game.test_mode:
		return
	var stream: AudioStreamWAV = _sounds.get(sound_name)
	if stream == null:
		push_warning("Sfx.play: unknown sound '%s'" % sound_name)
		return
	# One-shot AudioStreamPlayer that frees itself on finish.
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	# Mute below threshold instead of mapping to -inf dB.
	player.volume_db = -80.0 if volume_scale <= 0.001 else linear_to_db(volume_scale)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


# ---------------------------------------------------------------------------
# Synthesis helpers
# ---------------------------------------------------------------------------

# Square-wave with linear frequency sweep from start_freq → end_freq over
# duration seconds. amplitude in [0, 1]. Adds a short attack/decay envelope
# so clicks don't pop at the boundaries.
func _synth_tone(start_freq: float, end_freq: float, duration: float,
		amplitude: float) -> AudioStreamWAV:
	var num_samples: int = int(duration * float(_SAMPLE_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)

	var fade_samples: int = max(1, _SAMPLE_RATE / 80)
	var phase: float = 0.0

	for i in num_samples:
		var t: float = float(i) / float(_SAMPLE_RATE)
		var freq: float = lerp(start_freq, end_freq, t / duration)
		phase += TAU * freq / float(_SAMPLE_RATE)
		var sample: float = (1.0 if sin(phase) > 0.0 else -1.0) * amplitude
		var env: float = _envelope(i, num_samples, fade_samples)
		sample *= env
		_write_sample(data, i, sample)

	return _build_wav(data)


# White-noise burst with the same attack/decay envelope. Used for dash/whoosh.
func _synth_noise(duration: float, amplitude: float) -> AudioStreamWAV:
	var num_samples: int = int(duration * float(_SAMPLE_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)

	var fade_samples: int = max(1, _SAMPLE_RATE / 80)

	for i in num_samples:
		var sample: float = (randf() * 2.0 - 1.0) * amplitude
		var env: float = _envelope(i, num_samples, fade_samples)
		sample *= env
		_write_sample(data, i, sample)

	return _build_wav(data)


# Linear attack/decay envelope. Returns 1.0 in the middle, ramps from 0
# during the first `fade` samples and back to 0 over the last `fade` samples.
func _envelope(i: int, total: int, fade: int) -> float:
	if i < fade:
		return float(i) / float(fade)
	if total - i < fade:
		return float(total - i) / float(fade)
	return 1.0


# Writes a 16-bit little-endian sample to the byte buffer at sample index i.
func _write_sample(data: PackedByteArray, i: int, sample: float) -> void:
	var amp: int = int(clampf(sample * 32767.0, -32768.0, 32767.0))
	data[i * 2]     = amp & 0xFF
	data[i * 2 + 1] = (amp >> 8) & 0xFF


func _build_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = _SAMPLE_RATE
	wav.data = data
	return wav
