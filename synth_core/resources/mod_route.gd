class_name ModRoute
extends Resource

enum ModSource {
	OSC_3,
	NOISE,
	FILTER_ENV,
	DRIFT_LFO
}

enum ModTarget {
	PITCH,
	FILTER_CUTOFF,
	AMP_LEVEL,
	OSC_DETUNE
}

const SOURCE_NAMES: Array[String] = ["OSC 3", "NOISE", "FILT ENV", "DRIFT LFO"]
const TARGET_NAMES: Array[String] = ["PITCH", "CUTOFF", "AMP", "DETUNE"]

@export var enabled: bool = true
@export var source: ModSource = ModSource.OSC_3
@export var target: ModTarget = ModTarget.FILTER_CUTOFF
@export_range(-1.0, 1.0, 0.001) var amount: float = 0.0
@export_range(0.25, 4.0, 0.05) var curve_power: float = 1.0


func duplicate_config() -> ModRoute:
	var copy := ModRoute.new()
	copy.enabled = enabled
	copy.source = source
	copy.target = target
	copy.amount = amount
	copy.curve_power = curve_power
	return copy
