extends Node
## Musique d'ambiance procédurale (aucun fichier audio) : une boucle par monde + menu.
## Chaque boucle est composée de façon déterministe (graine fixe), puis synthétisée
## par petits morceaux dans _process (budget de temps par frame, adapté au web),
## mise en cache, et jouée en fondu enchaîné sur 2 AudioStreamPlayer.

const RATE := 22050
const MENU_ID := 0
const NONE_ID := -1
const FADE_TIME := 1.0
const BUDGET_USEC := 4000
const INV_RS := 1.0 / 1073741824.0
const KNEE := 0.7

# Gammes pentatoniques japonaises (demi-tons)
const YO := [0, 2, 5, 7, 9]
const IN_SC := [0, 1, 5, 7, 8]
const HIRA := [0, 2, 3, 7, 8]

# Cloche bonshō (partiels inharmoniques, doublet battant)
const BELL_R := [0.5, 1.0, 1.007, 1.52, 2.0, 2.74]
const BELL_A := [0.5, 0.8, 0.6, 0.35, 0.3, 0.15]
const BELL_D := [0.35, 0.5, 0.5, 0.9, 1.2, 2.0]
# Clochettes suzu et enclume
const SUZU_R := [1.0, 2.32, 4.1]
const SUZU_A := [1.0, 0.6, 0.35]
const SUZU_D := [9.0, 12.0, 16.0]
const ANVIL_R := [1.0, 2.76, 5.4]
const ANVIL_A := [1.0, 0.5, 0.3]
const ANVIL_D := [7.0, 10.0, 14.0]
# Force relative des 4 vagues du ressac
const SURF_STR := [1.0, 0.7, 0.9, 0.75]

enum { K_KOTO, K_SHAMI, K_SHAKU, K_TAIKO, K_SUZU, K_ANVIL }
enum { BED_NONE, BED_SURF, BED_WIND, BED_DRONE }
enum { PH_BED, PH_EVENTS, PH_PEAK, PH_ENCODE }

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _tween: Tween = null
var _fade_old: AudioStreamPlayer = null
var _fade_new: AudioStreamPlayer = null
var _fade_old_lin := 1.0

## Volume de la musique (dB), appliqué aux lecteurs actifs.
var volume_db := -10.0:
	set(value):
		volume_db = value
		if _players.size() == 2 and (_tween == null or not _tween.is_running()):
			_players[_active].volume_db = value

var _cache := {}
var _queue: Array[int] = []
var _wanted := NONE_ID
var _playing_id := NONE_ID

# --- état de la génération en cours ---
var _job := NONE_ID
var _phase := PH_BED
var _gen_buf := PackedFloat32Array()
var _gen_bytes := PackedByteArray()
var _gen_n := 0
var _gen_spb := 1.0
var _gen_pos := 0
var _gen_events: Array = []
var _gen_delay := 0
var _gen_fb := 0.0
var _gen_taps := 0
var _gen_peak := 0.0
var _gen_gain := 1.0
var _notes := {}
var _evs: Array = []
var _rs := 12345

# --- fond continu (ressac / vent / bourdon / cloche) ---
var _bed_type := BED_NONE
var _bed_amp := 0.0
var _lp1 := 0.0
var _lp2 := 0.0
var _dk := 0.0
var _dy1 := 0.0
var _dy2 := 0.0
var _b_k := PackedFloat64Array()
var _b_w := PackedFloat64Array()
var _b_y1 := PackedFloat64Array()
var _b_y2 := PackedFloat64Array()
var _b_a := PackedFloat64Array()
var _b_g := PackedFloat64Array()
var _b_strikes := PackedInt32Array()
var _b_level := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var has_bus := AudioServer.get_bus_index("Music") >= 0
	for i in 2:
		var p := AudioStreamPlayer.new()
		if has_bus:
			p.bus = "Music"
		add_child(p)
		_players.append(p)
	# La boucle du menu est préparée d'office (c'est la première entendue).
	prepare(MENU_ID)


# ===================== API publique =====================

## Fondu enchaîné vers la boucle du monde id (1..5), générée si besoin.
func play_world(id: int) -> void:
	_request(clampi(id, 1, 5))


## Boucle calme du menu (koto lent).
func play_menu() -> void:
	_request(MENU_ID)


