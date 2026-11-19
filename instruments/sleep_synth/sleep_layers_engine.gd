class_name SleepLayersEngine
extends Node

const SAMPLE_RATE: float = 48000.0
const INV_SR: float = 1.0 / 48000.0
const TAU: float = 6.283185307179586
const BASE_C2_HZ: float = 65.40639

enum BinauralMode { BINAURAL = 0, ISOCHRONIC = 1, BOTH = 2 }
enum NatureType {
	DISTANT_RAIN = 0,
	WIND_TREES = 1,
	OCEAN_SURF = 2,
	FIRE_CRACKLE = 3,
	NIGHT_CRICKETS = 4,
	BROOK_STREAM = 5,
	THUNDER_RUMBLE = 6
}
enum SwellWave { SINE = 0, TRIANGLE = 1, SOFT_WARM = 2 }

const NOTE_NAMES: Array[String] = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

const INTERVAL_NAMES: Array[String] = [
	"0: Unison (P1)",
	"1: Minor 2nd (m2)",
	"2: Major 2nd (M2)",
	"3: Minor 3rd (m3)",
	"4: Major 3rd (M3)",
	"5: Perfect 4th (P4)",
	"6: Tritone (TT)",
	"7: Perfect 5th (P5)",
	"8: Minor 6th (m6)",
	"9: Major 6th (M6)",
	"10: Minor 7th (m7)",
	"11: Major 7th (M7)",
	"12: Octave (P8)"
]

const SCALE_NAMES: Array[String] = [
	"Major",
	"Natural Minor",
	"Melodic Minor (Asc)",
	"Major Pentatonic",
	"Minor Pentatonic",
	"Whole Tone",
	"Whole-Half Diminished",
	"Dorian",
	"Phrygian",
	"Phrygian Dominant",
	"Lydian",
	"Mixolydian",
	"Locrian"
]

const SCALE_INTERVALS: Array = [
	[0, 2, 4, 5, 7, 9, 11],
	[0, 2, 3, 5, 7, 8, 10],
	[0, 2, 3, 5, 7, 9, 11],
	[0, 2, 4, 7, 9],
	[0, 3, 5, 7, 10],
	[0, 2, 4, 6, 8, 10],
	[0, 2, 3, 5, 6, 8, 9, 11],
	[0, 2, 3, 5, 7, 9, 10],
	[0, 1, 3, 5, 7, 8, 10],
	[0, 1, 4, 5, 7, 8, 10],
	[0, 2, 4, 6, 7, 9, 11],
	[0, 2, 4, 5, 7, 9, 10],
	[0, 1, 3, 5, 6, 8, 10]
]

# --- Global Master Volume (synced with SynthRig / MinimodMain MASTER) ---
var master_volume: float = 0.72

# --- Module 1: Brown Hearth ---
var brown_enabled: bool = false
var brown_level: float = 0.68
var brown_cutoff_hz: float = 220.0
var brown_sub_level: float = 0.40
var brown_pitch_semi: float = 0.0
var brown_breath_hz: float = 0.05

# --- Module 2: Pink Canopy ---
var pink_enabled: bool = false
var pink_level: float = 0.62
var pink_cutoff_hz: float = 640.0
var pink_breath_hz: float = 0.09
var pink_swell_depth: float = 0.32
var pink_pitch_semi: float = 0.0

# --- Module 3: Velvet Harmony ---
var velvet_enabled: bool = false
var velvet_level: float = 0.58
var velvet_interval_semis: int = 7
var velvet_cutoff_hz: float = 340.0
var velvet_osc1_semi: float = 0.0
var velvet_osc2_semi: float = 0.02
var velvet_floor_level: float = 0.28

# --- Module 4: Binaural / Isochronic ---
var binaural_enabled: bool = false
var binaural_level: float = 0.28
var binaural_mode: int = BinauralMode.BINAURAL
var binaural_carrier_hz: float = 110.0
var binaural_beat_hz: float = 2.5
var binaural_depth: float = 0.65

# --- Module 5: Filtered Nature Textures ---
var nature_enabled: bool = false
var nature_level: float = 0.45
var nature_type: int = NatureType.DISTANT_RAIN
var nature_tone: float = 0.50
var nature_rate: float = 0.35
var nature_density: float = 0.55

