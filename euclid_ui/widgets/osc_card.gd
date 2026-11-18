class_name OscCard
extends Control

signal config_modified()
signal remove_requested(osc_cfg: OscConfig)

var _osc: OscConfig
var _allow_remove: bool = false

var _active_toggle: EuclidToggle
var _wave_selector: EuclidToggle
var _octave_selector: EuclidToggle
var _tune_dial: EuclidDial
var _level_dial: EuclidDial
var _mod_only_toggle: EuclidToggle
var _remove_btn: Button


func _init() -> void:
	custom_minimum_size = Vector2(182, 248)
	_build_controls()


func _build_controls() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Top row: Active Toggle + Remove Button (if dynamic osc > 3)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	vbox.add_child(top_row)

	_active_toggle = EuclidToggle.new()
	_active_toggle.label = "ACTIVE"
	_active_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_toggle.custom_minimum_size = Vector2(64, 22)
	_active_toggle.toggled.connect(func(is_on: bool) -> void:
		if _osc != null:
			_osc.enabled = is_on
			config_modified.emit()
	)
	top_row.add_child(_active_toggle)

	_remove_btn = Button.new()
	_remove_btn.text = "X"
	_remove_btn.custom_minimum_size = Vector2(24, 22)
	_remove_btn.visible = false
	_remove_btn.pressed.connect(func() -> void:
		if _osc != null:
			remove_requested.emit(_osc)
	)
	top_row.add_child(_remove_btn)

	# Spacer for custom _draw() waveform geometry preview
	var wave_preview_spacer := Control.new()
	wave_preview_spacer.custom_minimum_size = Vector2(0, 38)
	wave_preview_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(wave_preview_spacer)

	# Waveform & Footage selectors
	var sel_row := HBoxContainer.new()
	sel_row.add_theme_constant_override("separation", 4)
	vbox.add_child(sel_row)

	_wave_selector = EuclidToggle.new()
	_wave_selector.options = OscConfig.WAVEFORM_NAMES
	_wave_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_selector.custom_minimum_size = Vector2(84, 26)
	_wave_selector.option_selected.connect(func(idx: int) -> void:
		if _osc != null:
			_osc.waveform = idx as OscConfig.Waveform
			queue_redraw()
			config_modified.emit()
	)
	sel_row.add_child(_wave_selector)

	_octave_selector = EuclidToggle.new()
	_octave_selector.options = OscConfig.OCTAVE_NAMES
	_octave_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_octave_selector.custom_minimum_size = Vector2(64, 26)
	_octave_selector.option_selected.connect(func(idx: int) -> void:
		if _osc != null:
			_osc.octave_range = idx as OscConfig.OctaveRange
			_sync_tune_dial_mode()
			config_modified.emit()
	)
	sel_row.add_child(_octave_selector)

	# Dials row: Tune/LO Rate + Output Level
	var dial_row := HBoxContainer.new()
	dial_row.add_theme_constant_override("separation", 4)
	vbox.add_child(dial_row)

	_tune_dial = EuclidDial.new()
	_tune_dial.label = "TUNE"
	_tune_dial.unit = "st"
	_tune_dial.min_value = -12.0
	_tune_dial.max_value = 12.0
	_tune_dial.default_value = 0.0
	_tune_dial.bipolar = true
	_tune_dial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tune_dial.value_changed.connect(func(v: float) -> void:
		if _osc != null:
			if _osc.octave_range == OscConfig.OctaveRange.LO:
				_osc.lo_freq_hz = v
			else:
				_osc.detune_semitones = v
			config_modified.emit()
	)
	dial_row.add_child(_tune_dial)

	_level_dial = EuclidDial.new()
	_level_dial.label = "LEVEL"
	_level_dial.unit = "%"
	_level_dial.min_value = 0.0
	_level_dial.max_value = 1.0
	_level_dial.default_value = 0.75
	_level_dial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_dial.value_changed.connect(func(v: float) -> void:
		if _osc != null:
			_osc.level = v
			config_modified.emit()
	)
	dial_row.add_child(_level_dial)

	# Bottom Mod-Only Toggle (ideal for Osc 3 LFO/FM routing)
	_mod_only_toggle = EuclidToggle.new()
	_mod_only_toggle.label = "MOD ONLY (MUTE AUDIO)"
	_mod_only_toggle.accent_color = EuclidPalette.ACCENT_CYAN
	_mod_only_toggle.custom_minimum_size = Vector2(0, 22)
	_mod_only_toggle.toggled.connect(func(is_mod: bool) -> void:
		if _osc != null:
			_osc.mod_source_only = is_mod
			config_modified.emit()
	)
	vbox.add_child(_mod_only_toggle)


