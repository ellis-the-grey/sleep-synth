class_name PianoStrip
extends Control

@export var base_midi_note: int = 48 # C3 (matches MidiRouter lower row C)
@export var total_semitones: int = 29 # C3 to E5 (2.5 octaves)
@export var show_qwerty_hints: bool = true

const IS_BLACK_KEY: Array[bool] = [
	false, true, false, true, false, false, true, false, true, false, true, false
]

const QWERTY_MAP: Dictionary = {
	0: "Z", 1: "S", 2: "X", 3: "D", 4: "C", 5: "V", 6: "G",
	7: "B", 8: "H", 9: "N", 10: "J", 11: "M",
	12: "Q", 13: "2", 14: "W", 15: "3", 16: "E", 17: "R", 18: "5",
	19: "T", 20: "6", 21: "Y", 22: "7", 23: "U", 24: "I", 25: "9",
	26: "O", 27: "0", 28: "P"
}

var _white_rects: Array[Dictionary] = []
var _black_rects: Array[Dictionary] = []

var _hovered_note: int = -1
var _pressed_note: int = -1
var _mouse_down: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(480, 116)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	SynthBus.active_notes_changed.connect(queue_redraw)
	SynthBus.accidental_mode_changed.connect(func(_m: int) -> void: queue_redraw())
	resized.connect(_rebuild_key_geometry)
	mouse_exited.connect(_on_mouse_exited)
	_rebuild_key_geometry()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		if not visible:
			_release_active_mouse_note()
			_hovered_note = -1
			_mouse_down = false
			queue_redraw()


func _on_mouse_exited() -> void:
	_hovered_note = -1
	if not _mouse_down:
		queue_redraw()


func _release_active_mouse_note() -> void:
	if _pressed_note >= 0:
		SynthBus.note_off(_pressed_note, "piano_ui")
		_pressed_note = -1


func _rebuild_key_geometry() -> void:
	_white_rects.clear()
	_black_rects.clear()

	if size.x <= 16.0 or size.y <= 16.0:
		return

	var pad_x: float = 8.0
	var pad_top: float = 20.0
	var pad_bot: float = 6.0
	var inner_w: float = size.x - pad_x * 2.0
	var inner_h: float = size.y - pad_top - pad_bot

	var white_count: int = 0
	for i in range(total_semitones):
		var note: int = base_midi_note + i
		if not IS_BLACK_KEY[posmod(note, 12)]:
			white_count += 1

	if white_count <= 0:
		return

	var white_w: float = inner_w / float(white_count)
	var black_w: float = white_w * 0.62
	var black_h: float = inner_h * 0.60

	var w_idx: int = 0
	for i in range(total_semitones):
		var note: int = base_midi_note + i
		var semi: int = posmod(note, 12)
		if not IS_BLACK_KEY[semi]:
			var rx: float = pad_x + float(w_idx) * white_w
			var rect := Rect2(rx, pad_top, white_w, inner_h)
			_white_rects.append({"note": note, "rect": rect, "offset": i})
			w_idx += 1
		else:
			var boundary_x: float = pad_x + float(w_idx) * white_w
			var rx: float = boundary_x - black_w * 0.5
			var rect := Rect2(rx, pad_top, black_w, black_h)
			_black_rects.append({"note": note, "rect": rect, "offset": i})

	queue_redraw()


func _hit_test_note(pos: Vector2) -> Dictionary:
	for item in _black_rects:
		var r: Rect2 = item["rect"]
		if r.has_point(pos):
			var vel: float = clampf(0.55 + ((pos.y - r.position.y) / maxf(1.0, r.size.y)) * 0.45, 0.45, 1.0)
			return {"note": int(item["note"]), "vel": vel}

	for item in _white_rects:
		var r: Rect2 = item["rect"]
		if r.has_point(pos):
			var vel: float = clampf(0.55 + ((pos.y - r.position.y) / maxf(1.0, r.size.y)) * 0.45, 0.45, 1.0)
			return {"note": int(item["note"]), "vel": vel}

	return {"note": -1, "vel": 0.85}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_down = true
				var hit: Dictionary = _hit_test_note(mb.position)
				var note: int = int(hit["note"])
				if note >= 0:
					_release_active_mouse_note()
					_pressed_note = note
					SynthBus.note_on(note, float(hit["vel"]), "piano_ui")
				queue_redraw()
				accept_event()
			else:
				_mouse_down = false
				_release_active_mouse_note()
				queue_redraw()
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			base_midi_note = mini(84, base_midi_note + 12)
			_rebuild_key_geometry()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			base_midi_note = maxi(24, base_midi_note - 12)
			_rebuild_key_geometry()
			accept_event()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var hit: Dictionary = _hit_test_note(mm.position)
		var new_hover: int = int(hit["note"])
		if new_hover != _hovered_note:
			_hovered_note = new_hover
			if _mouse_down and new_hover >= 0 and new_hover != _pressed_note:
				_release_active_mouse_note()
				_pressed_note = new_hover
				SynthBus.note_on(new_hover, float(hit["vel"]), "piano_ui")
			queue_redraw()