# --- Module 6: Generative Harmonic Swells ---
var swells_enabled: bool = false
var swells_level: float = 0.35
var swells_wave: int = SwellWave.SINE
var swells_asc_enabled: bool = true
var swells_desc_enabled: bool = false
var swells_scale_up_idx: int = 3   # Major Pentatonic
var swells_scale_down_idx: int = 4 # Minor Pentatonic
var swells_root_midi: int = 48     # C3
var swells_octaves: int = 1        # 1 or 2 octaves
var swells_duration_sec: float = 6.0
var swells_gap_sec: float = 3.0
var swells_spread: float = 0.65
var swells_high_damp: float = 0.70
var swells_status_text: String = "IDLE"

# --- Audio Output ---
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()

# --- Shared Noise State ---
var _pink_b0: float = 0.0
var _pink_b1: float = 0.0
var _pink_b2: float = 0.0
var _pink_b3: float = 0.0
var _brown_acc_l: float = 0.0
var _brown_acc_r: float = 0.0

# --- DSP State: Brown Hearth ---
var _bh_sub_phase: float = 0.0
var _bh_lfo_phase: float = 0.0
var _bh_lp1_l: float = 0.0
var _bh_lp2_l: float = 0.0
var _bh_lp1_r: float = 0.0
var _bh_lp2_r: float = 0.0

# --- DSP State: Pink Canopy ---
var _pc_sub_phase: float = 0.0
var _pc_lfo_phase: float = 0.25
var _pc_lp1_l: float = 0.0
var _pc_lp2_l: float = 0.0
var _pc_lp1_r: float = 0.0
var _pc_lp2_r: float = 0.0

# --- DSP State: Velvet Harmony ---
var _vf_root_phase: float = 0.0
var _vf_int_phase: float = 0.0
var _vf_lfo_phase: float = 0.5
var _vf_lp1_l: float = 0.0
var _vf_lp2_l: float = 0.0
var _vf_lp1_r: float = 0.0
var _vf_lp2_r: float = 0.0

# --- DSP State: Binaural ---
var _bin_phase_l: float = 0.0
var _bin_phase_r: float = 0.0
var _iso_phase: float = 0.0
var _bin_env: float = 0.0

# --- DSP State: Nature Noise & Rhythmic Forest Crickets ---
var _nat_lfo1: float = 0.0
var _nat_lfo2: float = 1.7
var _nat_bp_low_l: float = 0.0
var _nat_bp_band_l: float = 0.0
var _nat_bp_low_r: float = 0.0
var _nat_bp_band_r: float = 0.0
var _crackle_env: float = 0.0
var _crackle_pan: float = 0.0
var _crackle_lp: float = 0.0

const NUM_CRICKETS: int = 4
var _crk_phase: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _crk_base_hz: Array[float] = [3820.0, 4150.0, 3580.0, 4390.0]
var _crk_pan: Array[float] = [-0.68, 0.72, -0.25, 0.38]
var _crk_dist_gain: Array[float] = [0.68, 0.56, 0.42, 0.34]
var _crk_cycle_phase: Array[float] = [0.0, 0.37, 0.68, 0.19]
var _crk_rate_ratio: Array[float] = [1.0, 0.96, 1.04, 0.92]
var _crk_syllables: Array[int] = [3, 4, 3, 4]
var _crk_air_lp_l: float = 0.0
var _crk_air_lp_r: float = 0.0

var _thunder_env: float = 0.0
var _thunder_lp: float = 0.0

# --- DSP State: Generative Swells ---
const MAX_SWELL_VOICES: int = 4
var _sv_active: Array[bool] = [false, false, false, false]
var _sv_phase: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _sv_freq: Array[float] = [220.0, 220.0, 220.0, 220.0]
var _sv_gain_comp: Array[float] = [1.0, 1.0, 1.0, 1.0]
var _sv_age: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _sv_dur: Array[float] = [6.0, 6.0, 6.0, 6.0]
var _sv_pan: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _swl_lp_l: float = 0.0
var _swl_lp_r: float = 0.0
var _swell_spawn_timer: float = 0.1
var _scale_step_cursor: int = 0
var _moving_up: bool = true


func _ready() -> void:
	_rng.randomize()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.08

	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.bus = &"Master"
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func any_layer_enabled() -> bool:
	return brown_enabled or pink_enabled or velvet_enabled or binaural_enabled or (_bin_env > 0.0005) or nature_enabled or swells_enabled


