\# Master Build Prompt \& Architecture Specification: `sleepsynth` (`minimod` Core)



\*\*Target Root Directory:\*\* `C:\\Users\\Iamch\\OneDrive\\Documents\\sleepsynth`

\*\*Engine Target:\*\* Godot 4.x (100% procedural GDScript \& `\_draw()` geometry, zero external assets, 100% offline-first)

\*\*Deployment Method:\*\* Multi-step PowerShell scripts (`Set-Location "C:\\Users\\Iamch\\OneDrive\\Documents\\sleepsynth"`, UTF-8 no-BOM file generation, strict tab indentation).



\---



\## 1. Directory \& File Structure



```text

C:\\Users\\Iamch\\OneDrive\\Documents\\sleepsynth\\

├── project.godot

├── autoload/

│   ├── synth\_bus.gd                # Global signal bus (MIDI, note\_on/off, CC, patch hot-swap)

│   └── midi\_router.gd              # OS.open\_midi\_inputs() + InputEventMIDI + QWERTY parser

├── synth\_core/

│   ├── resources/

│   │   ├── osc\_config.gd           # Resource: waveform, octave\_range, detune, level, enabled, mod\_source

│   │   ├── noise\_config.gd         # Resource: noise\_color (White/Pink/Brown), level, enabled

│   │   ├── filter\_config.gd        # Resource: cutoff\_hz, emphasis, contour\_amt, kbd\_track, drive

│   │   ├── contour\_config.gd       # Resource: attack\_ms, decay\_ms, sustain\_lvl, release\_on\_decay

│   │   ├── mod\_route.gd            # Resource: source\_id, target\_param, amount, curve\_power

│   │   └── synth\_patch.gd          # Resource: master\_vol, max\_voices (1-16), glide\_ms, Array\[osc\_config], etc.

│   ├── dsp/

│   │   ├── polyblep\_osc.gd         # Stateful oscillator math + PolyBLEP anti-aliasing

│   │   ├── noise\_generator.gd      # Seeded White, Paul Kellet Pink (-3dB/oct), and Brown (-6dB/oct)

│   │   ├── moog\_ladder\_filter.gd   # 4-pole 24dB/oct non-linear resonant low-pass filter

│   │   ├── ads\_envelope.gd         # Minimoog ADS contour math with legato retrigger option

│   │   ├── synth\_voice.gd          # Single voice state combining dynamic Osc array + Filter + 2 Contours

│   │   └── synth\_rig.gd            # AudioStreamPlayer + AudioStreamGenerator + dedicated Thread \& Mutex

│   └── presets/

│       ├── init\_minimod.tres       # Default 3-Osc Model D configuration

│       ├── sub\_808\_foundation.tres # Sine/Triangle + pitch-drop contour starter

│       └── sleep\_brown\_drift.tres  # Brown noise + dual slow sub-audio LFO drone

├── euclid\_ui/

│   ├── theme/

│   │   └── euclid\_palette.gd       # Static color \& 1px line-weight constants

│   ├── widgets/

│   │   ├── euclid\_dial.gd          # Compass-style rotary knob with hover/drag \& modulation arc

│   │   ├── euclid\_toggle.gd        # Geometric state switch (Idle / Hover / Active)

│   │   ├── euclid\_envelope\_view.gd # Book I style A-B-C-D vertex graph for Filter \& VCA Contours

│   │   ├── euclid\_scope.gd         # Real-time 60fps ring-buffer oscilloscope \& filter curve display

│   │   └── osc\_card.gd             # Modular UI strip bound to a single OscConfig resource

│   └── keyboards/

│       ├── piano\_strip.gd          # Hideable 2.5-octave linear keyboard (Idle / Hover / Pressed states)

│       └── hex\_harmonic\_table.gd   # Hideable axial Tonnetz/Harmonic Table hex lattice (Idle / Hover / Pressed)

├── instruments/

│   ├── minimod/

│   │   ├── minimod\_main.gd         # Master rack controller, preset loader/saver, "+ Add Osc" modular spawner

│   │   └── minimod\_main.tscn       # Main runnable scene

│   ├── tr808/                      # Placeholder folder for Phase 2 808 Drum Machine scene

│   └── sleep\_synth/                # Placeholder folder for Phase 3 Offline Sleep Scheduler \& Bulb HTTP Bridge



```



