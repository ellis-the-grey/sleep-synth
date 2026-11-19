class_name MinimodMain
extends Control

const USER_PRESET_DIR := "user://presets"
const BUILTIN_PRESET_DIR := "res://synth_core/presets"

var _rig: SynthRig
var _patch: SynthPatch

# Top Bar Controls
var _preset_dropdown: OptionButton
var _preset_paths: Array[String] = []
var _patch_name_edit: LineEdit
var _voices_dial: EuclidDial
var _glide_dial: EuclidDial
var _legato_toggle: EuclidToggle
var _master_dial: EuclidDial
var _accidental_toggle: EuclidToggle
var _piano_toggle: EuclidToggle
var _hex_toggle: EuclidToggle
var _qwerty_mode_toggle: EuclidToggle
var _sleep_mode_toggle: EuclidToggle
var _midi_status_label: Label

# Rack Containers & Widgets
var _rack_scroll: ScrollContainer
var _sleep_panel: SleepModePanel
var _osc_container: HBoxContainer
var _add_osc_btn: Button

var _noise_active_toggle: EuclidToggle
var _noise_color_toggle: EuclidToggle
var _noise_level_dial: EuclidDial
var _overload_dial: EuclidDial

var _cutoff_dial: EuclidDial
var _emphasis_dial: EuclidDial
var _filter_contour_amt_dial: EuclidDial
var _kbd_track_toggle: EuclidToggle

var _f_env_view: EuclidEnvelopeView
var _f_atk_dial: EuclidDial
var _f_dec_dial: EuclidDial
var _f_sus_dial: EuclidDial
var _f_rel_toggle: EuclidToggle

var _a_env_view: EuclidEnvelopeView
var _a_atk_dial: EuclidDial
var _a_dec_dial: EuclidDial
var _a_sus_dial: EuclidDial
var _a_rel_toggle: EuclidToggle

var _scope: EuclidScope
var _mod_routes_container: VBoxContainer

# Bottom Keyboards
var _keyboard_dock: VBoxContainer
var _piano_strip: PianoStrip
var _hex_table: HexHarmonicTable


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(USER_PRESET_DIR)

	_rig = SynthRig.new()
	_rig.name = "SynthRig"
	add_child(_rig)

	_patch = _rig.patch
	_build_ui()
	_refresh_preset_list()
	_bind_patch_to_ui()
	_update_midi_status()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), EuclidPalette.BG_VOID, true)


