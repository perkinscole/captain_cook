class_name Weather
extends Node
## Basic weather: fair spells broken by squalls and the odd bank of mist.
## It drives the Wind and publishes a few plain numbers (visibility, gloom,
## sea_state) that other systems read. It does not touch the ship directly.

signal changed(state: State)

enum State { FAIR, BUILDING, SQUALL, CLEARING, MIST }

const STATE_NAMES: Array[String] = [
	"Fair", "Squall making up to windward", "Squall", "Clearing", "Mist",
]

# What each state does: [wind scale, gustiness, visibility, gloom, sea state]
const EFFECTS: Array[Array] = [
	[1.0, 0.08, 1.0, 0.0, 0.0],    # FAIR
	[1.15, 0.15, 0.9, 0.45, 0.25], # BUILDING
	[1.7, 0.30, 0.45, 0.85, 1.0],  # SQUALL
	[1.2, 0.15, 0.8, 0.35, 0.6],   # CLEARING
	[0.6, 0.03, 0.4, 0.30, 0.0],   # MIST
]
const SETTLE_SECONDS := 6.0  ## how quickly conditions ease into a new state

var wind: Wind

var state: State = State.FAIR
var visibility: float = 1.0  ## 1 = clear, lower = you see less far
var gloom: float = 0.0       ## 0 = bright day, 1 = dark squall sky
var sea_state: float = 0.0   ## 0 = easy swell, 1 = steep sea

var _time_left: float = 75.0  # the first fair spell, long enough to get going
var _shift_target: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func state_name() -> String:
	return STATE_NAMES[state]


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		_advance()

	var e: Array = EFFECTS[state]
	var k := 1.0 - exp(-delta / SETTLE_SECONDS)
	visibility = lerpf(visibility, e[2], k)
	gloom = lerpf(gloom, e[3], k)
	sea_state = lerpf(sea_state, e[4], k)
	if wind != null:
		wind.strength_scale = lerpf(wind.strength_scale, e[0], k)
		wind.gustiness = lerpf(wind.gustiness, e[1], k)
		wind.shift_deg = lerpf(wind.shift_deg, _shift_target, k)


func _advance() -> void:
	match state:
		State.FAIR:
			if _rng.randf() < 0.3:
				_enter(State.MIST, _rng.randf_range(45.0, 70.0))
			else:
				_enter(State.BUILDING, 25.0)
		State.BUILDING:
			# A squall often brings a sharp change in the wind's direction.
			_shift_target = _rng.randf_range(25.0, 45.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
			_enter(State.SQUALL, _rng.randf_range(40.0, 60.0))
		State.SQUALL:
			_enter(State.CLEARING, 25.0)
		_:
			_shift_target = 0.0
			_enter(State.FAIR, _rng.randf_range(80.0, 140.0))


func _enter(next: State, seconds: float) -> void:
	state = next
	_time_left = seconds
	changed.emit(state)
