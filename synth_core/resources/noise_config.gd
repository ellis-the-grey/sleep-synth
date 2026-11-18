class_name NoiseConfig
extends Resource

enum NoiseColor {
	WHITE,
	PINK,
	BROWN
}

const COLOR_NAMES: Array[String] = ["WHITE", "PINK", "BROWN"]

@export var enabled: bool = false
@export var color: NoiseColor = NoiseColor.PINK
@export_range(0.0, 1.0, 0.001) var level: float = 0.25


func duplicate_config() -> NoiseConfig:
	var copy := NoiseConfig.new()
	copy.enabled = enabled
	copy.color = color
	copy.level = level
	return copy
