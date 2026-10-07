extends RefCounted
## Compositeur + synthétiseur de la musique (aucun fichier audio source).
## N'est PAS utilisé pendant le jeu : tools/bake_music.gd l'appelle une fois au CI (render(nom) pour
## chaque piste de music_player.gd TRACKS), écrit des WAV que le CI convertit en OGG ; le jeu ne fait
## que les lire (scripts/music_player.gd).
##
## Chaque piste est composée de façon déterministe (graine fixe) :
##  - boucles : introduction (jouée une fois, durée = music_player.LOOP_START) puis corps bouclé
##    (sections A / A' / B / coda) ; les queues de notes en fin de corps se replient sur son début
##    (raccord sans couture) ;
##  - jingles : rendu linéaire, avec une queue de résonance.
## Mixage : un bus « sec » (percussions, fond) et un bus « mouillé » (instruments mélodiques) qui
## reçoit un écho bouclé, puis normalisation en puissance (RMS), filtre doux et limiteur.

const MP = preload("res://scripts/music_player.gd")

const RATE := 22050
const INV_RS := 1.0 / 1073741824.0
const KNEE := 0.6

# Gammes pentatoniques japonaises (demi-tons)
const YO := [0, 2, 5, 7, 9]
const IN_SC := [0, 1, 5, 7, 8]
const HIRA := [0, 2, 3, 7, 8]
const KUMOI := [0, 2, 3, 7, 9]

# Cloche bonshō (partiels inharmoniques, doublet battant)
const BELL_R := [0.5, 1.0, 1.007, 1.52, 2.0, 2.74]
const BELL_A := [0.5, 0.8, 0.6, 0.35, 0.3, 0.15]
const BELL_D := [0.35, 0.5, 0.5, 0.9, 1.2, 2.0]
# Clochettes suzu, enclume, claquoirs hyōshigi
const SUZU_R := [1.0, 2.32, 4.1]
const SUZU_A := [1.0, 0.6, 0.35]
const SUZU_D := [9.0, 12.0, 16.0]
const ANVIL_R := [1.0, 2.76, 5.4]
const ANVIL_A := [1.0, 0.5, 0.3]
const ANVIL_D := [7.0, 10.0, 14.0]
const HYO_R := [1.0, 2.43, 3.9]
const HYO_A := [1.0, 0.5, 0.25]
const HYO_D := [45.0, 60.0, 80.0]
# Timbre d'anche du shō (harmoniques)
const SHO_H := [1.0, 0.55, 0.42, 0.22, 0.16, 0.08, 0.05]
# Force relative des vagues du ressac
const SURF_STR := [1.0, 0.7, 0.9, 0.75]

enum { K_KOTO, K_KOTO_S, K_SHAMI, K_SHAKU, K_SHAKU_F, K_FUE, K_TAIKO, K_SUZU, K_ANVIL, K_SHO, K_KANE, K_HYO }
enum { BED_NONE, BED_SURF, BED_WIND, BED_DRONE }

var _evs: Array = []
var _intro_mode := false
var _notes := {}
var _rs := 12345
var _sho_tab := PackedFloat32Array()

# --- rendu en cours ---
var _wet := PackedFloat32Array()
var _dry := PackedFloat32Array()
var _spb := 1.0
var _loop := true
var _intro_n := 0
var _body_n := 0
var _total_n := 0


# ===================== API =====================

