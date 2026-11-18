class_name SynthRig
extends Node

const SAMPLE_RATE: float = 48000.0
const INV_SAMPLE_RATE: float = 1.0 / 48000.0
const BUFFER_SECONDS: float = 0.05
const MAX_VOICES_POOL: int = 16
const SCOPE_BUFFER_SIZE: int = 512

@export var patch: SynthPatch
@export var target_bus_name: String = "Synth"

var _player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback

var _thread: Thread
var _mutex: Mutex
var _running: bool = false

# Shared state protected by _mutex
var _thread_patch: SynthPatch
var _pending_events: Array[Dictionary] = []
var _pitch_bend_semis: float = 0.0
var _scope_ring: PackedFloat32Array
var _scope_write_idx: int = 0

# Audio-thread owned state
var _voices: Array[SynthVoice] = []
var _voice_buf_scratch := PackedFloat32Array()
var _mix_buf_scratch := PackedFloat32Array()
var _chunk_scratch := PackedVector2Array()
var _scope_scratch := PackedFloat32Array()
var _mono_note_stack: Array[int] = []
var _mono_velocities: Dictionary = {}
var _round_robin_idx: int = 0
var _age_counter: int = 0


func _ready() -> void:
	if patch == null:
		patch = SynthPatch.create_default_minimod()

	_mutex = Mutex.new()
	_thread_patch = patch.duplicate_snapshot()
	_scope_ring = PackedFloat32Array()
	_scope_ring.resize(SCOPE_BUFFER_SIZE)
	_scope_ring.fill(0.0)

	for i in range(MAX_VOICES_POOL):
		_voices.append(SynthVoice.new(i))

	_setup_audio_player()
	_connect_bus_signals()

	_running = true
	_thread = Thread.new()
	_thread.start(_audio_thread_loop)


func _setup_audio_player() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SAMPLE_RATE
	_generator.buffer_length = BUFFER_SECONDS

	_player = AudioStreamPlayer.new()
	_player.stream = _generator

	if AudioServer.get_bus_index(target_bus_name) != -1:
		_player.bus = target_bus_name
	else:
		_player.bus = "Master"

	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _connect_bus_signals() -> void:
	SynthBus.note_on_triggered.connect(_on_note_on)
	SynthBus.note_off_triggered.connect(_on_note_off)
	SynthBus.all_notes_off_triggered.connect(_on_all_notes_off)
	SynthBus.pitch_bend_received.connect(_on_pitch_bend)


func sync_patch_to_audio_thread() -> void:
	if patch == null or _mutex == null:
		return
	var snap: SynthPatch = patch.duplicate_snapshot()
	_mutex.lock()
	_thread_patch = snap
	_mutex.unlock()


func load_patch(new_patch: SynthPatch) -> void:
	if new_patch == null:
		return
	patch = new_patch
	sync_patch_to_audio_thread()
	SynthBus.patch_changed.emit(patch)


func get_scope_samples() -> PackedFloat32Array:
	var copy := PackedFloat32Array()
	copy.resize(SCOPE_BUFFER_SIZE)
	_mutex.lock()
	var read_idx: int = _scope_write_idx
	for i in range(SCOPE_BUFFER_SIZE):
		copy[i] = _scope_ring[(read_idx + i) % SCOPE_BUFFER_SIZE]
	_mutex.unlock()
	return copy


func _on_note_on(midi_note: int, velocity: float) -> void:
	_mutex.lock()
	_pending_events.append({"type": "on", "note": midi_note, "vel": velocity})
	_mutex.unlock()


func _on_note_off(midi_note: int) -> void:
	_mutex.lock()
	_pending_events.append({"type": "off", "note": midi_note})
	_mutex.unlock()


func _on_all_notes_off() -> void:
	_mutex.lock()
	_pending_events.append({"type": "panic"})
	_mutex.unlock()


func _on_pitch_bend(semitones: float) -> void:
	_mutex.lock()
	_pitch_bend_semis = semitones
	_mutex.unlock()


