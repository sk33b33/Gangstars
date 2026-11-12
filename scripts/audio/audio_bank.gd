class_name AudioBank
extends RefCounted
## All game sounds, synthesized at runtime (no audio assets): 16-bit mono AudioStreamWAV.
## Streams are generated once and cached. Loops are built to wrap seamlessly.

const RATE := 22050

static var _cache: Dictionary = {}


static func get_stream(stream_name: String) -> AudioStreamWAV:
	if _cache.has(stream_name):
		return _cache[stream_name]
	var s: AudioStreamWAV
	match stream_name:
		"horn": s = _horn()
		"door": s = _door()
		"whistle": s = _whistle()
		"alarm": s = _alarm()
		"jingle": s = _jingle()
		"click": s = _click()
		"bird": s = _bird()
		"engine": s = _engine()
		"wind": s = _wind()
		"rain": s = _rain()
		"crickets": s = _crickets()
		"bark": s = _bark()
		"gunshot": s = _gunshot()
		"siren": s = _siren()
		"ring": s = _ring()
		"music_plain": s = _music("plain")
		"music_jazz": s = _music("jazz")
		"music_gospel": s = _music("gospel")
		"music_ghoema": s = _music("ghoema")
		"music_kasi": s = _music("kasi")
		"mumble0": s = _mumble(0)
		"mumble1": s = _mumble(1)
		"mumble2": s = _mumble(2)
		"mumble3": s = _mumble(3)
		"bell": s = _bell()
		"hooter": s = _hooter()
		_: push_warning("AudioBank: unknown sound " + stream_name)
	_cache[stream_name] = s
	return s


static func names() -> PackedStringArray:
	return ["horn", "door", "whistle", "alarm", "jingle", "click", "bird", "engine", "wind", "rain", "crickets", "bark", "gunshot", "siren", "ring",
		"bell", "hooter", "mumble0", "mumble1", "mumble2", "mumble3"]   # music_* are long: built on first play


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _env(t: float, length: float, attack := 0.01, release := 0.08) -> float:
	return clampf(t / attack, 0.0, 1.0) * clampf((length - t) / release, 0.0, 1.0)


## Two gruff barks: a voiced tone sliding down (620 -> 380 Hz) with rough harmonics and breath noise.
static func _bark() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var n := int(RATE * 0.62)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for start in [0.0, 0.3]:
			var bt: float = t - start
			if bt >= 0.0 and bt < 0.2:
				var f := lerpf(620.0, 380.0, bt / 0.2)
				phase += TAU * f / RATE
				var tone := tanh(sin(phase) * 2.5) * 0.7 + sin(phase * 2.0) * 0.2 + sin(phase * 3.0) * 0.1
				v += (tone + rng.randf_range(-0.35, 0.35)) * _env(bt, 0.2, 0.008, 0.09)
		out[i] = v * 0.4
	return _wav(out)


## A sharp crack: a noise burst with a fast decay and a low thump underneath.
static func _gunshot() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var n := int(RATE * 0.45)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35)
		var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 60.0)
		var body := lp * exp(-t * 9.0)
		var thump := sin(TAU * 70.0 * t) * exp(-t * 22.0)
		out[i] = clampf(crack * 0.9 + body * 0.6 + thump * 0.5, -1.0, 1.0) * 0.7
	return _wav(out)


## One cycle of a two-tone police siren (hi-lo), about 1.6 s.
static func _siren() -> AudioStreamWAV:
	var n := int(RATE * 1.6)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 960.0 if fmod(t, 0.8) < 0.4 else 720.0
		phase += TAU * f / RATE
		out[i] = (sin(phase) * 0.6 + sin(phase * 2.0) * 0.15) * 0.3 * _env(t, 1.6, 0.03, 0.1)
	return _wav(out)


## A cellphone ring: two short warbled tones.
static func _ring() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var on := fmod(t, 0.45) < 0.32
		var f: float = 1300.0 + 180.0 * signf(sin(TAU * 18.0 * t))
		out[i] = (sin(TAU * f * t) * 0.35 if on else 0.0) * _env(fmod(t, 0.45), 0.32, 0.01, 0.03)
	return _wav(out)


static func _horn() -> AudioStreamWAV:
	var n := int(RATE * 0.55)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := tanh(sin(TAU * 405.0 * t) * 3.0) + tanh(sin(TAU * 508.0 * t) * 3.0)
		out[i] = v * 0.22 * _env(t, 0.55, 0.02, 0.06)
	return _wav(out)


static func _door() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := int(RATE * 0.4)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var click := rng.randf_range(-1, 1) * maxf(0.0, 1.0 - t / 0.025) * 0.5
		phase += TAU * lerpf(320.0, 170.0, t / 0.4) / RATE
		var creak := sin(phase) * (0.5 + 0.5 * sin(TAU * 31.0 * t)) * 0.12 * _env(t, 0.4, 0.05, 0.1)
		out[i] = click + creak
	return _wav(out)