func _build_ui() -> void:
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 10)
	root_margin.add_theme_constant_override("margin_right", 10)
	root_margin.add_theme_constant_override("margin_top", 8)
	root_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(root_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	root_margin.add_child(main_vbox)

	# --- 1. TOP COMMAND BAR ---
	main_vbox.add_child(_build_top_bar())

	# --- 2. EMBEDDED SLEEP MODE PANEL (Hidden by default) ---
	_sleep_panel = SleepModePanel.new()
	_sleep_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sleep_panel.visible = false
	_sleep_panel.bind_rig(_rig)
	_sleep_panel.exit_sleep_mode_requested.connect(func() -> void:
		_set_sleep_mode_active(false)
	)
	main_vbox.add_child(_sleep_panel)

	# --- 3. RACK SCROLL AREA ---
	_rack_scroll = ScrollContainer.new()
	_rack_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_rack_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(_rack_scroll)

	var rack_vbox := VBoxContainer.new()
	rack_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rack_vbox.add_theme_constant_override("separation", 8)
	_rack_scroll.add_child(rack_vbox)

	# Row A: Modular Oscillators + Add Button
	var osc_band := _make_framed_panel("OSCILLATOR BANK (MODULAR ARRAY)")
	rack_vbox.add_child(osc_band)
	var osc_band_inner: VBoxContainer = osc_band.get_meta("content_box")

	var osc_scroll := ScrollContainer.new()
	osc_scroll.custom_minimum_size = Vector2(0, 260)
	osc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	osc_band_inner.add_child(osc_scroll)

	var osc_row := HBoxContainer.new()
	osc_row.add_theme_constant_override("separation", 8)
	osc_scroll.add_child(osc_row)

	_osc_container = HBoxContainer.new()
	_osc_container.add_theme_constant_override("separation", 8)
	osc_row.add_child(_osc_container)

	_add_osc_btn = Button.new()
	_add_osc_btn.text = "+ ADD\nOSC"
	_add_osc_btn.custom_minimum_size = Vector2(68, 248)
	_add_osc_btn.tooltip_text = "Append a new modular oscillator (up to 8 per voice)"
	_add_osc_btn.pressed.connect(_on_add_osc_pressed)
	osc_row.add_child(_add_osc_btn)

	# Row B: Mixer/Noise + 24dB Ladder Filter + Contours + Scope/Mod Matrix
	var lower_rack_row := HBoxContainer.new()
	lower_rack_row.add_theme_constant_override("separation", 8)
	rack_vbox.add_child(lower_rack_row)

	lower_rack_row.add_child(_build_noise_mixer_panel())
	lower_rack_row.add_child(_build_filter_panel())
	lower_rack_row.add_child(_build_contours_panel())
	lower_rack_row.add_child(_build_scope_and_mod_panel())

	# --- 4. BOTTOM HIDEABLE KEYBOARD CONTROLLERS ---
	_keyboard_dock = VBoxContainer.new()
	_keyboard_dock.add_theme_constant_override("separation", 6)
	main_vbox.add_child(_keyboard_dock)

	_piano_strip = PianoStrip.new()
	_piano_strip.show_qwerty_hints = false
	_piano_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keyboard_dock.add_child(_piano_strip)

	_hex_table = HexHarmonicTable.new()
	_hex_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keyboard_dock.add_child(_hex_table)


func _set_sleep_mode_active(active: bool) -> void:
	if _sleep_mode_toggle != null:
		_sleep_mode_toggle.set_active_silent(active)
	if active:
		SynthBus.panic()
		_rack_scroll.visible = false
		_keyboard_dock.visible = false
		_sleep_panel.visible = true
		_sleep_panel.bind_rig(_rig)
	else:
		_sleep_panel.stop_sleep_audio()
		_sleep_panel.visible = false
		_rack_scroll.visible = true
		_keyboard_dock.visible = true
		_rig.load_patch(_patch)
		_bind_patch_to_ui()


func _make_framed_panel(title: String, min_sz: Vector2 = Vector2.ZERO) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_sz

	var sb := StyleBoxFlat.new()
	sb.bg_color = EuclidPalette.BG_PANEL
	sb.border_color = EuclidPalette.LINE_DIM
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var hdr := Label.new()
	hdr.text = title
	hdr.add_theme_font_size_override("font_size", 10)
	hdr.add_theme_color_override("font_color", EuclidPalette.TEXT_DIM)
	vbox.add_child(hdr)

	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = EuclidPalette.LINE_DIM
	sep_sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	vbox.add_child(sep)

	panel.set_meta("content_box", vbox)
	return panel


func _build_top_bar() -> Control:
	var panel := _make_framed_panel("MINIMOD // EUCLID SUBTRACTIVE SYNTHESIZER  [48 kHz]")
	var content: VBoxContainer = panel.get_meta("content_box")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)

	_preset_dropdown = OptionButton.new()
	_preset_dropdown.custom_minimum_size = Vector2(150, 28)
	_preset_dropdown.item_selected.connect(_on_preset_selected)
	row.add_child(_preset_dropdown)

	_patch_name_edit = LineEdit.new()
	_patch_name_edit.custom_minimum_size = Vector2(115, 28)
	_patch_name_edit.placeholder_text = "Patch Name"
	_patch_name_edit.text_changed.connect(func(new_txt: String) -> void:
		if _patch != null:
			_patch.patch_name = new_txt
	)
	row.add_child(_patch_name_edit)

	var save_btn := Button.new()
	save_btn.text = "SAVE .TRES"
	save_btn.custom_minimum_size = Vector2(76, 28)
	save_btn.pressed.connect(_on_save_patch_pressed)
	row.add_child(save_btn)

	var init_btn := Button.new()
	init_btn.text = "INIT"
	init_btn.custom_minimum_size = Vector2(44, 28)
	init_btn.pressed.connect(_on_init_patch_pressed)
	row.add_child(init_btn)

	# Placed prominently on the left so it never clips off narrow viewports
	_sleep_mode_toggle = EuclidToggle.new()
	_sleep_mode_toggle.label = "SLEEP MODE"
	_sleep_mode_toggle.accent_color = EuclidPalette.ACCENT_GOLD
	_sleep_mode_toggle.custom_minimum_size = Vector2(96, 28)
	_sleep_mode_toggle.toggled.connect(_set_sleep_mode_active)
	row.add_child(_sleep_mode_toggle)

	_voices_dial = EuclidDial.new()
	_voices_dial.label = "VOICES"
	_voices_dial.min_value = 1.0
	_voices_dial.max_value = 16.0
	_voices_dial.default_value = 1.0
	_voices_dial.step = 1.0
	_voices_dial.custom_minimum_size = Vector2(56, 64)
	_voices_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null:
			_patch.max_voices = int(v)
			_voices_dial.label = "MONO 1" if _patch.max_voices == 1 else "POLY %d" % _patch.max_voices
			_push_patch_update()
	)
	row.add_child(_voices_dial)

	_glide_dial = EuclidDial.new()
	_glide_dial.label = "GLIDE"
	_glide_dial.unit = "ms"
	_glide_dial.min_value = 0.0
	_glide_dial.max_value = 2000.0
	_glide_dial.default_value = 35.0
	_glide_dial.custom_minimum_size = Vector2(56, 64)
	_glide_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null:
			_patch.glide_ms = v
			_push_patch_update()
	)
	row.add_child(_glide_dial)

	_legato_toggle = EuclidToggle.new()
	_legato_toggle.label = "RETRIG"
	_legato_toggle.custom_minimum_size = Vector2(64, 28)
	_legato_toggle.toggled.connect(func(on: bool) -> void:
		if _patch != null:
			_patch.legato_retrigger = on
			_push_patch_update()
	)
	row.add_child(_legato_toggle)

	_master_dial = EuclidDial.new()
	_master_dial.label = "MASTER"
	_master_dial.unit = "%"
	_master_dial.min_value = 0.0
	_master_dial.max_value = 1.0
	_master_dial.default_value = 0.72
	_master_dial.custom_minimum_size = Vector2(56, 64)
	_master_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null:
			_patch.master_volume = v
			_push_patch_update()
	)
	row.add_child(_master_dial)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var view_col := VBoxContainer.new()
	view_col.add_theme_constant_override("separation", 4)
	row.add_child(view_col)

	var kbd_btn_row := HBoxContainer.new()
	kbd_btn_row.add_theme_constant_override("separation", 5)
	view_col.add_child(kbd_btn_row)

	_accidental_toggle = EuclidToggle.new()
	_accidental_toggle.options = ["D#/Eb", "SHARP #", "FLAT b"]
	_accidental_toggle.accent_color = EuclidPalette.ACCENT_GOLD
	_accidental_toggle.custom_minimum_size = Vector2(72, 26)
	_accidental_toggle.option_selected.connect(func(idx: int) -> void:
		SynthBus.accidental_mode = idx as SynthBus.AccidentalMode
	)
	kbd_btn_row.add_child(_accidental_toggle)

	_qwerty_mode_toggle = EuclidToggle.new()
	_qwerty_mode_toggle.options = ["KEYS: HEX", "KEYS: PIANO"]
	_qwerty_mode_toggle.accent_color = EuclidPalette.ACCENT_CYAN
	_qwerty_mode_toggle.custom_minimum_size = Vector2(96, 26)
	_qwerty_mode_toggle.option_selected.connect(func(idx: int) -> void:
		var mode := MidiRouter.QwertyLayoutMode.HEX if idx == 0 else MidiRouter.QwertyLayoutMode.PIANO
		MidiRouter.set_layout_mode(mode)
		if _piano_strip != null:
			_piano_strip.show_qwerty_hints = (idx == 1)
			_piano_strip.queue_redraw()
		if _hex_table != null:
			_hex_table.queue_redraw()
	)
	kbd_btn_row.add_child(_qwerty_mode_toggle)

	_piano_toggle = EuclidToggle.new()
	_piano_toggle.label = "PIANO"
	_piano_toggle.active = true
	_piano_toggle.custom_minimum_size = Vector2(66, 26)
	_piano_toggle.toggled.connect(func(vis: bool) -> void:
		if _piano_strip != null:
			_piano_strip.visible = vis
		_sync_qwerty_mode_from_visibility()
	)
	kbd_btn_row.add_child(_piano_toggle)

	_hex_toggle = EuclidToggle.new()
	_hex_toggle.label = "HEX GRID"
	_hex_toggle.active = true
	_hex_toggle.custom_minimum_size = Vector2(80, 26)
	_hex_toggle.toggled.connect(func(vis: bool) -> void:
		if _hex_table != null:
			_hex_table.visible = vis
		_sync_qwerty_mode_from_visibility()
	)
	kbd_btn_row.add_child(_hex_toggle)

	var panic_btn := Button.new()
	panic_btn.text = "PANIC"
	panic_btn.custom_minimum_size = Vector2(54, 26)
	panic_btn.pressed.connect(func() -> void:
		SynthBus.panic()
	)
	kbd_btn_row.add_child(panic_btn)

	var midi_row := HBoxContainer.new()
	midi_row.add_theme_constant_override("separation", 6)
	view_col.add_child(midi_row)

	var scan_midi_btn := Button.new()
	scan_midi_btn.text = "SCAN MIDI"
	scan_midi_btn.custom_minimum_size = Vector2(76, 22)
	scan_midi_btn.pressed.connect(func() -> void:
		MidiRouter.refresh_midi_devices()
		_update_midi_status()
	)
	midi_row.add_child(scan_midi_btn)

	_midi_status_label = Label.new()
	_midi_status_label.add_theme_font_size_override("font_size", 9)
	_midi_status_label.add_theme_color_override("font_color", EuclidPalette.TEXT_DIM)
	midi_row.add_child(_midi_status_label)

	return panel


