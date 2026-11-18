class_name EuclidDial
extends Control

signal value_changed(new_value: float)

@export var label: String = "PARAM"
@export var unit: String = ""
@export var min_value: float = 0.0
@export var max_value: float = 1.0
@export var default_value: float = 0.5
@export var step: float = 0.0
@export var logarithmic: bool = false
@export var bipolar: bool = false
@export var mod_amount: float = 0.0
@export var accent_color: Color = EuclidPalette.ACCENT_GOLD

var value: float = 0.5:
	set(v):
		var clamped: float = clampf(v, min_value, max_value)
		if step > 0.0:
			clamped = snappedf(clamped, step)
		if not is_equal_approx(value, clamped):
			value = clamped
			queue_redraw()
			value_changed.emit(value)

var _hovered: bool = false
var _dragging: bool = false
var _drag_start_y: float = 0.0
var _drag_start_norm: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(68, 84)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(func() -> void:
		_hovered = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		queue_redraw()
	)


func set_value_silent(v: float) -> void:
	var clamped: float = clampf(v, min_value, max_value)
	if step > 0.0:
		clamped = snappedf(clamped, step)
	value = clamped
	queue_redraw()


func _value_to_norm(v: float) -> float:
	if max_value <= min_value:
		return 0.0
	var clamped: float = clampf(v, min_value, max_value)
	if logarithmic and min_value > 0.0:
		var log_min: float = log(min_value)
		var log_max: float = log(max_value)
		return clampf((log(clamped) - log_min) / (log_max - log_min), 0.0, 1.0)
	return clampf((clamped - min_value) / (max_value - min_value), 0.0, 1.0)


func _norm_to_value(n: float) -> float:
	var clamped_n: float = clampf(n, 0.0, 1.0)
	if logarithmic and min_value > 0.0:
		var log_min: float = log(min_value)
		var log_max: float = log(max_value)
		return exp(lerpf(log_min, log_max, clamped_n))
	return lerpf(min_value, max_value, clamped_n)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					value = default_value
				else:
					_dragging = true
					_drag_start_y = mb.position.y
					_drag_start_norm = _value_to_norm(value)
				queue_redraw()
				accept_event()
			else:
				if _dragging:
					_dragging = false
					queue_redraw()
					accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			value = default_value
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			var inc: float = 0.01 if Input.is_key_pressed(KEY_SHIFT) else 0.035
			value = _norm_to_value(_value_to_norm(value) + inc)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			var dec: float = 0.01 if Input.is_key_pressed(KEY_SHIFT) else 0.035
			value = _norm_to_value(_value_to_norm(value) - dec)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var sensitivity: float = 420.0 if Input.is_key_pressed(KEY_SHIFT) else 150.0
		var delta_norm: float = (_drag_start_y - mm.position.y) / sensitivity
		value = _norm_to_value(_drag_start_norm + delta_norm)
		accept_event()


func _format_readout() -> String:
	if unit == "Hz":
		if value >= 1000.0:
			return "%.2fk" % (value / 1000.0)
		elif value >= 100.0:
			return "%.0fHz" % value
		else:
			return "%.1fHz" % value
	elif unit == "ms":
		if value >= 1000.0:
			return "%.2fs" % (value / 1000.0)
		elif value >= 100.0:
			return "%.0fms" % value
		else:
			return "%.1fms" % value
	elif unit == "st":
		return "%+.2f" % value
	elif unit == "%":
		return "%.0f%%" % (value * 100.0)
	else:
		if bipolar:
			return "%+.2f" % value
		return "%.2f" % value


func _draw() -> void:
	var font: Font = EuclidPalette.get_font()
	var w: float = size.x
	var h: float = size.y

	# Top Title Label
	draw_string(font, Vector2(0.0, 12.0), label, HORIZONTAL_ALIGNMENT_CENTER, w, 10, EuclidPalette.TEXT_DIM)

	# Compass Circle Geometry
	var center := Vector2(w * 0.5, h * 0.5 + 1.0)
	var radius: float = minf(w * 0.36, (h - 32.0) * 0.46)
	radius = maxf(radius, 14.0)

	# Angle span: 135 deg (bottom-left) to 405 deg (bottom-right) -> 270 deg sweep
	var start_ang: float = deg_to_rad(135.0)
	var end_ang: float = deg_to_rad(405.0)
	var norm: float = _value_to_norm(value)
	var cur_ang: float = lerpf(start_ang, end_ang, norm)

	# Outer inscribed background disk
	var disk_fill: Color = EuclidPalette.BG_HOVER if (_hovered or _dragging) else EuclidPalette.BG_SUBPANEL
	draw_circle(center, radius, disk_fill)

	# Base track arc
	draw_arc(center, radius, start_ang, end_ang, 36, EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN, true)

	# Active value arc
	if bipolar:
		var zero_norm: float = _value_to_norm(0.0)
		var zero_ang: float = lerpf(start_ang, end_ang, zero_norm)
		draw_arc(center, radius, minf(zero_ang, cur_ang), maxf(zero_ang, cur_ang), 28, accent_color, EuclidPalette.LINE_BOLD, true)
		# Top noon reference tick
		var noon_dir := Vector2(cos(zero_ang), sin(zero_ang))
		draw_line(center + noon_dir * (radius - 3.0), center + noon_dir * (radius + 3.0), EuclidPalette.LINE_MID, EuclidPalette.LINE_THIN)
	else:
		if norm > 0.005:
			draw_arc(center, radius, start_ang, cur_ang, 28, accent_color, EuclidPalette.LINE_BOLD, true)

	# Optional modulation range arc (Euclid cyan secondary arc)
	if absf(mod_amount) > 0.005:
		var mod_norm: float = clampf(norm + mod_amount, 0.0, 1.0)
		var mod_ang: float = lerpf(start_ang, end_ang, mod_norm)
		draw_arc(center, radius + 3.5, minf(cur_ang, mod_ang), maxf(cur_ang, mod_ang), 20, EuclidPalette.ACCENT_CYAN, EuclidPalette.LINE_MED, true)

	# Endpoint compass ticks
	for tick_ang in [start_ang, end_ang]:
		var t_dir := Vector2(cos(tick_ang), sin(tick_ang))
		draw_line(center + t_dir * (radius - 2.5), center + t_dir * (radius + 2.5), EuclidPalette.LINE_MID, EuclidPalette.LINE_THIN)

	# Radial pointer line from center vertex to circumference
	var pointer_dir := Vector2(cos(cur_ang), sin(cur_ang))
	var line_col: Color = EuclidPalette.LINE_MAIN if (_hovered or _dragging) else accent_color
	draw_line(center, center + pointer_dir * (radius - 1.5), line_col, EuclidPalette.LINE_MED, true)

	# Center vertex point
	draw_circle(center, 2.2, EuclidPalette.LINE_MAIN)

	# Bottom Numeric Value Readout
	var readout: String = _format_readout()
	var val_col: Color = EuclidPalette.TEXT_MAIN if (_hovered or _dragging) else EuclidPalette.TEXT_DIM
	draw_string(font, Vector2(0.0, h - 3.0), readout, HORIZONTAL_ALIGNMENT_CENTER, w, 10, val_col)
