class_name SoundBoard
extends Node
## Every sound the game makes. The sounds in audio/ are synthesised
## placeholders (see tools/make_sounds.py). Replace any of them with a real
## recording of the same name and it will be used instead.
##
## Voices: there are none yet, but there is a place for them. If a file
## named audio/voice/<id>.wav (or .ogg or .mp3) exists, say(id) plays it.
## The ids the game asks for are listed in audio/voice/README.md.

const DIR := "res://audio/"
const VOICE_DIR := "res://audio/voice/"
const VOICE_TYPES: Array[String] = [".wav", ".ogg", ".mp3"]

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _voice: AudioStreamPlayer
var _sea: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _creak_wait: float = 6.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	_sea = _loop("sea_loop")
	_wind = _loop("wind_loop")


## Plays a one-off sound by file name (without ".wav").
func play(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _stream(DIR + id + ".wav")
	if stream == null:
		return
	for player in _pool:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.pitch_scale = pitch
			player.play()
			return


## Plays a recorded voice line if one has been added. Returns whether it did.
func say(id: String) -> bool:
	for ending in VOICE_TYPES:
		var stream := _stream(VOICE_DIR + id + ending)
		if stream != null:
			_voice.stream = stream
			_voice.play()
			return true
	return false


## Sets the background sound of sea and wind. All three run 0..1 or so.
func set_ambience(wind_strength: float, ship_speed: float, sea_state: float) -> void:
	if _sea != null:
		_sea.volume_db = lerpf(-22.0, -9.0, clampf(0.25 + ship_speed / 12.0 + 0.5 * sea_state, 0.0, 1.0))
		_sea.pitch_scale = lerpf(0.9, 1.15, clampf(ship_speed / 10.0, 0.0, 1.0))
	if _wind != null:
		var blow := clampf((wind_strength - 3.0) / 14.0, 0.0, 1.0)
		_wind.volume_db = lerpf(-30.0, -8.0, blow)
		_wind.pitch_scale = lerpf(0.85, 1.25, blow)

	# The ship's timbers work harder in a seaway.
	_creak_wait -= get_process_delta_time() * (1.0 + 2.5 * sea_state)
	if _creak_wait <= 0.0:
		_creak_wait = _rng.randf_range(4.0, 11.0)
		play("creak_%d" % _rng.randi_range(1, 3), -14.0, _rng.randf_range(0.85, 1.15))


func _loop(id: String) -> AudioStreamPlayer:
	var stream := _stream(DIR + id + ".wav")
	if stream == null:
		return null
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -30.0
	add_child(player)
	player.play()
	return player


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	_streams[path] = stream
	return stream