func _build_noise_mixer_panel() -> Control:
	var panel := _make_framed_panel("NOISE & DRIVE", Vector2(156, 250))
	var box: VBoxContainer = panel.get_meta("content_box")

	_noise_active_toggle = EuclidToggle.new()
	_noise_active_toggle.label = "NOISE ON"
	_noise_active_toggle.toggled.connect(func(on: bool) -> void:
		if _patch != null and _patch.noise != null:
			_patch.noise.enabled = on
			_push_patch_update()
	)
	box.add_child(_noise_active_toggle)

	_noise_color_toggle = EuclidToggle.new()
	_noise_color_toggle.options = NoiseConfig.COLOR_NAMES
	_noise_color_toggle.option_selected.connect(func(idx: int) -> void:
		if _patch != null and _patch.noise != null:
			_patch.noise.color = idx as NoiseConfig.NoiseColor
			_push_patch_update()
	)
	box.add_child(_noise_color_toggle)

	var dials := HBoxContainer.new()
	dials.add_theme_constant_override("separation", 4)
	box.add_child(dials)

	_noise_level_dial = EuclidDial.new()
	_noise_level_dial.label = "NOISE"
	_noise_level_dial.unit = "%"
	_noise_level_dial.min_value = 0.0
	_noise_level_dial.max_value = 1.0
	_noise_level_dial.default_value = 0.20
	_noise_level_dial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_noise_level_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null and _patch.noise != null:
			_patch.noise.level = v
			_push_patch_update()
	)
	dials.add_child(_noise_level_dial)

	_overload_dial = EuclidDial.new()
	_overload_dial.label = "DRIVE"
	_overload_dial.min_value = 0.0
	_overload_dial.max_value = 2.0
	_overload_dial.default_value = 0.15
	_overload_dial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overload_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null and _patch.filter != null:
			_patch.filter.overload_drive = v
			_push_patch_update()
	)
	dials.add_child(_overload_dial)

	return panel