## Fondu de sortie puis silence.
func stop() -> void:
	_wanted = NONE_ID
	_playing_id = NONE_ID
	var cur := _players[_active]
	if not cur.playing:
		return
	var lin := clampf(db_to_linear(cur.volume_db - volume_db), 0.0, 1.0)
	_start_fade(cur, lin, null)


## Pré-génère une boucle en arrière-plan sans la jouer (0 = menu, 1..5 = mondes).
func prepare(id: int) -> void:
	if _cache.has(id) or _job == id or _queue.has(id):
		return
	_queue.push_back(id)


func is_ready(id: int) -> bool:
	return _cache.has(id)


# ===================== lecture / fondus =====================

func _request(id: int) -> void:
	_wanted = id
	if id == _playing_id and _players[_active].playing:
		return
	if _cache.has(id):
		_crossfade_to(id)
		return
	# Priorité à la boucle demandée (la musique en cours continue en attendant).
	if _job != id:
		_queue.erase(id)
		_queue.push_front(id)


func _crossfade_to(id: int) -> void:
	var stream: AudioStreamWAV = _cache[id]
	var old := _players[_active]
	var old_lin := 0.0
	if old.playing:
		old_lin = clampf(db_to_linear(old.volume_db - volume_db), 0.0, 1.0)
	_active = 1 - _active
	var nw := _players[_active]
	nw.stop()
	nw.stream = stream
	nw.volume_db = -80.0
	nw.play()
	_playing_id = id
	_start_fade(old, old_lin, nw)


func _start_fade(old: AudioStreamPlayer, old_lin: float, nw: AudioStreamPlayer) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# Un lecteur encore en fondu de sortie et non réutilisé est coupé.
	if _fade_old != null and _fade_old != old and _fade_old != nw:
		_fade_old.stop()
	_fade_old = old
	_fade_old_lin = old_lin
	_fade_new = nw
	_tween = create_tween()
	_tween.tween_method(_on_fade, 0.0, 1.0, FADE_TIME)
	_tween.tween_callback(_on_fade_done)


# Fondu à puissance constante (sin / cos).
func _on_fade(k: float) -> void:
	if _fade_new != null:
		_fade_new.volume_db = volume_db + linear_to_db(maxf(sin(k * PI * 0.5), 0.0001))
	if _fade_old != null:
		_fade_old.volume_db = volume_db + linear_to_db(maxf(cos(k * PI * 0.5) * _fade_old_lin, 0.0001))


func _on_fade_done() -> void:
	if _fade_old != null:
		_fade_old.stop()
	if _fade_new != null:
		_fade_new.volume_db = volume_db
	_fade_old = null
	_fade_new = null


# ===================== génération étalée =====================

func _process(_delta: float) -> void:
	if _job == NONE_ID:
		if _queue.is_empty():
			return
		var next_id: int = _queue.pop_front()
		_start_job(next_id)
	# Budget plus large tant qu'aucune musique ne joue.
	var budget := BUDGET_USEC
	if not _players[_active].playing:
		budget = BUDGET_USEC * 2
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < budget:
		if _step():
			_finish_job()
			return


