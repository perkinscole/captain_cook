class_name CrewCards
extends PanelContainer
## The ship's company as a row of cards: a face, a name, how each hand is
## and how they feel, with the stores written underneath.

var crew: Crew
var supplies: Supplies

var _rows: Array[Dictionary] = []
var _stores: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	var heading := _text(column, "The ship's company", 28)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", UiTheme.RED)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	for h in crew.hands:
		row.add_child(_card(h))

	_stores = _text(column, "", 19)
	_stores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var keys := _text(column, "R  change rations        K  serve sour krout        "
			+ "G  extra grog        C  close", 16)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.add_theme_color_override("font_color", UiTheme.FADED)


func _process(_delta: float) -> void:
	if not visible:
		return
	for entry in _rows:
		var h: Hand = entry["hand"]
		(entry["health"] as ProgressBar).value = h.health
		(entry["morale"] as ProgressBar).value = h.morale
		var state := entry["state"] as Label
		state.text = "%s, %s" % [h.health_word(), h.morale_word()]
		state.add_theme_color_override("font_color", UiTheme.RED if h.sick else UiTheme.INK)
	_stores.text = "Day %d.     Fresh greens %.1f days.     Sour krout %.1f days (%s).\n" % [
		supplies.day(), supplies.greens, supplies.krout,
		"being served" if supplies.serving_krout else "not served"] \
		+ "Salt provisions %.1f days on %s.     Extra grog: %d." % [
		supplies.provisions / Supplies.RATION_RATE[supplies.rations],
		Supplies.RATION_NAMES[supplies.rations].to_lower(), supplies.grog]


func _card(h: Hand) -> PanelContainer:
	var card := PanelContainer.new()
	var box := UiTheme.paper_box(1.0)
	box.bg_color = UiTheme.PAPER.lightened(0.2)
	box.set_content_margin_all(10.0)
	box.shadow_size = 3
	card.add_theme_stylebox_override("panel", box)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	card.add_child(column)
	var face := Portrait.new()
	face.hand = h
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(face)

	var name_label := _text(column, h.full_name, 21)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _text(column, h.title, 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiTheme.ITALIC)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(160.0, 40.0)

	var health := _bar(column, "Health", UiTheme.GREEN)
	var morale := _bar(column, "Spirits", UiTheme.BRASS)
	var state := _text(column, "", 16)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows.append({"hand": h, "health": health, "morale": morale, "state": state})
	return card


func _text(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _bar(parent: Control, title: String, colour: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _text(row, title, 14)
	label.custom_minimum_size.x = 52.0
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 10.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return bar
