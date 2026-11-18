class_name MoogLadderFilter
extends RefCounted

# 4-pole 24dB/oct non-linear resonant low-pass ladder filter (2x oversampled)
var _stage0: float = 0.0
var _stage1: float = 0.0
var _stage2: float = 0.0
var _stage3: float = 0.0
var _delay0: float = 0.0
var _delay1: float = 0.0
var _delay2: float = 0.0
var _delay3: float = 0.0


func reset() -> void:
	_stage0 = 0.0
	_stage1 = 0.0
	_stage2 = 0.0
	_stage3 = 0.0
	_delay0 = 0.0
	_delay1 = 0.0
	_delay2 = 0.0
	_delay3 = 0.0


func _fast_tanh(x: float) -> float:
	var clamped: float = clampf(x, -3.5, 3.5)
	var x2: float = clamped * clamped
	return clamped * (27.0 + x2) / (27.0 + 9.0 * x2)


func process(input_sample: float, cutoff_hz: float, emphasis: float, sample_rate: float) -> float:
	var oversampled_rate: float = sample_rate * 2.0
	var clamped_cutoff: float = clampf(cutoff_hz, 20.0, oversampled_rate * 0.42)
	var f: float = 1.0 - exp(-TAU * clamped_cutoff / oversampled_rate)
	var fb: float = clampf(emphasis, 0.0, 3.95)

	var out: float = 0.0
	for _step in range(2):
		var inp: float = input_sample - fb * _delay3
		inp = _fast_tanh(inp)

		_stage0 = inp * f + _delay0 * (1.0 - f)
		_delay0 = _stage0

		_stage1 = _stage0 * f + _delay1 * (1.0 - f)
		_delay1 = _stage1

		_stage2 = _stage1 * f + _delay2 * (1.0 - f)
		_delay2 = _stage2

		_stage3 = _stage2 * f + _delay3 * (1.0 - f)
		_delay3 = _stage3

		out = _stage3

	return out