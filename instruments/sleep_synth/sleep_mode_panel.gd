class_name SleepModePanel
extends Control

signal exit_sleep_mode_requested()

const LayersEngine = preload("res://instruments/sleep_synth/sleep_layers_engine.gd")
const NOTE_NAMES: Array[String] = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

var _rig: SynthRig
var _layers: LayersEngine

var _force_awake_chk: CheckBox
var _screen_saver_chk: CheckBox
var _master_vol_dial: EuclidDial
var _all_toggles: Array[EuclidToggle] = []
var _all_off_labels: Array[String] = []

var _bin_band_btn: OptionButton
var _bin_beat_dial: EuclidDial
var _bin_desc_lbl: Label
var _swl_asc_chk: CheckBox
var _swl_desc_chk: CheckBox
var _swl_root_btn: OptionButton
var _swl_oct_btn: OptionButton
var _swl_span_btn: OptionButton
var _swl_status_lbl: Label

# Fullscreen Black Clock Overlay
var _saver_layer: CanvasLayer
var _saver_overlay: Control
var _clock_timer: Timer


func bind_rig(rig: SynthRig) -> void:
	_rig = rig
	if _rig != null and _rig.patch != null and _layers != null:
		_layers.master_volume = _rig.patch.master_volume
		if _master_vol_dial != null:
			_master_vol_dial.set_value_silent(_rig.patch.master_volume)


func _init() -> void:
	_layers = LayersEngine.new()
	_layers.name = "SleepLayersEngine"
	add_child(_layers)

	_build_ui()
	_build_screen_saver_overlay()


func _process(_delta: float) -> void:
	# Keep wired in sync with SynthRig master volume (top bar MASTER knob)
	if _rig != null and _rig.patch != null and _layers != null:
		if not is_equal_approx(_layers.master_volume, _rig.patch.master_volume):
			_layers.master_volume = _rig.patch.master_volume
			if _master_vol_dial != null:
				_master_vol_dial.set_value_silent(_rig.patch.master_volume)

	if _swl_status_lbl != null and _layers != null:
		if _layers.swells_enabled:
			_swl_status_lbl.text = "ACTIVE NOTE: " + _layers.swells_status_text
		else:
			_swl_status_lbl.text = "ACTIVE NOTE: IDLE"


func _draw() -> void:
	EuclidPalette.draw_euclid_frame(self, Rect2(Vector2.ZERO, size), EuclidPalette.BG_PANEL, EuclidPalette.LINE_DIM, true)


func _style_checkbox(cb: CheckBox) -> void:
	cb.add_theme_font_size_override("font_size", 11)
	cb.add_theme_color_override("font_color", EuclidPalette.TEXT_MAIN)
	cb.add_theme_color_override("font_hover_color", EuclidPalette.ACCENT_GOLD)
	cb.add_theme_color_override("font_pressed_color", EuclidPalette.ACCENT_GOLD)
	cb.add_theme_color_override("font_focus_color", EuclidPalette.TEXT_MAIN)


func _make_subpanel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = EuclidPalette.BG_SUBPANEL
	sb.border_color = EuclidPalette.LINE_DIM
	sb.set_border_width_all(1)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	return p


func _make_dial(lbl: String, unit_str: String, min_v: float, max_v: float, def_v: float, is_log: bool, col: Color) -> EuclidDial:
	var d := EuclidDial.new()
	d.label = lbl
	d.unit = unit_str
	d.min_value = min_v
	d.max_value = max_v
	d.default_value = def_v
	d.logarithmic = is_log
	d.accent_color = col
	d.custom_minimum_size = Vector2(74, 84)
	d.set_value_silent(def_v)
	return d


