class_name PolyBLEPOsc
extends RefCounted

var phase: float = 0.0


func reset(initial_phase: float = 0.0) -> void:
	phase = fmod(absf(initial_phase), 1.0)


func _poly_blep(t: float, dt: float) -> float:
	if dt <= 0.0:
		return 0.0
	if t < dt:
		var x: float = t / dt
		return x + x - x * x - 1.0
	elif t > 1.0 - dt:
		var x: float = (t - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


func process(freq_hz: float, inv_sample_rate: float, waveform: int) -> float:
	var dt: float = clampf(freq_hz * inv_sample_rate, 0.0, 0.49)
	var t: float = phase
	var sample: float = 0.0

	match waveform:
		OscConfig.Waveform.TRIANGLE:
			sample = 4.0 * absf(t - 0.5) - 1.0
		OscConfig.Waveform.SHARKTOOTH:
			# Authentic Minimoog hybrid Triangle + Sawtooth waveform
			var tri: float = 4.0 * absf(t - 0.5) - 1.0
			var saw: float = (2.0 * t - 1.0) - _poly_blep(t, dt)
			sample = (tri * 0.55) + (saw * 0.45)
		OscConfig.Waveform.SAWTOOTH:
			sample = (2.0 * t - 1.0) - _poly_blep(t, dt)
		OscConfig.Waveform.SQUARE:
			sample = (1.0 if t < 0.5 else -1.0)
			sample += _poly_blep(t, dt)
			sample -= _poly_blep(fmod(t + 0.5, 1.0), dt)
		OscConfig.Waveform.WIDE_PULSE:
			var pw_wide: float = 0.25
			sample = (1.0 if t < pw_wide else -1.0)
			sample += _poly_blep(t, dt)
			sample -= _poly_blep(fmod(t + (1.0 - pw_wide), 1.0), dt)
		OscConfig.Waveform.NARROW_PULSE:
			var pw_narrow: float = 0.125
			sample = (1.0 if t < pw_narrow else -1.0)
			sample += _poly_blep(t, dt)
			sample -= _poly_blep(fmod(t + (1.0 - pw_narrow), 1.0), dt)

	phase += dt
	if phase >= 1.0:
		phase -= 1.0

	return sample