func _build_filter_panel() -> Control:
	var panel := _make_framed_panel("24dB LADDER FILTER", Vector2(226, 250))
	var box: VBoxContainer = panel.get_meta("content_box")

	var top_dials := HBoxContainer.new()
	top_dials.add_theme_constant_override("separation", 6)
	box.add_child(top_dials)

	_cutoff_dial = EuclidDial.new()
	_cutoff_dial.label = "CUTOFF"
	_cutoff_dial.unit = "Hz"
	_cutoff_dial.min_value = 20.0
	_cutoff_dial.max_value = 18000.0
	_cutoff_dial.default_value = 2200.0
	_cutoff_dial.logarithmic = true
	_cutoff_dial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cutoff_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null and _patch.filter != null:
			_patch.filter.cutoff_hz = v
			_scope.queue_redraw()
			_push_patch_update()
	)
	top_dials.add_child(_cutoff_dial)

	_emphasis_dial = EuclidDial.new()
	_emphasis_dial.label = "EMPHASIS"
	_emphasis_dial.min_value = 0.0
	_emphasis_dial.max_value = 3.95
	_emphasis_dial.default_value = 0.85
	_emphasis_dial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_emphasis_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null and _patch.filter != null:
			_patch.filter.emphasis = v
			_scope.queue_redraw()
			_push_patch_update()
	)
	top_dials.add_child(_emphasis_dial)

	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 6)
	box.add_child(bot_row)

	_filter_contour_amt_dial = EuclidDial.new()
	_filter_contour_amt_dial.label = "CONTOUR"
	_filter_contour_amt_dial.bipolar = true
	_filter_contour_amt_dial.min_value = -1.0
	_filter_contour_amt_dial.max_value = 1.0
	_filter_contour_amt_dial.default_value = 0.45
	_filter_contour_amt_dial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_contour_amt_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null and _patch.filter != null:
			_patch.filter.contour_amount = v
			_push_patch_update()
	)
	bot_row.add_child(_filter_contour_amt_dial)

	var kbd_col := VBoxContainer.new()
	kbd_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kbd_col.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_row.add_child(kbd_col)

	var kbd_lbl := Label.new()
	kbd_lbl.text = "KBD TRACK"
	kbd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kbd_lbl.add_theme_font_size_override("font_size", 9)
	kbd_lbl.add_theme_color_override("font_color", EuclidPalette.TEXT_DIM)
	kbd_col.add_child(kbd_lbl)

	_kbd_track_toggle = EuclidToggle.new()
	_kbd_track_toggle.options = FilterConfig.TRACKING_NAMES
	_kbd_track_toggle.option_selected.connect(func(idx: int) -> void:
		if _patch != null and _patch.filter != null:
			_patch.filter.kbd_tracking_idx = idx
			_push_patch_update()
	)
	kbd_col.add_child(_kbd_track_toggle)

	return panel


