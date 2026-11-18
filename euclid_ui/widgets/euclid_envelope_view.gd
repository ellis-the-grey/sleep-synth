class_name EuclidEnvelopeView
extends Control

@export var title: String = "CONTOUR"
@export var accent_color: Color = EuclidPalette.ACCENT_GOLD

var _contour: ContourConfig


func _init() -> void:
	custom_minimum_size = Vector2(180, 76)


func bind_contour(cfg: ContourConfig) -> void:
	_contour = cfg
	queue_redraw()


func _draw() -> void:
	var font: Font = EuclidPalette.get_font()
	var rect := Rect2(Vector2.ZERO, size)
	EuclidPalette.draw_euclid_frame(self, rect, EuclidPalette.BG_SUBPANEL, EuclidPalette.LINE_DIM, false)

	draw_string(font, Vector2(6.0, 12.0), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 9, EuclidPalette.TEXT_DIM)

	var pad_l: float = 10.0
	var pad_r: float = 12.0
	var pad_t: float = 18.0
	var pad_b: float = 14.0
	var plot_w: float = maxf(20.0, size.x - pad_l - pad_r)
	var plot_h: float = maxf(20.0, size.y - pad_t - pad_b)

	var origin := Vector2(pad_l, pad_t + plot_h)
	var top_y: float = pad_t

	# Baseline & Ceiling geometric construction hairlines
	draw_line(origin, Vector2(pad_l + plot_w, origin.y), EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN)
	draw_line(Vector2(pad_l, top_y), Vector2(pad_l + plot_w, top_y), EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN)

	if _contour == null:
		return

	# Normalized logarithmic proportions for A, D, S, R visual geometry
	var a_norm: float = clampf(log(_contour.attack_ms) / log(10000.0), 0.03, 0.30)
	var d_norm: float = clampf(log(_contour.decay_ms) / log(25000.0), 0.05, 0.32)
	var s_lvl: float = clampf(_contour.sustain_level, 0.0, 1.0)
	var r_ms: float = _contour.decay_ms if _contour.release_on_decay else 15.0
	var r_norm: float = clampf(log(maxf(4.0, r_ms)) / log(25000.0), 0.03, 0.25)

	var pt_o := origin
	var pt_a := Vector2(pad_l + plot_w * a_norm, top_y)
	var sustain_y: float = lerpf(origin.y, top_y, s_lvl)
	var pt_b := Vector2(pt_a.x + plot_w * d_norm, sustain_y)
	var pt_c := Vector2(maxf(pt_b.x + 12.0, pad_l + plot_w * (1.0 - r_norm)), sustain_y)
	var pt_d := Vector2(pad_l + plot_w, origin.y)

	# Vertical perpendicular drop-lines (Euclid Book I construction lines)
	draw_line(pt_a, Vector2(pt_a.x, origin.y), EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN)
	draw_line(pt_b, Vector2(pt_b.x, origin.y), EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN)
	draw_line(pt_c, Vector2(pt_c.x, origin.y), EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN)

	# Translucent polygon area under envelope
	var poly := PackedVector2Array([pt_o, pt_a, pt_b, pt_c, pt_d])
	var fill_col := Color(accent_color.r, accent_color.g, accent_color.b, 0.12)
	draw_colored_polygon(poly, fill_col)

	# Main contour polyline
	draw_polyline(poly, accent_color, EuclidPalette.LINE_MED, true)

	# Geometric vertices A, B, C, D
	var vertices: Array[Vector2] = [pt_a, pt_b, pt_c, pt_d]
	var labels: Array[String] = ["A", "B", "C", "D"]
	for i in range(vertices.size()):
		var v: Vector2 = vertices[i]
		draw_circle(v, 2.5, EuclidPalette.BG_PANEL)
		draw_arc(v, 2.5, 0.0, TAU, 16, EuclidPalette.LINE_MAIN, EuclidPalette.LINE_THIN, true)
		var lbl_offset := Vector2(-3.0, -5.0) if i < 2 else Vector2(-3.0, 11.0)
		draw_string(font, v + lbl_offset, labels[i], HORIZONTAL_ALIGNMENT_LEFT, 16.0, 8, EuclidPalette.TEXT_DIM)
