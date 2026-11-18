class_name FilterConfig
extends Resource

const TRACKING_NAMES: Array[String] = ["0%", "33%", "66%", "100%"]

@export_range(20.0, 18000.0, 0.1) var cutoff_hz: float = 2400.0
@export_range(0.0, 3.95, 0.001) var emphasis: float = 0.65
@export_range(-1.0, 1.0, 0.001) var contour_amount: float = 0.45
@export_range(0, 3, 1) var kbd_tracking_idx: int = 2
@export_range(0.0, 2.0, 0.01) var overload_drive: float = 0.15


func get_kbd_tracking_ratio() -> float:
	match kbd_tracking_idx:
		0:
			return 0.0
		1:
			return 0.3333
		2:
			return 0.6667
		_:
			return 1.0


func duplicate_config() -> FilterConfig:
	var copy := FilterConfig.new()
	copy.cutoff_hz = cutoff_hz
	copy.emphasis = emphasis
	copy.contour_amount = contour_amount
	copy.kbd_tracking_idx = kbd_tracking_idx
	copy.overload_drive = overload_drive
	return copy