func _start_job(id: int) -> void:
	_job = id
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + id * 7919
	_evs = []
	var c: Dictionary
	match id:
		1:
			c = _w1(rng)
		2:
			c = _w2(rng)
		3:
			c = _w3(rng)
		4:
			c = _w4(rng)
		5:
			c = _w5(rng)
		_:
			c = _menu(rng)
	var bpm: float = c["bpm"]
	var beats: float = c["beats"]
	_gen_spb = RATE * 60.0 / bpm
	_gen_n = int(roundf(beats * _gen_spb))
	_gen_buf = PackedFloat32Array()
	_gen_buf.resize(_gen_n)
	_gen_buf.fill(0.0)
	_gen_events = _evs
	_evs = []
	var echo_beats: float = c.get("echo", 0.0)
	_gen_delay = int(echo_beats * _gen_spb)
	_gen_fb = c.get("fb", 0.0)
	_gen_taps = c.get("taps", 0)
	_gen_pos = 0
	_gen_peak = 0.0
	_phase = PH_BED
	_notes.clear()
	_rs = 12345 + id * 977
	# Fond continu
	_bed_type = c.get("bed", BED_NONE)
	_bed_amp = c.get("bed_amp", 0.0)
	_lp1 = 0.0
	_lp2 = 0.0
	# Bourdon : nombre entier de cycles sur la boucle (raccord sans clic)
	var cycles := maxf(1.0, roundf(146.83 * _gen_n / RATE))
	var dw := TAU * cycles / _gen_n
	_dk = 2.0 * cos(dw)
	_dy1 = 0.0
	_dy2 = -sin(dw)
	# Cloche bonshō éventuelle
	_b_k = PackedFloat64Array()
	_b_w = PackedFloat64Array()
	_b_y1 = PackedFloat64Array()
	_b_y2 = PackedFloat64Array()
	_b_a = PackedFloat64Array()
	_b_g = PackedFloat64Array()
	_b_strikes = PackedInt32Array()
	_b_level = 0.0
	if c.has("bell_f"):
		var bf: float = c["bell_f"]
		for p in BELL_R.size():
			var wb: float = TAU * bf * float(BELL_R[p]) / RATE
			_b_w.append(wb)
			_b_k.append(2.0 * cos(wb))
			_b_y1.append(0.0)
			_b_y2.append(-sin(wb))
			_b_a.append(0.0)
			_b_g.append(exp(-float(BELL_D[p]) / RATE))
		var strikes: Array = c["bell_beats"]
		for bt in strikes:
			_b_strikes.append(int(float(bt) * _gen_spb))
		_b_level = c["bell_amp"]


# Une petite tranche de travail ; renvoie true quand la boucle est prête.
func _step() -> bool:
	match _phase:
		PH_BED:
			var b := mini(_gen_pos + 2048, _gen_n)
			_bed_chunk(_gen_pos, b)
			_gen_pos = b
			if b >= _gen_n:
				_phase = PH_EVENTS
				_gen_pos = 0
		PH_EVENTS:
			if _gen_pos < _gen_events.size():
				_place(_gen_events[_gen_pos])
				_gen_pos += 1
			else:
				_phase = PH_PEAK
				_gen_pos = 0
		PH_PEAK:
			var b := mini(_gen_pos + 8192, _gen_n)
			var pk := _gen_peak
			for i in range(_gen_pos, b):
				var v: float = absf(_gen_buf[i])
				if v > pk:
					pk = v
			_gen_peak = pk
			_gen_pos = b
			if b >= _gen_n:
				# Normalisation : les crêtes rares dépassent le genou et sont adoucies.
				_gen_gain = 1.1 / maxf(_gen_peak, 0.001)
				_gen_bytes = PackedByteArray()
				_gen_bytes.resize(_gen_n * 2)
				_phase = PH_ENCODE
				_gen_pos = 0
		PH_ENCODE:
			var b := mini(_gen_pos + 4096, _gen_n)
			var g := _gen_gain
			for i in range(_gen_pos, b):
				var x: float = _gen_buf[i] * g
				var ax := absf(x)
				if ax > KNEE:
					# Limiteur doux (tanh au-dessus du genou)
					var y := KNEE + (1.0 - KNEE) * tanh((ax - KNEE) / (1.0 - KNEE))
					x = y if x > 0.0 else -y
				_gen_bytes.encode_s16(i * 2, int(x * 29000.0))
			_gen_pos = b
			if b >= _gen_n:
				return true
	return false


func _finish_job() -> void:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = _gen_bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = _gen_n
	var id := _job
	_cache[id] = w
	_job = NONE_ID
	_gen_buf = PackedFloat32Array()
	_gen_bytes = PackedByteArray()
	_gen_events = []
	_notes.clear()
	if _wanted == id:
		_crossfade_to(id)


# ===================== mixage =====================

func _place(ev: Array) -> void:
	var kind: int = ev[0]
	var beat: float = ev[1]
	var freq: float = ev[2]
	var dur: float = ev[3]
	var amp: float = ev[4]
	var note := _get_note(kind, freq, dur)
	var st := int(roundf(beat * _gen_spb))
	_mix(note, st, amp)
	# Échos (sauf percussions) : donnent l'espace, bouclent naturellement.
	if _gen_fb > 0.0 and kind != K_TAIKO and kind != K_ANVIL:
		var g := amp
		for _t in _gen_taps:
			g *= _gen_fb
			st += _gen_delay
			_mix(note, st, g)