func _draw() -> void:
	var font: Font = EuclidPalette.get_font()
	var frame := Rect2(Vector2.ZERO, size)
	EuclidPalette.draw_euclid_frame(self, frame, EuclidPalette.BG_SUBPANEL, EuclidPalette.LINE_DIM, true)

	var range_str: String = "%s - %s" % [
		SynthBus.get_note_name(base_midi_note),
		SynthBus.get_note_name(base_midi_note + total_semitones - 1)
	]
	draw_string(font, Vector2(10.0, 14.0), "LINEAR KEYBOARD  [%s]  (WHEEL: OCTAVE)" % range_str, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, 9, EuclidPalette.TEXT_DIM)

	for item in _white_rects:
		var note: int = int(item["note"])
		var r: Rect2 = item["rect"]
		var offset: int = int(item["offset"])
		var is_active: bool = SynthBus.is_note_active(note)
		var is_hover: bool = (note == _hovered_note)

		var fill: Color = EuclidPalette.BG_PANEL
		var border: Color = EuclidPalette.LINE_DIM
		var label_col: Color = EuclidPalette.TEXT_DIM

		if is_active:
			fill = Color(0.24, 0.21, 0.15, 1.0)
			border = EuclidPalette.ACCENT_GOLD
			label_col = EuclidPalette.ACCENT_GOLD
		elif is_hover:
			fill = EuclidPalette.BG_HOVER
			border = Color("#7A8294")
			label_col = EuclidPalette.TEXT_MAIN

		draw_rect(r, fill, true)
		draw_rect(r, border, false, EuclidPalette.LINE_MED if is_active else EuclidPalette.LINE_THIN)

		if is_active:
			var cx: float = r.position.x + r.size.x * 0.5
			var cy: float = r.end.y - 28.0
			draw_line(Vector2(cx - 5.0, cy), Vector2(cx + 5.0, cy), EuclidPalette.ACCENT_GOLD, EuclidPalette.LINE_THIN)
			draw_line(Vector2(cx, cy - 5.0), Vector2(cx, cy + 5.0), EuclidPalette.ACCENT_GOLD, EuclidPalette.LINE_THIN)

		if posmod(note, 12) == 0:
			var dot_pos := Vector2(r.position.x + r.size.x * 0.5, r.end.y - 18.0)
			draw_circle(dot_pos, 2.0, EuclidPalette.ACCENT_GOLD if is_active else EuclidPalette.LINE_MID)

		if show_qwerty_hints and QWERTY_MAP.has(offset) and r.size.x >= 16.0:
			var q_txt: String = str(QWERTY_MAP[offset])
			draw_string(font, Vector2(r.position.x, r.end.y - 14.0), q_txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, EuclidPalette.LINE_MID)

		if r.size.x >= 16.0:
			var n_txt: String = SynthBus.get_note_name(note) if posmod(note, 12) == 0 else SynthBus.SHARP_NAMES[posmod(note, 12)]
			draw_string(font, Vector2(r.position.x, r.end.y - 4.0), n_txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, label_col)

	for item in _black_rects:
		var note: int = int(item["note"])
		var r: Rect2 = item["rect"]
		var offset: int = int(item["offset"])
		var is_active: bool = SynthBus.is_note_active(note)
		var is_hover: bool = (note == _hovered_note)

		var fill: Color = EuclidPalette.BG_VOID
		var border: Color = EuclidPalette.LINE_MID
		var label_col: Color = EuclidPalette.TEXT_DIM

		if is_active:
			fill = Color(0.28, 0.24, 0.16, 1.0)
			border = EuclidPalette.ACCENT_GOLD
			label_col = EuclidPalette.ACCENT_GOLD
		elif is_hover:
			fill = EuclidPalette.BG_HOVER
			border = EuclidPalette.LINE_MAIN
			label_col = EuclidPalette.TEXT_MAIN

		draw_rect(r, fill, true)
		draw_rect(r, border, false, EuclidPalette.LINE_MED if is_active else EuclidPalette.LINE_THIN)

		if is_active:
			var cx: float = r.position.x + r.size.x * 0.5
			var cy: float = r.position.y + 12.0
			draw_line(Vector2(cx - 4.0, cy), Vector2(cx + 4.0, cy), EuclidPalette.ACCENT_GOLD, EuclidPalette.LINE_THIN)
			draw_line(Vector2(cx, cy - 4.0), Vector2(cx, cy + 4.0), EuclidPalette.ACCENT_GOLD, EuclidPalette.LINE_THIN)

		if show_qwerty_hints and QWERTY_MAP.has(offset) and r.size.x >= 12.0:
			var q_txt: String = str(QWERTY_MAP[offset])
			draw_string(font, Vector2(r.position.x, r.end.y - 13.0), q_txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, EuclidPalette.LINE_MID)

		if r.size.x >= 14.0:
			var sharp_txt: String = SynthBus.get_pitch_class_name(note, true)
			var f_sz: int = 6 if sharp_txt.contains("/") else 7
			draw_string(font, Vector2(r.position.x, r.end.y - 4.0), sharp_txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, f_sz, label_col)
