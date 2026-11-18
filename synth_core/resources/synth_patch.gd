class_name SynthPatch
extends Resource

@export var patch_name: String = "Init minimod"
@export_range(0.0, 1.0, 0.001) var master_volume: float = 0.72
@export_range(1, 16, 1) var max_voices: int = 1
@export_range(0.0, 2000.0, 1.0) var glide_ms: float = 35.0
@export var legato_retrigger: bool = false
@export var oscillators: Array[OscConfig] = []
@export var noise: NoiseConfig
@export var filter: FilterConfig
@export var filter_contour: ContourConfig
@export var loudness_contour: ContourConfig
@export var mod_routes: Array[ModRoute] = []


static func create_default_minimod() -> SynthPatch:
	var patch := SynthPatch.new()
	patch.patch_name = "Init minimod"
	patch.master_volume = 0.72
	patch.max_voices = 1
	patch.glide_ms = 35.0
	patch.legato_retrigger = false

	var osc1 := OscConfig.new()
	osc1.label = "OSC 1"
	osc1.enabled = true
	osc1.waveform = OscConfig.Waveform.SAWTOOTH
	osc1.octave_range = OscConfig.OctaveRange.FT_16
	osc1.detune_semitones = 0.0
	osc1.level = 0.80

	var osc2 := OscConfig.new()
	osc2.label = "OSC 2"
	osc2.enabled = true
	osc2.waveform = OscConfig.Waveform.SAWTOOTH
	osc2.octave_range = OscConfig.OctaveRange.FT_8
	osc2.detune_semitones = 0.08
	osc2.level = 0.65

	var osc3 := OscConfig.new()
	osc3.label = "OSC 3"
	osc3.enabled = true
	osc3.waveform = OscConfig.Waveform.TRIANGLE
	osc3.octave_range = OscConfig.OctaveRange.FT_8
	osc3.detune_semitones = -0.07
	osc3.level = 0.55

	patch.oscillators = [osc1, osc2, osc3]

	patch.noise = NoiseConfig.new()
	patch.noise.enabled = false
	patch.noise.color = NoiseConfig.NoiseColor.PINK
	patch.noise.level = 0.20

	patch.filter = FilterConfig.new()
	patch.filter.cutoff_hz = 2200.0
	patch.filter.emphasis = 0.85
	patch.filter.contour_amount = 0.45
	patch.filter.kbd_tracking_idx = 2
	patch.filter.overload_drive = 0.15

	patch.filter_contour = ContourConfig.new()
	patch.filter_contour.attack_ms = 14.0
	patch.filter_contour.decay_ms = 520.0
	patch.filter_contour.sustain_level = 0.35
	patch.filter_contour.release_on_decay = true

	patch.loudness_contour = ContourConfig.new()
	patch.loudness_contour.attack_ms = 8.0
	patch.loudness_contour.decay_ms = 380.0
	patch.loudness_contour.sustain_level = 0.78
	patch.loudness_contour.release_on_decay = true

	var route1 := ModRoute.new()
	route1.enabled = true
	route1.source = ModRoute.ModSource.OSC_3
	route1.target = ModRoute.ModTarget.FILTER_CUTOFF
	route1.amount = 0.0

	var route2 := ModRoute.new()
	route2.enabled = true
	route2.source = ModRoute.ModSource.DRIFT_LFO
	route2.target = ModRoute.ModTarget.PITCH
	route2.amount = 0.02

	patch.mod_routes = [route1, route2]
	return patch


func duplicate_snapshot() -> SynthPatch:
	var snap := SynthPatch.new()
	snap.patch_name = patch_name
	snap.master_volume = master_volume
	snap.max_voices = max_voices
	snap.glide_ms = glide_ms
	snap.legato_retrigger = legato_retrigger

	var osc_copies: Array[OscConfig] = []
	for osc in oscillators:
		if osc != null:
			osc_copies.append(osc.duplicate_config())
	snap.oscillators = osc_copies

	snap.noise = noise.duplicate_config() if noise != null else NoiseConfig.new()
	snap.filter = filter.duplicate_config() if filter != null else FilterConfig.new()
	snap.filter_contour = filter_contour.duplicate_config() if filter_contour != null else ContourConfig.new()
	snap.loudness_contour = loudness_contour.duplicate_config() if loudness_contour != null else ContourConfig.new()

	var route_copies: Array[ModRoute] = []
	for r in mod_routes:
		if r != null:
			route_copies.append(r.duplicate_config())
	snap.mod_routes = route_copies
	return snap
