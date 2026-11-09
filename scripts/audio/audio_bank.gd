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
		_: push_warning("AudioBank: unknown sound " + stream_name)
	_cache[stream_name] = s
	return s


static func names() -> PackedStringArray:
	return ["horn", "door", "whistle", "alarm", "jingle", "click", "bird", "engine", "wind", "rain", "crickets"]


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
