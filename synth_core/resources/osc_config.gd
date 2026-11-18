class_name OscConfig
extends Resource

enum Waveform {
	TRIANGLE,
	SHARKTOOTH,
	SAWTOOTH,
	SQUARE,
	WIDE_PULSE,
	NARROW_PULSE
}

enum OctaveRange {
	LO,
	FT_32,
	FT_16,
	FT_8,
	FT_4,
	FT_2
}

const WAVEFORM_NAMES: Array[String] = ["TRI", "SHARK", "SAW", "SQR", "PULSE 25%", "PULSE 12%"]
const OCTAVE_NAMES: Array[String] = ["LO", "32'", "16'", "8'", "4'", "2'"]

@export var label: String = "OSC 1"
@export var enabled: bool = true
@export var waveform: Waveform = Waveform.SAWTOOTH
@export var octave_range: OctaveRange = OctaveRange.FT_8
@export_range(-12.0, 12.0, 0.01) var detune_semitones: float = 0.0
@export_range(0.0, 1.0, 0.001) var level: float = 0.75
@export var mod_source_only: bool = false
@export_range(0.05, 20.0, 0.01) var lo_freq_hz: float = 1.5


func get_octave_semitone_offset() -> float:
	match octave_range:
		OctaveRange.FT_32:
			return -24.0
		OctaveRange.FT_16:
			return -12.0
		OctaveRange.FT_8:
			return 0.0
		OctaveRange.FT_4:
			return 12.0
		OctaveRange.FT_2:
			return 24.0
		_:
			return 0.0


func duplicate_config() -> OscConfig:
	var copy := OscConfig.new()
	copy.label = label
	copy.enabled = enabled
	copy.waveform = waveform
	copy.octave_range = octave_range
	copy.detune_semitones = detune_semitones
	copy.level = level
	copy.mod_source_only = mod_source_only
	copy.lo_freq_hz = lo_freq_hz
	return copy
