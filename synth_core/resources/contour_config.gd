class_name ContourConfig
extends Resource

@export_range(1.0, 10000.0, 0.5) var attack_ms: float = 12.0
@export_range(4.0, 25000.0, 0.5) var decay_ms: float = 420.0
@export_range(0.0, 1.0, 0.001) var sustain_level: float = 0.65
@export var release_on_decay: bool = true


func duplicate_config() -> ContourConfig:
	var copy := ContourConfig.new()
	copy.attack_ms = attack_ms
	copy.decay_ms = decay_ms
	copy.sustain_level = sustain_level
	copy.release_on_decay = release_on_decay
	return copy
