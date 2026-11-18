class_name EuclidScope
extends Control

var _rig: SynthRig
var _filter: FilterConfig
var _samples := PackedFloat32Array()


func _init() -> void:
	custom_minimum_size = Vector2(220, 110)


func bind_rig(rig: SynthRig) -> void:
	_rig = rig


func bind_filter(filter_cfg: FilterConfig) -> void:
	_filter = filter_cfg
	queue_redraw()


func _process(_delta: float) -> void:
	if _rig != null:
		_samples = _rig.get_scope_samples()
		queue_redraw()


func _draw() -> void:
	var font: Font = EuclidPalette.get_font()
	var rect := Rect2(Vector2.ZERO, size)
	EuclidPalette.draw_euclid_frame(self, rect, EuclidPalette.BG_SUBPANEL, EuclidPalette.LINE_DIM, true)

	var w: float = size.x
	var h: float = size.y
	var mid_y: float = h * 0.5
	var center := Vector2(w * 0.5, mid_y)

	# Euclid inscribed geometric construction reticle
	draw_line(Vector2(6.0, mid_y), Vector2(w - 6.0, mid_y), EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN)
	draw_line(Vector2(w * 0.5, 6.0), Vector2(w * 0.5, h - 6.0), EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN)
	draw_arc(center, minf(w, h) * 0.36, 0.0, TAU, 48, EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN, true)

	# 24dB/oct Ladder Filter Frequency Response Curve (Logarithmic 20Hz - 18kHz)
	if _filter != null and w > 24.0:
		var curve_pts := PackedVector2Array()
		var steps: int = 64
		var log_min: float = log(20.0)
		var log_max: float = log(18000.0)
		var fc: float = clampf(_filter.cutoff_hz, 20.0, 18000.0)
		var q_boost: float = (_filter.emphasis / 3.95) * 0.42

		for i in range(steps + 1):
			var t: float = float(i) / float(steps)
			var freq: float = exp(lerpf(log_min, log_max, t))
			var ratio: float = freq / fc
			# 4-pole rolloff approximation + resonant peak around ratio == 1.0
			var mag: float = 1.0 / sqrt(1.0 + pow(ratio, 8.0))
			var peak: float = q_boost * exp(-pow((ratio - 0.96) * 4.5, 2.0))
			var total_mag: float = clampf((mag + peak) * 0.65, 0.0, 1.0)
			var px: float = lerpf(8.0, w - 8.0, t)
			var py: float = lerpf(h - 10.0, 14.0, total_mag)
			curve_pts.append(Vector2(px, py))

		draw_polyline(curve_pts, EuclidPalette.ACCENT_CYAN, EuclidPalette.LINE_THIN, true)

	# Live Audio Waveform Trace
	if _samples.size() >= 2 and w > 24.0:
		var wave_pts := PackedVector2Array()
		var count: int = _samples.size()
		# Trigger zero-crossing alignment for visual stability
		var start_idx: int = 0
		for i in range(1, count / 2):
			if _samples[i - 1] < 0.0 and _samples[i] >= 0.0:
				start_idx = i
				break

		var draw_len: int = count - start_idx
		if draw_len >= 2:
			for i in range(draw_len):
				var norm_x: float = float(i) / float(draw_len - 1)
				var px: float = lerpf(8.0, w - 8.0, norm_x)
				var s: float = clampf(_samples[start_idx + i], -1.0, 1.0)
				var py: float = mid_y - s * (h * 0.40)
				wave_pts.append(Vector2(px, py))
			draw_polyline(wave_pts, EuclidPalette.ACCENT_GOLD, EuclidPalette.LINE_MED, true)

	draw_string(font, Vector2(8.0, 13.0), "SCOPE / LADDER", HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 9, EuclidPalette.TEXT_DIM)