func _register_layer_toggle(on_txt: String, off_txt: String, callback: Callable) -> EuclidToggle:
	var tog := EuclidToggle.new()
	tog.label = off_txt
	tog.accent_color = EuclidPalette.ACCENT_GOLD
	tog.custom_minimum_size = Vector2(165, 28)
	tog.toggled.connect(func(on: bool) -> void:
		tog.label = on_txt if on else off_txt
		callback.call(on)
	)
	_all_toggles.append(tog)
	_all_off_labels.append(off_txt)
	return tog


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(outer_vbox)

	# --- Pinned Header, Master Volume & Power Options Bar ---
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(hdr_row)

	var left_hdr_vbox := VBoxContainer.new()
	left_hdr_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_hdr_vbox.add_theme_constant_override("separation", 6)
	hdr_row.add_child(left_hdr_vbox)

	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 10)
	left_hdr_vbox.add_child(title_bar)

	var title_lbl := Label.new()
	title_lbl.text = "SLEEP MIXER // ENABLE & LAYER ANY COMBINATION"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", EuclidPalette.ACCENT_GOLD)
	title_bar.add_child(title_lbl)

	var mute_btn := Button.new()
	mute_btn.text = "MUTE ALL LAYERS"
	mute_btn.custom_minimum_size = Vector2(130, 28)
	mute_btn.pressed.connect(stop_sleep_audio)
	title_bar.add_child(mute_btn)

	var back_btn := Button.new()
	back_btn.text = "BACK TO SYNTH RACK"
	back_btn.custom_minimum_size = Vector2(150, 28)
	back_btn.pressed.connect(func() -> void:
		_set_screen_saver_active(false)
		_set_force_awake(false)
		stop_sleep_audio()
		exit_sleep_mode_requested.emit()
	)
	title_bar.add_child(back_btn)

	var opt_row := HBoxContainer.new()
	opt_row.add_theme_constant_override("separation", 18)
	left_hdr_vbox.add_child(opt_row)

	_force_awake_chk = CheckBox.new()
	_force_awake_chk.text = "FORCE AWAKE (PREVENT OS SLEEP)"
	_style_checkbox(_force_awake_chk)
	_force_awake_chk.toggled.connect(_set_force_awake)
	opt_row.add_child(_force_awake_chk)

	_screen_saver_chk = CheckBox.new()
	_screen_saver_chk.text = "BLACK CLOCK OVERLAY"
	_style_checkbox(_screen_saver_chk)
	_screen_saver_chk.toggled.connect(_set_screen_saver_active)
	opt_row.add_child(_screen_saver_chk)

	var os_hint := Label.new()
	os_hint.text = "(BOTH UNCHECKED = WINDOWS DEFAULT)"
	os_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	os_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	os_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	os_hint.add_theme_font_size_override("font_size", 10)
	os_hint.add_theme_color_override("font_color", EuclidPalette.TEXT_DIM)
	opt_row.add_child(os_hint)

	# Master Volume Dial (synced two-way with top bar MASTER)
	_master_vol_dial = _make_dial("MASTER", "%", 0.0, 1.0, 0.72, false, EuclidPalette.ACCENT_GOLD)
	_master_vol_dial.value_changed.connect(func(v: float) -> void:
		_layers.master_volume = v
		if _rig != null and _rig.patch != null:
			_rig.patch.master_volume = v
			_rig.sync_patch_to_audio_thread()
			SynthBus.patch_parameter_updated.emit()
	)
	hdr_row.add_child(_master_vol_dial)

	# --- Unified Scrollable Mixer List (All 6 Independent Modules) ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	var mixer_list := VBoxContainer.new()
	mixer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mixer_list.add_theme_constant_override("separation", 8)
	scroll.add_child(mixer_list)

	# =========================================================================
	# 1. BROWN HEARTH
	# =========================================================================
	var bh_panel := _make_subpanel()
	mixer_list.add_child(bh_panel)
	var bh_hbox := HBoxContainer.new()
	bh_hbox.add_theme_constant_override("separation", 12)
	bh_panel.add_child(bh_hbox)

	var bh_left := VBoxContainer.new()
	bh_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh_left.add_theme_constant_override("separation", 4)
	bh_hbox.add_child(bh_left)

	bh_left.add_child(_register_layer_toggle("1. BROWN HEARTH: ON", "1. BROWN HEARTH: OFF", func(on: bool) -> void:
		_layers.brown_enabled = on
	))

	var bh_desc := Label.new()
	bh_desc.text = "Deep -6dB/oct Brownian thermal rumble + tunable C2 sub-bass anchor to absorb footsteps, traffic, and wall vibration."
	bh_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bh_desc.add_theme_font_size_override("font_size", 10)
	bh_desc.add_theme_color_override("font_color", EuclidPalette.TEXT_DIM)
	bh_left.add_child(bh_desc)

	var bh_dials := HBoxContainer.new()
	bh_dials.add_theme_constant_override("separation", 6)
	bh_hbox.add_child(bh_dials)

	var bh_lvl := _make_dial("LAYER LVL", "%", 0.0, 1.0, 0.68, false, EuclidPalette.ACCENT_GOLD)
	bh_lvl.value_changed.connect(func(v: float) -> void: _layers.brown_level = v)
	bh_dials.add_child(bh_lvl)

	var bh_cf := _make_dial("CUTOFF", "Hz", 50.0, 1400.0, 220.0, true, EuclidPalette.ACCENT_CYAN)
	bh_cf.value_changed.connect(func(v: float) -> void: _layers.brown_cutoff_hz = v)
	bh_dials.add_child(bh_cf)

	var bh_sub := _make_dial("SUB ANCHOR", "%", 0.0, 1.0, 0.40, false, EuclidPalette.ACCENT_CYAN)
	bh_sub.value_changed.connect(func(v: float) -> void: _layers.brown_sub_level = v)
	bh_dials.add_child(bh_sub)

	var bh_pitch := _make_dial("SUB PITCH", "st", -6.0, 6.0, 0.0, false, EuclidPalette.ACCENT_CYAN)
	bh_pitch.bipolar = true
	bh_pitch.value_changed.connect(func(v: float) -> void: _layers.brown_pitch_semi = v)
	bh_dials.add_child(bh_pitch)

	var bh_rate := _make_dial("BREATH", "Hz", 0.02, 0.35, 0.05, true, EuclidPalette.ACCENT_CYAN)
	bh_rate.value_changed.connect(func(v: float) -> void: _layers.brown_breath_hz = v)
	bh_dials.add_child(bh_rate)

	# =========================================================================
	# 2. PINK CANOPY
	# =========================================================================
	var pc_panel := _make_subpanel()
	mixer_list.add_child(pc_panel)
	var pc_hbox := HBoxContainer.new()
	pc_hbox.add_theme_constant_override("separation", 12)
	pc_panel.add_child(pc_hbox)

	var pc_left := VBoxContainer.new()
	pc_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc_left.add_theme_constant_override("separation", 4)
	pc_hbox.add_child(pc_left)

	pc_left.add_child(_register_layer_toggle("2. PINK CANOPY: ON", "2. PINK CANOPY: OFF", func(on: bool) -> void:
		_layers.pink_enabled = on
	))

	var pc_desc := Label.new()
	pc_desc.text = "Balanced -3dB/oct 1/f spectral blanket with slow tidal filter swell to mask speech, doors, and sudden transients."
	pc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pc_desc.add_theme_font_size_override("font_size", 10)
	pc_desc.add_theme_color_override("font_color", EuclidPalette.TEXT_DIM)
	pc_left.add_child(pc_desc)

	var pc_dials := HBoxContainer.new()
	pc_dials.add_theme_constant_override("separation", 6)
	pc_hbox.add_child(pc_dials)

	var pc_lvl := _make_dial("LAYER LVL", "%", 0.0, 1.0, 0.62, false, EuclidPalette.ACCENT_GOLD)
	pc_lvl.value_changed.connect(func(v: float) -> void: _layers.pink_level = v)
	pc_dials.add_child(pc_lvl)

	var pc_cf := _make_dial("CUTOFF", "Hz", 120.0, 2400.0, 640.0, true, EuclidPalette.ACCENT_CYAN)
	pc_cf.value_changed.connect(func(v: float) -> void: _layers.pink_cutoff_hz = v)
	pc_dials.add_child(pc_cf)

	var pc_rate := _make_dial("TIDAL RATE", "Hz", 0.02, 0.35, 0.09, true, EuclidPalette.ACCENT_CYAN)
	pc_rate.value_changed.connect(func(v: float) -> void: _layers.pink_breath_hz = v)
	pc_dials.add_child(pc_rate)

	var pc_swl := _make_dial("SWELL AMT", "%", 0.0, 1.0, 0.32, false, EuclidPalette.ACCENT_CYAN)
	pc_swl.value_changed.connect(func(v: float) -> void: _layers.pink_swell_depth = v)
	pc_dials.add_child(pc_swl)

	var pc_pitch := _make_dial("SUB PITCH", "st", -6.0, 6.0, 0.0, false, EuclidPalette.ACCENT_CYAN)
	pc_pitch.bipolar = true
	pc_pitch.value_changed.connect(func(v: float) -> void: _layers.pink_pitch_semi = v)
	pc_dials.add_child(pc_pitch)

	# =========================================================================
	# 3. VELVET HARMONY
	# =========================================================================
	var vf_panel := _make_subpanel()
	mixer_list.add_child(vf_panel)
	var vf_hbox := HBoxContainer.new()
	vf_hbox.add_theme_constant_override("separation", 12)
	vf_panel.add_child(vf_hbox)

	var vf_left := VBoxContainer.new()
	vf_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vf_left.add_theme_constant_override("separation", 6)
	vf_hbox.add_child(vf_left)

	var vf_hdr := HBoxContainer.new()
	vf_hdr.add_theme_constant_override("separation", 8)
	vf_left.add_child(vf_hdr)

	vf_hdr.add_child(_register_layer_toggle("3. VELVET HARMONY: ON", "3. VELVET HARMONY: OFF", func(on: bool) -> void:
		_layers.velvet_enabled = on
	))

	var vf_int_btn := OptionButton.new()
	for int_name in LayersEngine.INTERVAL_NAMES:
		vf_int_btn.add_item(int_name)
	vf_int_btn.selected = 7
	vf_int_btn.custom_minimum_size = Vector2(180, 28)
	vf_int_btn.item_selected.connect(func(idx: int) -> void:
		_layers.velvet_interval_semis = idx
	)
	vf_hdr.add_child(vf_int_btn)

	var vf_desc := Label.new()
	vf_desc.text = "Warm filtered C2 root + selectable musical interval up to an octave (INT DETUNE +0.02 st adds subtle just-intonation shimmer)."
	vf_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vf_desc.add_theme_font_size_override("font_size", 10)
	vf_desc.add_theme_color_override("font_color", EuclidPalette.TEXT_DIM)
	vf_left.add_child(vf_desc)

	var vf_dials := HBoxContainer.new()
	vf_dials.add_theme_constant_override("separation", 6)
	vf_hbox.add_child(vf_dials)

	var vf_lvl := _make_dial("LAYER LVL", "%", 0.0, 1.0, 0.58, false, EuclidPalette.ACCENT_GOLD)
	vf_lvl.value_changed.connect(func(v: float) -> void: _layers.velvet_level = v)
	vf_dials.add_child(vf_lvl)

	var vf_cf := _make_dial("CUTOFF", "Hz", 80.0, 1800.0, 340.0, true, EuclidPalette.ACCENT_CYAN)
	vf_cf.value_changed.connect(func(v: float) -> void: _layers.velvet_cutoff_hz = v)
	vf_dials.add_child(vf_cf)

	var vf_p1 := _make_dial("ROOT PITCH", "st", -6.0, 6.0, 0.0, false, EuclidPalette.ACCENT_CYAN)
	vf_p1.bipolar = true
	vf_p1.value_changed.connect(func(v: float) -> void: _layers.velvet_osc1_semi = v)
	vf_dials.add_child(vf_p1)

	var vf_p2 := _make_dial("INT DETUNE", "st", -6.0, 6.0, 0.02, false, EuclidPalette.ACCENT_CYAN)
	vf_p2.bipolar = true
	vf_p2.value_changed.connect(func(v: float) -> void: _layers.velvet_osc2_semi = v)
	vf_dials.add_child(vf_p2)

	var vf_flr := _make_dial("NOISE FLOOR", "%", 0.0, 1.0, 0.28, false, EuclidPalette.ACCENT_CYAN)
	vf_flr.value_changed.connect(func(v: float) -> void: _layers.velvet_floor_level = v)
	vf_dials.add_child(vf_flr)

	# =========================================================================
	# 4. BINAURAL / ISOCHRONIC PULSE
	# =========================================================================
	var bin_panel := _make_subpanel()
	mixer_list.add_child(bin_panel)
	var bin_hbox := HBoxContainer.new()
	bin_hbox.add_theme_constant_override("separation", 12)
	bin_panel.add_child(bin_hbox)

	var bin_left := VBoxContainer.new()
	bin_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bin_left.add_theme_constant_override("separation", 6)
	bin_hbox.add_child(bin_left)

	var bin_hdr := HBoxContainer.new()
	bin_hdr.add_theme_constant_override("separation", 8)
	bin_left.add_child(bin_hdr)

	bin_hdr.add_child(_register_layer_toggle("4. BINAURAL: ON", "4. BINAURAL: OFF", func(on: bool) -> void:
		_layers.binaural_enabled = on
	))

	var bin_mode_btn := OptionButton.new()
	bin_mode_btn.add_item("STEREO BINAURAL")
	bin_mode_btn.add_item("ISOCHRONIC PULSE")
	bin_mode_btn.add_item("HYBRID (BOTH)")
	bin_mode_btn.custom_minimum_size = Vector2(148, 28)
	bin_mode_btn.item_selected.connect(func(idx: int) -> void:
		_layers.binaural_mode = idx
	)
	bin_hdr.add_child(bin_mode_btn)

	_bin_band_btn = OptionButton.new()
	_bin_band_btn.add_item("WAVE: DELTA (2.5 Hz)")
	_bin_band_btn.add_item("WAVE: THETA (6.0 Hz)")
	_bin_band_btn.add_item("WAVE: ALPHA (10.0 Hz)")
	_bin_band_btn.add_item("WAVE: BETA (18.0 Hz)")
	_bin_band_btn.add_item("WAVE: GAMMA (36.0 Hz)")
	_bin_band_btn.custom_minimum_size = Vector2(168, 28)
	_bin_band_btn.item_selected.connect(func(idx: int) -> void:
		var presets: Array[float] = [2.5, 6.0, 10.0, 18.0, 36.0]
		var hz: float = presets[clampi(idx, 0, presets.size() - 1)]
		_layers.binaural_beat_hz = hz
		if _bin_beat_dial != null:
			_bin_beat_dial.set_value_silent(hz)
		_update_binaural_readout(hz, false)
	)
	bin_hdr.add_child(_bin_band_btn)

	_bin_desc_lbl = Label.new()
	_bin_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bin_desc_lbl.add_theme_font_size_override("font_size", 10)
	_bin_desc_lbl.add_theme_color_override("font_color", EuclidPalette.ACCENT_CYAN)
	bin_left.add_child(_bin_desc_lbl)

	var bin_dials := HBoxContainer.new()
	bin_dials.add_theme_constant_override("separation", 6)
	bin_hbox.add_child(bin_dials)

	var bin_lvl := _make_dial("LAYER LVL", "%", 0.0, 1.0, 0.28, false, EuclidPalette.ACCENT_GOLD)
	bin_lvl.value_changed.connect(func(v: float) -> void: _layers.binaural_level = v)
	bin_dials.add_child(bin_lvl)

	var bin_car := _make_dial("CARRIER", "Hz", 55.0, 432.0, 110.0, true, EuclidPalette.ACCENT_CYAN)
	bin_car.value_changed.connect(func(v: float) -> void: _layers.binaural_carrier_hz = v)
	bin_dials.add_child(bin_car)

	_bin_beat_dial = _make_dial("BEAT FREQ", "Hz", 0.5, 40.0, 2.5, true, EuclidPalette.ACCENT_CYAN)
	_bin_beat_dial.value_changed.connect(func(v: float) -> void:
		_layers.binaural_beat_hz = v
		_update_binaural_readout(v, true)
	)
	bin_dials.add_child(_bin_beat_dial)

	var bin_dep := _make_dial("PULSE DEPTH", "%", 0.0, 1.0, 0.65, false, EuclidPalette.ACCENT_CYAN)
	bin_dep.value_changed.connect(func(v: float) -> void: _layers.binaural_depth = v)
	bin_dials.add_child(bin_dep)

	_update_binaural_readout(2.5, true)

	# =========================================================================
	# 5. FILTERED NATURE TEXTURES
	# =========================================================================
	var nat_panel := _make_subpanel()
	mixer_list.add_child(nat_panel)
	var nat_hbox := HBoxContainer.new()
	nat_hbox.add_theme_constant_override("separation", 12)
	nat_panel.add_child(nat_hbox)

	var nat_left := VBoxContainer.new()
	nat_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nat_left.add_theme_constant_override("separation", 6)
	nat_hbox.add_child(nat_left)

	var nat_hdr := HBoxContainer.new()
	nat_hdr.add_theme_constant_override("separation", 8)
	nat_left.add_child(nat_hdr)

	nat_hdr.add_child(_register_layer_toggle("5. NATURE: ON", "5. NATURE: OFF", func(on: bool) -> void:
		_layers.nature_enabled = on
	))

	var nat_type_btn := OptionButton.new()
	nat_type_btn.add_item("DISTANT RAIN")
	nat_type_btn.add_item("WIND IN TREES")
	nat_type_btn.add_item("OCEAN SURF")
	nat_type_btn.add_item("FIRE CRACKLE")
	nat_type_btn.add_item("NIGHT CRICKETS")
	nat_type_btn.add_item("BROOK / STREAM")
	nat_type_btn.add_item("THUNDER RUMBLE")
	nat_type_btn.custom_minimum_size = Vector2(165, 28)
	nat_type_btn.item_selected.connect(func(idx: int) -> void:
		_layers.nature_type = idx
	)
	nat_hdr.add_child(nat_type_btn)

	var nat_sub := Label.new()
	nat_sub.text = "Asynchronous LFO bandpass & rhythmic pulse synthesizer (Rain, Wind, Surf, Fire, Crickets, Brook, Thunder)."
	nat_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nat_sub.add_theme_font_size_override("font_size", 10)
	nat_sub.add_theme_color_override("font_color", EuclidPalette.TEXT_DIM)
	nat_left.add_child(nat_sub)

	var nat_dials := HBoxContainer.new()
	nat_dials.add_theme_constant_override("separation", 6)
	nat_hbox.add_child(nat_dials)

	var nat_lvl := _make_dial("LAYER LVL", "%", 0.0, 1.0, 0.45, false, EuclidPalette.ACCENT_GOLD)
	nat_lvl.value_changed.connect(func(v: float) -> void: _layers.nature_level = v)
	nat_dials.add_child(nat_lvl)

	var nat_tone := _make_dial("TONE / PITCH", "%", 0.0, 1.0, 0.50, false, EuclidPalette.ACCENT_CYAN)
	nat_tone.value_changed.connect(func(v: float) -> void: _layers.nature_tone = v)
	nat_dials.add_child(nat_tone)

	var nat_rate := _make_dial("CHIRP / RATE", "%", 0.0, 1.0, 0.35, false, EuclidPalette.ACCENT_CYAN)
	nat_rate.value_changed.connect(func(v: float) -> void: _layers.nature_rate = v)
	nat_dials.add_child(nat_rate)

	var nat_den := _make_dial("DENSITY / Q", "%", 0.0, 1.0, 0.55, false, EuclidPalette.ACCENT_CYAN)
	nat_den.value_changed.connect(func(v: float) -> void: _layers.nature_density = v)
	nat_dials.add_child(nat_den)

	# =========================================================================
	# 6. GENERATIVE HARMONIC SWELLS
	# =========================================================================
	var swl_panel := _make_subpanel()
	mixer_list.add_child(swl_panel)
	var swl_hbox := HBoxContainer.new()
	swl_hbox.add_theme_constant_override("separation", 12)
	swl_panel.add_child(swl_hbox)

	var swl_left := VBoxContainer.new()
	swl_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swl_left.add_theme_constant_override("separation", 6)
	swl_hbox.add_child(swl_left)

	var swl_row1 := HBoxContainer.new()
	swl_row1.add_theme_constant_override("separation", 8)
	swl_left.add_child(swl_row1)

	swl_row1.add_child(_register_layer_toggle("6. SWELLS: ON", "6. SWELLS: OFF", func(on: bool) -> void:
		_layers.swells_enabled = on
		if on:
			_layers.reset_swell_sequence(false)
	))

	_swl_asc_chk = CheckBox.new()
	_swl_asc_chk.text = "ASCENDING"
	_swl_asc_chk.button_pressed = true
	_style_checkbox(_swl_asc_chk)
	_swl_asc_chk.toggled.connect(func(on: bool) -> void:
		_layers.swells_asc_enabled = on
		if not on and not _swl_desc_chk.button_pressed:
			_swl_desc_chk.button_pressed = true
		_layers.reset_swell_sequence(not on)
	)
	swl_row1.add_child(_swl_asc_chk)

	_swl_desc_chk = CheckBox.new()
	_swl_desc_chk.text = "DESCENDING"
	_swl_desc_chk.button_pressed = false
	_style_checkbox(_swl_desc_chk)
	_swl_desc_chk.toggled.connect(func(on: bool) -> void:
		_layers.swells_desc_enabled = on
		if not on and not _swl_asc_chk.button_pressed:
			_swl_asc_chk.button_pressed = true
		_layers.reset_swell_sequence(on)
	)
	swl_row1.add_child(_swl_desc_chk)

	_swl_root_btn = OptionButton.new()
	for n_name in NOTE_NAMES:
		_swl_root_btn.add_item("ROOT: " + n_name)
	_swl_root_btn.custom_minimum_size = Vector2(96, 26)
	_swl_root_btn.item_selected.connect(func(_idx: int) -> void: _update_swell_root_midi())
	swl_row1.add_child(_swl_root_btn)

	_swl_oct_btn = OptionButton.new()
	_swl_oct_btn.add_item("OCT 2")
	_swl_oct_btn.add_item("OCT 3")
	_swl_oct_btn.add_item("OCT 4")
	_swl_oct_btn.selected = 1
	_swl_oct_btn.custom_minimum_size = Vector2(72, 26)
	_swl_oct_btn.item_selected.connect(func(_idx: int) -> void: _update_swell_root_midi())
	swl_row1.add_child(_swl_oct_btn)

	_swl_span_btn = OptionButton.new()
	_swl_span_btn.add_item("1 OCT")
	_swl_span_btn.add_item("2 OCT")
	_swl_span_btn.custom_minimum_size = Vector2(74, 26)
	_swl_span_btn.item_selected.connect(func(idx: int) -> void:
		_layers.swells_octaves = idx + 1
		_layers.reset_swell_sequence(false)
	)
	swl_row1.add_child(_swl_span_btn)

	var swl_row2 := HBoxContainer.new()
	swl_row2.add_theme_constant_override("separation", 8)
	swl_left.add_child(swl_row2)

	var up_lbl := Label.new()
	up_lbl.text = "SCALE UP:"
	up_lbl.add_theme_font_size_override("font_size", 10)
	up_lbl.add_theme_color_override("font_color", EuclidPalette.ACCENT_CYAN)
	swl_row2.add_child(up_lbl)

	var swl_scale_up_btn := OptionButton.new()
	for s_name in LayersEngine.SCALE_NAMES:
		swl_scale_up_btn.add_item(s_name)
	swl_scale_up_btn.selected = 3
	swl_scale_up_btn.custom_minimum_size = Vector2(148, 26)
	swl_scale_up_btn.item_selected.connect(func(idx: int) -> void:
		_layers.swells_scale_up_idx = idx
		_layers.reset_swell_sequence(false)
	)
	swl_row2.add_child(swl_scale_up_btn)

	var dn_lbl := Label.new()
	dn_lbl.text = "SCALE DOWN:"
	dn_lbl.add_theme_font_size_override("font_size", 10)
	dn_lbl.add_theme_color_override("font_color", EuclidPalette.ACCENT_GOLD)
	swl_row2.add_child(dn_lbl)

	var swl_scale_dn_btn := OptionButton.new()
	for s_name in LayersEngine.SCALE_NAMES:
		swl_scale_dn_btn.add_item(s_name)
	swl_scale_dn_btn.selected = 4
	swl_scale_dn_btn.custom_minimum_size = Vector2(148, 26)
	swl_scale_dn_btn.item_selected.connect(func(idx: int) -> void:
		_layers.swells_scale_down_idx = idx
		_layers.reset_swell_sequence(true)
	)
	swl_row2.add_child(swl_scale_dn_btn)

	var swl_wave_btn := OptionButton.new()
	swl_wave_btn.add_item("SINE")
	swl_wave_btn.add_item("TRIANGLE")
	swl_wave_btn.add_item("SOFT WARM")
	swl_wave_btn.custom_minimum_size = Vector2(96, 26)
	swl_wave_btn.item_selected.connect(func(idx: int) -> void:
		_layers.swells_wave = idx
	)
	swl_row2.add_child(swl_wave_btn)

	_swl_status_lbl = Label.new()
	_swl_status_lbl.text = "ACTIVE NOTE: IDLE"
	_swl_status_lbl.clip_text = true
	_swl_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_swl_status_lbl.add_theme_font_size_override("font_size", 10)
	_swl_status_lbl.add_theme_color_override("font_color", EuclidPalette.ACCENT_GOLD)
	swl_left.add_child(_swl_status_lbl)

	var swl_dials := HBoxContainer.new()
	swl_dials.add_theme_constant_override("separation", 6)
	swl_hbox.add_child(swl_dials)

	var swl_lvl := _make_dial("LAYER LVL", "%", 0.0, 1.0, 0.35, false, EuclidPalette.ACCENT_GOLD)
	swl_lvl.value_changed.connect(func(v: float) -> void: _layers.swells_level = v)
	swl_dials.add_child(swl_lvl)

	var swl_damp := _make_dial("HIGH DAMP", "%", 0.0, 1.0, 0.70, false, EuclidPalette.ACCENT_GOLD)
	swl_damp.value_changed.connect(func(v: float) -> void: _layers.swells_high_damp = v)
	swl_dials.add_child(swl_damp)

	var swl_dur := _make_dial("PITCH DUR", "s", 0.5, 30.0, 6.0, false, EuclidPalette.ACCENT_CYAN)
	swl_dur.value_changed.connect(func(v: float) -> void:
		_layers.swells_duration_sec = v
		_layers.clamp_swell_wait_timer()
	)
	swl_dials.add_child(swl_dur)

	var swl_gap := _make_dial("STEP GAP", "s", 0.0, 40.0, 3.0, false, EuclidPalette.ACCENT_CYAN)
	swl_gap.value_changed.connect(func(v: float) -> void:
		_layers.swells_gap_sec = v
		_layers.clamp_swell_wait_timer()
	)
	swl_dials.add_child(swl_gap)

	var swl_spr := _make_dial("PAN SPREAD", "%", 0.0, 1.0, 0.65, false, EuclidPalette.ACCENT_CYAN)
	swl_spr.value_changed.connect(func(v: float) -> void: _layers.swells_spread = v)
	swl_dials.add_child(swl_spr)