func bind_osc(cfg: OscConfig, allow_remove: bool = false) -> void:
	_osc = cfg
	_allow_remove = allow_remove
	if _remove_btn != null:
		_remove_btn.visible = allow_remove
	refresh_from_resource()


func refresh_from_resource() -> void:
	if _osc == null:
		return
	_active_toggle.set_active_silent(_osc.enabled)
	_wave_selector.set_index_silent(int(_osc.waveform))
	_octave_selector.set_index_silent(int(_osc.octave_range))
	_level_dial.set_value_silent(_osc.level)
	_mod_only_toggle.set_active_silent(_osc.mod_source_only)
	_sync_tune_dial_mode()
	queue_redraw()


func _sync_tune_dial_mode() -> void:
	if _osc == null:
		return
	if _osc.octave_range == OscConfig.OctaveRange.LO:
		_tune_dial.label = "LO RATE"
		_tune_dial.unit = "Hz"
		_tune_dial.min_value = 0.05
		_tune_dial.max_value = 20.0
		_tune_dial.default_value = 1.5
		_tune_dial.bipolar = false
		_tune_dial.logarithmic = true
		_tune_dial.accent_color = EuclidPalette.ACCENT_CYAN
		_tune_dial.set_value_silent(_osc.lo_freq_hz)
	else:
		_tune_dial.label = "TUNE"
		_tune_dial.unit = "st"
		_tune_dial.min_value = -12.0
		_tune_dial.max_value = 12.0
		_tune_dial.default_value = 0.0
		_tune_dial.bipolar = true
		_tune_dial.logarithmic = false
		_tune_dial.accent_color = EuclidPalette.ACCENT_GOLD
		_tune_dial.set_value_silent(_osc.detune_semitones)


func _draw() -> void:
	var font: Font = EuclidPalette.get_font()
	var rect := Rect2(Vector2.ZERO, size)
	EuclidPalette.draw_euclid_frame(self, rect, EuclidPalette.BG_PANEL, EuclidPalette.LINE_DIM, true)

	# Header divider line & title
	draw_line(Vector2(1.0, 21.0), Vector2(size.x - 1.0, 21.0), EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN)
	var title_txt: String = _osc.label if _osc != null else "OSC"
	draw_string(font, Vector2(9.0, 15.0), title_txt, HORIZONTAL_ALIGNMENT_LEFT, size.x - 18.0, 11, EuclidPalette.TEXT_MAIN)

	# Geometric Waveform Preview Box (located inside the spacer slot at y=54..92)
	var box := Rect2(8.0, 54.0, size.x - 16.0, 38.0)
	draw_rect(box, EuclidPalette.BG_SUBPANEL, true)
	draw_rect(box, EuclidPalette.LINE_DIM, false, EuclidPalette.LINE_THIN)

	var mid_y: float = box.position.y + box.size.y * 0.5
	draw_line(Vector2(box.position.x + 2.0, mid_y), Vector2(box.end.x - 2.0, mid_y), EuclidPalette.LINE_DIM, EuclidPalette.LINE_THIN)

	if _osc == null:
		return

	var pts := PackedVector2Array()
	var steps: int = 48
	var amp: float = box.size.y * 0.36
	var wave_col: Color = EuclidPalette.ACCENT_GOLD if _osc.enabled else EuclidPalette.LINE_MID

	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var v: float = 0.0
		match _osc.waveform:
			OscConfig.Waveform.TRIANGLE:
				v = 4.0 * absf(t - 0.5) - 1.0
			OscConfig.Waveform.SHARKTOOTH:
				var tri: float = 4.0 * absf(t - 0.5) - 1.0
				var saw: float = 2.0 * t - 1.0
				v = tri * 0.55 + saw * 0.45
			OscConfig.Waveform.SAWTOOTH:
				v = 2.0 * t - 1.0
			OscConfig.Waveform.SQUARE:
				v = 1.0 if t < 0.5 else -1.0
			OscConfig.Waveform.WIDE_PULSE:
				v = 1.0 if t < 0.25 else -1.0
			OscConfig.Waveform.NARROW_PULSE:
				v = 1.0 if t < 0.125 else -1.0
		var px: float = lerpf(box.position.x + 6.0, box.end.x - 6.0, t)
		var py: float = mid_y - v * amp
		pts.append(Vector2(px, py))

	draw_polyline(pts, wave_col, EuclidPalette.LINE_MED, true)
