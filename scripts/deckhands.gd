class_name Deckhands
extends Node3D
## The rest of the ship's company: hands who cannot be spoken to but who make
## the ship feel lived in. Each walks a beat about the deck, stopping here
## and there to lean on the rail, haul on a rope, or stand and look at the sea.
## Child of the Ship.

const PACE := 1.05   ## metres a second: nobody hurries without an order

var _hands: Array[Dictionary] = []


func _ready() -> void:
	var waist := ShipLayout.WAIST_Y
	var fore := ShipLayout.FORECASTLE_Y
	var aft := ShipLayout.QUARTERDECK_Y
	# Two hands about the port side of the waist, round the main hatch.
	var port_beat: Array[Vector3] = [
		Vector3(-2.35, waist, -6.6), Vector3(-2.35, waist, -1.4),
		Vector3(-0.5, waist, -1.5), Vector3(-0.6, waist, -6.8),
	]
	_add(port_beat, 0, Color(0.36, 0.30, 0.24), false)
	_add(port_beat, 2, Color(0.24, 0.32, 0.40), false)
	# One on the forecastle, round the windlass.
	var fore_beat: Array[Vector3] = [
		Vector3(-2.1, fore, -13.2), Vector3(2.1, fore, -13.2),
		Vector3(2.3, fore, -9.8), Vector3(-2.3, fore, -9.8),
	]
	_add(fore_beat, 1, Color(0.42, 0.40, 0.30), false)
	# A marine sentry pacing across the forward end of the quarterdeck.
	var sentry_beat: Array[Vector3] = [Vector3(-1.9, aft, 4.9), Vector3(1.9, aft, 4.9)]
	_add(sentry_beat, 0, Color(0.62, 0.12, 0.10), true)


func _process(delta: float) -> void:
	for hand in _hands:
		# Either a code-built Figure or a modelled SeamanBody: both answer to
		# `walking`, `facing` and `set_pose`.
		var figure = hand["figure"]
		var beat: Array = hand["beat"]
		if float(hand["wait"]) > 0.0:
			hand["wait"] = float(hand["wait"]) - delta
			if float(hand["wait"]) <= 0.0:
				hand["next"] = (int(hand["next"]) + 1) % beat.size()
				figure.set_pose("at_ease", 0.5)
			continue
		var target: Vector3 = beat[hand["next"]]
		var here: Vector3 = figure.position
		var to := target - here
		if to.length() < 0.08:
			# Arrived. Stop a while and do something.
			figure.walking = false
			hand["wait"] = randf_range(3.0, 9.0)
			if hand["marine"]:
				hand["wait"] = 1.5   # a sentry only turns about
			else:
				var doing: String = ["lean", "haul", "at_ease", "lean"][randi() % 4]
				figure.set_pose(doing, 0.8)
				if doing == "lean":
					# Lean on the nearest rail, looking out.
					figure.facing = -signf(here.x) * PI * 0.5
			continue
		figure.walking = true
		var step := to.normalized() * minf(PACE * delta, to.length())
		figure.position += step
		figure.facing = atan2(-to.x, -to.z)


func _add(beat: Array[Vector3], start: int, jacket: Color, marine: bool) -> void:
	# The hands are the modelled seaman where his model is there to use. The
	# marine, and everyone if it is not, are built in code.
	if not marine and SeamanBody.available():
		var seaman := SeamanBody.new()
		seaman.pace = PACE
		# The same man three times over would look it; wash each a little differently.
		seaman.tint = [Color(1.0, 1.0, 1.0), Color(0.9, 0.86, 0.8), Color(0.82, 0.9, 0.95)][start % 3]
		seaman.position = beat[start]
		add_child(seaman)
		_hands.append({
			"figure": seaman, "beat": beat, "next": (start + 1) % beat.size(),
			"wait": randf_range(0.0, 3.0), "marine": false,
		})
		return
	var figure := Figure.new()
	figure.coat_color = jacket
	figure.legs_color = Color(0.86, 0.83, 0.74) if marine else Color(0.80, 0.76, 0.66)
	figure.hair_color = Color(0.25, 0.18, 0.12).lerp(Color(0.6, 0.5, 0.3), randf())
	figure.neck_color = Color(0.9, 0.88, 0.82) if marine else Color(0.2, 0.25, 0.4)
	figure.wears_hat = marine
	figure.wears_cap = not marine and start != 2
	figure.long_coat = marine
	figure.cross_belts = marine
	figure.position = beat[start]
	add_child(figure)
	_hands.append({
		"figure": figure, "beat": beat, "next": (start + 1) % beat.size(),
		"wait": randf_range(0.0, 3.0), "marine": marine,
	})