func _update_binaural_readout(beat_hz: float, sync_dropdown: bool) -> void:
	if _bin_desc_lbl == null:
		return
	var band_idx: int = 0
	if beat_hz < 4.0:
		band_idx = 0
		_bin_desc_lbl.text = "DELTA (%.1f Hz | 0.5-4 Hz): Deep dreamless slow-wave sleep & physical restoration. Eases in over 3.5s." % beat_hz
	elif beat_hz < 8.0:
		band_idx = 1
		_bin_desc_lbl.text = "THETA (%.1f Hz | 4-8 Hz): Hypnagogic twilight, REM dreaming & deep meditative drift. Eases in over 3.5s." % beat_hz
	elif beat_hz < 13.0:
		band_idx = 2
		_bin_desc_lbl.text = "ALPHA (%.1f Hz | 8-13 Hz): Relaxed wakefulness, eyes-closed calm & pre-sleep wind-down. Eases in over 3.5s." % beat_hz
	elif beat_hz < 30.0:
		band_idx = 3
		_bin_desc_lbl.text = "BETA (%.1f Hz | 13-30 Hz): Active focus & alert concentration (typically too stimulating for sleep)." % beat_hz
	else:
		band_idx = 4
		_bin_desc_lbl.text = "GAMMA (%.1f Hz | 30-40 Hz): Peak cognitive binding & heightened sensory processing." % beat_hz

	if sync_dropdown and _bin_band_btn != null and _bin_band_btn.selected != band_idx:
		_bin_band_btn.selected = band_idx


