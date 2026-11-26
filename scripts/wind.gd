class_name Wind
extends Node
## The wind over the whole patch of ocean. It has a direction it blows FROM
## (compass degrees, 0 = north, 90 = east) and a strength in metres per second.
## Both wander slowly over time. Weather can scale it, shift it and add gusts.

@export var base_from_deg: float = 90.0
@export var swing_deg: float = 70.0
@export var base_strength: float = 8.0
@export var strength_swing: float = 3.0

## Set by Weather. Left alone, the wind is a steady fair-weather breeze.
var strength_scale: float = 1.0
var gustiness: float = 0.0   ## 0 = steady, 0.3 = hard gusts
var shift_deg: float = 0.0   ## extra change of direction, e.g. in a squall

var from_deg: float = 90.0
var strength: float = 8.0

var _noise := FastNoiseLite.new()
var _time: float = 0.0


func _ready() -> void:
	_noise.seed = 1768
	_noise.frequency = 0.01  # one "feature" per ~100 seconds
	_update()


func _process(delta: float) -> void:
	_time += delta
	_update()


func _update() -> void:
	var swing := swing_deg * _noise.get_noise_1d(_time)
	from_deg = wrapf(base_from_deg + swing + shift_deg, 0.0, 360.0)

	var steady := (base_strength + strength_swing * _noise.get_noise_1d(_time + 5000.0))
	var gust := 1.0 + gustiness * _noise.get_noise_1d(_time * 15.0 + 9000.0)
	strength = maxf(1.5, steady * strength_scale * gust)
