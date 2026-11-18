class_name ADSEnvelope
extends RefCounted

enum Stage {
	IDLE,
	ATTACK,
	DECAY,
	SUSTAIN,
	RELEASE
}

var stage: Stage = Stage.IDLE
var value: float = 0.0


func trigger(reset_to_zero: bool = true) -> void:
	if reset_to_zero:
		value = 0.0
	stage = Stage.ATTACK


func release() -> void:
	if stage != Stage.IDLE:
		stage = Stage.RELEASE


func kill() -> void:
	stage = Stage.IDLE
	value = 0.0


func is_active() -> bool:
	return stage != Stage.IDLE


func process(sample_rate: float, cfg: ContourConfig) -> float:
	if stage == Stage.IDLE or cfg == null:
		return 0.0

	match stage:
		Stage.ATTACK:
			var attack_samples: float = maxf(1.0, (cfg.attack_ms * 0.001) * sample_rate)
			var step: float = 1.0 / attack_samples
			value += step
			if value >= 1.0:
				value = 1.0
				stage = Stage.DECAY
		Stage.DECAY:
			var decay_samples: float = maxf(1.0, (cfg.decay_ms * 0.001) * sample_rate)
			var coeff: float = 1.0 - exp(-4.6 / decay_samples)
			value += (cfg.sustain_level - value) * coeff
			if absf(value - cfg.sustain_level) < 0.0005:
				value = cfg.sustain_level
				stage = Stage.SUSTAIN
		Stage.SUSTAIN:
			value = cfg.sustain_level
		Stage.RELEASE:
			var rel_ms: float = cfg.decay_ms if cfg.release_on_decay else 8.0
			var rel_samples: float = maxf(1.0, (rel_ms * 0.001) * sample_rate)
			var rel_coeff: float = 1.0 - exp(-5.0 / rel_samples)
			value += (0.0 - value) * rel_coeff
			if value <= 0.0002:
				value = 0.0
				stage = Stage.IDLE

	return value