func _update_swell_root_midi() -> void:
	if _layers == null or _swl_root_btn == null or _swl_oct_btn == null:
		return
	var semi: int = _swl_root_btn.selected
	var oct: int = _swl_oct_btn.selected + 2
	_layers.swells_root_midi = (oct + 1) * 12 + semi
	_layers.reset_swell_sequence(false)


func _build_screen_saver_overlay() -> void:
	_saver_layer = CanvasLayer.new()
	_saver_layer.layer = 100
	_saver_layer.visible = false
	add_child(_saver_layer)

	_saver_overlay = Control.new()
	_saver_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_saver_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_saver_overlay.draw.connect(_on_draw_screen_saver)
	_saver_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_set_screen_saver_active(false)
		elif event is InputEventScreenTouch and event.pressed:
			_set_screen_saver_active(false)
		elif event is InputEventKey and event.pressed:
			_set_screen_saver_active(false)
	)
	_saver_layer.add_child(_saver_overlay)

	_clock_timer = Timer.new()
	_clock_timer.wait_time = 5.0
	_clock_timer.timeout.connect(func() -> void:
		if _saver_overlay != null:
			_saver_overlay.queue_redraw()
	)
	add_child(_clock_timer)


func _set_force_awake(awake: bool) -> void:
	if _force_awake_chk != null and _force_awake_chk.button_pressed != awake:
		_force_awake_chk.set_pressed_no_signal(awake)
	DisplayServer.screen_set_keep_on(awake)