func _build_contours_panel() -> Control:
	var panel := _make_framed_panel("CONTOUR GENERATORS (ADS)", Vector2(460, 250))
	var box: VBoxContainer = panel.get_meta("content_box")

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 10)
	box.add_child(split)

	var f_col := VBoxContainer.new()
	f_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f_col.add_theme_constant_override("separation", 4)
	split.add_child(f_col)

	_f_env_view = EuclidEnvelopeView.new()
	_f_env_view.title = "FILTER CONTOUR"
	_f_env_view.accent_color = EuclidPalette.ACCENT_CYAN
	f_col.add_child(_f_env_view)

	var f_dials := HBoxContainer.new()
	f_dials.add_theme_constant_override("separation", 2)
	f_col.add_child(f_dials)

	_f_atk_dial = _make_env_dial("ATK", "ms", 1.0, 10000.0, 14.0, true, EuclidPalette.ACCENT_CYAN)
	_f_atk_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null and _patch.filter_contour != null:
			_patch.filter_contour.attack_ms = v
			_f_env_view.queue_redraw()
			_push_patch_update()
	)
	f_dials.add_child(_f_atk_dial)

	_f_dec_dial = _make_env_dial("DEC", "ms", 4.0, 25000.0, 520.0, true, EuclidPalette.ACCENT_CYAN)
	_f_dec_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null and _patch.filter_contour != null:
			_patch.filter_contour.decay_ms = v
			_f_env_view.queue_redraw()
			_push_patch_update()
	)
	f_dials.add_child(_f_dec_dial)

	_f_sus_dial = _make_env_dial("SUS", "%", 0.0, 1.0, 0.35, false, EuclidPalette.ACCENT_CYAN)
	_f_sus_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null and _patch.filter_contour != null:
			_patch.filter_contour.sustain_level = v
			_f_env_view.queue_redraw()
			_push_patch_update()
	)
	f_dials.add_child(_f_sus_dial)

	_f_rel_toggle = EuclidToggle.new()
	_f_rel_toggle.label = "DECAY REL"
	_f_rel_toggle.accent_color = EuclidPalette.ACCENT_CYAN
	_f_rel_toggle.custom_minimum_size = Vector2(0, 22)
	_f_rel_toggle.toggled.connect(func(on: bool) -> void:
		if _patch != null and _patch.filter_contour != null:
			_patch.filter_contour.release_on_decay = on
			_f_env_view.queue_redraw()
			_push_patch_update()
	)
	f_col.add_child(_f_rel_toggle)

	var a_col := VBoxContainer.new()
	a_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_col.add_theme_constant_override("separation", 4)
	split.add_child(a_col)

	_a_env_view = EuclidEnvelopeView.new()
	_a_env_view.title = "LOUDNESS (VCA) CONTOUR"
	_a_env_view.accent_color = EuclidPalette.ACCENT_GOLD
	a_col.add_child(_a_env_view)

	var a_dials := HBoxContainer.new()
	a_dials.add_theme_constant_override("separation", 2)
	a_col.add_child(a_dials)

	_a_atk_dial = _make_env_dial("ATK", "ms", 1.0, 10000.0, 8.0, true, EuclidPalette.ACCENT_GOLD)
	_a_atk_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null and _patch.loudness_contour != null:
			_patch.loudness_contour.attack_ms = v
			_a_env_view.queue_redraw()
			_push_patch_update()
	)
	a_dials.add_child(_a_atk_dial)

	_a_dec_dial = _make_env_dial("DEC", "ms", 4.0, 25000.0, 380.0, true, EuclidPalette.ACCENT_GOLD)
	_a_dec_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null and _patch.loudness_contour != null:
			_patch.loudness_contour.decay_ms = v
			_a_env_view.queue_redraw()
			_push_patch_update()
	)
	a_dials.add_child(_a_dec_dial)

	_a_sus_dial = _make_env_dial("SUS", "%", 0.0, 1.0, 0.78, false, EuclidPalette.ACCENT_GOLD)
	_a_sus_dial.value_changed.connect(func(v: float) -> void:
		if _patch != null and _patch.loudness_contour != null:
			_patch.loudness_contour.sustain_level = v
			_a_env_view.queue_redraw()
			_push_patch_update()
	)
	a_dials.add_child(_a_sus_dial)

	_a_rel_toggle = EuclidToggle.new()
	_a_rel_toggle.label = "DECAY REL"
	_a_rel_toggle.accent_color = EuclidPalette.ACCENT_GOLD
	_a_rel_toggle.custom_minimum_size = Vector2(0, 22)
	_a_rel_toggle.toggled.connect(func(on: bool) -> void:
		if _patch != null and _patch.loudness_contour != null:
			_patch.loudness_contour.release_on_decay = on
			_a_env_view.queue_redraw()
			_push_patch_update()
	)
	a_col.add_child(_a_rel_toggle)

	return panel


