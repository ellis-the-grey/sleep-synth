class_name HexHarmonicTable
extends Control

# Isomorphic Harmonic Table (Tonnetz) Lattice
# Flat-top axial coordinates (q, r):
#   Up         (0, -1)  -> +7 semitones (Perfect 5th)
#   Up-Right   (+1, -1) -> +4 semitones (Major 3rd)
#   Down-Right (+1, 0)  -> -3 semitones (Minor 3rd down)
#   Up-Left    (-1, 0)  -> +3 semitones (Minor 3rd up)

@export var center_midi_note: int = 60 # C4
@export var hex_radius: float = 33.0
@export var show_qwerty_hints: bool = true

const DQ_SEMITONES: int = -3
const DR_SEMITONES: int = -7
const SQRT3: float = 1.7320508

var _cells: Array[Dictionary] = []
var _hovered_cell_idx: int = -1
var _pressed_note: int = -1
var _mouse_down: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(480, 260)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	SynthBus.active_notes_changed.connect(queue_redraw)
	SynthBus.accidental_mode_changed.connect(func(_m: int) -> void: queue_redraw())
	resized.connect(_rebuild_hex_grid)
	mouse_exited.connect(_on_mouse_exited)
	_rebuild_hex_grid()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		if not visible:
			_release_active_mouse_note()
			_hovered_cell_idx = -1
			_mouse_down = false
			queue_redraw()


func _on_mouse_exited() -> void:
	_hovered_cell_idx = -1
	if not _mouse_down:
		queue_redraw()


func _release_active_mouse_note() -> void:
	if _pressed_note >= 0:
		SynthBus.note_off(_pressed_note, "hex_ui")
		_pressed_note = -1


func _axial_to_pixel(q: int, r: int, origin: Vector2) -> Vector2:
	var x: float = hex_radius * 1.5 * float(q)
	var y: float = hex_radius * SQRT3 * (float(r) + float(q) * 0.5)
	return origin + Vector2(x, y)


