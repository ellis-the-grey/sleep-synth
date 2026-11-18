extends Node

enum QwertyLayoutMode {
	HEX,
	PIANO
}

var qwerty_enabled: bool = true
var layout_mode: QwertyLayoutMode = QwertyLayoutMode.HEX
var base_octave: int = 4 # C4 = 60 center for Hex, C3 = 48 base for Piano

var _held_qwerty_notes: Dictionary = {}

const PIANO_LOWER_OFFSETS: Dictionary = {
	KEY_Z: 0, KEY_S: 1, KEY_X: 2, KEY_D: 3, KEY_C: 4, KEY_V: 5, KEY_G: 6,
	KEY_B: 7, KEY_H: 8, KEY_N: 9, KEY_J: 10, KEY_M: 11, KEY_COMMA: 12,
	KEY_L: 13, KEY_PERIOD: 14, KEY_SEMICOLON: 15, KEY_SLASH: 16
}

const PIANO_UPPER_OFFSETS: Dictionary = {
	KEY_Q: 0, KEY_2: 1, KEY_W: 2, KEY_3: 3, KEY_E: 4, KEY_R: 5, KEY_5: 6,
	KEY_T: 7, KEY_6: 8, KEY_Y: 9, KEY_7: 10, KEY_U: 11, KEY_I: 12,
	KEY_9: 13, KEY_O: 14, KEY_0: 15, KEY_P: 16
}

const HEX_KEY_COORDS: Dictionary = {
	KEY_1: Vector2i(-4, -1), KEY_2: Vector2i(-3, -1), KEY_3: Vector2i(-2, -1),
	KEY_4: Vector2i(-1, -1), KEY_5: Vector2i(0, -1),  KEY_6: Vector2i(1, -1),
	KEY_7: Vector2i(2, -1),  KEY_8: Vector2i(3, -1),  KEY_9: Vector2i(4, -1),
	KEY_0: Vector2i(5, -1),
	KEY_Q: Vector2i(-4, 0),  KEY_W: Vector2i(-3, 0),  KEY_E: Vector2i(-2, 0),
	KEY_R: Vector2i(-1, 0),  KEY_T: Vector2i(0, 0),   KEY_Y: Vector2i(1, 0),
	KEY_U: Vector2i(2, 0),   KEY_I: Vector2i(3, 0),   KEY_O: Vector2i(4, 0),
	KEY_P: Vector2i(5, 0),
	KEY_A: Vector2i(-4, 1),  KEY_S: Vector2i(-3, 1),  KEY_D: Vector2i(-2, 1),
	KEY_F: Vector2i(-1, 1),  KEY_G: Vector2i(0, 1),   KEY_H: Vector2i(1, 1),
	KEY_J: Vector2i(2, 1),   KEY_K: Vector2i(3, 1),   KEY_L: Vector2i(4, 1),
	KEY_SEMICOLON: Vector2i(5, 1),
	KEY_Z: Vector2i(-4, 2),  KEY_X: Vector2i(-3, 2),  KEY_C: Vector2i(-2, 2),
	KEY_V: Vector2i(-1, 2),  KEY_B: Vector2i(0, 2),   KEY_N: Vector2i(1, 2),
	KEY_M: Vector2i(2, 2),   KEY_COMMA: Vector2i(3, 2), KEY_PERIOD: Vector2i(4, 2),
	KEY_SLASH: Vector2i(5, 2)
}

const HEX_KEY_LABELS: Dictionary = {
	Vector2i(-4, -1): "1", Vector2i(-3, -1): "2", Vector2i(-2, -1): "3",
	Vector2i(-1, -1): "4", Vector2i(0, -1): "5",  Vector2i(1, -1): "6",
	Vector2i(2, -1): "7",  Vector2i(3, -1): "8",  Vector2i(4, -1): "9",
	Vector2i(5, -1): "0",
	Vector2i(-4, 0): "Q",  Vector2i(-3, 0): "W",  Vector2i(-2, 0): "E",
	Vector2i(-1, 0): "R",  Vector2i(0, 0): "T",   Vector2i(1, 0): "Y",
	Vector2i(2, 0): "U",   Vector2i(3, 0): "I",   Vector2i(4, 0): "O",
	Vector2i(5, 0): "P",
	Vector2i(-4, 1): "A",  Vector2i(-3, 1): "S",  Vector2i(-2, 1): "D",
	Vector2i(-1, 1): "F",  Vector2i(0, 1): "G",   Vector2i(1, 1): "H",
	Vector2i(2, 1): "J",   Vector2i(3, 1): "K",   Vector2i(4, 1): "L",
	Vector2i(5, 1): ";",
	Vector2i(-4, 2): "Z",  Vector2i(-3, 2): "X",  Vector2i(-2, 2): "C",
	Vector2i(-1, 2): "V",  Vector2i(0, 2): "B",   Vector2i(1, 2): "N",
	Vector2i(2, 2): "M",   Vector2i(3, 2): ",",   Vector2i(4, 2): ".",
	Vector2i(5, 2): "/"
}