func _make_env_dial(lbl: String, unit_str: String, min_v: float, max_v: float, def_v: float, is_log: bool, col: Color) -> EuclidDial:
	var d := EuclidDial.new()
	d.label = lbl
	d.unit = unit_str
	d.min_value = min_v
	d.max_value = max_v
	d.default_value = def_v
	d.logarithmic = is_log
	d.accent_color = col
	d.custom_minimum_size = Vector2(64, 74)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d


func _build_scope_and_mod_panel() -> Control:
	var panel := _make_framed_panel("SCOPE & MODULATION MATRIX", Vector2(360, 250))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = panel.get_meta("content_box")

	_scope = EuclidScope.new()
	_scope.custom_minimum_size = Vector2(240, 96)
	_scope.bind_rig(_rig)
	box.add_child(_scope)

	var mod_hdr_row := HBoxContainer.new()
	box.add_child(mod_hdr_row)

	var mod_lbl := Label.new()
	mod_lbl.text = "MOD ROUTES"
	mod_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_lbl.add_theme_font_size_override("font_size", 9)
	mod_lbl.add_theme_color_override("font_color", EuclidPalette.TEXT_DIM)
	mod_hdr_row.add_child(mod_lbl)

	var add_route_btn := Button.new()
	add_route_btn.text = "+ ROUTE"
	add_route_btn.custom_minimum_size = Vector2(68, 20)
	add_route_btn.pressed.connect(_on_add_mod_route_pressed)
	mod_hdr_row.add_child(add_route_btn)

	var mod_scroll := ScrollContainer.new()
	mod_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mod_scroll.custom_minimum_size = Vector2(0, 86)
	box.add_child(mod_scroll)

	_mod_routes_container = VBoxContainer.new()
	_mod_routes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mod_routes_container.add_theme_constant_override("separation", 4)
	mod_scroll.add_child(_mod_routes_container)

	return panel


