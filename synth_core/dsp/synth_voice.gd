class_name SynthVoice
extends RefCounted

const MAX_VOICE_OSCS: int = 8
const SUB_BLOCK_SIZE: int = 32

var active: bool = false
var gate_on: bool = false
var midi_note: int = 60
var velocity: float = 0.85
var current_freq: float = 261.6256
var target_freq: float = 261.6256
var age: int = 0

var _osc_phases := PackedFloat64Array()
var _osc3_sub_buf := PackedFloat32Array()
var _noise_sub_buf := PackedFloat32Array()

# Seeded PRNG + Pink/Brown filter states
var _seed: int = 19710808
var _b0: float = 0.0
var _b1: float = 0.0
var _b2: float = 0.0
var _brown_state: float = 0.0

# 4-pole Moog ladder states
var _delay0: float = 0.0
var _delay1: float = 0.0
var _delay2: float = 0.0
var _delay3: float = 0.0

# Envelope states (0=IDLE, 1=ATTACK, 2=DECAY, 3=SUSTAIN, 4=RELEASE)
var _f_stage: int = 0
var _f_val: float = 0.0
var _a_stage: int = 0
var _a_val: float = 0.0

var _drift_phase: float = 0.0


func _init(voice_index: int = 0) -> void:
	_osc_phases.resize(MAX_VOICE_OSCS)
	for i in range(MAX_VOICE_OSCS):
		_osc_phases[i] = float((voice_index * 3 + i) % 7) * 0.13

	_osc3_sub_buf.resize(SUB_BLOCK_SIZE)
	_noise_sub_buf.resize(SUB_BLOCK_SIZE)
	_seed = 19710808 + voice_index * 7919
	_drift_phase = float(voice_index) * 0.19


func midi_to_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


func _reset_filter() -> void:
	_delay0 = 0.0
	_delay1 = 0.0
	_delay2 = 0.0
	_delay3 = 0.0


func note_on(note: int, vel: float, age_stamp: int, glide_from_active: bool, reset_envelopes: bool) -> void:
	midi_note = note
	velocity = vel
	age = age_stamp
	target_freq = midi_to_hz(float(note))
	if not glide_from_active or not active:
		current_freq = target_freq
		_reset_filter()
	active = true
	gate_on = true
	if reset_envelopes or _f_stage == 0:
		_f_val = 0.0
	if reset_envelopes or _a_stage == 0:
		_a_val = 0.0
	_f_stage = 1
	_a_stage = 1


func note_off() -> void:
	gate_on = false
	if _f_stage != 0:
		_f_stage = 4
	if _a_stage != 0:
		_a_stage = 4


func panic_kill() -> void:
	active = false
	gate_on = false
	_f_stage = 0
	_f_val = 0.0
	_a_stage = 0
	_a_val = 0.0
	_reset_filter()


func _step_envelope_block(is_filter: bool, block_samples: float, sample_rate: float, cfg: ContourConfig) -> float:
	var stage: int = _f_stage if is_filter else _a_stage
	var val: float = _f_val if is_filter else _a_val

	if stage == 0 or cfg == null:
		return 0.0

	match stage:
		1: # ATTACK
			var attack_samples: float = maxf(1.0, (cfg.attack_ms * 0.001) * sample_rate)
			val += block_samples / attack_samples
			if val >= 1.0:
				val = 1.0
				stage = 2
		2: # DECAY
			var decay_samples: float = maxf(1.0, (cfg.decay_ms * 0.001) * sample_rate)
			var coeff: float = 1.0 - exp(-4.6 * block_samples / decay_samples)
			val += (cfg.sustain_level - val) * coeff
			if absf(val - cfg.sustain_level) < 0.0005:
				val = cfg.sustain_level
				stage = 3
		3: # SUSTAIN
			val = cfg.sustain_level
		4: # RELEASE
			var rel_ms: float = cfg.decay_ms if cfg.release_on_decay else 8.0
			var rel_samples: float = maxf(1.0, (rel_ms * 0.001) * sample_rate)
			var rel_coeff: float = 1.0 - exp(-5.0 * block_samples / rel_samples)
			val += (0.0 - val) * rel_coeff
			if val <= 0.0002:
				val = 0.0
				stage = 0

	if is_filter:
		_f_stage = stage
		_f_val = val
	else:
		_a_stage = stage
		_a_val = val

	return val