# Additionne une note dans le buffer, avec bouclage en fin de boucle.
func _mix(note: PackedFloat32Array, start: int, gain: float) -> void:
	var n := _gen_n
	var m := mini(note.size(), n)
	var st := posmod(start, n)
	var first := mini(m, n - st)
	for j in first:
		_gen_buf[st + j] += note[j] * gain
	for j in range(first, m):
		_gen_buf[j - first] += note[j] * gain


func _get_note(kind: int, freq: float, dur: float) -> PackedFloat32Array:
	var key: String = "%d_%d_%d" % [kind, int(freq * 16.0), int(dur * 1000.0)]
	if _notes.has(key):
		return _notes[key]
	var s := PackedFloat32Array()
	match kind:
		K_KOTO:
			s = _pluck(freq, dur, false)
		K_SHAMI:
			s = _pluck(freq, dur, true)
		K_SHAKU:
			s = _shaku(freq, dur)
		K_TAIKO:
			s = _taiko(freq, dur)
		K_SUZU:
			s = _bell_note(freq, dur, SUZU_R, SUZU_A, SUZU_D)
		K_ANVIL:
			s = _bell_note(freq, dur, ANVIL_R, ANVIL_A, ANVIL_D)
	_notes[key] = s
	return s


# ===================== fond continu =====================

# Enveloppe du fond par bloc de 64 échantillons : (coef filtre, gain bruit, gain bourdon).
func _bed_env(i: int) -> Vector3:
	var ph := float(i) / float(_gen_n)
	match _bed_type:
		BED_SURF:
			# 4 vagues par boucle : montée rapide, retrait lent
			var x := fmod(ph * 4.0, 1.0)
			var wi := int(ph * 4.0) & 3
			var strength: float = SURF_STR[wi]
			var e := 0.0
			if x < 0.25:
				e = x / 0.25
			else:
				e = pow(1.0 - (x - 0.25) / 0.75, 1.6)
			e = 0.2 + 0.8 * e * e * strength
			var c := 0.015 + 0.09 * e
			return Vector3(c, _bed_amp * e * 1.8 / sqrt(c), 0.0)
		BED_WIND:
			var e := 0.55 + 0.3 * sin(TAU * ph * 2.0) + 0.15 * sin(TAU * ph * 5.0)
			var c := 0.02 + 0.03 * e
			return Vector3(c, _bed_amp * e * 1.8 / sqrt(c), 0.0)
		BED_DRONE:
			# Basse qui pulse sur chaque temps + léger souffle de vapeur
			var fr := fmod(float(i) / _gen_spb, 1.0)
			var dg := _bed_amp * (0.3 + 0.7 * exp(-4.0 * fr))
			return Vector3(0.35, _bed_amp * 0.12, dg)
	return Vector3(0.1, 0.0, 0.0)


func _bed_chunk(a: int, b: int) -> void:
	var lp1 := _lp1
	var lp2 := _lp2
	var rs := _rs
	var dy1 := _dy1
	var dy2 := _dy2
	var dk := _dk
	var i := a
	while i < b:
		var e := _bed_env(i)
		var c := e.x
		var g := e.y
		var dg := e.z
		var end := mini(i + 64, b)
		for j in range(i, end):
			rs = (rs * 1103515245 + 12345) & 0x7fffffff
			lp1 += c * (float(rs) * INV_RS - 1.0 - lp1)
			lp2 += c * (lp1 - lp2)
			var y := dk * dy1 - dy2
			dy2 = dy1
			dy1 = y
			_gen_buf[j] += lp2 * g + y * dg
		if _b_k.size() > 0:
			_bell_block(i, end)
		i = end
	_lp1 = lp1
	_lp2 = lp2
	_rs = rs
	_dy1 = dy1
	_dy2 = dy2


# Cloche bonshō : oscillateurs récurrents frappés aux instants prévus.
func _bell_block(i: int, end: int) -> void:
	for s in _b_strikes:
		if s >= i and s < end:
			for p in _b_k.size():
				_b_a[p] = _b_level * float(BELL_A[p])
				_b_y1[p] = 0.0
				_b_y2[p] = -sin(_b_w[p])
	for p in _b_k.size():
		var a: float = _b_a[p]
		if a < 0.00005:
			continue
		var k: float = _b_k[p]
		var y1: float = _b_y1[p]
		var y2: float = _b_y2[p]
		var g: float = _b_g[p]
		for j in range(i, end):
			var y := k * y1 - y2
			y2 = y1
			y1 = y
			_gen_buf[j] += y * a
			a *= g
		_b_a[p] = a
		_b_y1[p] = y1
		_b_y2[p] = y2