func _bind_patch_to_ui() -> void:
	if _patch == null:
		return

	_patch_name_edit.text = _patch.patch_name
	_voices_dial.set_value_silent(float(_patch.max_voices))
	_voices_dial.label = "MONO 1" if _patch.max_voices == 1 else "POLY %d" % _patch.max_voices
	_glide_dial.set_value_silent(_patch.glide_ms)
	_legato_toggle.set_active_silent(_patch.legato_retrigger)
	_master_dial.set_value_silent(_patch.master_volume)

	for child in _osc_container.get_children():
		child.queue_free()

	for i in range(_patch.oscillators.size()):
		var osc_cfg: OscConfig = _patch.oscillators[i]
		var card := OscCard.new()
		card.bind_osc(osc_cfg, i >= 3)
		card.config_modified.connect(_push_patch_update)
		card.remove_requested.connect(_on_remove_osc_requested)
		_osc_container.add_child(card)

	_add_osc_btn.disabled = (_patch.oscillators.size() >= SynthVoice.MAX_VOICE_OSCS)

	if _patch.noise != null:
		_noise_active_toggle.set_active_silent(_patch.noise.enabled)
		_noise_color_toggle.set_index_silent(int(_patch.noise.color))
		_noise_level_dial.set_value_silent(_patch.noise.level)

	if _patch.filter != null:
		_overload_dial.set_value_silent(_patch.filter.overload_drive)
		_cutoff_dial.set_value_silent(_patch.filter.cutoff_hz)
		_emphasis_dial.set_value_silent(_patch.filter.emphasis)
		_filter_contour_amt_dial.set_value_silent(_patch.filter.contour_amount)
		_kbd_track_toggle.set_index_silent(_patch.filter.kbd_tracking_idx)
		_scope.bind_filter(_patch.filter)

	if _patch.filter_contour != null:
		_f_env_view.bind_contour(_patch.filter_contour)
		_f_atk_dial.set_value_silent(_patch.filter_contour.attack_ms)
		_f_dec_dial.set_value_silent(_patch.filter_contour.decay_ms)
		_f_sus_dial.set_value_silent(_patch.filter_contour.sustain_level)
		_f_rel_toggle.set_active_silent(_patch.filter_contour.release_on_decay)

	if _patch.loudness_contour != null:
		_a_env_view.bind_contour(_patch.loudness_contour)
		_a_atk_dial.set_value_silent(_patch.loudness_contour.attack_ms)
		_a_dec_dial.set_value_silent(_patch.loudness_contour.decay_ms)
		_a_sus_dial.set_value_silent(_patch.loudness_contour.sustain_level)
		_a_rel_toggle.set_active_silent(_patch.loudness_contour.release_on_decay)

	_rebuild_mod_routes_ui()
	_push_patch_update()


func _rebuild_mod_routes_ui() -> void:
	for child in _mod_routes_container.get_children():
		child.queue_free()

	if _patch == null:
		return

	for route in _patch.mod_routes:
		if route == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_mod_routes_container.add_child(row)

		var en_tog := EuclidToggle.new()
		en_tog.label = "ON"
		en_tog.accent_color = EuclidPalette.ACCENT_CYAN
		en_tog.custom_minimum_size = Vector2(44, 24)
		en_tog.set_active_silent(route.enabled)
		en_tog.toggled.connect(func(on: bool) -> void:
			route.enabled = on
			_push_patch_update()
		)
		row.add_child(en_tog)

		var src_sel := EuclidToggle.new()
		src_sel.options = ModRoute.SOURCE_NAMES
		src_sel.accent_color = EuclidPalette.ACCENT_CYAN
		src_sel.custom_minimum_size = Vector2(82, 24)
		src_sel.set_index_silent(int(route.source))
		src_sel.option_selected.connect(func(idx: int) -> void:
			route.source = idx as ModRoute.ModSource
			_push_patch_update()
		)
		row.add_child(src_sel)

		var dst_sel := EuclidToggle.new()
		dst_sel.options = ModRoute.TARGET_NAMES
		dst_sel.accent_color = EuclidPalette.ACCENT_GOLD
		dst_sel.custom_minimum_size = Vector2(74, 24)
		dst_sel.set_index_silent(int(route.target))
		dst_sel.option_selected.connect(func(idx: int) -> void:
			route.target = idx as ModRoute.ModTarget
			_push_patch_update()
		)
		row.add_child(dst_sel)

		var amt_slider := HSlider.new()
		amt_slider.min_value = -1.0
		amt_slider.max_value = 1.0
		amt_slider.step = 0.01
		amt_slider.value = route.amount
		amt_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amt_slider.value_changed.connect(func(val: float) -> void:
			route.amount = val
			_push_patch_update()
		)
		row.add_child(amt_slider)

		var del_btn := Button.new()
		del_btn.text = "X"
		del_btn.custom_minimum_size = Vector2(22, 24)
		del_btn.pressed.connect(func() -> void:
			_patch.mod_routes.erase(route)
			_rebuild_mod_routes_ui()
			_push_patch_update()
		)
		row.add_child(del_btn)