static func _whistle() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 1500.0 + 800.0 * sin(PI * clampf(t / 0.35, 0.0, 1.0)) if t < 0.4 else lerpf(1700.0, 1100.0, (t - 0.45) / 0.45)
		if t >= 0.38 and t < 0.45:
			f = 0.0
		phase += TAU * f / RATE
		out[i] = sin(phase) * 0.3 * (_env(t, 0.38, 0.02, 0.03) + (_env(t - 0.45, 0.45, 0.02, 0.1) if t >= 0.45 else 0.0))
	return _wav(out)


static func _alarm() -> AudioStreamWAV:
	var n := int(RATE * 2.4)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 800.0 if fmod(t, 0.5) < 0.25 else 1150.0
		phase += TAU * f / RATE
		out[i] = signf(sin(phase)) * 0.12 * _env(t, 2.4, 0.01, 0.1)
	return _wav(out)


static func _jingle() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var k := mini(int(t / 0.13), notes.size() - 1)
		var nt := t - k * 0.13
		var f: float = notes[k]
		out[i] = (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * 0.22 * exp(-nt * (6.0 if k < 3 else 2.5))
	return _wav(out)


static func _click() -> AudioStreamWAV:
	var n := int(RATE * 0.04)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * 1800.0 * t) * 0.25 * exp(-t * 120.0)
	return _wav(out)


static func _bird() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := fmod(t, 0.18)
		phase += TAU * lerpf(2600.0, 3900.0, k / 0.12) / RATE
		out[i] = sin(phase) * 0.18 * (1.0 if k < 0.12 else 0.0) * _env(k, 0.12, 0.01, 0.04)
	return _wav(out)


## 55.125 Hz engine: exactly 400 samples per cycle so the loop is seamless.
static func _engine() -> AudioStreamWAV:
	var period := 400
	var n := period * 28
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var p := float(i % period) / period
		var saw := 2.0 * p - 1.0
		out[i] = (saw * 0.35 + sin(TAU * p) * 0.4 + sin(TAU * p * 3.0) * 0.12) * 0.5
	return _wav(out, true)