# ===================== instruments =====================

# Somme de partiels amortis (oscillateur récurrent : pas de sin() par échantillon).
func _partials(out: PackedFloat32Array, freq: float, ratios: Array, amps: Array, decays: Array, dmul: float) -> PackedFloat32Array:
	var n := out.size()
	for p in ratios.size():
		var f: float = freq * float(ratios[p])
		if f >= RATE * 0.45:
			continue
		var w := TAU * f / RATE
		var k := 2.0 * cos(w)
		var y1 := 0.0
		var y2 := -sin(w)
		var a: float = amps[p]
		var g := exp(-float(decays[p]) * dmul / RATE)
		for i in n:
			var y := k * y1 - y2
			y2 = y1
			y1 = y
			out[i] += y * a
			a *= g
	return out


# Bruit bref filtré ajouté au début (attaque du plectre, frappe).
func _transient(out: PackedFloat32Array, length_s: float, amount: float, c: float) -> PackedFloat32Array:
	var tn := mini(out.size(), int(length_s * RATE))
	if tn <= 0:
		return out
	var rs := _rs
	var lp := 0.0
	for i in tn:
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		lp += c * (float(rs) * INV_RS - 1.0 - lp)
		out[i] += lp * amount * (1.0 - float(i) / tn)
	_rs = rs
	return out


# Rampes d'entrée / de sortie (anti-clic).
func _edges(out: PackedFloat32Array, att: int, rel: int) -> PackedFloat32Array:
	var n := out.size()
	var a := mini(att, n)
	for i in a:
		out[i] *= float(i) / a
	var r := mini(rel, n)
	for i in r:
		out[n - 1 - i] *= float(i) / r
	return out


func _new_buf(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(1, int(dur * RATE)))
	out.fill(0.0)
	return out


# Koto (doux) ou shamisen (brillant, sec) : cordes pincées additives.
func _pluck(freq: float, dur: float, bright: bool) -> PackedFloat32Array:
	var out := _new_buf(dur)
	var dmul := sqrt(freq / 300.0)
	if bright:
		out = _partials(out, freq, [1.0, 2.0, 3.0, 4.0, 5.0], [1.0, 0.75, 0.55, 0.4, 0.25], [6.0, 8.0, 10.0, 13.0, 16.0], dmul)
		out = _transient(out, 0.02, 0.6, 0.6)
	else:
		out = _partials(out, freq, [1.0, 2.003, 3.008, 4.015], [1.0, 0.45, 0.25, 0.1], [3.0, 4.5, 6.5, 9.0], dmul)
		out = _transient(out, 0.015, 0.3, 0.4)
	out = _edges(out, 30, int(0.08 * RATE))
	return out


# Shakuhachi : sinus doux, attaque soufflée, glissé d'entrée, vibrato lent.
func _shaku(freq: float, dur: float) -> PackedFloat32Array:
	var out := _new_buf(dur)
	var n := out.size()
	var att := 0.09 * RATE
	var rel := minf(0.3 * RATE, n * 0.4)
	var ph := 0.0
	var inc := 0.0
	var env := 0.0
	var breath := 0.0
	var lp := 0.0
	var rs := _rs
	for i in n:
		if (i & 31) == 0:
			var t := float(i) / RATE
			var vib := 1.0 + 0.007 * sin(TAU * 4.8 * t) * clampf((t - 0.35) * 2.0, 0.0, 1.0)
			var scoop := 1.0 - 0.025 * maxf(0.0, 1.0 - t / 0.12)
			inc = TAU * freq * vib * scoop / RATE
			env = minf(1.0, float(i) / att) * minf(1.0, float(n - i) / rel)
			env *= 0.9 + 0.1 * sin(TAU * 0.7 * t)
			breath = 0.12 + 0.5 * maxf(0.0, 1.0 - t / 0.15)
		ph += inc
		if ph > TAU:
			ph -= TAU
		var s := sin(ph)
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		lp += 0.18 * (float(rs) * INV_RS - 1.0 - lp)
		out[i] = (s - 0.25 * (s * s - 0.5) + lp * breath * 2.0) * env * 0.8
	_rs = rs
	return out