func _on_add_osc_pressed() -> void:
	if _patch == null or _patch.oscillators.size() >= SynthVoice.MAX_VOICE_OSCS:
		return
	var next_num: int = _patch.oscillators.size() + 1
	var new_osc := OscConfig.new()
	new_osc.label = "OSC %d" % next_num
	new_osc.enabled = true
	new_osc.waveform = OscConfig.Waveform.SAWTOOTH
	new_osc.octave_range = OscConfig.OctaveRange.FT_8
	new_osc.detune_semitones = 0.05 * float(next_num - 3)
	new_osc.level = 0.50
	_patch.oscillators.append(new_osc)
	_bind_patch_to_ui()


func _on_remove_osc_requested(osc_cfg: OscConfig) -> void:
	if _patch == null or _patch.oscillators.size() <= 1:
		return
	_patch.oscillators.erase(osc_cfg)
	for i in range(_patch.oscillators.size()):
		_patch.oscillators[i].label = "OSC %d" % (i + 1)
	_bind_patch_to_ui()


func _on_add_mod_route_pressed() -> void:
	if _patch == null:
		return
	var route := ModRoute.new()
	route.enabled = true
	route.source = ModRoute.ModSource.OSC_3
	route.target = ModRoute.ModTarget.FILTER_CUTOFF
	route.amount = 0.25
	_patch.mod_routes.append(route)
	_rebuild_mod_routes_ui()
	_push_patch_update()


func _push_patch_update() -> void:
	if _rig != null:
		_rig.sync_patch_to_audio_thread()
		SynthBus.patch_parameter_updated.emit()


func _refresh_preset_list() -> void:
	_preset_dropdown.clear()
	_preset_paths.clear()

	for dir_path in [BUILTIN_PRESET_DIR, USER_PRESET_DIR]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".tres"):
				var full_path: String = dir_path.path_join(fname)
				_preset_paths.append(full_path)
				var tag: String = "[USER] " if dir_path == USER_PRESET_DIR else ""
				_preset_dropdown.add_item(tag + fname.get_basename())
			fname = dir.get_next()
		dir.list_dir_end()


func _on_preset_selected(index: int) -> void:
	if index < 0 or index >= _preset_paths.size():
		return
	var loaded := ResourceLoader.load(_preset_paths[index], "", ResourceLoader.CACHE_MODE_IGNORE) as SynthPatch
	if loaded != null:
		_patch = loaded.duplicate_snapshot()
		_rig.load_patch(_patch)
		_bind_patch_to_ui()


func _on_save_patch_pressed() -> void:
	if _patch == null:
		return
	var raw_name: String = _patch_name_edit.text.strip_edges()
	if raw_name.is_empty():
		raw_name = "custom_patch"
	_patch.patch_name = raw_name
	var safe_file: String = raw_name.to_lower().replace(" ", "_") + ".tres"
	var save_path: String = USER_PRESET_DIR.path_join(safe_file)
	var snap: SynthPatch = _patch.duplicate_snapshot()
	ResourceSaver.save(snap, save_path)
	_refresh_preset_list()


func _on_init_patch_pressed() -> void:
	_patch = SynthPatch.create_default_minimod()
	_rig.load_patch(_patch)
	_bind_patch_to_ui()


func _sync_qwerty_mode_from_visibility() -> void:
	if _piano_strip == null or _hex_table == null or _qwerty_mode_toggle == null:
		return
	if _hex_table.visible and not _piano_strip.visible:
		_qwerty_mode_toggle.selected_index = 0
	elif _piano_strip.visible and not _hex_table.visible:
		_qwerty_mode_toggle.selected_index = 1


func _update_midi_status() -> void:
	var devices: PackedStringArray = OS.get_connected_midi_inputs()
	if devices.is_empty():
		_midi_status_label.text = "MIDI: NONE (QWERTY + UI READY)"
	else:
		_midi_status_label.text = "MIDI: %s" % devices[0]