func disable_all_layers() -> void:
	brown_enabled = false
	pink_enabled = false
	velvet_enabled = false
	binaural_enabled = false
	_bin_env = 0.0
	nature_enabled = false
	swells_enabled = false


func _get_span_for_scale(scale_idx: int) -> int:
	var intervals: Array = SCALE_INTERVALS[clampi(scale_idx, 0, SCALE_INTERVALS.size() - 1)]
	return intervals.size() * swells_octaves + 1


func reset_swell_sequence(prefer_descending: bool = false) -> void:
	if prefer_descending and swells_desc_enabled:
		_moving_up = false
		_scale_step_cursor = _get_span_for_scale(swells_scale_down_idx) - 1
	elif swells_asc_enabled:
		_moving_up = true
		_scale_step_cursor = 0
	elif swells_desc_enabled:
		_moving_up = false
		_scale_step_cursor = _get_span_for_scale(swells_scale_down_idx) - 1
	else:
		_moving_up = true
		_scale_step_cursor = 0
	_swell_spawn_timer = 0.08


func clamp_swell_wait_timer() -> void:
	var max_wait: float = swells_duration_sec + swells_gap_sec
	if _swell_spawn_timer > max_wait:
		_swell_spawn_timer = max_wait


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	if not any_layer_enabled():
		var silent_block := PackedVector2Array()
		silent_block.resize(mini(frames_available, 512))
		_playback.push_buffer(silent_block)
		return

	while frames_available > 0:
		var chunk: int = mini(frames_available, 64)
		var buf := PackedVector2Array()
		buf.resize(chunk)
		_render_block(buf, chunk)
		_playback.push_buffer(buf)
		frames_available -= chunk