# Taiko : sinus grave à hauteur qui chute + peau + bruit de frappe.
func _taiko(freq: float, dur: float) -> PackedFloat32Array:
	var out := _new_buf(dur)
	var n := out.size()
	var ph := 0.0
	var ph2 := 0.0
	var fe := 1.0
	var kf := exp(-1.0 / (0.04 * RATE))
	var a := 1.0
	var ka := exp(-1.0 / (dur * 0.28 * RATE))
	var a2 := 0.5
	var ka2 := exp(-1.0 / (0.06 * RATE))
	var nz := 0.6
	var kn := exp(-1.0 / (0.025 * RATE))
	var lp := 0.0
	var rs := _rs
	for i in n:
		var f := freq * (1.0 + 1.3 * fe)
		fe *= kf
		ph += TAU * f / RATE
		ph2 += TAU * f * 2.6 / RATE
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		lp += 0.25 * (float(rs) * INV_RS - 1.0 - lp)
		out[i] = sin(ph) * a + sin(ph2) * a2 + lp * nz
		a *= ka
		a2 *= ka2
		nz *= kn
	_rs = rs
	out = _edges(out, 8, int(0.05 * RATE))
	return out


# Clochette / enclume : quelques partiels inharmoniques brefs.
func _bell_note(freq: float, dur: float, ratios: Array, amps: Array, decays: Array) -> PackedFloat32Array:
	var out := _new_buf(dur)
	out = _partials(out, freq, ratios, amps, decays, 1.0)
	out = _transient(out, 0.004, 0.4, 0.8)
	out = _edges(out, 4, int(0.05 * RATE))
	return out


# ===================== composition =====================

func _ev(kind: int, beat: float, freq: float, dur: float, amp: float) -> void:
	_evs.append([kind, beat, freq, dur, amp])


# Degré de gamme (peut être négatif / sur plusieurs octaves) -> fréquence.
func _f(root: float, scale: Array, deg: int) -> float:
	var o := floori(deg / 5.0)
	var k := deg - o * 5
	var semi: int = o * 12 + int(scale[k])
	return root * pow(2.0, semi / 12.0)


# Marche aléatoire sur la gamme : [[temps, degré, durée en temps], ...]
func _melody(rng: RandomNumberGenerator, total: float, deg0: int, lo: int, hi: int, durs: Array) -> Array:
	var out: Array = []
	var b := 0.0
	var d := deg0
	while b < total - 0.01:
		var du: float = durs[rng.randi() % durs.size()]
		du = minf(du, total - b)
		out.append([b, d, du])
		b += du
		var step := rng.randi_range(-2, 2)
		if step == 0:
			step = 1 if rng.randf() < 0.5 else -1
		d = clampi(d + step, lo, hi)
	return out


# Monde 1 (plage) : koto + shakuhachi, 92 BPM, ressac, taiko léger.
func _w1(rng: RandomNumberGenerator) -> Dictionary:
	var root := 293.66
	var bs := 60.0 / 92.0
	var bases := [0, 0, -2, -1, 0, 0, -2, 1]
	var pat := [0, 2, 4, 2]
	for bar in 8:
		var base: int = int(bases[bar]) - 5
		for k in 4:
			var d: int = base + int(pat[k])
			_ev(K_KOTO, bar * 4 + k, _f(root, YO, d), 1.3, 0.28 if k == 0 else 0.2)
		_ev(K_KOTO, bar * 4 + 3.5, _f(root, YO, base + 3), 0.9, 0.12)
		_ev(K_TAIKO, bar * 4, 72.0, 0.9, 0.42)
		if bar % 2 == 1:
			_ev(K_TAIKO, bar * 4 + 2.5, 88.0, 0.6, 0.22)
	# Shakuhachi : question (mesures 2-3) / réponse qui se pose sur la tonique
	var ph := _melody(rng, 7.0, 4, 1, 7, [1.0, 1.0, 2.0, 1.5, 0.5])
	for i in ph.size():
		var nt: Array = ph[i]
		var bt: float = nt[0]
		var d1: int = nt[1]
		var dl: float = nt[2]
		_ev(K_SHAKU, 4.0 + bt, _f(root, YO, d1), dl * bs * 0.95, 0.34)
		var d2 := d1
		if i == ph.size() - 1:
			d2 = 5
		_ev(K_SHAKU, 20.0 + bt, _f(root, YO, d2), dl * bs * 0.95, 0.34)
	# Égrenages aigus de koto (mesures 4 et 8)
	for start in [12.0, 28.0]:
		var sp := _melody(rng, 4.0, 7, 5, 10, [0.5, 0.5, 1.0])
		for nt in sp:
			var bt2: float = nt[0]
			var dd: int = nt[1]
			_ev(K_KOTO, float(start) + bt2, _f(root, YO, dd), 1.0, 0.16)
	return {"bpm": 92.0, "beats": 32.0, "echo": 0.75, "fb": 0.22, "taps": 2, "bed": BED_SURF, "bed_amp": 0.11}


