extends Node

enum AccidentalMode {
	BOTH,
	SHARP,
	FLAT
}

signal note_on_triggered(midi_note: int, velocity: float)
signal note_off_triggered(midi_note: int)
signal all_notes_off_triggered()
signal cc_received(cc_number: int, value: float)
signal pitch_bend_received(semitones: float)
signal patch_changed(patch: SynthPatch)
signal patch_parameter_updated()
signal active_notes_changed()
signal accidental_mode_changed(mode: AccidentalMode)

const SHARP_NAMES: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const FLAT_NAMES: Array[String] = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
const DUAL_NAMES: Array[String] = ["C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B"]

# Kept for backwards compatibility
const NOTE_NAMES: Array[String] = SHARP_NAMES

var accidental_mode: AccidentalMode = AccidentalMode.BOTH:
	set(v):
		if accidental_mode != v:
			accidental_mode = v
			accidental_mode_changed.emit(accidental_mode)
			active_notes_changed.emit()

# Maps midi_note (int) -> Dictionary of active source tags
var _active_note_sources: Dictionary = {}


func note_on(midi_note: int, velocity: float = 0.85, source: String = "ui") -> void:
	var clamped_note: int = clampi(midi_note, 0, 127)
	var clamped_vel: float = clampf(velocity, 0.01, 1.0)
	var was_active: bool = _active_note_sources.has(clamped_note)
	if not was_active:
		_active_note_sources[clamped_note] = {}
	_active_note_sources[clamped_note][source] = clamped_vel
	note_on_triggered.emit(clamped_note, clamped_vel)
	if not was_active:
		active_notes_changed.emit()


func note_off(midi_note: int, source: String = "ui") -> void:
	var clamped_note: int = clampi(midi_note, 0, 127)
	if not _active_note_sources.has(clamped_note):
		return
	var sources: Dictionary = _active_note_sources[clamped_note]
	sources.erase(source)
	if sources.is_empty():
		_active_note_sources.erase(clamped_note)
		note_off_triggered.emit(clamped_note)
		active_notes_changed.emit()


func panic() -> void:
	_active_note_sources.clear()
	all_notes_off_triggered.emit()
	active_notes_changed.emit()


func is_note_active(midi_note: int) -> bool:
	return _active_note_sources.has(midi_note)


func get_active_notes() -> Array[int]:
	var notes: Array[int] = []
	for key in _active_note_sources.keys():
		notes.append(int(key))
	notes.sort()
	return notes


func get_pitch_class_name(midi_note: int, compact: bool = false) -> String:
	var idx: int = posmod(midi_note, 12)
	match accidental_mode:
		AccidentalMode.SHARP:
			return SHARP_NAMES[idx]
		AccidentalMode.FLAT:
			return FLAT_NAMES[idx]
		_:
			if compact:
				return "%s/%s" % [SHARP_NAMES[idx], FLAT_NAMES[idx]] if SHARP_NAMES[idx] != FLAT_NAMES[idx] else SHARP_NAMES[idx]
			return DUAL_NAMES[idx]


func get_note_name(midi_note: int) -> String:
	var idx: int = posmod(midi_note, 12)
	var octave: int = int(floor(float(midi_note) / 12.0)) - 1
	match accidental_mode:
		AccidentalMode.SHARP:
			return "%s%d" % [SHARP_NAMES[idx], octave]
		AccidentalMode.FLAT:
			return "%s%d" % [FLAT_NAMES[idx], octave]
		_:
			if SHARP_NAMES[idx] != FLAT_NAMES[idx]:
				return "%s%d/%s%d" % [SHARP_NAMES[idx], octave, FLAT_NAMES[idx], octave]
			return "%s%d" % [SHARP_NAMES[idx], octave]