\---



\## 2. Audio \& DSP Specifications (`synth\_core`)



\* \*\*Sample Rate \& Threading:\*\*

\* `mix\_rate = 48000` Hz (`48 kHz`), `buffer\_length = 0.02` seconds (`960` stereo frames).

\* Dedicated `Thread` runs the DSP loop continuously; `Mutex` locks only at the top of each buffer block to copy parameter changes from `SynthPatch`, ensuring UI interaction or frame stalls never crackle the audio.





\* \*\*Voicing \& Allocation (`1` to `16` Voices):\*\*

\* Controlled via live UI slider/spinbox (`max\_voices`: `1` to `16`).

\* \*\*`max\_voices == 1` (Original Model D Mono):\*\* Last-note priority stack, single-trigger legato envelope option, and exponential pitch \*\*Glide (Portamento)\*\* (`0 ms` to `2000 ms`).

\* \*\*`max\_voices > 1` (Polyphonic Mode):\*\* Round-robin voice allocation across up to 16 pre-allocated `SynthVoice` instances with oldest-voice stealing when all voices are active.





\* \*\*Modular Oscillator Array (`Array\[OscConfig]`):\*\*

\* Defaults to \*\*3 Oscillators\*\* on boot, with a \*\*"+ Add Oscillator"\*\* button in the UI that appends additional `OscConfig` resources dynamically.

\* \*\*6 Octave Footage Settings:\*\* `LO` (sub-audio LFO `0.05 Hz – 20 Hz`), `32'`, `16'`, `8'`, `4'`, `2'`.

\* \*\*6 Classic Waveforms:\*\* Triangle, Triangle-Saw (Sharktooth), Sawtooth (PolyBLEP), Square (PolyBLEP), Wide Pulse (25%), Narrow Pulse (12%).

\* \*\*Oscillator 3 Dual Role:\*\* Can be routed as an audio voice in the mixer, or toggled as a modulation source driving Pitch or Filter Cutoff.





\* \*\*Noise \& Feedback Mixer:\*\*

\* Seeded \*\*White\*\*, \*\*Pink\*\*, and \*\*Brown\*\* noise generator.

\* \*\*Feedback / Overload Drive:\*\* Simulates looping the Model D main output back into the external input for warm low-end saturation before the filter.





\* \*\*Filter \& Contours:\*\*

\* \*\*Filter:\*\* 24dB/octave 4-pole Moog ladder low-pass filter with `cutoff\_hz` (`20 Hz – 18,000 Hz`), `emphasis` (resonance `0.0 – 3.95` with self-oscillation ceiling), `contour\_amount` (`-1.0` to `+1.0`), and keyboard tracking (`0%`, `33%`, `66%`, `100%`).

\* \*\*Contours (x2):\*\* Filter Contour and Loudness (VCA) Contour, each with `Attack` (`1 ms – 10,000 ms`), `Decay` (`4 ms – 25,000 ms`), `Sustain` (`0.0 – 1.0`), and a `Release Switch` (toggles between instant release and Decay-time release).







\---



\## 3. Input, Keyboards \& MIDI Architecture



\* \*\*Unified Event Flow:\*\* Mouse clicks, QWERTY presses, and hardware USB MIDI events all route through `SynthBus.note\_on(midi\_note: int, velocity: float)` and `SynthBus.note\_off(midi\_note: int)`. Active notes are tracked in a global bitmask/dictionary so both on-screen keyboards highlight keys in real time regardless of which input triggered the note.

\* \*\*QWERTY 2-Row Chromatic Mapping:\*\*