# Monde 2 (bambouseraie) : shakuhachi solo, clochettes suzu, kotsuzumi sec, vent.
func _w2(rng: RandomNumberGenerator) -> Dictionary:
	var root := 329.63
	var bs := 60.0 / 72.0
	var a := _melody(rng, 9.0, 3, -1, 6, [1.5, 2.0, 1.0, 3.0, 0.5])
	for nt in a:
		var bt: float = nt[0]
		var d: int = nt[1]
		var dl: float = nt[2]
		_ev(K_SHAKU, bt, _f(root, IN_SC, d), dl * bs * 0.95, 0.4)
	var b := _melody(rng, 9.0, 4, -1, 6, [1.5, 2.0, 1.0, 3.0, 0.5])
	for i in b.size():
		var nt: Array = b[i]
		var bt: float = nt[0]
		var d: int = nt[1]
		var dl: float = nt[2]
		if i == b.size() - 1:
			d = 0
		_ev(K_SHAKU, 12.0 + bt, _f(root, IN_SC, d), dl * bs * 0.95, 0.4)
	# Grappes de clochettes en fin de phrase
	for st in [10.0, 22.0]:
		for j in 4:
			_ev(K_SUZU, float(st) + j * 0.08, 2600.0 * (1.0 + 0.04 * rng.randf()), 0.5, 0.12)
	_ev(K_SUZU, 4.5, 2900.0, 0.5, 0.07)
	_ev(K_SUZU, 16.5, 2750.0, 0.5, 0.07)
	# « Pon » du kotsuzumi
	for p in [0.0, 3.0, 6.5, 12.0, 15.0, 18.5]:
		_ev(K_TAIKO, float(p), 230.0, 0.3, 0.16)
	return {"bpm": 72.0, "beats": 24.0, "echo": 1.0, "fb": 0.3, "taps": 2, "bed": BED_WIND, "bed_amp": 0.06}


# Monde 3 (temple enneigé) : shamisen grave, cloche bonshō, murmure grave, neige/vent.
func _w3(rng: RandomNumberGenerator) -> Dictionary:
	var root := 146.83
	var bs := 60.0 / 66.0
	var pos := [0.0, 1.0, 1.5, 2.5, 3.0]
	var d := 2
	for bar in 5:
		for p in pos:
			if rng.randf() > 0.72:
				continue
			d = clampi(d + rng.randi_range(-2, 2), 0, 7)
			var bt: float = bar * 4 + float(p)
			# Appoggiature (ornement) avant certaines notes
			if rng.randf() < 0.3:
				_ev(K_SHAMI, bt - 0.15, _f(root, IN_SC, d + 1), 0.4, 0.16)
			_ev(K_SHAMI, bt, _f(root, IN_SC, d), 0.9, 0.3)
	# Murmure grave (évoque le chœur) : longues tenues
	_ev(K_SHAKU, 2.0, _f(root, IN_SC, 0), 5.0 * bs, 0.16)
	_ev(K_SHAKU, 12.0, _f(root, IN_SC, -1), 5.0 * bs, 0.14)
	# Bois qui frappe la cloche
	_ev(K_TAIKO, 0.0, 90.0, 0.5, 0.2)
	_ev(K_TAIKO, 10.0, 90.0, 0.5, 0.15)
	return {"bpm": 66.0, "beats": 20.0, "echo": 1.5, "fb": 0.2, "taps": 2, "bed": BED_WIND, "bed_amp": 0.05,
		"bell_f": root, "bell_beats": [0.0, 10.0], "bell_amp": 0.45}