## Compose et synthétise la piste `tname` (voir music_player.gd TRACKS). null si nom inconnu.
func render(tname: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + (hash(tname) & 0xffffff)
	_evs = []
	_intro_mode = false
	_notes.clear()
	_rs = 12345 + (hash(tname) & 0xffff)
	var c: Dictionary = {}
	match tname:
		"menu":
			c = _menu(rng)
		"w1":
			c = _w1(rng)
		"w2":
			c = _w2(rng)
		"w3":
			c = _w3(rng)
		"w4":
			c = _w4(rng)
		"w5":
			c = _w5(rng)
		"boss1", "boss2", "boss3", "boss4", "boss5":
			c = _boss(rng, tname.right(1).to_int())
		"mini":
			c = _mini(rng)
		"win":
			c = _win()
		"lose":
			c = _lose()
		_:
			return null
	_intro_mode = false
	var bpm: float = c["bpm"]
	var beats: float = c["beats"]
	_spb = RATE * 60.0 / bpm
	_loop = bool(c.get("loop", true))
	if _loop:
		var ls: float = float(MP.LOOP_START.get(tname, 0.0))
		_intro_n = int(roundf(ls * RATE))
		_body_n = int(roundf(beats * _spb))
		_total_n = _intro_n + _body_n
		var ib: float = float(c.get("intro", 0.0))
		if absf(ib * _spb - float(_intro_n)) > RATE * 0.02:
			print("MUSIQUE: intro de %s incohérente avec LOOP_START" % tname)
	else:
		var tail: float = float(c.get("tail", 1.0))
		_intro_n = 0
		_body_n = 0
		_total_n = int(roundf(beats * _spb + tail * RATE))
	_wet = PackedFloat32Array()
	_wet.resize(_total_n)
	_wet.fill(0.0)
	_dry = PackedFloat32Array()
	_dry.resize(_total_n)
	_dry.fill(0.0)

	_bed(c)
	for ev in _evs:
		_place(ev)
	_evs = []
	_echo(float(c.get("echo", 0.0)), float(c.get("fb", 0.0)))
	var bytes := _master(float(c.get("rms", 0.13)))
	_wet = PackedFloat32Array()
	_dry = PackedFloat32Array()
	_notes.clear()

	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return w


# ===================== mixage =====================

func _place(ev: Array) -> void:
	var kind: int = ev[0]
	var beat: float = ev[1]
	var freq: float = ev[2]
	var dur: float = ev[3]
	var amp: float = ev[4]
	var intro: bool = ev[5]
	var note := _get_note(kind, freq, dur)
	var wet := kind != K_TAIKO and kind != K_ANVIL and kind != K_HYO
	var s := int(roundf(beat * _spb))
	if _loop and not intro:
		_mix_wrap(note, s, amp, wet)
	elif _loop:
		_mix_lin(note, _intro_n + s, amp, wet, _intro_n)
	else:
		_mix_lin(note, s, amp, wet, _total_n)


# Corps de boucle : la note se replie au début du corps si elle dépasse la fin.
func _mix_wrap(note: PackedFloat32Array, s: int, gain: float, wet: bool) -> void:
	var n := _body_n
	var m := mini(note.size(), n)
	var st := posmod(s, n)
	var first := mini(m, n - st)
	var a := _intro_n + st
	var b := _intro_n - first
	if wet:
		for j in first:
			_wet[a + j] += note[j] * gain
		for j in range(first, m):
			_wet[b + j] += note[j] * gain
	else:
		for j in first:
			_dry[a + j] += note[j] * gain
		for j in range(first, m):
			_dry[b + j] += note[j] * gain


# Introduction / jingle : linéaire, coupée (en fondu bref) à `limit`.
func _mix_lin(note: PackedFloat32Array, start: int, gain: float, wet: bool, limit: int) -> void:
	var j0 := maxi(0, -start)
	var j1 := mini(note.size(), limit - start)
	if j1 <= j0:
		return
	var fl := 0
	if j1 < note.size():
		fl = mini(1500, j1 - j0)
	var jm := j1 - fl
	if wet:
		for j in range(j0, jm):
			_wet[start + j] += note[j] * gain
		for j in range(jm, j1):
			_wet[start + j] += note[j] * gain * float(j1 - j) / float(fl)
	else:
		for j in range(j0, jm):
			_dry[start + j] += note[j] * gain
		for j in range(jm, j1):
			_dry[start + j] += note[j] * gain * float(j1 - j) / float(fl)


# Écho à réinjection (2 prises moyennées : un peu assombri) sur le bus mouillé.
# Sur le corps de boucle : calcul circulaire (2 passes), donc raccord sans couture.
func _echo(beats: float, fb_in: float) -> void:
	var d := int(beats * _spb)
	if fb_in <= 0.0 or d < 2:
		return
	var fb := fb_in * 0.5
	var x := _wet.duplicate()
	var lin_end := _intro_n if _loop else _total_n
	for i in range(d + 1, lin_end):
		_wet[i] = x[i] + fb * (_wet[i - d] + _wet[i - d - 1])
	if not _loop:
		return
	var n := _body_n
	if d + 1 >= n:
		return
	var o := _intro_n
	for pass_i in 2:
		var lim := n
		if pass_i == 1:
			lim = mini(n, d * 12)
		for j in mini(d + 1, lim):
			var k1 := j - d + n
			if k1 >= n:
				k1 -= n
			var k2 := k1 - 1
			if k2 < 0:
				k2 += n
			_wet[o + j] = x[o + j] + fb * (_wet[o + k1] + _wet[o + k2])
		for j in range(d + 1, lim):
			_wet[o + j] = x[o + j] + fb * (_wet[o + j - d] + _wet[o + j - d - 1])


# Somme des bus, normalisation RMS (plafonnée par la crête), filtre doux, limiteur, 16 bits.
func _master(target: float) -> PackedByteArray:
	var n := _total_n
	var sum := 0.0
	var pk := 0.001
	for i in n:
		var v: float = _dry[i] + _wet[i]
		_dry[i] = v
		sum += v * v
		var av := absf(v)
		if av > pk:
			pk = av
	var rms := sqrt(sum / maxf(1.0, float(n)))
	var g := minf(target / maxf(rms, 0.0001), 1.3 / pk)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var lp := 0.0
	if n > 0:
		lp = _dry[n - 1] * g
	for i in n:
		var x: float = _dry[i] * g
		# passe-bas doux (~5 kHz) : moins d'aigus fatigants sous les bruitages
		lp += 0.72 * (x - lp)
		x = lp
		var ax := absf(x)
		if ax > KNEE:
			var y: float = KNEE + (1.0 - KNEE) * tanh((ax - KNEE) / (1.0 - KNEE))
			x = y if x > 0.0 else -y
		bytes.encode_s16(i * 2, int(x * 30000.0))
	return bytes


# ===================== fond continu =====================

func _bed(c: Dictionary) -> void:
	var typ: int = int(c.get("bed", BED_NONE))
	if typ == BED_NONE:
		return
	var amp: float = float(c.get("bed_amp", 0.0))
	var waves: int = int(c.get("waves", 4))
	var drone_f: float = float(c.get("drone", 0.0))
	var lp1 := 0.0
	var lp2 := 0.0
	var rs := 777
	# Bourdon : nombre entier de cycles sur le corps (raccord sans clic)
	var dk := 0.0
	var dy1 := 0.0
	var dy2 := 0.0
	if drone_f > 0.0:
		var span := _body_n if _loop else _total_n
		var cycles := maxf(1.0, roundf(drone_f * span / RATE))
		var dw := TAU * cycles / span
		dk = 2.0 * cos(dw)
		dy2 = -sin(dw)
	var i := 0
	while i < _total_n:
		var e := _bed_env(typ, i, amp, waves)
		var cf := e.x
		var g := e.y
		var dg := e.z
		var end := mini(i + 64, _total_n)
		for j in range(i, end):
			rs = (rs * 1103515245 + 12345) & 0x7fffffff
			lp1 += cf * (float(rs) * INV_RS - 1.0 - lp1)
			lp2 += cf * (lp1 - lp2)
			var y := dk * dy1 - dy2
			dy2 = dy1
			dy1 = y
			_dry[j] += lp2 * g + y * dg
		i = end


# Enveloppe du fond par bloc de 64 échantillons : (coef filtre, gain bruit, gain bourdon).
# Périodique sur le corps ; l'intro reprend la fin du corps (raccord intro -> corps) en fondu d'entrée.
func _bed_env(typ: int, i: int, amp: float, waves: int) -> Vector3:
	var ph := 0.0
	var fade := 1.0
	var rel := i
	if _loop:
		rel = i - _intro_n
		if i < _intro_n:
			ph = float(i - _intro_n + _body_n) / float(_body_n)
			fade = float(i) / maxf(1.0, float(_intro_n))
		else:
			ph = float(i - _intro_n) / float(_body_n)
	else:
		ph = float(i) / float(_total_n)
	match typ:
		BED_SURF:
			var x := fmod(ph * waves, 1.0)
			var wi := int(ph * waves) % 4
			var strength: float = SURF_STR[wi]
			var e := 0.0
			if x < 0.25:
				e = x / 0.25
			else:
				e = pow(1.0 - (x - 0.25) / 0.75, 1.6)
			e = 0.2 + 0.8 * e * e * strength
			var c := 0.015 + 0.09 * e
			return Vector3(c, amp * e * 1.8 / sqrt(c) * fade, 0.0)
		BED_WIND:
			var e := 0.55 + 0.3 * sin(TAU * ph * 3.0) + 0.15 * sin(TAU * ph * 7.0)
			var c := 0.02 + 0.03 * e
			return Vector3(c, amp * e * 1.8 / sqrt(c) * fade, 0.0)
		BED_DRONE:
			# basse qui pulse sur chaque temps + léger souffle de vapeur
			var fr := fposmod(float(rel) / _spb, 1.0)
			var dg := amp * (0.3 + 0.7 * exp(-4.0 * fr))
			return Vector3(0.35, amp * 0.12 * fade, dg * fade)
	return Vector3(0.1, 0.0, 0.0)


# ===================== instruments =====================

func _get_note(kind: int, freq: float, dur: float) -> PackedFloat32Array:
	var key: String = "%d_%d_%d" % [kind, int(freq * 16.0), int(dur * 1000.0)]
	if _notes.has(key):
		return _notes[key]
	var s := PackedFloat32Array()
	match kind:
		K_KOTO:
			s = _pluck(freq, dur, false, false)
		K_KOTO_S:
			s = _pluck(freq, dur, false, true)
		K_SHAMI:
			s = _pluck(freq, dur, true, false)
		K_SHAKU:
			s = _shaku(freq, dur, false, 0.0)
		K_SHAKU_F:
			s = _shaku(freq, dur, false, -1.5)
		K_FUE:
			s = _shaku(freq, dur, true, 0.0)
		K_TAIKO:
			s = _taiko(freq, dur)
		K_SUZU:
			s = _bell_note(freq, dur, SUZU_R, SUZU_A, SUZU_D)
		K_ANVIL:
			s = _bell_note(freq, dur, ANVIL_R, ANVIL_A, ANVIL_D)
		K_KANE:
			s = _bell_note(freq, dur, BELL_R, BELL_A, BELL_D)
		K_HYO:
			s = _bell_note(freq, dur, HYO_R, HYO_A, HYO_D)
		K_SHO:
			s = _sho(freq, dur)
	_notes[key] = s
	return s


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
		var dec: float = float(decays[p]) * dmul
		var g := exp(-dec / RATE)
		var m := n
		if dec > 0.0:
			m = mini(n, int(log(maxf(a, 0.0003) / 0.0002) / dec * RATE) + 1)
		for i in m:
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


# Koto (doux), koto étouffé (bref) ou shamisen (brillant, sec) : cordes pincées additives.
func _pluck(freq: float, dur: float, bright: bool, mute: bool) -> PackedFloat32Array:
	var out := _new_buf(dur)
	var dmul := sqrt(freq / 300.0)
	if mute:
		dmul *= 2.5
	if bright:
		out = _partials(out, freq, [1.0, 2.0, 3.0, 4.0, 5.0], [1.0, 0.75, 0.55, 0.4, 0.25], [6.0, 8.0, 10.0, 13.0, 16.0], dmul)
		out = _transient(out, 0.02, 0.6, 0.6)
	else:
		out = _partials(out, freq, [1.0, 2.003, 3.008, 4.015], [1.0, 0.45, 0.25, 0.1], [3.0, 4.5, 6.5, 9.0], dmul)
		out = _transient(out, 0.015, 0.3, 0.4)
	out = _edges(out, 30, int(0.08 * RATE))
	return out


# Shakuhachi (doux, soufflé) ou fue (ryūteki/nōkan : plus brillant, vibrato plus vif).
# fall : glissé descendant (demi-tons) sur la note.
func _shaku(freq: float, dur: float, bright: bool, fall: float) -> PackedFloat32Array:
	var out := _new_buf(dur)
	var n := out.size()
	var att: float = (0.06 if bright else 0.09) * RATE
	var rel := minf(0.3 * RATE, n * 0.4)
	var vib_r: float = 5.6 if bright else 4.8
	var vib_d: float = 0.009 if bright else 0.007
	var ph := 0.0
	var inc := 0.0
	var env := 0.0
	var breath := 0.0
	var lp := 0.0
	var rs := _rs
	for i in n:
		if (i & 31) == 0:
			var t := float(i) / RATE
			var vib := 1.0 + vib_d * sin(TAU * vib_r * t) * clampf((t - 0.3) * 2.0, 0.0, 1.0)
			var scoop := 1.0 - 0.025 * maxf(0.0, 1.0 - t / 0.12)
			var bend := 1.0
			if fall != 0.0:
				bend = pow(2.0, fall * clampf((float(i) / n - 0.25) / 0.6, 0.0, 1.0) / 12.0)
			inc = TAU * freq * vib * scoop * bend / RATE
			env = minf(1.0, float(i) / att) * minf(1.0, float(n - i) / rel)
			env *= 0.9 + 0.1 * sin(TAU * 0.7 * t)
			breath = 0.12 + 0.5 * maxf(0.0, 1.0 - t / 0.15)
		ph += inc
		if ph > TAU:
			ph -= TAU
		var s := sin(ph)
		var v := s - 0.25 * (s * s - 0.5)
		if bright:
			v += 0.22 * (4.0 * s * s * s - 3.0 * s) - 0.1 * (s * s - 0.5)
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		lp += 0.18 * (float(rs) * INV_RS - 1.0 - lp)
		out[i] = (v + lp * breath * 2.0) * env * 0.8
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


# Cloches, clochettes, enclume, claquoirs : quelques partiels inharmoniques.
func _bell_note(freq: float, dur: float, ratios: Array, amps: Array, decays: Array) -> PackedFloat32Array:
	var out := _new_buf(dur)
	out = _partials(out, freq, ratios, amps, decays, 1.0)
	out = _transient(out, 0.004, 0.4, 0.8)
	out = _edges(out, 4, mini(int(0.6 * RATE), int(out.size() * 0.33)))
	return out


# Shō : anche (table d'onde) à deux voix légèrement désaccordées, souffle lent qui enfle.
func _sho(freq: float, dur: float) -> PackedFloat32Array:
	if _sho_tab.is_empty():
		_build_sho()
	var tab := _sho_tab
	var out := _new_buf(dur)
	var n := out.size()
	var att := minf(1.4 * RATE, n * 0.4)
	var rel := minf(1.6 * RATE, n * 0.45)
	var inc := freq * 1024.0 / RATE
	var inc2 := inc * 1.0035
	var ph := 0.0
	var ph2 := 380.0
	var env := 0.0
	for i in n:
		if (i & 63) == 0:
			var t := float(i) / RATE
			env = minf(1.0, float(i) / att) * minf(1.0, float(n - i) / rel)
			env *= 0.88 + 0.12 * sin(TAU * 0.23 * t)
		ph += inc
		if ph >= 1024.0:
			ph -= 1024.0
		ph2 += inc2
		if ph2 >= 1024.0:
			ph2 -= 1024.0
		out[i] = (tab[int(ph)] + tab[int(ph2)]) * env * 0.5
	return out


func _build_sho() -> void:
	_sho_tab = PackedFloat32Array()
	_sho_tab.resize(1024)
	var pk := 0.0001
	for k in 1024:
		var v := 0.0
		for h in SHO_H.size():
			v += float(SHO_H[h]) * sin(TAU * float(h + 1) * float(k) / 1024.0)
		_sho_tab[k] = v
		pk = maxf(pk, absf(v))
	for k in 1024:
		_sho_tab[k] = _sho_tab[k] / pk


# ===================== écriture =====================

func _ev(kind: int, beat: float, freq: float, dur: float, amp: float) -> void:
	_evs.append([kind, beat, freq, dur, amp, _intro_mode])


# Durée quantifiée (moins de notes différentes à synthétiser).
func _q(d: float) -> float:
	return maxf(0.12, roundf(d * 20.0) / 20.0)


# Durée de note selon l'instrument (cordes pincées et frappes : résonance naturelle).
func _dur(kind: int, sec: float) -> float:
	match kind:
		K_KOTO:
			return 1.6
		K_KOTO_S:
			return 0.5
		K_SHAMI:
			return 0.8
		K_SUZU:
			return 0.6
		K_ANVIL:
			return 0.6
		K_HYO:
			return 0.15
		K_KANE:
			return 7.0
	return _q(sec)


# Degré de gamme (peut être négatif / sur plusieurs octaves) -> fréquence.
func _f(root: float, scale: Array, deg: int) -> float:
	var o := floori(deg / 5.0)
	var k := deg - o * 5
	var semi: int = o * 12 + int(scale[k])
	return root * pow(2.0, semi / 12.0)


# Phrase mélodique : [[temps, degré, durée en temps], ...] ; surtout des pas conjoints,
# quelques sauts, des silences (rest_p), ramenée vers le centre de la tessiture.
func _phrase(rng: RandomNumberGenerator, beats: float, deg0: int, lo: int, hi: int, rh: Array, rest_p: float) -> Array:
	var out: Array = []
	var b := 0.0
	var d := deg0
	while b < beats - 0.01:
		var du: float = rh[rng.randi() % rh.size()]
		du = minf(du, beats - b)
		if out.is_empty() or rng.randf() >= rest_p:
			out.append([b, d, du])
		b += du
		var r := rng.randf()
		var step := 1
		if r < 0.15:
			step = 2
		elif r > 0.93:
			step = 3
		if rng.randf() < 0.5:
			step = -step
		if d >= hi - 1:
			step = -absi(step)
		elif d <= lo + 1:
			step = absi(step)
		d = clampi(d + step, lo, hi)
	return out


# Variation : quelques notes déplacées d'un degré (la première reste : le motif se reconnaît).
func _vary(rng: RandomNumberGenerator, ph: Array, p: float) -> Array:
	var o: Array = ph.duplicate(true)
	for i in range(1, o.size()):
		if rng.randf() < p:
			var nt: Array = o[i]
			nt[1] = int(nt[1]) + (1 if rng.randf() < 0.5 else -1)
	return o


# Fin de phrase posée sur un degré donné.
func _cadence(ph: Array, deg: int) -> Array:
	var o: Array = ph.duplicate(true)
	if not o.is_empty():
		var last: Array = o[o.size() - 1]
		last[1] = deg
	return o


# Augmentation rythmique (durées multipliées).
func _augment(ph: Array, k: float) -> Array:
	var o: Array = ph.duplicate(true)
	for nt in o:
		var a: Array = nt
		a[0] = float(a[0]) * k
		a[2] = float(a[2]) * k
	return o


func _put(kind: int, ph: Array, at: float, root: float, scale: Array, shift: int, amp: float, bs: float) -> void:
	for i in ph.size():
		var nt: Array = ph[i]
		var bt: float = nt[0]
		var d: int = nt[1]
		var ln: float = nt[2]
		var a := amp
		if i == 0:
			a *= 1.1
		_ev(kind, at + bt, _f(root, scale, d + shift), _dur(kind, ln * bs * 0.92), a)


# Accompagnement en arpèges (une mesure = 4 temps), basse de la progression + motif de degrés.
func _arp(kind: int, root: float, scale: Array, b0: int, bars: int, prog: Array, pat: Array, step: float, amp: float, oct: int) -> void:
	for bar in bars:
		var base: int = int(prog[bar % prog.size()]) + oct
		var k := 0
		var t := 0.0
		while t < 3.999:
			var d: int = base + int(pat[k % pat.size()])
			var a := amp
			if k == 0:
				a *= 1.35
			_ev(kind, (b0 + bar) * 4.0 + t, _f(root, scale, d), _dur(kind, 1.0), a)
			k += 1
			t += step


# Nappes de shō : un accord (degrés relatifs) toutes les `span` mesures.
func _pad_prog(root: float, scale: Array, b0: int, bars: int, prog: Array, chord: Array, amp: float, bs: float, span: int) -> void:
	var bar := 0
	while bar < bars:
		var base: int = int(prog[bar % prog.size()])
		var len_s := _q(minf(span, bars - bar) * 4.0 * bs + 0.5)
		for c in chord:
			_ev(K_SHO, (b0 + bar) * 4.0, _f(root, scale, base + int(c)), len_s, amp)
		bar += span


# Glissando (sararin du koto) : count notes, pas de degré dirn, écart gap (temps).
func _gliss(kind: int, root: float, scale: Array, beat: float, d0: int, count: int, dirn: int, gap: float, amp: float) -> void:
	for k in count:
		_ev(kind, beat + k * gap, _f(root, scale, d0 + k * dirn), _dur(kind, 0.5), amp * (0.65 + 0.35 * float(k) / count))


# Ligne de shamisen clairsemée : [[temps, degré, ornement], ...] (ornement = appoggiature).
func _shami_line(rng: RandomNumberGenerator, bars: int, density: float, lo: int, hi: int) -> Array:
	var out: Array = []
	var pos := [0.0, 1.0, 1.5, 2.5, 3.0]
	var d := int((lo + hi) * 0.5)
	for bar in bars:
		for p in pos:
			if rng.randf() > density:
				continue
			d = clampi(d + rng.randi_range(-2, 2), lo, hi)
			out.append([bar * 4.0 + float(p), d, 1.0 if rng.randf() < 0.3 else 0.0])
	return out


func _put_shami(ln: Array, at: float, root: float, scale: Array, amp: float) -> void:
	for nt in ln:
		var e: Array = nt
		var bt: float = e[0]
		var d: int = e[1]
		var gr: float = e[2]
		if gr > 0.5:
			_ev(K_SHAMI, at + bt - 0.15, _f(root, scale, d + 1), 0.8, amp * 0.5)
		_ev(K_SHAMI, at + bt, _f(root, scale, d), 0.8, amp)


# ===================== pistes =====================

# Menu : koto lent en arpèges, nappe de shō, mélodie clairsemée puis shakuhachi, ressac lointain.
# 64 BPM, 16 mesures (60 s), sans intro.
func _menu(rng: RandomNumberGenerator) -> Dictionary:
	var root := 220.0
	var bs := 60.0 / 64.0
	var prog := [0, -1, 0, -2, 1, 0, -1, 0]
	_arp(K_KOTO, root, YO, 0, 16, prog, [0, 2, 4, 2], 1.0, 0.12, -5)
	_pad_prog(root, YO, 0, 16, prog, [0, 2, 4], 0.022, bs, 2)
	var m := _phrase(rng, 14.0, 5, 3, 9, [2.0, 2.0, 1.0, 3.0], 0.1)
	_put(K_KOTO, m, 1.0, root, YO, 0, 0.15, bs)
	_put(K_KOTO, _cadence(_vary(rng, m, 0.4), 5), 17.0, root, YO, 0, 0.15, bs)
	var s := _phrase(rng, 13.0, 4, 2, 8, [2.0, 3.0, 1.0, 2.0], 0.15)
	_put(K_SHAKU, s, 33.0, root, YO, 0, 0.19, bs)
	_put(K_SHAKU, _cadence(_vary(rng, s, 0.4), 5), 49.0, root, YO, 0, 0.19, bs)
	return {"bpm": 64.0, "beats": 64.0, "intro": 0.0, "echo": 0.75, "fb": 0.33,
		"bed": BED_SURF, "bed_amp": 0.025, "waves": 6, "rms": 0.11}


# Monde 1, la Grande Vague (mer, aube) : gamme yo en ré, 88 BPM, ressac.
# Intro 2 mesures (shō + sararin) ; A (koto + appel/réponse du shakuhachi), A' (croches, shō),
# B (la vague se forme : koto mélodique, sararin, taiko qui monte), coda (la vague se brise).
func _w1(rng: RandomNumberGenerator) -> Dictionary:
	var root := 293.66
	var bs := 60.0 / 88.0
	var prog_a := [0, 0, -2, -1, 0, 0, -2, 1]
	var prog_b := [-2, -2, 0, 0, -1, -1, 1, 1]
	_intro_mode = true
	for c in [0, 1, 3]:
		_ev(K_SHO, -8.0, _f(root, YO, int(c)), _q(8.0 * bs - 0.4), 0.045)
	_ev(K_TAIKO, -8.0, 66.0, 1.2, 0.25)
	_gliss(K_KOTO, root, YO, -3.5, -5, 9, 1, 0.25, 0.16)
	_intro_mode = false
	# A (0-7) / A' (8-15)
	_arp(K_KOTO, root, YO, 0, 8, prog_a, [0, 2, 4, 2], 1.0, 0.13, -5)
	_arp(K_KOTO, root, YO, 8, 8, prog_a, [0, 2, 4, 5, 4, 2, 1, 2], 0.5, 0.085, -5)
	_pad_prog(root, YO, 8, 8, prog_a, [0, 1, 3], 0.032, bs, 2)
	for bar in 16:
		var b0 := bar * 4.0
		_ev(K_TAIKO, b0, 72.0, 0.9, 0.3)
		if bar % 2 == 1:
			_ev(K_TAIKO, b0 + 2.5, 88.0, 0.6, 0.16)
		if bar >= 8 and bar % 4 == 3:
			_ev(K_TAIKO, b0 + 3.0, 80.0, 0.7, 0.2)
			_ev(K_TAIKO, b0 + 3.5, 80.0, 0.7, 0.24)
	var m1 := _phrase(rng, 7.0, 4, 1, 7, [1.0, 1.0, 2.0, 1.5, 0.5], 0.1)
	var m2 := _cadence(_vary(rng, m1, 0.4), 5)
	_put(K_SHAKU, m1, 4.0, root, YO, 0, 0.28, bs)
	_put(K_SHAKU, m2, 20.0, root, YO, 0, 0.28, bs)
	_put(K_SHAKU, _vary(rng, m1, 0.3), 36.0, root, YO, 1, 0.28, bs)
	_put(K_SHAKU, _cadence(_vary(rng, m2, 0.3), 5), 52.0, root, YO, 0, 0.28, bs)
	for st in [12.0, 28.0, 44.0, 60.0]:
		_put(K_KOTO, _phrase(rng, 4.0, 7, 5, 10, [0.5, 0.5, 1.0], 0.0), float(st), root, YO, 0, 0.11, bs)
	# B (16-21) : la vague se forme
	_arp(K_KOTO, root, YO, 16, 6, prog_b, [0, 4, 2, 4], 1.0, 0.09, -5)
	_pad_prog(root, YO, 16, 6, prog_b, [0, 1, 3], 0.04, bs, 2)
	var m3 := _phrase(rng, 8.0, 7, 5, 10, [1.0, 0.5, 0.5, 2.0, 1.0], 0.05)
	_put(K_KOTO, m3, 64.0, root, YO, 0, 0.15, bs)
	_put(K_KOTO, _cadence(_vary(rng, m3, 0.5), 7), 72.0, root, YO, 0, 0.15, bs)
	_ev(K_SHAKU, 66.0, _f(root, YO, 2), _q(6.0 * bs), 0.17)
	_ev(K_SHAKU, 74.0, _f(root, YO, 4), _q(6.0 * bs), 0.17)
	_ev(K_SHAKU, 82.0, _f(root, YO, 3), _q(5.0 * bs), 0.19)
	for k in 3:
		_gliss(K_KOTO, root, YO, 71.0 + 8.0 * k, -2 + k, 8, 1, 0.125, 0.11)
	for bar in range(16, 22):
		var b0 := bar * 4.0
		_ev(K_TAIKO, b0, 66.0, 1.0, 0.36)
		_ev(K_TAIKO, b0 + 2.0, 72.0, 0.8, 0.22)
		if bar >= 20:
			for k in 4:
				_ev(K_TAIKO, b0 + 2.0 + k * 0.5, 96.0, 0.4, 0.12 + 0.03 * k)
	# coda (22-23) : la vague se brise, puis le calme revient (reprise de A)
	_ev(K_TAIKO, 88.0, 55.0, 1.6, 0.6)
	_ev(K_TAIKO, 88.0, 110.0, 0.5, 0.22)
	for c in [-5, 0, 2, 4]:
		_ev(K_SHO, 88.0, _f(root, YO, int(c)), _q(7.0 * bs), 0.035)
	_gliss(K_KOTO, root, YO, 88.0, 10, 10, -1, 0.25, 0.13)
	_ev(K_KOTO, 93.0, _f(root, YO, -5), 1.6, 0.14)
	return {"bpm": 88.0, "beats": 96.0, "intro": 8.0, "echo": 0.75, "fb": 0.28,
		"bed": BED_SURF, "bed_amp": 0.075, "waves": 8, "rms": 0.13}


# Monde 2, Tanabata (nuit, bambous, étoiles, feux de renard) : gamme in en mi, 72 BPM, vent.
# Intro (clochettes, souffle) ; A (shakuhachi solo, étoiles du koto, kotsuzumi) ;
# B (feux de renard : fue joueur, koto étouffé en croches) ; A' (shakuhachi sur shō).
func _w2(rng: RandomNumberGenerator) -> Dictionary:
	var root := 329.63
	var bs := 60.0 / 72.0
	_intro_mode = true
	for j in 5:
		_ev(K_SUZU, -7.0 + j * 0.07, 2500.0 + 140.0 * j, 0.6, 0.06)
	_ev(K_KOTO, -8.0, _f(root, IN_SC, -5), 1.6, 0.12)
	_ev(K_SHAKU, -5.5, _f(root, IN_SC, 0), _q(4.0 * bs), 0.22)
	_intro_mode = false
	# A (0-7) : shakuhachi solo
	var p1 := _phrase(rng, 15.0, 3, -1, 6, [1.5, 2.0, 1.0, 3.0, 0.5], 0.15)
	var p2 := _cadence(_vary(rng, p1, 0.5), 0)
	_put(K_SHAKU, p1, 0.5, root, IN_SC, 0, 0.3, bs)
	_put(K_SHAKU, p2, 16.5, root, IN_SC, 0, 0.3, bs)
	var prog := [0, 0, -1, 0, -2, -2, -1, 0]
	for bar in 20:
		var b0 := bar * 4.0
		var base: int = int(prog[bar % 8]) - 5
		var fox := bar >= 8 and bar < 14
		if not fox:
			_ev(K_KOTO, b0, _f(root, IN_SC, base), 1.6, 0.13)
			_ev(K_KOTO, b0 + 2.0, _f(root, IN_SC, base + 2), 1.6, 0.075)
		# étoiles : notes aiguës clairsemées
		if rng.randf() < 0.7:
			_ev(K_KOTO, b0 + float(rng.randi_range(1, 7)) * 0.5, _f(root, IN_SC, rng.randi_range(8, 12)), 1.6, 0.05)
		# kotsuzumi « pon »
		if fox:
			for p in [0.0, 0.75, 1.5, 3.0]:
				_ev(K_TAIKO, b0 + float(p), 240.0, 0.3, 0.1)
			if bar % 2 == 1:
				for j in 3:
					_ev(K_SUZU, b0 + 3.5 + j * 0.06, 2700.0 + 120.0 * j, 0.6, 0.05)
		elif bar % 2 == 0:
			_ev(K_TAIKO, b0, 230.0, 0.3, 0.12)
			_ev(K_TAIKO, b0 + 1.5, 260.0, 0.3, 0.07)
	# B (8-13) : feux de renard
	var fx := _phrase(rng, 7.0, 5, 3, 9, [0.5, 0.5, 1.0, 0.5, 1.5], 0.1)
	var shifts := [0, 2, -1]
	for k in 3:
		_put(K_FUE, _vary(rng, fx, 0.25), 32.0 + 8.0 * k, root, IN_SC, int(shifts[k]), 0.2, bs)
	_arp(K_KOTO_S, root, IN_SC, 8, 6, [0, 0, 1, 1, -1, 0], [0, 2, 3, 2, 4, 2, 3, 1], 0.5, 0.06, -5)
	# A' (14-19) : shakuhachi sur nappe de shō
	_pad_prog(root, IN_SC, 14, 6, [0, -1, -2], [0, 2, 4], 0.028, bs, 2)
	_put(K_SHAKU, _vary(rng, p1, 0.35), 56.5, root, IN_SC, 0, 0.3, bs)
	_put(K_SHAKU, _cadence(_phrase(rng, 6.0, 2, -1, 5, [1.0, 2.0, 1.5], 0.0), 0), 72.0, root, IN_SC, 0, 0.28, bs)
	for st in [15.5, 31.5, 71.5, 78.5]:
		for j in 4:
			_ev(K_SUZU, float(st) + j * 0.08, 2600.0 + 90.0 * j, 0.6, 0.08)
	return {"bpm": 72.0, "beats": 80.0, "intro": 8.0, "echo": 1.0, "fb": 0.33,
		"bed": BED_WIND, "bed_amp": 0.05, "rms": 0.12}


# Monde 3, les Cent Contes (neige, fantômes, cloches du temple) : gamme in en ré grave, 66 BPM.
# Intro (bonshō, claquoirs du veilleur) ; A (shamisen clairsemé à ornements, chœur murmuré) ;
# B (fantômes : shakuhachi aigu, shō en grappe dissonante, trémolo de shamisen) ; C (retour du motif).
func _w3(rng: RandomNumberGenerator) -> Dictionary:
	var root := 146.83
	var bs := 60.0 / 66.0
	_intro_mode = true
	_ev(K_KANE, -8.0, root, 7.0, 0.3)
	_ev(K_HYO, -2.5, 1900.0, 0.15, 0.2)
	_ev(K_HYO, -2.25, 1900.0, 0.15, 0.16)
	_intro_mode = false
	# A (0-7)
	var la := _shami_line(rng, 4, 0.3, 0, 7)
	_put_shami(la, 0.0, root, IN_SC, 0.27)
	_put_shami(_vary(rng, la, 0.35), 16.0, root, IN_SC, 0.25)
	_ev(K_SHAKU, 2.0, _f(root, IN_SC, 0), _q(5.0 * bs), 0.14)
	_ev(K_SHAKU, 18.0, _f(root, IN_SC, -1), _q(5.0 * bs), 0.13)
	_ev(K_KANE, 0.0, root, 7.0, 0.28)
	_ev(K_TAIKO, 0.0, 90.0, 0.5, 0.16)
	_ev(K_TAIKO, 16.0, 90.0, 0.5, 0.12)
	_ev(K_HYO, 30.0, 1900.0, 0.15, 0.14)
	_ev(K_HYO, 30.25, 1900.0, 0.15, 0.11)
	# B (8-13) : fantômes
	_pad_prog(root * 2.0, IN_SC, 8, 6, [0, 0, -1], [0, 1, 2], 0.026, bs, 2)
	var g := _phrase(rng, 10.0, 6, 4, 9, [2.0, 3.0, 1.0, 1.5], 0.1)
	_put(K_SHAKU, g, 33.0, root, IN_SC, 0, 0.2, bs)
	_put(K_SHAKU, _cadence(_vary(rng, g, 0.4), 5), 45.0, root, IN_SC, 0, 0.2, bs)
	for bar in range(8, 14):
		var b0 := bar * 4.0
		for k in 8:
			var dd := -5 if bar % 2 == 0 else -4
			_ev(K_SHAMI, b0 + k * 0.5, _f(root, IN_SC, dd + 5), 0.8, 0.065 if k % 2 == 0 else 0.045)
	_ev(K_KANE, 36.0, root * 0.75, 7.0, 0.22)
	_ev(K_HYO, 50.0, 1900.0, 0.15, 0.12)
	_ev(K_HYO, 50.25, 1900.0, 0.15, 0.09)
	# C (14-17) : le conte reprend
	_put_shami(la, 56.0, root, IN_SC, 0.26)
	_ev(K_SHAKU, 58.0, _f(root, IN_SC, 0), _q(6.0 * bs), 0.12)
	_ev(K_TAIKO, 56.0, 90.0, 0.5, 0.14)
	return {"bpm": 66.0, "beats": 72.0, "intro": 8.0, "echo": 1.5, "fb": 0.25,
		"bed": BED_WIND, "bed_amp": 0.045, "rms": 0.12}


# Monde 4, le Fuji rouge (volcan, forge, feu) : gamme hirajōshi en ré, 120 BPM, bourdon qui pulse.
# Intro (roulement qui enfle) ; A (ōdaiko, enclume, ostinato de shamisen) ; A' (+ shime, appels de
# shakuhachi) ; B (brèche de lave : demi-temps, koto mélodique, shō) ; A'' (tutti, fue) + roulement.
func _w4(rng: RandomNumberGenerator) -> Dictionary:
	var root := 146.83
	var bs := 0.5
	_intro_mode = true
	for k in 15:
		_ev(K_TAIKO, -8.0 + k * 0.5, 70.0, 0.4, 0.1 + 0.025 * k)
	_ev(K_ANVIL, -6.0, 1250.0, 0.6, 0.09)
	_ev(K_ANVIL, -2.0, 1250.0, 0.6, 0.1)
	_intro_mode = false
	var pat := [0, 0, 3, 2, 0, 0, 4, 3]
	var shifts := [0, 0, 0, 0, -1, -1, 0, 1]
	for bar in 32:
		var b0 := bar * 4.0
		var sec := int(bar / 8.0)
		if sec == 2:
			_ev(K_TAIKO, b0, 52.0, 1.4, 0.8)
			if bar % 2 == 1:
				_ev(K_ANVIL, b0 + 3.0, 1250.0, 0.6, 0.08)
			continue
		_ev(K_TAIKO, b0, 52.0, 1.2, 0.85)
		_ev(K_TAIKO, b0 + 2.0, 52.0, 1.2, 0.62)
		if bar % 2 == 1:
			_ev(K_TAIKO, b0 + 3.5, 60.0, 0.8, 0.45)
		if sec == 3 and bar % 2 == 0:
			_ev(K_TAIKO, b0 + 1.5, 58.0, 0.8, 0.4)
		_ev(K_ANVIL, b0 + 1.0, 1250.0, 0.6, 0.1)
		_ev(K_ANVIL, b0 + 3.0, 1250.0, 0.6, 0.1)
		if sec >= 1:
			for k in 8:
				_ev(K_TAIKO, b0 + k * 0.5, 190.0, 0.25, 0.2 if k % 2 == 0 else 0.11)
		var sh: int = int(shifts[bar % 8])
		if sec == 3 and bar >= 28:
			sh += 2
		for k in 8:
			_ev(K_SHAMI, b0 + k * 0.5, _f(root, HIRA, int(pat[k]) + sh), 0.8, 0.15)
	# A' : appels de shakuhachi
	for st in [40.0, 56.0]:
		_put(K_SHAKU, _phrase(rng, 7.0, 7, 5, 9, [2.0, 1.0, 1.0, 3.0, 0.5], 0.0), float(st), root, HIRA, 0, 0.24, bs)
	# B : brèche de lave
	var mb := _phrase(rng, 16.0, 5, 3, 9, [1.0, 1.0, 2.0, 0.5, 0.5], 0.1)
	_put(K_KOTO, mb, 64.0, root, HIRA, 0, 0.16, bs)
	_put(K_KOTO, _cadence(_vary(rng, mb, 0.4), 5), 80.0, root, HIRA, 0, 0.16, bs)
	_pad_prog(root, HIRA, 16, 8, [0, -1, 0, 1], [0, 1, 3], 0.035, bs, 2)
	_ev(K_FUE, 68.0, _f(root, HIRA, 7), _q(6.0 * bs), 0.13)
	_ev(K_FUE, 84.0, _f(root, HIRA, 8), _q(6.0 * bs), 0.13)
	# A'' : fue
	var mf := _phrase(rng, 14.0, 7, 5, 10, [1.0, 0.5, 0.5, 2.0, 1.0], 0.1)
	_put(K_FUE, mf, 96.0, root, HIRA, 0, 0.19, bs)
	_put(K_FUE, _cadence(_vary(rng, mf, 0.4), 5), 112.0, root, HIRA, 0, 0.19, bs)
	# roulement final qui relance la boucle
	for k in 8:
		_ev(K_TAIKO, 126.0 + k * 0.25, 70.0, 0.5, 0.3 + 0.05 * k)
	return {"bpm": 120.0, "beats": 128.0, "intro": 8.0, "echo": 0.0, "fb": 0.0,
		"bed": BED_DRONE, "bed_amp": 0.08, "drone": 146.83, "rms": 0.14}


# Monde 5, les Trente-six Vues (encre, papier, atelier) : gamme kumoi en la, 76 BPM.
# Un motif de koto et ses « vues » (variations), petits coups de pinceau (bois), shō ;
# B : shakuhachi sur shō ; A' : le motif augmenté qui s'efface comme l'encre.
func _w5(rng: RandomNumberGenerator) -> Dictionary:
	var root := 220.0
	var bs := 60.0 / 76.0
	_intro_mode = true
	for c in [0, 2, 4]:
		_ev(K_SHO, -8.0, _f(root, KUMOI, int(c)), _q(8.0 * bs - 0.4), 0.04)
	_ev(K_KOTO, -6.0, _f(root, KUMOI, 5), 1.6, 0.14)
	_ev(K_KOTO, -4.5, _f(root, KUMOI, 7), 1.6, 0.12)
	_ev(K_KOTO, -3.0, _f(root, KUMOI, 4), 1.6, 0.1)
	_intro_mode = false
	# A (0-7) : le motif et ses vues
	var m := _phrase(rng, 7.0, 5, 2, 9, [1.0, 1.0, 0.5, 1.5, 2.0], 0.05)
	_put(K_KOTO, m, 0.0, root, KUMOI, 0, 0.2, bs)
	_put(K_KOTO, _vary(rng, m, 0.3), 8.0, root, KUMOI, -1, 0.18, bs)
	_put(K_KOTO, _vary(rng, m, 0.5), 16.0, root, KUMOI, 1, 0.18, bs)
	_put(K_KOTO, _cadence(_vary(rng, m, 0.3), 5), 24.0, root, KUMOI, 0, 0.17, bs)
	var bass := [0, -2, 0, -1, -2, -1, 0, 0, 0, -2]
	for k in 10:
		_ev(K_KOTO, k * 8.0, _f(root, KUMOI, -5 + int(bass[k])), 1.6, 0.15)
	for bar in 20:
		if bar < 8 or bar >= 14:
			_ev(K_HYO, bar * 4.0 + 1.0, 2400.0, 0.15, 0.035)
			_ev(K_HYO, bar * 4.0 + 3.0, 2600.0, 0.15, 0.03)
	# B (8-13) : shakuhachi sur shō
	_pad_prog(root, KUMOI, 8, 6, [0, -1, 1], [0, 2, 4], 0.032, bs, 2)
	var s1 := _phrase(rng, 11.0, 4, 1, 7, [1.0, 2.0, 1.5, 3.0], 0.1)
	_put(K_SHAKU, s1, 32.5, root, KUMOI, 0, 0.26, bs)
	_put(K_SHAKU, _cadence(_vary(rng, s1, 0.4), 0), 44.5, root, KUMOI, 0, 0.26, bs)
	_arp(K_KOTO, root, KUMOI, 8, 6, [0, -1, 1, 0, -2, 0], [0, 2, 4, 2], 1.0, 0.065, -5)
	# A' (14-19) : le motif augmenté, l'encre s'efface
	var aug := _augment(m, 2.0)
	for i in aug.size():
		var nt: Array = aug[i]
		var bt: float = nt[0]
		if i > 3 and i % 2 == 1:
			continue
		_ev(K_KOTO, 56.0 + bt, _f(root, KUMOI, int(nt[1])), 1.6, lerpf(0.2, 0.09, clampf(bt / 14.0, 0.0, 1.0)))
	_ev(K_TAIKO, 76.0, 62.0, 1.2, 0.28)
	return {"bpm": 76.0, "beats": 80.0, "intro": 8.0, "echo": 0.75, "fb": 0.4,
		"bed": BED_WIND, "bed_amp": 0.02, "rms": 0.12}


# Gardien de monde : ōdaiko pressant, shime, ostinato de shamisen, grappes de shō dissonantes,
# appel de shakuhachi (ou fue) ; couleur du monde (ressac, clochettes, bonshō, enclume, pinceau).
# Intro 1 mesure (roulement), corps 24 mesures (A, B en doubles croches, A').
func _boss(rng: RandomNumberGenerator, w: int) -> Dictionary:
	var roots := [146.83, 146.83, 164.81, 146.83, 146.83, 110.0]
	var bpms := [132.0, 132.0, 128.0, 120.0, 144.0, 136.0]
	var wi := clampi(w, 1, 5)
	var root: float = roots[wi]
	var bpm: float = bpms[wi]
	var bs := 60.0 / bpm
	var sc: Array = HIRA if wi == 4 else IN_SC
	var lroot: float = root * 2.0 if root < 130.0 else root
	_intro_mode = true
	for k in 7:
		_ev(K_TAIKO, -4.0 + k * 0.5, 64.0, 0.4, 0.15 + 0.07 * k)
	_intro_mode = false
	var prog_a := [0, 0, 1, -1, 0, 0, 2, 1]
	var prog_b := [-1, -1, 0, 0, 1, 1, 2, 2]
	var pat := [0, 0, 2, 0, 3, 0, 2, 1]
	for bar in 24:
		var b0 := bar * 4.0
		var sec := 0
		if bar >= 16:
			sec = 2
		elif bar >= 8:
			sec = 1
		var pr: Array = prog_b if sec == 1 else prog_a
		var base: int = int(pr[bar % 8])
		_ev(K_TAIKO, b0, 55.0, 1.0, 0.85)
		_ev(K_TAIKO, b0 + 1.5, 60.0, 0.7, 0.4)
		_ev(K_TAIKO, b0 + 2.0, 55.0, 1.0, 0.62)
		if bar % 2 == 1:
			_ev(K_TAIKO, b0 + 3.0, 62.0, 0.6, 0.45)
			_ev(K_TAIKO, b0 + 3.5, 62.0, 0.6, 0.52)
		var sub: float = 0.25 if sec == 1 else 0.5
		var nsub := int(roundf(4.0 / sub))
		for k in nsub:
			var acc: float = 0.16 if k % 2 == 0 else 0.07
			_ev(K_TAIKO, b0 + k * sub, 200.0, 0.2, acc)
		for k in 8:
			_ev(K_SHAMI, b0 + k * 0.5, _f(root, sc, base + int(pat[k])), 0.8, 0.17 if k == 0 else 0.12)
		if bar % 2 == 0:
			for c in [0, 1, 2]:
				_ev(K_SHO, b0, _f(lroot, sc, 5 + base + int(c)), _q(8.0 * bs), 0.028)
		# couleur du monde
		match wi:
			1:
				if bar % 4 == 3:
					_gliss(K_KOTO, root * 2.0, sc, b0 + 2.0, 0, 8, 1, 0.125, 0.1)
			2:
				for j in 3:
					_ev(K_SUZU, b0 + 3.5 + j * 0.05, 2700.0 + 130.0 * j, 0.6, 0.05)
			3:
				if bar % 8 == 0:
					_ev(K_KANE, b0, root, 7.0, 0.22)
				if bar % 2 == 1:
					_ev(K_HYO, b0 + 3.0, 1900.0, 0.15, 0.12)
					_ev(K_HYO, b0 + 3.25, 1900.0, 0.15, 0.1)
			4:
				_ev(K_ANVIL, b0 + 1.0, 1250.0, 0.6, 0.1)
				_ev(K_ANVIL, b0 + 3.0, 1250.0, 0.6, 0.1)
			5:
				_ev(K_HYO, b0 + 1.0, 2400.0, 0.15, 0.06)
				_ev(K_HYO, b0 + 3.0, 2600.0, 0.15, 0.05)
				if bar % 4 == 3:
					_gliss(K_KOTO, lroot, sc, b0 + 2.0, 9, 8, -1, 0.125, 0.1)
	var lead: int = K_FUE if (wi == 2 or wi == 4) else K_SHAKU
	var m1 := _phrase(rng, 15.0, 7, 4, 10, [1.0, 0.5, 0.5, 2.0, 1.5], 0.1)
	var m2 := _vary(rng, m1, 0.5)
	_put(lead, m1, 16.0, lroot, sc, 0, 0.22, bs)
	_put(lead, m2, 32.0, lroot, sc, 2, 0.22, bs)
	_put(lead, _cadence(_vary(rng, m1, 0.3), 5), 48.0, lroot, sc, 1, 0.22, bs)
	_put(lead, m1, 64.0, lroot, sc, 0, 0.22, bs)
	_put(lead, _cadence(_vary(rng, m2, 0.4), 5), 80.0, lroot, sc, 0, 0.22, bs)
	for k in 8:
		_ev(K_TAIKO, 94.0 + k * 0.25, 70.0, 0.4, 0.25 + 0.05 * k)
	var bed := BED_NONE
	var bed_amp := 0.0
	if wi == 1:
		bed = BED_SURF
		bed_amp = 0.04
	elif wi == 3:
		bed = BED_WIND
		bed_amp = 0.03
	elif wi == 4:
		bed = BED_DRONE
		bed_amp = 0.06
	return {"bpm": bpm, "beats": 96.0, "intro": 4.0, "echo": 0.5, "fb": 0.15,
		"bed": bed, "bed_amp": bed_amp, "waves": 4, "drone": root, "rms": 0.15}


# Gardien de salle (Ō-kappa) : court et nerveux, 150 BPM, gamme in en sol.
func _mini(rng: RandomNumberGenerator) -> Dictionary:
	var root := 196.0
	var bs := 60.0 / 150.0
	_intro_mode = true
	for k in 12:
		_ev(K_TAIKO, -4.0 + k * 0.25, 210.0, 0.2, 0.08 + 0.02 * k)
	_intro_mode = false
	var prog := [0, 0, 1, -1, 0, 0, 2, 1, 0, 1, -1, 0]
	var pat := [0, 2, 1, 0, 3, 2, 1, 2]
	for bar in 12:
		var b0 := bar * 4.0
		_ev(K_TAIKO, b0, 58.0, 0.9, 0.75)
		_ev(K_TAIKO, b0 + 2.0, 58.0, 0.9, 0.55)
		if bar % 2 == 1:
			_ev(K_TAIKO, b0 + 2.5, 64.0, 0.6, 0.4)
		for k in 8:
			_ev(K_TAIKO, b0 + k * 0.5, 210.0, 0.2, 0.15 if k % 2 == 0 else 0.07)
		_ev(K_HYO, b0 + 1.0, 1900.0, 0.15, 0.1)
		_ev(K_HYO, b0 + 3.0, 1900.0, 0.15, 0.1)
		var base: int = int(prog[bar])
		for k in 8:
			_ev(K_SHAMI, b0 + k * 0.5, _f(root, IN_SC, base + int(pat[k]) - 2), 0.8, 0.13)
	var m := _phrase(rng, 7.0, 7, 5, 10, [0.5, 0.5, 1.0, 1.5], 0.15)
	_put(K_FUE, m, 8.0, root, IN_SC, 0, 0.2, bs)
	_put(K_FUE, _vary(rng, m, 0.4), 24.0, root, IN_SC, 1, 0.2, bs)
	_put(K_FUE, _cadence(_vary(rng, m, 0.3), 5), 40.0, root, IN_SC, 0, 0.2, bs)
	for k in 4:
		_ev(K_TAIKO, 46.0 + k * 0.5, 66.0, 0.5, 0.3 + 0.08 * k)
	return {"bpm": 150.0, "beats": 48.0, "intro": 4.0, "echo": 0.5, "fb": 0.12, "rms": 0.15}


# Victoire (~3,6 s) : sararin montant, ōdaiko, accord de shō, clochettes.
func _win() -> Dictionary:
	var root := 293.66
	_ev(K_TAIKO, 0.0, 70.0, 1.0, 0.5)
	_gliss(K_KOTO, root, YO, 0.0, -3, 10, 1, 0.125, 0.18)
	_ev(K_TAIKO, 1.5, 70.0, 0.6, 0.35)
	_ev(K_TAIKO, 2.0, 55.0, 1.6, 0.8)
	for c in [0, 2, 4, 5]:
		_ev(K_KOTO, 2.0, _f(root, YO, int(c)), 1.6, 0.16)
	for c in [0, 1, 3, 5]:
		_ev(K_SHO, 2.0, _f(root, YO, int(c)), 1.9, 0.06)
	for j in 4:
		_ev(K_SUZU, 2.0 + j * 0.06, 2600.0 + 150.0 * j, 0.6, 0.08)
	_ev(K_SHAKU, 2.0, _f(root, YO, 5), 1.6, 0.22)
	return {"bpm": 100.0, "beats": 4.0, "loop": false, "tail": 1.2, "echo": 0.5, "fb": 0.25, "rms": 0.16}


# Défaite (~4 s) : coup grave, bonshō lointain, shakuhachi qui retombe.
func _lose() -> Dictionary:
	var root := 146.83
	_ev(K_TAIKO, 0.0, 50.0, 1.8, 0.7)
	_ev(K_KANE, 0.0, 110.0, 4.0, 0.2)
	_ev(K_SHAKU_F, 0.5, _f(root, IN_SC, 6), 2.2, 0.3)
	_ev(K_SHAMI, 2.5, _f(root, IN_SC, -1), 0.8, 0.18)
	_ev(K_SHAMI, 2.75, _f(root, IN_SC, -5), 0.8, 0.2)
	_ev(K_TAIKO, 2.5, 45.0, 1.4, 0.45)
	return {"bpm": 60.0, "beats": 3.0, "loop": false, "tail": 1.2, "echo": 1.0, "fb": 0.3, "rms": 0.14}