\* \*\*Lower Octave (C3–E4):\*\* `Z` (C), `S` (C#), `X` (D), `D` (D#), `C` (E), `V` (F), `G` (F#), `B` (G), `H` (G#), `N` (A), `J` (A#), `M` (B), `,` (C4).

\* \*\*Upper Octave (C4–E5):\*\* `Q` (C), `2` (C#), `W` (D), `3` (D#), `E` (E), `R` (F), `5` (F#), `T` (G), `6` (G#), `Y` (A), `7` (A#), `U` (B), `I` (C5).

\* Octave transpose hotkeys: `-` and `=` shift base octave.





\* \*\*Dual Hideable On-Screen Controllers:\*\*

\* Top-bar toggle switches (`\[Show/Hide Piano]`, `\[Show/Hide Hex Lattice]`) allow showing both, either one, or hiding both for a compact rack view.

\* \*\*Harmonic Table (Hexagonal Grid):\*\* Axial hexagon layout where moving \*\*Up (`0, -1`) = +7 semitones (Perfect 5th)\*\*, \*\*Up-Right (`+1, -1`) = +4 semitones (Major 3rd)\*\*, and \*\*Down-Right (`+1, 0`) = -3/+3 semitones (Minor 3rd)\*\*.

\* \*\*3 Visual States per Key/Hex:\*\*

1\. \*\*Idle:\*\* Obsidian fill (`#15171C`) with 1px hairline border (`#2D323E`) and note/interval label.

2\. \*\*Hover:\*\* Elevated slate fill (`#222630`) with highlighted perimeter (`#7A8294`).

3\. \*\*Pressed / Active:\*\* Chalk-gold vector fill/outline (`#C9A96E`) with internal geometric crosshairs.











\---



\## 4. Visual Style: Dark-Mode Euclid's \*Elements\*



\* \*\*Color Tokens (`euclid\_palette.gd`):\*\*

\* `BG\_VOID`: `#0D0E11` (Main background)

\* `BG\_PANEL`: `#15171C` (Module cards)

\* `BG\_HOVER`: `#222630` (Interactive hover state)

\* `LINE\_DIM`: `#2D323E` (1px structural hairlines \& construction circles)

\* `LINE\_MAIN`: `#D8DCE6` (Primary vector geometry, dial needles, active waveforms)

\* `ACCENT\_GOLD`: `#C9A96E` (Active notes, filter cutoff vector, pressed state)

\* `ACCENT\_CYAN`: `#7FB3D5` (Modulation arcs \& LFO phase indicators)







\---



\## 5. Multi-Step PowerShell Execution Plan



1\. \*\*Step 1 — Scaffold \& Core Bus:\*\* Create `C:\\Users\\Iamch\\OneDrive\\Documents\\sleepsynth` directory structure, `project.godot` (configured for `48000 Hz`, dark window, autoloads), `euclid\_palette.gd`, `synth\_bus.gd`, and `midi\_router.gd`.

2\. \*\*Step 2 — Modular Resources \& DSP Math:\*\* Generate all `Resource` scripts (`osc\_config.gd`, `filter\_config.gd`, `contour\_config.gd`, `synth\_patch.gd`) and the pure math classes (`polyblep\_osc.gd`, `noise\_generator.gd`, `moog\_ladder\_filter.gd`, `ads\_envelope.gd`).

3\. \*\*Step 3 — Threaded Synth Engine:\*\* Generate `synth\_voice.gd` and `synth\_rig.gd` (background `Thread`, `Mutex`, `1–16` round-robin / mono glide voice allocator, and oscilloscope ring buffer).

4\. \*\*Step 4 — Euclid Vector UI Widgets:\*\* Generate `euclid\_dial.gd`, `euclid\_toggle.gd`, `euclid\_envelope\_view.gd`, `euclid\_scope.gd`, and the modular `osc\_card.gd`.

5\. \*\*Step 5 — Hideable Piano \& Hexagonal Harmonic Table:\*\* Generate `piano\_strip.gd` and `hex\_harmonic\_table.gd` with full mouse drag, QWERTY, MIDI highlight sync, and Idle/Hover/Pressed states.

6\. \*\*Step 6 — Master `minimod` Scene \& Presets:\*\* Generate `minimod\_main.gd`, `minimod\_main.tscn`, and default `.tres` patches so you can open Godot and play immediately.



Say the word and I will drop \*\*Step 1 (PowerShell Scaffold, `project.godot`, Autoloads, and MIDI/QWERTY Router)\*\*.