# Monde 4 (forge volcanique) : ōdaiko massif 120 BPM, enclume, ostinato, basse qui pulse.
func _w4(rng: RandomNumberGenerator) -> Dictionary:
	var root := 146.83
	var bs := 0.5
	var pat := [0, 0, 3, 2, 0, 0, 4, 3]
	var shifts := [0, 0, 0, 0, -1, -1, 0, 0, 1, 0]
	for bar in 10:
		var b0 := bar * 4.0
		_ev(K_TAIKO, b0, 52.0, 1.2, 0.95)
		_ev(K_TAIKO, b0 + 2.0, 52.0, 1.2, 0.7)
		if bar % 2 == 1:
			_ev(K_TAIKO, b0 + 3.5, 60.0, 0.8, 0.5)
		_ev(K_ANVIL, b0 + 1.0, 1250.0, 0.5, 0.11)
		_ev(K_ANVIL, b0 + 3.0, 1250.0, 0.5, 0.11)
		# Shime-daiko en croches
		if bar >= 2 and bar < 9:
			for k in 8:
				_ev(K_TAIKO, b0 + k * 0.5, 190.0, 0.25, 0.24 if k % 2 == 0 else 0.14)
		var sh: int = shifts[bar]
		for k in 8:
			var dk: int = int(pat[k]) + sh
			_ev(K_KOTO, b0 + k * 0.5, _f(root, HIRA, dk), 0.45, 0.17)
	# Roulement final qui relance la boucle
	for k in 8:
		_ev(K_TAIKO, 38.0 + k * 0.25, 70.0, 0.5, 0.35 + 0.06 * k)
	# Appels de shakuhachi
	for start in [16.0, 32.0]:
		var m := _melody(rng, 7.0, 7, 5, 9, [2.0, 1.0, 1.0, 3.0, 0.5])
		for nt in m:
			var bt: float = nt[0]
			var d: int = nt[1]
			var dl: float = nt[2]
			_ev(K_SHAKU, float(start) + bt, _f(root, HIRA, d), dl * bs * 0.95, 0.28)
	return {"bpm": 120.0, "beats": 40.0, "echo": 0.0, "fb": 0.0, "taps": 0, "bed": BED_DRONE, "bed_amp": 0.10}


# Monde 5 (encre) : koto épuré qui s'efface, échos longs, un seul coup de taiko.
func _w5(rng: RandomNumberGenerator) -> Dictionary:
	var root := 220.0
	var m := _melody(rng, 18.0, 5, 2, 9, [1.0, 1.0, 0.5, 1.5, 2.0])
	for i in m.size():
		var nt: Array = m[i]
		var bt: float = nt[0]
		var d: int = nt[1]
		var keep := true
		if bt >= 8.0 and bt < 13.0:
			keep = i % 2 == 0
		elif bt >= 13.0:
			keep = i % 3 == 0
		if not keep:
			continue
		var amp := lerpf(0.34, 0.12, bt / 18.0)
		_ev(K_KOTO, bt, _f(root, HIRA, d), 1.8, amp)
	var bass := [0, -2, 0, -1]
	for k in 4:
		var db: int = -5 + int(bass[k])
		_ev(K_KOTO, k * 4.0, _f(root, HIRA, db), 2.0, 0.22 - 0.04 * k)
	_ev(K_TAIKO, 20.0, 62.0, 1.2, 0.3)
	return {"bpm": 60.0, "beats": 22.0, "echo": 0.75, "fb": 0.42, "taps": 3, "bed": BED_WIND, "bed_amp": 0.025}


# Menu : koto lent en arpèges, mélodie clairsemée, ressac lointain.
func _menu(rng: RandomNumberGenerator) -> Dictionary:
	var root := 220.0
	var bases := [0, -1, 0, -2, 1]
	var pat := [0, 2, 4, 2]
	for bar in 5:
		for k in 4:
			var d: int = int(bases[bar]) - 5 + int(pat[k])
			_ev(K_KOTO, bar * 4 + k, _f(root, YO, d), 1.8, 0.2 if k == 0 else 0.14)
	var m := _melody(rng, 18.0, 5, 3, 9, [2.0, 2.0, 1.0, 3.0])
	for nt in m:
		var bt: float = nt[0]
		var d2: int = nt[1]
		_ev(K_KOTO, 1.0 + bt, _f(root, YO, d2), 2.0, 0.17)
	return {"bpm": 64.0, "beats": 20.0, "echo": 0.75, "fb": 0.35, "taps": 3, "bed": BED_SURF, "bed_amp": 0.035}
