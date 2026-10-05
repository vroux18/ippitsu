extends Node
## Sons synthétisés au démarrage (pas de fichiers audio pour le prototype).

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["slash"] = _slash(0.22, 2600.0)
	_streams["kill"] = _slash(0.32, 1700.0)
	_streams["whoosh"] = _whoosh()
	_streams["hurt"] = _hurt()
	_streams["strike"] = _thud()
	_streams["shot"] = _blip()
	_streams["empty"] = _click()


func play(id: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(id):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## « Shing » : bruit très bref et aigu + sifflement métallique qui descend.
func _slash(dur: float, f0: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var ph2 := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 18.0)
		var noise := randf_range(-1.0, 1.0)
		var hp := noise - prev
		prev = noise
		var f := f0 * (1.0 - 0.45 * t / dur)
		ph += TAU * f / RATE
		ph2 += TAU * f * 1.51 / RATE
		var ring := (sin(ph) * 0.5 + sin(ph2) * 0.3) * exp(-t * 9.0)
		var attack := minf(1.0, t * 900.0)
		s[i] = attack * (hp * 0.55 * env + ring * 0.5)
	return _wav(s)


func _whoosh() -> AudioStreamWAV:
	var dur := 0.3
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var env := sin(PI * k) * (1.0 - k * 0.4)
		var a := 0.05 + 0.25 * sin(PI * k)
		lp += a * (randf_range(-1.0, 1.0) - lp)
		s[i] = lp * env * 1.6
	return _wav(s)


func _hurt() -> AudioStreamWAV:
	var dur := 0.35
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(260.0, 70.0, t / dur)
		ph += TAU * f / RATE
		var sq := 1.0 if sin(ph) > 0.0 else -1.0
		s[i] = (sq * 0.35 + randf_range(-0.3, 0.3) * exp(-t * 20.0)) * exp(-t * 7.0)
	return _wav(s)


func _thud() -> AudioStreamWAV:
	var dur := 0.25
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * lerpf(120.0, 45.0, t / dur) / RATE
		s[i] = (sin(ph) * 0.9 + randf_range(-0.4, 0.4) * exp(-t * 40.0)) * exp(-t * 12.0)
	return _wav(s)


func _blip() -> AudioStreamWAV:
	var dur := 0.18
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * lerpf(500.0, 900.0, t / dur) / RATE
		s[i] = sin(ph) * 0.35 * exp(-t * 14.0)
	return _wav(s)


func _click() -> AudioStreamWAV:
	var n := int(0.05 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = randf_range(-1.0, 1.0) * 0.3 * exp(-t * 90.0)
	return _wav(s)