## Noise loops are generated longer and cross-faded so the wrap point is inaudible.
static func _crossfade_loop(raw: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := raw.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for i in fade:
		var w := float(i) / fade
		out[i] = raw[i] * w + raw[n + i] * (1.0 - w)
	return out


static func _wind() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var n := int(RATE * 4.5)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var brown := 0.0
	for i in n:
		brown = brown * 0.995 + rng.randf_range(-1, 1) * 0.05
		var t := float(i) / RATE
		raw[i] = brown * (0.6 + 0.4 * sin(TAU * t / 4.5)) * 1.6
	return _wav(_crossfade_loop(raw, int(RATE * 0.5)), true)


static func _rain() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var n := int(RATE * 2.3)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var prev := 0.0
	for i in n:
		var w := rng.randf_range(-1, 1)
		var v := (w - prev) * 0.18
		prev = w
		if rng.randf() < 0.0015:
			v += rng.randf_range(0.3, 0.6)
		raw[i] = v
	return _wav(_crossfade_loop(raw, int(RATE * 0.3)), true)


static func _crickets() -> AudioStreamWAV:
	var n := int(RATE * 2.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var group := fmod(t, 0.5)
		var on := group < 0.12 and fmod(group, 0.03) < 0.018
		out[i] = sin(TAU * 4700.0 * t) * (0.08 if on else 0.0)
	return _wav(out, true)



# ------------------------------------------------------------------ music (made up, loops)

## A 4-bar loop for the radio and the smokkies:
##   plain  - a kwaito/house groove: four-on-the-floor kick, offbeat hats, a bass line, stabs
##   jazz   - Cape-jazz flavour: walking bass, soft brushes, mellow electric-piano chords
##   gospel - organ chords, claps on 2 and 4, a root bass
##   ghoema - a parade: the ghoema drum's 3+3+2 pattern, a bass, brass stabs, rim clicks
static func _music(style: String) -> AudioStreamWAV:
	var bpm: float = {"plain": 112.0, "jazz": 96.0, "gospel": 84.0, "ghoema": 104.0, "kasi": 112.0}[style]
	var beat: float = 60.0 / bpm
	var n := int(16 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var chords: Array = {"plain": [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]],
		"jazz": [[50, 53, 57, 60], [55, 59, 62, 65], [48, 52, 55, 59], [57, 61, 64, 67]],
		"gospel": [[48, 52, 55], [53, 57, 60], [55, 59, 62], [48, 52, 55]],
		"ghoema": [[57, 61, 64], [62, 66, 69], [64, 68, 71], [57, 61, 64]],
		"kasi": [[57, 60, 64], [55, 59, 62], [53, 57, 60], [55, 59, 62]]}[style]
	var rng := RandomNumberGenerator.new()
	rng.seed = style.hash()
	for bar in 4:
		var chord: Array = chords[bar]
		var t0: float = bar * 4 * beat
		for b in 4:
			var t: float = t0 + b * beat
			match style:
				"plain":
					_kick(out, t, 0.55)
					_hat(out, t + beat * 0.5, 0.12, rng)
					if b % 2 == 1:
						_clap(out, t, 0.25, rng)
					for e in 2:
						_note(out, t + e * beat * 0.5, beat * 0.45, _hz(int(chord[0]) - 24 + (7 if e == 1 and b == 3 else 0)), 0.32, "bass")
					_chord(out, t + beat * 0.5, beat * 0.25, chord, 0.09, "stab")
				"jazz":
					var swing: float = beat * 0.62
					_hat(out, t, 0.05, rng)
					_hat(out, t + swing, 0.04, rng)
					var walk: int = [0, 4, 7, 9][b]
					_note(out, t, beat * 0.9, _hz(int(chord[0]) - 12 + walk), 0.3, "bass")
					if b == 0 or b == 2:
						_chord(out, t + (0.0 if b == 0 else swing), beat * 1.4, chord, 0.07, "keys")
				"gospel":
					if b == 0:
						_chord(out, t, beat * 4.0, chord, 0.08, "organ")
						_note(out, t, beat * 3.8, _hz(int(chord[0]) - 12), 0.3, "bass")
					if b % 2 == 1:
						_clap(out, t, 0.3, rng)
				"kasi":   # a log-drum bass that slides down, shakers, a soft pad, a sparse bell tune
					for e in 2:
						var te: float = t + e * beat * 0.5
						_hat(out, te, 0.06 if e == 0 else 0.09, rng)
						if (b * 2 + e) in [0, 3, 6]:
							_logdrum(out, te, _hz(int(chord[0]) - 24), 0.5)
					if b == 0:
						_chord(out, t, beat * 4.0, chord, 0.05, "keys")
					if b == 2:
						_note(out, t + beat * 0.5, beat * 0.5, _hz(int(chord[2]) + 12), 0.1, "keys")
				"ghoema":
					for e in 2:
						var eighth := b * 2 + e   # 0..7 in the bar: the drum accents 0, 3 and 6
						var te: float = t + e * beat * 0.5
						if eighth in [0, 3, 6]:
							_kick(out, te, 0.6)
						if eighth in [2, 5, 7]:
							_clap(out, te, 0.12, rng)   # rim click
						_hat(out, te, 0.05, rng)
						if eighth in [0, 6]:
							_note(out, te, beat * 0.9, _hz(int(chord[0]) - 24), 0.3, "bass")
						if eighth in [0, 2, 3, 6]:   # brass stabs on the chord
							var tone: int = int(chord[[0, 1, 2, 1][eighth % 4]]) + (12 if eighth == 3 else 0)
							_note(out, te, beat * 0.4, _hz(tone), 0.17, "brass")
	for i in n:   # gentle limiter
		out[i] = tanh(out[i] * 1.2) * 0.8
	return _wav(_crossfade_loop(out, int(0.02 * RATE)), true)


static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


static func _note(out: PackedFloat32Array, t: float, length: float, f: float, amp: float, kind: String) -> void:
	var i0 := int(t * RATE)
	var count := int(length * RATE)
	for k in count:
		var i := i0 + k
		if i >= out.size():
			return
		var tt := float(k) / RATE
		var ph := TAU * f * tt
		var v := 0.0
		match kind:
			"bass":
				v = sin(ph) + 0.4 * sin(ph * 2.0) + 0.15 * sin(ph * 3.0)
				v *= exp(-tt * 3.0)
			"stab":
				v = (2.0 * absf(fmod(f * tt, 1.0) * 2.0 - 1.0) - 1.0) * exp(-tt * 9.0)
			"keys":
				v = (sin(ph) + 0.3 * sin(ph * 3.0)) * exp(-tt * 1.5) * (1.0 + 0.15 * sin(TAU * 5.0 * tt))
			"organ":
				v = (sin(ph) + 0.5 * sin(ph * 2.0) + 0.3 * sin(ph * 3.0) + 0.2 * sin(ph * 4.0)) * 0.6
			"brass":   # a bright, slightly buzzy horn
				v = (sin(ph) + 0.55 * sin(ph * 2.0) + 0.35 * sin(ph * 3.0) + 0.18 * sin(ph * 5.0)) * (1.0 + 0.04 * sin(TAU * 6.0 * tt)) * exp(-tt * 3.5)
		out[i] += v * amp * _env(tt, length, 0.008, 0.05)


static func _chord(out: PackedFloat32Array, t: float, length: float, chord: Array, amp: float, kind: String) -> void:
	for m in chord:
		_note(out, t, length, _hz(int(m)), amp, kind)


## The pitched, sliding drum at the heart of the kasi groove.
static func _logdrum(out: PackedFloat32Array, t: float, f: float, amp: float) -> void:
	var i0 := int(t * RATE)
	var ph := 0.0
	for k in int(0.35 * RATE):
		if i0 + k >= out.size():
			return
		var tt := float(k) / RATE
		ph += TAU * f * lerpf(1.7, 1.0, minf(tt / 0.06, 1.0)) / RATE
		out[i0 + k] += (sin(ph) + 0.3 * sin(ph * 2.0)) * exp(-tt * 7.0) * amp


static func _kick(out: PackedFloat32Array, t: float, amp: float) -> void:
	var i0 := int(t * RATE)
	var ph := 0.0
	for k in int(0.18 * RATE):
		if i0 + k >= out.size():
			return
		var tt := float(k) / RATE
		ph += TAU * lerpf(120.0, 48.0, minf(tt / 0.08, 1.0)) / RATE
		out[i0 + k] += sin(ph) * exp(-tt * 22.0) * amp


static func _hat(out: PackedFloat32Array, t: float, amp: float, rng: RandomNumberGenerator) -> void:
	var i0 := int(t * RATE)
	var prev := 0.0
	for k in int(0.05 * RATE):
		if i0 + k >= out.size():
			return
		var nz := rng.randf_range(-1.0, 1.0)
		out[i0 + k] += (nz - prev) * exp(-float(k) / RATE * 70.0) * amp
		prev = nz


static func _clap(out: PackedFloat32Array, t: float, amp: float, rng: RandomNumberGenerator) -> void:
	var i0 := int(t * RATE)
	for k in int(0.12 * RATE):
		if i0 + k >= out.size():
			return
		var tt := float(k) / RATE
		out[i0 + k] += rng.randf_range(-1.0, 1.0) * exp(-tt * 28.0) * amp * (1.0 if fmod(tt, 0.012) < 0.008 or tt > 0.03 else 0.3)


# ------------------------------------------------------------------ voices, bells, hooters

## Gibberish speech for greetings and chat (no real words): voiced syllables with simple
## formants and a breath of consonant. Pitch per person comes from the player.
static func _mumble(variant: int) -> AudioStreamWAV:
	var vowels := [[730.0, 1090.0], [530.0, 1840.0], [570.0, 840.0], [300.0, 2200.0], [440.0, 1020.0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + variant
	var syll := 3 + variant % 3
	var length := syll * 0.13 + 0.05
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	for sy in syll:
		var v: Array = vowels[(variant * 3 + sy * 2) % vowels.size()]
		var f0: float = 150.0 * (1.0 + 0.12 * sin(sy * 1.7 + variant))
		var i0 := int((0.02 + sy * 0.13) * RATE)
		var count := int(0.11 * RATE)
		for k in count:
			var tt := float(k) / RATE
			var x := 0.0
			for h in range(1, 14):
				var hf := f0 * h
				var g := exp(-pow((hf - float(v[0])) / 140.0, 2.0)) + 0.6 * exp(-pow((hf - float(v[1])) / 240.0, 2.0)) + 0.05
				x += sin(TAU * hf * tt) * g / h
			if tt < 0.018:
				x = x * 0.3 + rng.randf_range(-0.4, 0.4) * (1.0 - tt / 0.018)
			out[i0 + k] += x * 0.5 * _env(tt, 0.11, 0.012, 0.03)
	return _wav(out)


## A church bell: inharmonic partials ringing down.
static func _bell() -> AudioStreamWAV:
	var length := 3.5
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	var partials := [[1.0, 0.6, 1.0], [2.0, 0.3, 1.6], [2.4, 0.25, 2.2], [3.0, 0.2, 2.6], [4.2, 0.12, 3.5], [0.5, 0.25, 0.8]]
	for i in out.size():
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * 392.0 * float(p[0]) * t) * float(p[1]) * exp(-t * float(p[2]))
		out[i] = v * minf(t / 0.004, 1.0) * 0.7
	return _wav(out)


## A minibus taxi's double toot.
static func _hooter() -> AudioStreamWAV:
	var length := 0.42
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	for i in out.size():
		var t := float(i) / RATE
		var on := t < 0.13 or (t > 0.2 and t < 0.38)
		if on:
			var tt := t if t < 0.13 else t - 0.2
			var v := signf(sin(TAU * 520.0 * t)) * 0.35 + sin(TAU * 650.0 * t) * 0.3
			out[i] = v * _env(tt, 0.13 if t < 0.13 else 0.18, 0.006, 0.02)
	return _wav(out)