func _audio_thread_loop() -> void:
	while _running:
		if _playback == null:
			OS.delay_msec(4)
			continue

		var frames_available: int = _playback.get_frames_available()
		if frames_available < 256:
			OS.delay_msec(1)
			continue

		_mutex.lock()
		var active_patch: SynthPatch = _thread_patch
		var events: Array[Dictionary] = _pending_events.duplicate()
		_pending_events.clear()
		var bend: float = _pitch_bend_semis
		_mutex.unlock()

		for ev in events:
			_process_midi_event_on_thread(ev, active_patch)

		if _chunk_scratch.size() != frames_available:
			_chunk_scratch.resize(frames_available)
			_scope_scratch.resize(frames_available)
			_voice_buf_scratch.resize(frames_available)
			_mix_buf_scratch.resize(frames_available)

		var voice_limit: int = clampi(active_patch.max_voices, 1, MAX_VOICES_POOL)
		var master_gain: float = active_patch.master_volume * (0.65 if voice_limit == 1 else 0.42)

		_mix_buf_scratch.fill(0.0)
		var any_active: bool = false

		for v_idx in range(voice_limit):
			var v: SynthVoice = _voices[v_idx]
			if v.active:
				any_active = true
				v.process_block(_voice_buf_scratch, frames_available, SAMPLE_RATE, INV_SAMPLE_RATE, active_patch, bend)
				for i in range(frames_available):
					_mix_buf_scratch[i] += _voice_buf_scratch[i]

		if not any_active:
			_chunk_scratch.fill(Vector2.ZERO)
			_scope_scratch.fill(0.0)
		else:
			for i in range(frames_available):
				var out_sample: float = clampf(_mix_buf_scratch[i] * master_gain, -1.5, 1.5)
				var s2: float = out_sample * out_sample
				out_sample = out_sample * (27.0 + s2) / (27.0 + 9.0 * s2)
				_chunk_scratch[i] = Vector2(out_sample, out_sample)
				_scope_scratch[i] = out_sample

		_playback.push_buffer(_chunk_scratch)

		_mutex.lock()
		for i in range(frames_available):
			_scope_ring[_scope_write_idx] = _scope_scratch[i]
			_scope_write_idx = (_scope_write_idx + 1) % SCOPE_BUFFER_SIZE
		_mutex.unlock()


func _process_midi_event_on_thread(ev: Dictionary, active_patch: SynthPatch) -> void:
	var ev_type: String = ev.get("type", "")
	var voice_limit: int = clampi(active_patch.max_voices, 1, MAX_VOICES_POOL)

	if ev_type == "panic":
		_mono_note_stack.clear()
		_mono_velocities.clear()
		for v in _voices:
			v.panic_kill()
		return

	var note: int = int(ev.get("note", 60))

	if voice_limit == 1:
		var primary_voice: SynthVoice = _voices[0]
		for k in range(1, MAX_VOICES_POOL):
			if _voices[k].active:
				_voices[k].panic_kill()

		if ev_type == "on":
			var vel: float = float(ev.get("vel", 0.85))
			var was_holding_note: bool = not _mono_note_stack.is_empty()
			_mono_note_stack.erase(note)
			_mono_note_stack.append(note)
			_mono_velocities[note] = vel
			_age_counter += 1
			var should_retrigger: bool = (not was_holding_note) or active_patch.legato_retrigger
			primary_voice.note_on(note, vel, _age_counter, was_holding_note, should_retrigger)
		elif ev_type == "off":
			_mono_note_stack.erase(note)
			_mono_velocities.erase(note)
			if _mono_note_stack.is_empty():
				primary_voice.note_off()
			else:
				var fallback_note: int = _mono_note_stack[_mono_note_stack.size() - 1]
				var fallback_vel: float = float(_mono_velocities.get(fallback_note, 0.85))
				_age_counter += 1
				primary_voice.note_on(fallback_note, fallback_vel, _age_counter, true, active_patch.legato_retrigger)
	else:
		if ev_type == "on":
			var vel: float = float(ev.get("vel", 0.85))
			_age_counter += 1

			for i in range(voice_limit):
				if _voices[i].active and _voices[i].midi_note == note:
					_voices[i].note_on(note, vel, _age_counter, false, true)
					return

			for offset in range(voice_limit):
				var idx: int = (_round_robin_idx + offset) % voice_limit
				if not _voices[idx].active:
					_round_robin_idx = (idx + 1) % voice_limit
					_voices[idx].note_on(note, vel, _age_counter, false, true)
					return

			var oldest_rel_idx: int = -1
			var oldest_rel_age: int = 2147483647
			for i in range(voice_limit):
				if not _voices[i].gate_on and _voices[i].age < oldest_rel_age:
					oldest_rel_age = _voices[i].age
					oldest_rel_idx = i
			if oldest_rel_idx != -1:
				_round_robin_idx = (oldest_rel_idx + 1) % voice_limit
				_voices[oldest_rel_idx].note_on(note, vel, _age_counter, false, true)
				return

			var oldest_idx: int = 0
			var oldest_age: int = _voices[0].age
			for i in range(1, voice_limit):
				if _voices[i].age < oldest_age:
					oldest_age = _voices[i].age
					oldest_idx = i
			_round_robin_idx = (oldest_idx + 1) % voice_limit
			_voices[oldest_idx].note_on(note, vel, _age_counter, false, true)

		elif ev_type == "off":
			for i in range(voice_limit):
				if _voices[i].active and _voices[i].gate_on and _voices[i].midi_note == note:
					_voices[i].note_off()


func _exit_tree() -> void:
	_running = false
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