func _render_block(buf: PackedVector2Array, count: int) -> void:
	var bh_sub_hz: float = BASE_C2_HZ * pow(2.0, brown_pitch_semi / 12.0)
	var bh_sub_inc: float = bh_sub_hz * INV_SR
	var bh_lfo_inc: float = brown_breath_hz * INV_SR

	var pc_sub_hz: float = BASE_C2_HZ * pow(2.0, pink_pitch_semi / 12.0)
	var pc_sub_inc: float = pc_sub_hz * INV_SR
	var pc_lfo_inc: float = pink_breath_hz * INV_SR

	var vf_root_hz: float = BASE_C2_HZ * pow(2.0, velvet_osc1_semi / 12.0)
	var vf_int_total_semi: float = velvet_osc1_semi + float(velvet_interval_semis) + velvet_osc2_semi
	var vf_int_hz: float = BASE_C2_HZ * pow(2.0, vf_int_total_semi / 12.0)
	var vf_root_inc: float = vf_root_hz * INV_SR
	var vf_int_inc: float = vf_int_hz * INV_SR
	var vf_lfo_inc: float = 0.04 * INV_SR

	var half_beat: float = binaural_beat_hz * 0.5
	var freq_l: float = maxf(20.0, binaural_carrier_hz - half_beat)
	var freq_r: float = maxf(20.0, binaural_carrier_hz + half_beat)
	var inc_l: float = freq_l * INV_SR
	var inc_r: float = freq_r * INV_SR
	var inc_iso: float = binaural_beat_hz * INV_SR
	var bin_target: float = 1.0 if binaural_enabled else 0.0
	var bin_env_step: float = INV_SR / 3.5

	var lfo1_inc: float = (0.04 + nature_rate * 0.45) * INV_SR
	var lfo2_inc: float = (0.027 + nature_rate * 0.31) * INV_SR

	# Straightforward chirp frequency rate (0.55 to 3.10 chirps/sec)
	var crk_base_chirp_hz: float = lerpf(0.55, 3.10, nature_rate)
	var crk_air_cf: float = lerpf(2600.0, 4800.0, nature_tone)
	var crk_air_alpha: float = clampf(1.0 - exp(-TAU * crk_air_cf * INV_SR), 0.08, 0.85)

	var swl_lp_cf: float = lerpf(2400.0, 480.0, swells_high_damp)
	var swl_lp_alpha: float = clampf(1.0 - exp(-TAU * swl_lp_cf * INV_SR), 0.01, 0.9)

	var m_vol: float = clampf(master_volume, 0.0, 1.5)

	for i in range(count):
		var out_l: float = 0.0
		var out_r: float = 0.0

		var w_l: float = _rng.randf_range(-1.0, 1.0)
		var w_r: float = _rng.randf_range(-1.0, 1.0)
		var w_mono: float = (w_l + w_r) * 0.5

		_pink_b0 = 0.99765 * _pink_b0 + w_mono * 0.0990460
		_pink_b1 = 0.96300 * _pink_b1 + w_mono * 0.2965164
		_pink_b2 = 0.57000 * _pink_b2 + w_mono * 1.0526913
		_pink_b3 = 0.18480 * w_mono
		var pink_base: float = (_pink_b0 + _pink_b1 + _pink_b2 + _pink_b3) * 0.18
		var pink_l: float = pink_base + w_l * 0.025
		var pink_r: float = pink_base + w_r * 0.025

		_brown_acc_l = (_brown_acc_l + 0.024 * w_l) / 1.012
		_brown_acc_r = (_brown_acc_r + 0.024 * w_r) / 1.012
		var brown_l: float = clampf(_brown_acc_l * 2.7, -1.0, 1.0)
		var brown_r: float = clampf(_brown_acc_r * 2.7, -1.0, 1.0)

		# 1. BROWN HEARTH
		if brown_enabled and brown_level > 0.001:
			_bh_sub_phase = fmod(_bh_sub_phase + bh_sub_inc, 1.0)
			_bh_lfo_phase = fmod(_bh_lfo_phase + bh_lfo_inc, 1.0)
			var bh_mod: float = sin(_bh_lfo_phase * TAU)
			var bh_tri: float = 4.0 * absf(_bh_sub_phase - 0.5) - 1.0
			var bh_sub: float = lerpf(sin(_bh_sub_phase * TAU), bh_tri, 0.35) * (brown_sub_level * 0.42)

			var bh_cf: float = clampf(brown_cutoff_hz * (1.0 + 0.26 * bh_mod), 40.0, 2400.0)
			var bh_alpha: float = clampf(1.0 - exp(-TAU * bh_cf * INV_SR), 0.001, 0.85)

			var raw_bh_l: float = brown_l * 0.85 + bh_sub
			var raw_bh_r: float = brown_r * 0.85 + bh_sub
			_bh_lp1_l += bh_alpha * (raw_bh_l - _bh_lp1_l)
			_bh_lp2_l += bh_alpha * (_bh_lp1_l - _bh_lp2_l)
			_bh_lp1_r += bh_alpha * (raw_bh_r - _bh_lp1_r)
			_bh_lp2_r += bh_alpha * (_bh_lp1_r - _bh_lp2_r)

			var bh_gain: float = brown_level * 0.65
			out_l += _bh_lp2_l * bh_gain
			out_r += _bh_lp2_r * bh_gain

		# 2. PINK CANOPY
		if pink_enabled and pink_level > 0.001:
			_pc_sub_phase = fmod(_pc_sub_phase + pc_sub_inc, 1.0)
			_pc_lfo_phase = fmod(_pc_lfo_phase + pc_lfo_inc, 1.0)
			var pc_mod: float = sin(_pc_lfo_phase * TAU)
			var pc_sub: float = sin(_pc_sub_phase * TAU) * 0.14

			var pc_cf: float = clampf(pink_cutoff_hz * (1.0 + pink_swell_depth * pc_mod), 80.0, 4000.0)
			var pc_alpha: float = clampf(1.0 - exp(-TAU * pc_cf * INV_SR), 0.001, 0.85)

			_pc_lp1_l += pc_alpha * ((pink_l * 0.9 + pc_sub) - _pc_lp1_l)
			_pc_lp2_l += pc_alpha * (_pc_lp1_l - _pc_lp2_l)
			_pc_lp1_r += pc_alpha * ((pink_r * 0.9 + pc_sub) - _pc_lp1_r)
			_pc_lp2_r += pc_alpha * (_pc_lp1_r - _pc_lp2_r)

			var pc_gain: float = pink_level * 0.52
			out_l += _pc_lp2_l * pc_gain
			out_r += _pc_lp2_r * pc_gain

		# 3. VELVET HARMONY
		if velvet_enabled and velvet_level > 0.001:
			_vf_root_phase = fmod(_vf_root_phase + vf_root_inc, 1.0)
			_vf_int_phase = fmod(_vf_int_phase + vf_int_inc, 1.0)
			_vf_lfo_phase = fmod(_vf_lfo_phase + vf_lfo_inc, 1.0)
			var vf_mod: float = sin(_vf_lfo_phase * TAU)

			var vf_root: float = lerpf(sin(_vf_root_phase * TAU), 4.0 * absf(_vf_root_phase - 0.5) - 1.0, 0.45)
			var vf_int_wave: float = sin(_vf_int_phase * TAU) * 0.55
			var vf_chord: float = (vf_root + vf_int_wave) * 0.34

			var vf_cf: float = clampf(velvet_cutoff_hz * (1.0 + 0.22 * vf_mod), 60.0, 2600.0)
			var vf_alpha: float = clampf(1.0 - exp(-TAU * vf_cf * INV_SR), 0.001, 0.85)

			_vf_lp1_l += vf_alpha * ((vf_chord + brown_l * velvet_floor_level * 0.65) - _vf_lp1_l)
			_vf_lp2_l += vf_alpha * (_vf_lp1_l - _vf_lp2_l)
			_vf_lp1_r += vf_alpha * ((vf_chord + brown_r * velvet_floor_level * 0.65) - _vf_lp1_r)
			_vf_lp2_r += vf_alpha * (_vf_lp1_r - _vf_lp2_r)

			var vf_gain: float = velvet_level * 0.55
			out_l += _vf_lp2_l * vf_gain
			out_r += _vf_lp2_r * vf_gain

		# 4. BINAURAL / ISOCHRONIC LAYER
		if _bin_env < bin_target:
			_bin_env = minf(bin_target, _bin_env + bin_env_step)
		elif _bin_env > bin_target:
			_bin_env = maxf(bin_target, _bin_env - bin_env_step)

		if _bin_env > 0.0005 and binaural_level > 0.001:
			_bin_phase_l = fmod(_bin_phase_l + inc_l, 1.0)
			_bin_phase_r = fmod(_bin_phase_r + inc_r, 1.0)
			_iso_phase = fmod(_iso_phase + inc_iso, 1.0)

			var sl: float = sin(_bin_phase_l * TAU)
			var sr: float = sin(_bin_phase_r * TAU)

			if binaural_mode == BinauralMode.ISOCHRONIC:
				var mono_carrier: float = sin((_bin_phase_l + _bin_phase_r) * 0.5 * TAU)
				var pulse: float = 0.5 - 0.5 * cos(_iso_phase * TAU)
				var mod_env: float = lerpf(1.0, pulse, binaural_depth * 0.85)
				sl = mono_carrier * mod_env * 0.78
				sr = sl
			elif binaural_mode == BinauralMode.BOTH:
				var pulse_b: float = 0.5 - 0.5 * cos(_iso_phase * TAU)
				var mod_b: float = lerpf(1.0, pulse_b, binaural_depth * 0.55)
				sl *= mod_b * 0.85
				sr *= mod_b * 0.85

			var smooth_env: float = _bin_env * _bin_env * (3.0 - 2.0 * _bin_env)
			var b_gain: float = binaural_level * 0.068 * smooth_env
			out_l += sl * b_gain
			out_r += sr * b_gain

		# 5. FILTERED NATURE TEXTURES
		if nature_enabled and nature_level > 0.001:
			_nat_lfo1 = fmod(_nat_lfo1 + lfo1_inc, 1.0)
			_nat_lfo2 = fmod(_nat_lfo2 + lfo2_inc, 1.0)
			var m1: float = sin(_nat_lfo1 * TAU)
			var m2: float = sin(_nat_lfo2 * TAU)

			var nl: float = 0.0
			var nr: float = 0.0

			match nature_type:
				NatureType.DISTANT_RAIN:
					var base_cf: float = lerpf(550.0, 2600.0, nature_tone)
					var cf_l: float = clampf(base_cf * (1.0 + 0.22 * m1), 180.0, 6000.0)
					var cf_r: float = clampf(base_cf * (1.0 + 0.22 * m2), 180.0, 6000.0)
					var q_rain: float = lerpf(0.85, 0.35, nature_density)
					var f_l: float = minf(0.45, 2.0 * sin(PI * cf_l * INV_SR))
					var f_r: float = minf(0.45, 2.0 * sin(PI * cf_r * INV_SR))
					var hp_l: float = pink_l - _nat_bp_low_l - q_rain * _nat_bp_band_l
					_nat_bp_band_l += f_l * hp_l
					_nat_bp_low_l += f_l * _nat_bp_band_l
					var hp_r: float = (pink_r * 0.8 + w_r * 0.08) - _nat_bp_low_r - q_rain * _nat_bp_band_r
					_nat_bp_band_r += f_r * hp_r
					_nat_bp_low_r += f_r * _nat_bp_band_r
					nl = _nat_bp_band_l * 1.4
					nr = _nat_bp_band_r * 1.4

				NatureType.WIND_TREES:
					var wind_cf: float = lerpf(240.0, 1150.0, nature_tone)
					var cf_wl: float = clampf(wind_cf * (1.0 + 0.55 * m1), 120.0, 3200.0)
					var cf_wr: float = clampf(wind_cf * (1.0 + 0.55 * m2), 120.0, 3200.0)
					var q_wind: float = lerpf(0.42, 0.14, nature_density)
					var f_wl: float = minf(0.45, 2.0 * sin(PI * cf_wl * INV_SR))
					var f_wr: float = minf(0.45, 2.0 * sin(PI * cf_wr * INV_SR))
					var hp_wl: float = pink_l - _nat_bp_low_l - q_wind * _nat_bp_band_l
					_nat_bp_band_l += f_wl * hp_wl
					_nat_bp_low_l += f_wl * _nat_bp_band_l
					var hp_wr: float = pink_r - _nat_bp_low_r - q_wind * _nat_bp_band_r
					_nat_bp_band_r += f_wr * hp_wr
					_nat_bp_low_r += f_wr * _nat_bp_band_r
					nl = _nat_bp_band_l * (0.85 + 0.35 * m2)
					nr = _nat_bp_band_r * (0.85 + 0.35 * m1)

				NatureType.OCEAN_SURF:
					var wave_env: float = pow(0.5 + 0.5 * m1, 2.2)
					var surf_cf: float = lerpf(180.0, 1400.0, wave_env * (0.4 + 0.6 * nature_tone))
					var f_s: float = minf(0.42, 2.0 * sin(PI * surf_cf * INV_SR))
					_nat_bp_low_l += f_s * ((pink_base * 1.3 + brown_l * 0.5) - _nat_bp_low_l)
					var foam: float = _nat_bp_low_l * (0.25 + 1.15 * wave_env)
					nl = foam * (1.0 + 0.15 * m2)
					nr = foam * (1.0 - 0.15 * m2)

				NatureType.FIRE_CRACKLE:
					_crackle_lp += 0.03 * (brown_l - _crackle_lp)
					var prob: float = (0.00015 + nature_density * 0.0014) * (0.5 + nature_rate)
					if _rng.randf() < prob:
						_crackle_env = _rng.randf_range(0.35, 1.0)
						_crackle_pan = _rng.randf_range(-0.85, 0.85)
					_crackle_env *= 0.992
					var pop: float = (w_mono - _nat_bp_low_r) * _crackle_env * (1.2 + nature_tone * 1.5)
					_nat_bp_low_r += 0.28 * (w_mono - _nat_bp_low_r)
					var bed: float = _crackle_lp * 0.55
					nl = bed + pop * (1.0 - maxf(0.0, _crackle_pan))
					nr = bed + pop * (1.0 + minf(0.0, _crackle_pan))

				NatureType.NIGHT_CRICKETS:
					var active_voices: int = 2 if nature_density < 0.35 else (3 if nature_density < 0.72 else 4)
					var pitch_scale: float = lerpf(0.86, 1.12, nature_tone)

					var sum_crk_l: float = 0.0
					var sum_crk_r: float = 0.0

					for c in range(active_voices):
						var chirp_hz: float = crk_base_chirp_hz * _crk_rate_ratio[c]
						_crk_cycle_phase[c] = fmod(_crk_cycle_phase[c] + chirp_hz * INV_SR, 1.0)
						var cyc_ph: float = _crk_cycle_phase[c]

						var duty: float = clampf(0.24 + chirp_hz * 0.07, 0.24, 0.46)
						if cyc_ph < duty:
							var syl_count: int = _crk_syllables[c]
							var burst_pos: float = (cyc_ph / duty) * float(syl_count)
							var syl_idx: int = int(burst_pos)
							var local_t: float = fmod(burst_pos, 1.0)

							var env: float = 0.0
							if local_t < 0.16:
								env = local_t / 0.16
							else:
								env = exp(-(local_t - 0.16) * 3.6)

							var burst_taper: float = 0.68 if (syl_idx == 0 or syl_idx == syl_count - 1) else 1.0
							env *= burst_taper

							var inst_hz: float = _crk_base_hz[c] * pitch_scale * (1.0 - 0.032 * local_t)
							_crk_phase[c] = fmod(_crk_phase[c] + inst_hz * INV_SR, 1.0)
							var ph_c: float = _crk_phase[c]
							var body: float = sin(ph_c * TAU) * 0.88 + sin(ph_c * 2.0 * TAU) * 0.12
							var sig: float = body * env * _crk_dist_gain[c] * 0.65

							var p_c: float = _crk_pan[c]
							sum_crk_l += sig * sqrt(0.5 * (1.0 - p_c))
							sum_crk_r += sig * sqrt(0.5 * (1.0 + p_c))

					_crk_air_lp_l += crk_air_alpha * (sum_crk_l - _crk_air_lp_l)
					_crk_air_lp_r += crk_air_alpha * (sum_crk_r - _crk_air_lp_r)
					nl = _crk_air_lp_l + pink_l * 0.035
					nr = _crk_air_lp_r + pink_r * 0.035

				NatureType.BROOK_STREAM:
					var mod_cf: float = lerpf(420.0, 1900.0, nature_tone) * (1.0 + 0.45 * m1 * m2)
					var f_b: float = minf(0.45, 2.0 * sin(PI * mod_cf * INV_SR))
					var hp_b: float = pink_base - _nat_bp_low_l - 0.18 * _nat_bp_band_l
					_nat_bp_band_l += f_b * hp_b
					_nat_bp_low_l += f_b * _nat_bp_band_l
					nl = _nat_bp_band_l * (0.9 + 0.3 * m1)
					nr = _nat_bp_band_l * (0.9 - 0.3 * m2)

				NatureType.THUNDER_RUMBLE:
					if _rng.randf() < (0.000012 + nature_rate * 0.00005):
						_thunder_env = _rng.randf_range(0.55, 1.0)
					_thunder_env *= 0.99992
					var t_cf: float = lerpf(48.0, 145.0, nature_tone) * (0.6 + 0.6 * _thunder_env)
					var f_t: float = minf(0.25, 2.0 * sin(PI * t_cf * INV_SR))
					_thunder_lp += f_t * ((brown_l * 1.6 + pink_base * 0.3) - _thunder_lp)
					var rumble: float = _thunder_lp * (0.25 + 1.45 * _thunder_env)
					nl = rumble * (1.0 + 0.18 * m1)
					nr = rumble * (1.0 - 0.18 * m1)

			var n_gain: float = nature_level * 0.38
			out_l += nl * n_gain
			out_r += nr * n_gain

		# 6. GENERATIVE HARMONIC SWELLS (Full-duration sustained plateau envelope)
		if swells_enabled and swells_level > 0.001:
			_swell_spawn_timer -= INV_SR
			if _swell_spawn_timer <= 0.0:
				var dur_used: float = _trigger_next_swell_voice()
				_swell_spawn_timer = dur_used + swells_gap_sec

			var s_gain: float = swells_level * 0.24
			var swl_sum_l: float = 0.0
			var swl_sum_r: float = 0.0

			for v in range(MAX_SWELL_VOICES):
				if not _sv_active[v]:
					continue
				_sv_age[v] += INV_SR
				if _sv_age[v] >= _sv_dur[v]:
					_sv_active[v] = false
					continue

				# Smooth cosine fade-in (first 22%), full sustain plateau (middle 56%), smooth cosine fade-out (last 22%)
				var norm_t: float = _sv_age[v] / _sv_dur[v]
				var env: float = 1.0
				if norm_t < 0.22:
					env = 0.5 - 0.5 * cos((norm_t / 0.22) * PI)
				elif norm_t > 0.78:
					env = 0.5 - 0.5 * cos(((1.0 - norm_t) / 0.22) * PI)

				_sv_phase[v] = fmod(_sv_phase[v] + _sv_freq[v] * INV_SR, 1.0)
				var ph: float = _sv_phase[v]
				var sample: float = 0.0
				match swells_wave:
					SwellWave.SINE:
						sample = sin(ph * TAU)
					SwellWave.TRIANGLE:
						sample = 4.0 * absf(ph - 0.5) - 1.0
					SwellWave.SOFT_WARM:
						sample = sin(ph * TAU) * 0.82 + sin(ph * 2.0 * TAU) * 0.18

				var amp: float = sample * env * s_gain * _sv_gain_comp[v]
				var pan: float = _sv_pan[v]
				swl_sum_l += amp * sqrt(0.5 * (1.0 - pan))
				swl_sum_r += amp * sqrt(0.5 * (1.0 + pan))

			_swl_lp_l += swl_lp_alpha * (swl_sum_l - _swl_lp_l)
			_swl_lp_r += swl_lp_alpha * (swl_sum_r - _swl_lp_r)
			out_l += _swl_lp_l
			out_r += _swl_lp_r

		out_l *= m_vol
		out_r *= m_vol
		buf[i] = Vector2(clampf(out_l, -0.95, 0.95), clampf(out_r, -0.95, 0.95))