func process_block(out_buf: PackedFloat32Array, num_frames: int, sample_rate: float, inv_sr: float, patch: SynthPatch, pitch_bend_semis: float) -> void:
	out_buf.fill(0.0)
	if not active:
		return

	var oversampled_rate: float = sample_rate * 2.0
	var osc_count: int = mini(patch.oscillators.size(), MAX_VOICE_OSCS)
	var noise_enabled: bool = (patch.noise != null and patch.noise.enabled)
	var noise_color: int = patch.noise.color if patch.noise != null else 0
	var noise_level: float = patch.noise.level if noise_enabled else 0.0

	var base_cutoff: float = patch.filter.cutoff_hz if patch.filter != null else 2400.0
	var contour_amt: float = patch.filter.contour_amount if patch.filter != null else 0.0
	var kbd_ratio: float = patch.filter.get_kbd_tracking_ratio() if patch.filter != null else 0.0
	var emphasis: float = patch.filter.emphasis if patch.filter != null else 0.5
	var drive: float = patch.filter.overload_drive if patch.filter != null else 0.0
	var has_drive: bool = drive > 0.01
	var drive_gain: float = 1.0 + drive * 2.5
	var kbd_octaves: float = ((float(midi_note) - 60.0) / 12.0) * kbd_ratio

	# Check if any active mod route needs noise even when audio noise is muted
	var need_noise_for_mod: bool = false
	for r in patch.mod_routes:
		if r != null and r.enabled and r.source == ModRoute.ModSource.NOISE and absf(r.amount) >= 0.0001:
			need_noise_for_mod = true
			break

	var cursor: int = 0
	while cursor < num_frames:
		var block_len: int = mini(SUB_BLOCK_SIZE, num_frames - cursor)
		var f_block: float = float(block_len)

		# 1. Control-rate Glide & Envelopes
		if absf(current_freq - target_freq) > 0.001:
			if patch.glide_ms <= 0.5:
				current_freq = target_freq
			else:
				var glide_samples: float = (patch.glide_ms * 0.001) * sample_rate
				var glide_coeff: float = 1.0 - exp(-2.5 * f_block / maxf(1.0, glide_samples))
				current_freq += (target_freq - current_freq) * glide_coeff

		var f_env_val: float = _step_envelope_block(true, f_block, sample_rate, patch.filter_contour)
		var a_env_val: float = _step_envelope_block(false, f_block, sample_rate, patch.loudness_contour)

		if _a_stage == 0:
			active = false
			break

		# 2. Control-rate Drift LFO
		_drift_phase += 0.035 * inv_sr * f_block
		if _drift_phase >= 1.0:
			_drift_phase -= 1.0
		var drift_val: float = sin(_drift_phase * TAU)

		# 3. Pre-fill Noise Sub-Block only if needed
		if noise_enabled or need_noise_for_mod:
			var s_seed: int = _seed
			var b0: float = _b0
			var b1: float = _b1
			var b2: float = _b2
			var br: float = _brown_state
			for k in range(block_len):
				s_seed = int((s_seed * 1664525 + 1013904223) & 0x7FFFFFFF)
				var white: float = (float(s_seed) / 1073741824.0) - 1.0
				if noise_color == 0:
					_noise_sub_buf[k] = white * 0.75
				elif noise_color == 1:
					b0 = 0.99765 * b0 + white * 0.0990460
					b1 = 0.96300 * b1 + white * 0.2965164
					b2 = 0.57000 * b2 + white * 1.0526913
					_noise_sub_buf[k] = clampf((b0 + b1 + b2 + white * 0.1848) * 0.22, -1.0, 1.0)
				else:
					br = (br + (0.025 * white)) / 1.012
					_noise_sub_buf[k] = clampf(br * 2.8, -1.0, 1.0)
			_seed = s_seed
			_b0 = b0
			_b1 = b1
			_b2 = b2
			_brown_state = br
		else:
			_noise_sub_buf.fill(0.0)

		# 4. Pre-fill Oscillator 3 Sub-Block if enabled (supports audio-rate FM & filter FM)
		var osc3_active: bool = (osc_count >= 3 and patch.oscillators[2] != null and patch.oscillators[2].enabled)
		if osc3_active:
			var o3_cfg: OscConfig = patch.oscillators[2]
			var o3_freq: float = o3_cfg.lo_freq_hz
			if o3_cfg.octave_range != OscConfig.OctaveRange.LO:
				var semi3: float = o3_cfg.get_octave_semitone_offset() + o3_cfg.detune_semitones + pitch_bend_semis
				o3_freq = current_freq * pow(2.0, semi3 / 12.0)
			var dt3: float = clampf(o3_freq * inv_sr, 0.0, 0.49)
			var wf3: int = o3_cfg.waveform
			var ph3: float = _osc_phases[2]
			for k in range(block_len):
				var s3: float = 0.0
				match wf3:
					0:
						s3 = 4.0 * absf(ph3 - 0.5) - 1.0
					1:
						var tri3: float = 4.0 * absf(ph3 - 0.5) - 1.0
						var blep_s3: float = 0.0
						if dt3 > 0.0:
							if ph3 < dt3:
								var x: float = ph3 / dt3
								blep_s3 = x + x - x * x - 1.0
							elif ph3 > 1.0 - dt3:
								var x: float = (ph3 - 1.0) / dt3
								blep_s3 = x * x + x + x + 1.0
						s3 = tri3 * 0.55 + ((2.0 * ph3 - 1.0) - blep_s3) * 0.45
					2:
						var blep_s3: float = 0.0
						if dt3 > 0.0:
							if ph3 < dt3:
								var x: float = ph3 / dt3
								blep_s3 = x + x - x * x - 1.0
							elif ph3 > 1.0 - dt3:
								var x: float = (ph3 - 1.0) / dt3
								blep_s3 = x * x + x + x + 1.0
						s3 = (2.0 * ph3 - 1.0) - blep_s3
					3:
						s3 = 1.0 if ph3 < 0.5 else -1.0
					4:
						s3 = 1.0 if ph3 < 0.25 else -1.0
					5:
						s3 = 1.0 if ph3 < 0.125 else -1.0
				_osc3_sub_buf[k] = s3
				ph3 += dt3
				if ph3 >= 1.0:
					ph3 -= 1.0
			_osc_phases[2] = ph3
		else:
			_osc3_sub_buf.fill(0.0)

		# 5. Evaluate Modulation Routes at control rate
		var pitch_mod_semis: float = 0.0
		var cutoff_mod_octaves: float = 0.0
		var amp_mod: float = 0.0
		var detune_mod_semis: float = 0.0
		var osc3_mid: float = _osc3_sub_buf[0]
		var noise_mid: float = _noise_sub_buf[0]

		for route in patch.mod_routes:
			if route == null or not route.enabled or absf(route.amount) < 0.0001:
				continue
			var src_val: float = 0.0
			match route.source:
				ModRoute.ModSource.OSC_3:
					src_val = osc3_mid
				ModRoute.ModSource.NOISE:
					src_val = noise_mid
				ModRoute.ModSource.FILTER_ENV:
					src_val = f_env_val
				ModRoute.ModSource.DRIFT_LFO:
					src_val = drift_val

			if absf(route.curve_power - 1.0) > 0.01:
				src_val = signf(src_val) * pow(absf(src_val), route.curve_power)

			var scaled: float = src_val * route.amount
			match route.target:
				ModRoute.ModTarget.PITCH:
					pitch_mod_semis += scaled * 7.0
				ModRoute.ModTarget.FILTER_CUTOFF:
					cutoff_mod_octaves += scaled * 4.0
				ModRoute.ModTarget.AMP_LEVEL:
					amp_mod += scaled * 0.5
				ModRoute.ModTarget.OSC_DETUNE:
					detune_mod_semis += scaled * 0.5

		# 6. Precompute Oscillator frequencies & Filter coefficients once per 32-sample sub-block
		var osc_dts := PackedFloat32Array()
		var osc_levels := PackedFloat32Array()
		var osc_waves := PackedInt32Array()
		osc_dts.resize(osc_count)
		osc_levels.resize(osc_count)
		osc_waves.resize(osc_count)

		for i in range(osc_count):
			var osc_cfg: OscConfig = patch.oscillators[i]
			if osc_cfg == null or not osc_cfg.enabled:
				osc_levels[i] = 0.0
				continue
			osc_waves[i] = osc_cfg.waveform
			osc_levels[i] = 0.0 if osc_cfg.mod_source_only else osc_cfg.level
			if i != 2:
				var osc_freq: float = osc_cfg.lo_freq_hz
				if osc_cfg.octave_range != OscConfig.OctaveRange.LO:
					var detune_spread: float = detune_mod_semis * (1.0 if (i % 2 == 0) else -1.0)
					var total_semis: float = osc_cfg.get_octave_semitone_offset() + osc_cfg.detune_semitones + pitch_bend_semis + pitch_mod_semis + detune_spread
					osc_freq = current_freq * pow(2.0, total_semis / 12.0)
				osc_dts[i] = clampf(osc_freq * inv_sr, 0.0, 0.49)

		var env_octaves: float = f_env_val * contour_amt * 5.0
		var effective_cutoff: float = base_cutoff * pow(2.0, kbd_octaves + env_octaves + cutoff_mod_octaves)
		var clamped_cutoff: float = clampf(effective_cutoff, 20.0, oversampled_rate * 0.42)
		var filt_f: float = 1.0 - exp(-TAU * clamped_cutoff / oversampled_rate)
		var filt_one_minus_f: float = 1.0 - filt_f
		var filt_fb: float = clampf(emphasis, 0.0, 3.95)
		var final_gain: float = clampf(a_env_val * (1.0 + amp_mod), 0.0, 1.5) * velocity

		# 7. Inner Audio Loop (zero function calls, pure local register arithmetic)
		var d0: float = _delay0
		var d1: float = _delay1
		var d2: float = _delay2
		var d3: float = _delay3

		for k in range(block_len):
			var mix: float = 0.0
			for i in range(osc_count):
				var lvl: float = osc_levels[i]
				if lvl <= 0.0001:
					continue
				if i == 2:
					mix += _osc3_sub_buf[k] * lvl
					continue

				var ph: float = _osc_phases[i]
				var dt: float = osc_dts[i]
				var wf: int = osc_waves[i]
				var s: float = 0.0

				if wf == 0: # TRIANGLE
					s = 4.0 * absf(ph - 0.5) - 1.0
				elif wf == 1: # SHARKTOOTH
					var tri: float = 4.0 * absf(ph - 0.5) - 1.0
					var blep: float = 0.0
					if dt > 0.0:
						if ph < dt:
							var x: float = ph / dt
							blep = x + x - x * x - 1.0
						elif ph > 1.0 - dt:
							var x: float = (ph - 1.0) / dt
							blep = x * x + x + x + 1.0
					s = tri * 0.55 + ((2.0 * ph - 1.0) - blep) * 0.45
				elif wf == 2: # SAWTOOTH
					var blep: float = 0.0
					if dt > 0.0:
						if ph < dt:
							var x: float = ph / dt
							blep = x + x - x * x - 1.0
						elif ph > 1.0 - dt:
							var x: float = (ph - 1.0) / dt
							blep = x * x + x + x + 1.0
					s = (2.0 * ph - 1.0) - blep
				elif wf == 3: # SQUARE
					s = 1.0 if ph < 0.5 else -1.0
					if dt > 0.0:
						if ph < dt:
							var x: float = ph / dt
							s += x + x - x * x - 1.0
						elif ph > 1.0 - dt:
							var x: float = (ph - 1.0) / dt
							s += x * x + x + x + 1.0
						var ph_half: float = ph + 0.5
						if ph_half >= 1.0:
							ph_half -= 1.0
						if ph_half < dt:
							var x2: float = ph_half / dt
							s -= x2 + x2 - x2 * x2 - 1.0
						elif ph_half > 1.0 - dt:
							var x2: float = (ph_half - 1.0) / dt
							s -= x2 * x2 + x2 + x2 + 1.0
				elif wf == 4: # WIDE_PULSE (25%)
					s = 1.0 if ph < 0.25 else -1.0
				else: # NARROW_PULSE (12.5%)
					s = 1.0 if ph < 0.125 else -1.0

				ph += dt
				if ph >= 1.0:
					ph -= 1.0
				_osc_phases[i] = ph
				mix += s * lvl

			if noise_enabled:
				mix += _noise_sub_buf[k] * noise_level

			if has_drive:
				var dx: float = clampf(mix * drive_gain, -3.5, 3.5)
				mix = dx * (27.0 + dx * dx) / (27.0 + 9.0 * dx * dx)
			else:
				mix *= 0.65

			# 2x Oversampled 4-Pole Ladder Filter
			var inp1: float = clampf(mix - filt_fb * d3, -3.5, 3.5)
			var inp1_sq: float = inp1 * inp1
			inp1 = inp1 * (27.0 + inp1_sq) / (27.0 + 9.0 * inp1_sq)
			d0 = inp1 * filt_f + d0 * filt_one_minus_f
			d1 = d0 * filt_f + d1 * filt_one_minus_f
			d2 = d1 * filt_f + d2 * filt_one_minus_f
			d3 = d2 * filt_f + d3 * filt_one_minus_f

			var inp2: float = clampf(mix - filt_fb * d3, -3.5, 3.5)
			var inp2_sq: float = inp2 * inp2
			inp2 = inp2 * (27.0 + inp2_sq) / (27.0 + 9.0 * inp2_sq)
			d0 = inp2 * filt_f + d0 * filt_one_minus_f
			d1 = d0 * filt_f + d1 * filt_one_minus_f
			d2 = d1 * filt_f + d2 * filt_one_minus_f
			d3 = d2 * filt_f + d3 * filt_one_minus_f

			out_buf[cursor + k] = d3 * final_gain

		_delay0 = d0
		_delay1 = d1
		_delay2 = d2
		_delay3 = d3
		cursor += block_len