func _ready() -> void:
	OS.open_midi_inputs()


func set_layout_mode(new_mode: QwertyLayoutMode) -> void:
	if layout_mode == new_mode:
		return
	release_all_qwerty()
	layout_mode = new_mode


func release_all_qwerty() -> void:
	for code in _held_qwerty_notes.keys():
		var note: int = int(_held_qwerty_notes[code])
		SynthBus.note_off(note, "qwerty")
	_held_qwerty_notes.clear()


func refresh_midi_devices() -> PackedStringArray:
	OS.close_midi_inputs()
	OS.open_midi_inputs()
	return OS.get_connected_midi_inputs()


func _input(event: InputEvent) -> void:
	if event is InputEventMIDI:
		_handle_midi_event(event as InputEventMIDI)
	elif event is InputEventKey:
		_handle_key_event(event as InputEventKey)


func _handle_midi_event(midi_event: InputEventMIDI) -> void:
	match midi_event.message:
		MIDI_MESSAGE_NOTE_ON:
			if midi_event.velocity > 0:
				var vel: float = float(midi_event.velocity) / 127.0
				SynthBus.note_on(midi_event.pitch, vel, "midi")
			else:
				SynthBus.note_off(midi_event.pitch, "midi")
		MIDI_MESSAGE_NOTE_OFF:
			SynthBus.note_off(midi_event.pitch, "midi")
		MIDI_MESSAGE_CONTROL_CHANGE:
			var cc_val: float = float(midi_event.controller_value) / 127.0
			SynthBus.cc_received.emit(midi_event.controller_number, cc_val)
		MIDI_MESSAGE_PITCH_BEND:
			var normalized: float = (float(midi_event.pitch) - 8192.0) / 8192.0
			SynthBus.pitch_bend_received.emit(clampf(normalized * 2.0, -2.0, 2.0))


func _resolve_qwerty_midi_note(code: Key) -> int:
	if layout_mode == QwertyLayoutMode.HEX:
		if not HEX_KEY_COORDS.has(code):
			return -1
		var qr: Vector2i = HEX_KEY_COORDS[code]
		var center_note: int = (base_octave + 1) * 12
		var note: int = center_note + (qr.x * -3) + (qr.y * -7)
		return clampi(note, 24, 108)
	else:
		var offset: int = -1
		var octave_shift: int = 0
		if PIANO_LOWER_OFFSETS.has(code):
			offset = int(PIANO_LOWER_OFFSETS[code])
			octave_shift = 0
		elif PIANO_UPPER_OFFSETS.has(code):
			offset = int(PIANO_UPPER_OFFSETS[code])
			octave_shift = 1
		if offset < 0:
			return -1
		return clampi((base_octave + octave_shift) * 12 + offset, 24, 108)


func _handle_key_event(key_event: InputEventKey) -> void:
	if not qwerty_enabled or key_event.echo:
		return

	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	var code: Key = key_event.keycode

	if key_event.pressed:
		if code == KEY_MINUS:
			release_all_qwerty()
			base_octave = maxi(1, base_octave - 1)
			return
		elif code == KEY_EQUAL:
			release_all_qwerty()
			base_octave = mini(6, base_octave + 1)
			return

		if not _held_qwerty_notes.has(code):
			var midi_note: int = _resolve_qwerty_midi_note(code)
			if midi_note >= 0:
				_held_qwerty_notes[code] = midi_note
				SynthBus.note_on(midi_note, 0.85, "qwerty")
	else:
		if _held_qwerty_notes.has(code):
			var prev_note: int = int(_held_qwerty_notes[code])
			_held_qwerty_notes.erase(code)
			SynthBus.note_off(prev_note, "qwerty")