func _make_flat_hex_vertices(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var ang: float = deg_to_rad(60.0 * float(i))
		pts.append(center + Vector2(cos(ang), sin(ang)) * radius)
	return pts


func _rebuild_hex_grid() -> void:
	_cells.clear()
	_hovered_cell_idx = -1

	if size.x <= 40.0 or size.y <= 40.0:
		return

	var pad_x: float = 12.0
	var pad_top: float = 22.0
	var pad_bot: float = 8.0
	var bounds := Rect2(pad_x, pad_top, size.x - pad_x * 2.0, size.y - pad_top - pad_bot)
	var origin: Vector2 = bounds.get_center()

	var max_q: int = int(ceil(bounds.size.x / (hex_radius * 1.5))) + 1
	var max_r: int = int(ceil(bounds.size.y / (hex_radius * SQRT3))) + 2

	for q in range(-max_q, max_q + 1):
		for r in range(-max_r, max_r + 1):
			var c_pos: Vector2 = _axial_to_pixel(q, r, origin)
			if c_pos.x - hex_radius < bounds.position.x or c_pos.x + hex_radius > bounds.end.x:
				continue
			if c_pos.y - hex_radius * 0.866 < bounds.position.y or c_pos.y + hex_radius * 0.866 > bounds.end.y:
				continue

			var midi_note: int = center_midi_note + (q * DQ_SEMITONES) + (r * DR_SEMITONES)
			if midi_note < 24 or midi_note > 108:
				continue

			var verts: PackedVector2Array = _make_flat_hex_vertices(c_pos, hex_radius - 1.2)
			_cells.append({
				"q": q,
				"r": r,
				"note": midi_note,
				"center": c_pos,
				"verts": verts
			})

	queue_redraw()


func _hit_test_cell(pos: Vector2) -> int:
	var r_sq: float = hex_radius * hex_radius
	for i in range(_cells.size()):
		var cell: Dictionary = _cells[i]
		var c_pos: Vector2 = cell["center"]
		if pos.distance_squared_to(c_pos) <= r_sq:
			var verts: PackedVector2Array = cell["verts"]
			if Geometry2D.is_point_in_polygon(pos, verts):
				return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_down = true
				var idx: int = _hit_test_cell(mb.position)
				if idx >= 0:
					var note: int = int(_cells[idx]["note"])
					_release_active_mouse_note()
					_pressed_note = note
					SynthBus.note_on(note, 0.85, "hex_ui")
				queue_redraw()
				accept_event()
			else:
				_mouse_down = false
				_release_active_mouse_note()
				queue_redraw()
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			var step: int = 1 if Input.is_key_pressed(KEY_SHIFT) else 12
			center_midi_note = mini(84, center_midi_note + step)
			_rebuild_hex_grid()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			var step: int = 1 if Input.is_key_pressed(KEY_SHIFT) else 12
			center_midi_note = maxi(36, center_midi_note - step)
			_rebuild_hex_grid()
			accept_event()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var new_idx: int = _hit_test_cell(mm.position)
		if new_idx != _hovered_cell_idx:
			_hovered_cell_idx = new_idx
			if _mouse_down and new_idx >= 0:
				var note: int = int(_cells[new_idx]["note"])
				if note != _pressed_note:
					_release_active_mouse_note()
					_pressed_note = note
					SynthBus.note_on(note, 0.85, "hex_ui")
			queue_redraw()


func _format_hex_note_label(midi_note: int) -> String:
	var pc: String = SynthBus.get_pitch_class_name(midi_note, true)
	var octave: int = int(floor(float(midi_note) / 12.0)) - 1
	return "%s%d" % [pc, octave]


func _draw() -> void:
	var font: Font = EuclidPalette.get_font()
	var frame := Rect2(Vector2.ZERO, size)
	EuclidPalette.draw_euclid_frame(self, frame, EuclidPalette.BG_SUBPANEL, EuclidPalette.LINE_DIM, true)

	var center_name: String = SynthBus.get_note_name(center_midi_note)
	draw_string(
		font,
		Vector2(10.0, 14.0),
		"HARMONIC TABLE (ISOMORPHIC LATTICE)  [CENTER: %s | UP:+7 P5 | UP-R:+4 M3 | UP-L:+3 m3]" % center_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 20.0,
		9,
		EuclidPalette.TEXT_DIM
	)

	var show_hex_keys: bool = show_qwerty_hints and (MidiRouter.layout_mode == MidiRouter.QwertyLayoutMode.HEX)

	for i in range(_cells.size()):
		var cell: Dictionary = _cells[i]
		var note: int = int(cell["note"])
		var c_pos: Vector2 = cell["center"]
		var verts: PackedVector2Array = cell["verts"]
		var qr := Vector2i(int(cell["q"]), int(cell["r"]))
		var is_root: bool = (posmod(note, 12) == posmod(center_midi_note, 12))
		var is_active: bool = SynthBus.is_note_active(note)
		var is_hover: bool = (i == _hovered_cell_idx)

		var fill: Color = EuclidPalette.BG_ACTIVE if is_root else EuclidPalette.BG_PANEL
		var border: Color = EuclidPalette.LINE_MID if is_root else EuclidPalette.LINE_DIM
		var text_col: Color = EuclidPalette.TEXT_MAIN if is_root else EuclidPalette.TEXT_DIM
		var stroke_w: float = EuclidPalette.LINE_THIN

		if is_active:
			fill = Color(0.26, 0.22, 0.15, 1.0)
			border = EuclidPalette.ACCENT_GOLD
			text_col = EuclidPalette.ACCENT_GOLD
			stroke_w = EuclidPalette.LINE_MED
		elif is_hover:
			fill = EuclidPalette.BG_HOVER
			border = Color("#7A8294")
			text_col = EuclidPalette.TEXT_MAIN

		draw_colored_polygon(verts, fill)
		var closed_loop := PackedVector2Array(verts)
		closed_loop.append(verts[0])
		draw_polyline(closed_loop, border, stroke_w, true)

		if is_active:
			draw_line(verts[0], verts[3], EuclidPalette.ACCENT_GOLD_DIM, EuclidPalette.LINE_THIN, true)
			draw_line(verts[1], verts[4], EuclidPalette.ACCENT_GOLD_DIM, EuclidPalette.LINE_THIN, true)
			draw_line(verts[2], verts[5], EuclidPalette.ACCENT_GOLD_DIM, EuclidPalette.LINE_THIN, true)
		elif is_root:
			draw_arc(c_pos, hex_radius * 0.70, 0.0, TAU, 24, EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN, true)

		var note_label: String = _format_hex_note_label(note)
		var is_dual_accidental: bool = note_label.contains("/")
		var font_sz: int = 8 if is_dual_accidental else 10
		var y_offset: float = 1.0 if show_hex_keys and MidiRouter.HEX_KEY_LABELS.has(qr) else 4.0
		draw_string(
			font,
			Vector2(c_pos.x - hex_radius, c_pos.y + y_offset),
			note_label,
			HORIZONTAL_ALIGNMENT_CENTER,
			hex_radius * 2.0,
			font_sz,
			text_col
		)

		if show_hex_keys and MidiRouter.HEX_KEY_LABELS.has(qr):
			var key_cap: String = str(MidiRouter.HEX_KEY_LABELS[qr])
			draw_string(
				font,
				Vector2(c_pos.x - hex_radius, c_pos.y + 13.0),
				key_cap,
				HORIZONTAL_ALIGNMENT_CENTER,
				hex_radius * 2.0,
				8,
				EuclidPalette.ACCENT_CYAN if is_active else EuclidPalette.LINE_MID
			)
