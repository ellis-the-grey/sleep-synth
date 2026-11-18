class_name NoiseGenerator
extends RefCounted

var _seed: int = 19710808
var _b0: float = 0.0
var _b1: float = 0.0
var _b2: float = 0.0
var _b3: float = 0.0
var _b4: float = 0.0
var _b5: float = 0.0
var _b6: float = 0.0
var _brown_state: float = 0.0


func set_seed(new_seed: int) -> void:
	_seed = new_seed if new_seed != 0 else 19710808


func _next_white() -> float:
	# Thread-safe 32-bit LCG PRNG
	_seed = int((_seed * 1664525 + 1013904223) & 0x7FFFFFFF)
	return (float(_seed) / 1073741824.0) - 1.0


func process(color: int) -> float:
	var white: float = _next_white()
	match color:
		NoiseConfig.NoiseColor.WHITE:
			return white * 0.75
		NoiseConfig.NoiseColor.PINK:
			# Paul Kellet economy pink noise filter (-3 dB/octave)
			_b0 = 0.99765 * _b0 + white * 0.0990460
			_b1 = 0.96300 * _b1 + white * 0.2965164
			_b2 = 0.57000 * _b2 + white * 1.0526913
			var pink: float = _b0 + _b1 + _b2 + white * 0.1848
			return clampf(pink * 0.22, -1.0, 1.0)
		NoiseConfig.NoiseColor.BROWN:
			# Leaky integrator brownian noise (-6 dB/octave)
			_brown_state = (_brown_state + (0.025 * white)) / 1.012
			return clampf(_brown_state * 2.8, -1.0, 1.0)
	return white