func _set_screen_saver_active(active: bool) -> void:
	if _screen_saver_chk != null and _screen_saver_chk.button_pressed != active:
		_screen_saver_chk.set_pressed_no_signal(active)
	if _saver_layer != null:
		_saver_layer.visible = active
	if active:
		_saver_overlay.queue_redraw()
		_clock_timer.start()
	else:
		_clock_timer.stop()


func _on_draw_screen_saver() -> void:
	var sz: Vector2 = _saver_overlay.size
	_saver_overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color.BLACK, true)

	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var hour24: int = int(dt["hour"])
	var minute: int = int(dt["minute"])
	var ampm: String = "PM" if hour24 >= 12 else "AM"
	var hour12: int = hour24 % 12
	if hour12 == 0:
		hour12 = 12
	var time_str: String = "%d:%02d" % [hour12, minute]

	var font: Font = EuclidPalette.get_font()
	var drift_x: float = sin(float(minute) * 0.35) * 32.0
	var drift_y: float = cos(float(minute) * 0.25) * 24.0
	var center_y: float = sz.y * 0.5 + drift_y

	var clock_col := Color(0.788, 0.663, 0.431, 0.42)
	var sub_col := Color(0.533, 0.565, 0.643, 0.32)

	_saver_overlay.draw_string(font, Vector2(drift_x, center_y), time_str, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 76, clock_col)
	_saver_overlay.draw_string(font, Vector2(drift_x, center_y + 26.0), "%s  //  CLICK OR PRESS KEY TO EXIT" % ampm, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 11, sub_col)


func stop_sleep_audio() -> void:
	SynthBus.panic()
	if _layers != null:
		_layers.disable_all_layers()
	for i in range(_all_toggles.size()):
		_all_toggles[i].set_active_silent(false)
		_all_toggles[i].label = _all_off_labels[i]


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)
