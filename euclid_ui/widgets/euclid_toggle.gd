class_name EuclidToggle
extends Control

signal toggled(is_active: bool)
signal option_selected(index: int)

@export var label: String = "ACTIVE"
@export var options: Array[String] = []
@export var accent_color: Color = EuclidPalette.ACCENT_GOLD

var active: bool = false:
	set(v):
		if active != v:
			active = v
			queue_redraw()
			toggled.emit(active)

var selected_index: int = 0:
	set(v):
		if options.is_empty():
			return
		var wrapped: int = posmod(v, options.size())
		if selected_index != wrapped:
			selected_index = wrapped
			queue_redraw()
			option_selected.emit(selected_index)

var _hovered: bool = false
var _pressed: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(72, 26)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(func() -> void:
		_hovered = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_pressed = false
		queue_redraw()
	)


func set_active_silent(v: bool) -> void:
	active = v
	queue_redraw()


func set_index_silent(idx: int) -> void:
	if options.is_empty():
		return
	selected_index = posmod(idx, options.size())
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressed = true
				if options.is_empty():
					active = not active
				else:
					selected_index = posmod(selected_index + 1, options.size())
				queue_redraw()
				accept_event()
			else:
				_pressed = false
				queue_redraw()
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not options.is_empty():
			selected_index = posmod(selected_index - 1, options.size())
			queue_redraw()
			accept_event()


func _draw() -> void:
	var font: Font = EuclidPalette.get_font()
	var rect := Rect2(Vector2.ZERO, size)
	var is_selector: bool = not options.is_empty()

	var fill: Color = EuclidPalette.BG_SUBPANEL
	var border: Color = EuclidPalette.LINE_DIM
	var text_col: Color = EuclidPalette.TEXT_DIM

	if is_selector:
		fill = EuclidPalette.BG_HOVER if _hovered else EuclidPalette.BG_SUBPANEL
		border = accent_color if _hovered else EuclidPalette.LINE_MID
		text_col = EuclidPalette.TEXT_MAIN
	else:
		if active:
			fill = EuclidPalette.ACCENT_GOLD_DIM if accent_color == EuclidPalette.ACCENT_GOLD else EuclidPalette.ACCENT_CYAN_DIM
			border = accent_color
			text_col = EuclidPalette.TEXT_MAIN
		elif _hovered:
			fill = EuclidPalette.BG_HOVER
			border = EuclidPalette.LINE_MID
			text_col = EuclidPalette.TEXT_MAIN

	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, EuclidPalette.LINE_THIN)

	if is_selector:
		var display_text: String = options[clampi(selected_index, 0, options.size() - 1)]
		draw_string(font, Vector2(0.0, size.y * 0.5 + 2.0), display_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, text_col)

		# Geometric step pips along bottom edge
		var count: int = options.size()
		var margin: float = 6.0
		var usable_w: float = maxf(8.0, size.x - margin * 2.0)
		var gap: float = 2.0
		var pip_w: float = maxf(2.0, (usable_w - gap * float(count - 1)) / float(count))
		var pip_y: float = size.y - 3.5
		for i in range(count):
			var px: float = margin + float(i) * (pip_w + gap)
			var p_col: Color = accent_color if i == selected_index else EuclidPalette.LINE_DIM
			draw_line(Vector2(px, pip_y), Vector2(px + pip_w, pip_y), p_col, 1.5)
	else:
		# Inscribed Euclid diamond indicator on left + label
		var d_center := Vector2(11.0, size.y * 0.5)
		var r: float = 4.0
		var diamond := PackedVector2Array([
			d_center + Vector2(0.0, -r),
			d_center + Vector2(r, 0.0),
			d_center + Vector2(0.0, r),
			d_center + Vector2(-r, 0.0)
		])
		if active:
			draw_colored_polygon(diamond, accent_color)
		else:
			draw_polyline(diamond + PackedVector2Array([diamond[0]]), EuclidPalette.LINE_MID, EuclidPalette.LINE_THIN)

		draw_string(font, Vector2(20.0, size.y * 0.5 + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 10, text_col)