func _midi_to_note_label(midi: int) -> String:
	var note_idx: int = posmod(midi, 12)
	var oct: int = int(midi / 12) - 1
	return "%s%d" % [NOTE_NAMES[note_idx], oct]


func _trigger_next_swell_voice() -> float:
	if not swells_asc_enabled and not swells_desc_enabled:
		return swells_duration_sec

	var slot: int = -1
	for v in range(MAX_SWELL_VOICES):
		if not _sv_active[v]:
			slot = v
			break
	if slot == -1:
		var max_age: float = -1.0
		for v in range(MAX_SWELL_VOICES):
			if _sv_age[v] > max_age:
				max_age = _sv_age[v]
				slot = v

	if swells_asc_enabled and not swells_desc_enabled:
		_moving_up = true
	elif swells_desc_enabled and not swells_asc_enabled:
		_moving_up = false

	var active_scale_idx: int = swells_scale_up_idx if _moving_up else swells_scale_down_idx
	active_scale_idx = clampi(active_scale_idx, 0, SCALE_INTERVALS.size() - 1)
	var intervals: Array = SCALE_INTERVALS[active_scale_idx]
	var scale_len: int = intervals.size()
	var span: int = _get_span_for_scale(active_scale_idx)

	_scale_step_cursor = clampi(_scale_step_cursor, 0, span - 1)
	var octave_offset: int = int(_scale_step_cursor / scale_len) * 12
	var degree_semi: int = int(intervals[_scale_step_cursor % scale_len])
	var midi_note: int = swells_root_midi + octave_offset + degree_semi
	var hz: float = 440.0 * pow(2.0, float(midi_note - 69) / 12.0)

	var dur: float = maxf(0.5, swells_duration_sec)
	var dir_tag: String = "ASC" if _moving_up else "DESC"
	swells_status_text = "%s: %s (%s | %.1fs hold + %.1fs gap)" % [dir_tag, SCALE_NAMES[active_scale_idx], _midi_to_note_label(midi_note), dur, swells_gap_sec]

	var octaves_above_c3: float = maxf(0.0, float(midi_note - 48) / 12.0)
	var db_drop_per_oct: float = lerpf(2.5, 9.5, swells_high_damp)
	var gain_comp: float = pow(10.0, (-db_drop_per_oct * octaves_above_c3) / 20.0)

	if _moving_up:
		_scale_step_cursor += 1
		if _scale_step_cursor >= span:
			if swells_desc_enabled:
				_moving_up = false
				var down_span: int = _get_span_for_scale(swells_scale_down_idx)
				_scale_step_cursor = maxi(0, down_span - 2)
			else:
				_scale_step_cursor = 0
	else:
		_scale_step_cursor -= 1
		if _scale_step_cursor < 0:
			if swells_asc_enabled:
				_moving_up = true
				var up_span: int = _get_span_for_scale(swells_scale_up_idx)
				_scale_step_cursor = 1 if up_span > 1 else 0
			else:
				_scale_step_cursor = span - 1

	_sv_active[slot] = true
	_sv_phase[slot] = 0.0
	_sv_freq[slot] = hz
	_sv_gain_comp[slot] = gain_comp
	_sv_age[slot] = 0.0
	_sv_dur[slot] = dur
	_sv_pan[slot] = _rng.randf_range(-swells_spread, swells_spread)
	return dur
