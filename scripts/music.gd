extends RefCounted
## Compositeur + synthétiseur de toute la musique (aucun fichier audio source, aucun échantillon).
## N'est PAS utilisé pendant le jeu : tools/bake_music.gd l'appelle une fois au CI (render(nom) pour chaque
## piste de music_player.gd TRACKS), écrit des WAV que le CI convertit en OGG ; le jeu ne fait que les lire.
##
## Instruments (modèles physiques simples) :
##  - cordes pincées en Karplus-Strong (ligne à retard accordée au retard fractionnaire près, filtre de perte
##    réglé sur la tenue du fondamental et des aigus, position du plectre) : koto (tsume ; ato-oshi = la corde
##    pressée après le pincement monte d'un ton, yuri-iro = vibrato), koto étouffé, shamisen et biwa (sawari :
##    la corde frise sur le sillet, écrêtage asymétrique dans la boucle ; coup de bachi sur la peau) ;
##  - souffles : shakuhachi (fondamental + harmoniques, souffle accordé dans un résonateur, attaque par en
##    dessous, meri qui retombe, vibrato yuri retardé, muraiki), shinobue (plus brillant, vibrato vif),
##    horagai (conque des yamabushi, grondement) ;
##  - membranes : ōdaiko, nagado-daiko, shime-daiko, fuchi (cerclage), kotsuzumi ;
##  - métal et bois : clochettes suzu (secouées), rin, bonshō, fūrin, hyōshigi, mokugyo, enclume ;
##  - shō : anche en table d'onde, deux voix qui battent, souffle qui enfle (accords aitake).
## Gammes : yo, in (miyako-bushi), hirajōshi, kumoi.
##
## Les mondes ont deux couches synchrones de même durée : « wN » (calme, hors combat) et « wN_t » (tension :
## taiko, ostinato) que music_player.gd superpose en combat. Boucles : introduction jouée une fois
## (music_player.LOOP_START) puis corps bouclé ; les queues de notes et de réverbération se replient sur le début
## du corps, les fonds (ressac, vent…) glissent de la fin du corps vers ce qui précède son début : raccord sans
## couture. Jingles (victoire, défaite) : rendu linéaire avec une queue.
## Mixage : deux bus par couche (proche / lointain) vers une réverbération (Freeverb à demi-fréquence), puis
## niveau intégré mesuré comme EBU R128 (pondération K, fenêtres de 400 ms, seuils absolu et relatif), gain
## vers une cible commune à toutes les pistes, limiteur à anticipation sous CEIL : homogène, jamais saturé.

const MP = preload("res://scripts/music_player.gd")

const RATE := 22050
const INV_RS := 1.0 / 1073741824.0
const CEIL := 0.74  # crête maximale (≈ -2,6 dBFS) : marge pour l'encodage OGG (crête finale < -1 dBFS)
const LUFS_CALM := -19.0  # couche calme d'un monde, accueil, sanctuaire
const LUFS_FIGHT := -17.0  # couche calme + tension (combat), gardiens
const LUFS_JINGLE := -17.0

# Gammes pentatoniques japonaises (demi-tons)
const YO := [0, 2, 5, 7, 9]
const IN_SC := [0, 1, 5, 7, 8]  # in / miyako-bushi
const HIRA := [0, 2, 3, 7, 8]
const KUMOI := [0, 2, 3, 7, 9]

# Bonshō (partiels inharmoniques, doublets battants)
const KANE_R := [0.5, 0.503, 1.0, 1.006, 1.52, 2.0, 2.74, 3.2]
const KANE_A := [0.55, 0.45, 0.8, 0.6, 0.35, 0.3, 0.15, 0.08]
const KANE_D := [0.32, 0.34, 0.5, 0.52, 0.9, 1.2, 2.0, 3.0]
const RIN_R := [1.0, 1.0025, 2.71, 2.716, 5.18, 8.4]
const RIN_A := [1.0, 0.8, 0.45, 0.35, 0.18, 0.08]
const RIN_D := [0.7, 0.75, 1.5, 1.6, 3.0, 5.0]
const FURIN_R := [1.0, 2.76, 5.4, 8.9]
const FURIN_A := [1.0, 0.45, 0.25, 0.1]
const FURIN_D := [2.6, 4.0, 7.0, 11.0]
const ANVIL_R := [1.0, 2.76, 5.4, 7.18]
const ANVIL_A := [1.0, 0.55, 0.35, 0.15]
const ANVIL_D := [4.5, 7.0, 11.0, 15.0]
const SUZU_R := [1.0, 2.32, 4.1]
const SUZU_A := [1.0, 0.6, 0.3]
const SUZU_D := [10.0, 14.0, 20.0]
# Anche du shō (harmoniques)
const SHO_H := [1.0, 0.6, 0.45, 0.32, 0.22, 0.15, 0.1, 0.06, 0.04, 0.025]
# Force relative des vagues du ressac
const SURF_STR := [1.0, 0.7, 0.9, 0.75]

enum { K_KOTO, K_KOTO_M, K_SHAMI, K_BIWA, K_SHAKU, K_FUE, K_HORA, K_SHO,
	K_ODAIKO, K_TAIKO, K_SHIME, K_KA, K_TSUZUMI, K_HYO, K_MOKU,
	K_SUZU, K_RIN, K_KANE, K_FURIN, K_ANVIL }
# Console : gain de chaque instrument (les nuances des partitions restent relatives). Les graves des taiko
# sont modérés (inaudibles sur un haut-parleur de téléphone, ils pèseraient pourtant dans le niveau mesuré) ;
# les attaques (shime, fuchi, shamisen) portent la pulsation.
const TRIM := {K_KOTO: 1.3, K_KOTO_M: 1.35, K_SHAMI: 1.4, K_BIWA: 1.2, K_ODAIKO: 0.6, K_TAIKO: 0.8,
	K_SHIME: 1.3, K_KA: 1.2}
# ornements (écriture : ^ v ~ * ')
enum { O_NONE, O_UP, O_FALL, O_VIB, O_BREATH, O_GRACE }
enum { BED_NONE, BED_SURF, BED_WIND, BED_DRONE, BED_FIRE, BED_DEEP }

var _evs: Array = []
var _intro_mode := false
var _layer := 0  # 0 = calme, 1 = tension
var _notes := {}
var _rs := 12345
var _hum := RandomNumberGenerator.new()  # humanisation (léger décalage, nuance)
var _sho_tab := PackedFloat32Array()
var _prof := {}
var _synth_ms := 0

# --- rendu en cours ---
var _bs := 1.0  # secondes par temps
var _spb := 1.0  # échantillons par temps
var _loop := true
var _intro_n := 0
var _body_n := 0
var _total_n := 0


# ===================== API =====================

## Compose et synthétise la piste `tname` (voir music_player.gd TRACKS) : {nom de fichier: AudioStreamWAV}.
## Un monde donne deux fichiers (« wN » calme, « wN_t » tension). Vide si nom inconnu.
func render(tname: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + (hash(tname) & 0xffffff)
	_hum.seed = 777 + (hash(tname) & 0xffff)
	_evs = []
	_intro_mode = false
	_layer = 0
	_notes.clear()
	_rs = 12345 + (hash(tname) & 0xffff)
	var c: Dictionary = {}
	match tname:
		"menu":
			c = _menu(rng)
		"shrine":
			c = _shrine(rng)
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
		"w6":
			c = _w6(rng)
		"w7":
			c = _w7(rng)
		"w8":
			c = _w8(rng)
		"boss1", "boss2", "boss3", "boss4", "boss5", "boss6", "boss7", "boss8":
			c = _boss(rng, tname.right(1).to_int())
		"mini":
			c = _mini(rng)
		"win":
			c = _win()
		"lose":
			c = _lose()
		_:
			return {}
	_intro_mode = false
	_layer = 0
	var beats: float = c["beats"]
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
		_intro_n = 0
		_body_n = 0
		_total_n = int(roundf(beats * _spb + float(c.get("tail", 1.5)) * RATE))
	var layers := 1
	for ev in _evs:
		if int(ev[6]) == 1:
			layers = 2
			break
	var mixes: Array = []
	var tm := Time.get_ticks_msec()
	for li in layers:
		var near := _mix_bus(li, false)
		var far := _mix_bus(li, true)
		_prof["mix"] = int(_prof.get("mix", 0)) + Time.get_ticks_msec() - tm
		tm = Time.get_ticks_msec()
		var sn: float = float(c.get("send_near", 0.12))
		var sf: float = float(c.get("send_far", 0.38))
		var rin := PackedFloat32Array()
		rin.resize(_total_n)
		for i in _total_n:
			rin[i] = near[i] * sn + far[i] * sf
		var rev := _reverb(rin, float(c.get("room", 0.84)), float(c.get("damp", 0.35)))
		_prof["rev"] = int(_prof.get("rev", 0)) + Time.get_ticks_msec() - tm
		tm = Time.get_ticks_msec()
		rin = PackedFloat32Array()
		var wet: float = float(c.get("wet", 1.0))
		for i in _total_n:
			near[i] += far[i] + rev[i] * wet
		if li == 0:
			var bed := _bed(c)
			for i in _total_n:
				near[i] += bed[i]
		mixes.append(near)
		_prof["bed"] = int(_prof.get("bed", 0)) + Time.get_ticks_msec() - tm
		tm = Time.get_ticks_msec()
	_evs = []
	_notes.clear()
	var tgt_c: float = float(c.get("lufs", LUFS_CALM))
	var tgt_f: float = float(c.get("lufs_fight", LUFS_FIGHT))
	var outs := _master(mixes, tgt_c, tgt_f)
	_prof["master"] = int(_prof.get("master", 0)) + Time.get_ticks_msec() - tm
	print("  temps %s : %s (synthèse des notes %d ms)" % [tname, str(_prof), _synth_ms])
	_prof = {}
	_synth_ms = 0
	var res := {}
	for li in outs.size():
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = RATE
		w.stereo = false
		w.data = outs[li]
		w.loop_mode = AudioStreamWAV.LOOP_DISABLED
		res[tname if li == 0 else tname + "_t"] = w
	return res


# ===================== mixage =====================

func _far(kind: int) -> bool:
	return not kind in [K_ODAIKO, K_TAIKO, K_SHIME, K_KA, K_TSUZUMI, K_HYO, K_MOKU, K_ANVIL, K_SHAMI]


## Somme des notes d'une couche sur un bus. Corps de boucle : une note qui dépasse la fin se replie sur le début
## du corps. Introduction / jingle : linéaire, coupée en fondu bref à la fin de l'intro.
func _mix_bus(layer: int, far: bool) -> PackedFloat32Array:
	var acc := PackedFloat32Array()
	acc.resize(_total_n)
	acc.fill(0.0)
	var nb := _body_n
	var o := _intro_n
	for ev in _evs:
		var e: Array = ev
		var kind: int = e[0]
		if int(e[6]) != layer or _far(kind) != far:
			continue
		var note: PackedFloat32Array = _note(kind, float(e[2]), float(e[3]), int(e[5]), int(e[9]))
		var gain: float = e[4]
		var s := int(roundf(float(e[1]) * _spb)) + int(e[8])
		var m := note.size()
		if _loop and not bool(e[7]):
			m = mini(m, nb)
			var st := posmod(s, nb)
			var first := mini(m, nb - st)
			var a := o + st
			for j in first:
				acc[a + j] += note[j] * gain
			var b := o - first
			for j in range(first, m):
				acc[b + j] += note[j] * gain
		else:
			var start := s
			var limit := _total_n
			if _loop:
				start = o + s
				limit = o
			var j0 := maxi(0, -start)
			var j1 := mini(m, limit - start)
			if j1 <= j0:
				continue
			var fl := 0
			if j1 < m:
				fl = mini(1500, j1 - j0)
			var jm := j1 - fl
			for j in range(j0, jm):
				acc[start + j] += note[j] * gain
			for j in range(jm, j1):
				acc[start + j] += note[j] * gain * float(j1 - j) / float(fl)
	return acc


## Réverbération (Freeverb : 6 filtres en peigne amortis en parallèle, 3 passe-tout en série), calculée à
## demi-fréquence (queue plus douce, deux fois moins de calcul). Boucle : la queue au-delà de la fin se replie
## sur le début du corps (système linéaire : raccord exact).
func _reverb(x: PackedFloat32Array, room: float, damp: float) -> PackedFloat32Array:
	var n := x.size()
	var half := n >> 1
	var tail := int(3.5 * RATE) >> 1
	var hn := half + tail
	var h := PackedFloat32Array()
	h.resize(hn)
	h.fill(0.0)
	for k in half:
		h[k] = (x[2 * k] + x[2 * k + 1]) * 0.5
	var l1 := 279
	var l2 := 297
	var l3 := 319
	var l4 := 339
	var l5 := 355
	var l6 := 372
	var c1 := PackedFloat32Array()
	c1.resize(l1)
	c1.fill(0.0)
	var c2 := PackedFloat32Array()
	c2.resize(l2)
	c2.fill(0.0)
	var c3 := PackedFloat32Array()
	c3.resize(l3)
	c3.fill(0.0)
	var c4 := PackedFloat32Array()
	c4.resize(l4)
	c4.fill(0.0)
	var c5 := PackedFloat32Array()
	c5.resize(l5)
	c5.fill(0.0)
	var c6 := PackedFloat32Array()
	c6.resize(l6)
	c6.fill(0.0)
	var m1 := 139
	var m2 := 85
	var m3 := 56
	var a1 := PackedFloat32Array()
	a1.resize(m1)
	a1.fill(0.0)
	var a2 := PackedFloat32Array()
	a2.resize(m2)
	a2.fill(0.0)
	var a3 := PackedFloat32Array()
	a3.resize(m3)
	a3.fill(0.0)
	var i1 := 0
	var i2 := 0
	var i3 := 0
	var i4 := 0
	var i5 := 0
	var i6 := 0
	var j1 := 0
	var j2 := 0
	var j3 := 0
	var f1 := 0.0
	var f2 := 0.0
	var f3 := 0.0
	var f4 := 0.0
	var f5 := 0.0
	var f6 := 0.0
	var dm := damp
	var dk := 1.0 - damp
	var y := PackedFloat32Array()
	y.resize(hn)
	for k in hn:
		var inp: float = h[k] * 0.12
		var o1: float = c1[i1]
		f1 = o1 * dk + f1 * dm
		c1[i1] = inp + f1 * room
		i1 += 1
		if i1 >= l1:
			i1 = 0
		var o2: float = c2[i2]
		f2 = o2 * dk + f2 * dm
		c2[i2] = inp + f2 * room
		i2 += 1
		if i2 >= l2:
			i2 = 0
		var o3: float = c3[i3]
		f3 = o3 * dk + f3 * dm
		c3[i3] = inp + f3 * room
		i3 += 1
		if i3 >= l3:
			i3 = 0
		var o4: float = c4[i4]
		f4 = o4 * dk + f4 * dm
		c4[i4] = inp + f4 * room
		i4 += 1
		if i4 >= l4:
			i4 = 0
		var o5: float = c5[i5]
		f5 = o5 * dk + f5 * dm
		c5[i5] = inp + f5 * room
		i5 += 1
		if i5 >= l5:
			i5 = 0
		var o6: float = c6[i6]
		f6 = o6 * dk + f6 * dm
		c6[i6] = inp + f6 * room
		i6 += 1
		if i6 >= l6:
			i6 = 0
		var s := o1 + o2 + o3 + o4 + o5 + o6
		var b1: float = a1[j1]
		a1[j1] = s + b1 * 0.5
		s = b1 - s
		j1 += 1
		if j1 >= m1:
			j1 = 0
		var b2: float = a2[j2]
		a2[j2] = s + b2 * 0.5
		s = b2 - s
		j2 += 1
		if j2 >= m2:
			j2 = 0
		var b3: float = a3[j3]
		a3[j3] = s + b3 * 0.5
		s = b3 - s
		j3 += 1
		if j3 >= m3:
			j3 = 0
		y[k] = s
	h = PackedFloat32Array()
	if _loop:
		var ho := _intro_n >> 1
		var hb := half - ho
		if hb > 0:
			for j in tail:
				var t := ho + (j % hb)
				y[t] += y[half + j]
	var out := PackedFloat32Array()
	out.resize(n)
	var hs := _intro_n >> 1
	for k in half:
		var v: float = y[k]
		out[2 * k] = v
		var nx := 0.0
		if k + 1 < half:
			nx = y[k + 1]
		elif _loop:
			nx = y[hs]
		out[2 * k + 1] = 0.5 * (v + nx)
	if n & 1:
		out[n - 1] = y[half - 1] * 0.5 if half > 0 else 0.0
	return out


## Couches -> PCM 16 bits. Niveau intégré (pondération K, EBU R128) : la couche calme vers tgt_c, la somme
## calme + tension vers tgt_f (gain de la tension résolu par dichotomie) ; limiteur à anticipation calculé sur
## la somme, appliqué aux deux couches (leur somme, comme chacune, reste sous CEIL).
func _master(mixes: Array, tgt_c: float, tgt_f: float) -> Array:
	var c: PackedFloat32Array = mixes[0]
	var two := mixes.size() > 1
	var t := PackedFloat32Array()
	if two:
		t = mixes[1]
	var kc := _kweight(c)
	var kt := PackedFloat32Array()
	if two:
		kt = _kweight(t)
	# énergies par tranche de 100 ms (moyennes des carrés), et terme croisé
	var sub := int(0.1 * RATE * 0.5)
	var nsb := maxi(1, kc.size() / sub)
	var ec := PackedFloat32Array()
	ec.resize(nsb)
	var et := PackedFloat32Array()
	et.resize(nsb)
	var ex := PackedFloat32Array()
	ex.resize(nsb)
	for b in nsb:
		var s1 := 0.0
		var s2 := 0.0
		var s3 := 0.0
		for i in range(b * sub, mini(kc.size(), (b + 1) * sub)):
			var u: float = kc[i]
			s1 += u * u
			if two:
				var v: float = kt[i]
				s2 += v * v
				s3 += 2.0 * u * v
		ec[b] = s1 / sub
		et[b] = s2 / sub
		ex[b] = s3 / sub
	var gc := 1.0
	var gt := 0.0
	var lc := _lufs(ec, et, ex, 1.0, 0.0)
	if two:
		gc = pow(10.0, (tgt_c - lc) / 20.0)
		var lo := 0.0
		var hi := 12.0 * gc
		for it in 30:
			var mid := (lo + hi) * 0.5
			if _lufs(ec, et, ex, gc, mid) < tgt_f:
				lo = mid
			else:
				hi = mid
		gt = (lo + hi) * 0.5
	else:
		gc = pow(10.0, (tgt_c - lc) / 20.0)
	print("  niveau : calme %.1f LUFS (gain %.2f)%s" % [lc + 20.0 * log(gc) / log(10.0), gc, ("  tension gain %.2f -> %.1f LUFS" % [gt, _lufs(ec, et, ex, gc, gt)]) if two else ""])
	# gain de limitation sur la somme
	var n := c.size()
	var sum := PackedFloat32Array()
	sum.resize(n)
	for i in n:
		var v: float = c[i] * gc
		if two:
			v += t[i] * gt
		sum[i] = v
	var env := _limiter(sum)
	sum = PackedFloat32Array()
	var outs: Array = []
	for li in mixes.size():
		var src: PackedFloat32Array = mixes[li]
		var g := gc if li == 0 else gt
		var bytes := PackedByteArray()
		bytes.resize(n * 2)
		for i in n:
			var v: float = clampf(src[i] * g * env[i], -CEIL, CEIL)
			bytes.encode_s16(i * 2, int(v * 32767.0))
		outs.append(bytes)
	return outs


## Gain du limiteur (≤ 1) : montée en ~2 ms avant chaque crête, retour en ~90 ms. Boucle : calculé en anneau sur
## le corps (deux tours), pas de saut de gain au raccord.
func _limiter(x: PackedFloat32Array) -> PackedFloat32Array:
	var n := x.size()
	var r := PackedFloat32Array()
	r.resize(n)
	var hit := false
	for i in n:
		var a := absf(x[i])
		if a > CEIL:
			r[i] = CEIL / a
			hit = true
		else:
			r[i] = 1.0
	if not hit:
		return r
	var att := 1.0 / 44.0
	var rel := 1.0 / 2000.0
	var ring := _loop and _body_n > 0
	var o := _intro_n if ring else n
	# arrière (anticipation) : en anneau sur le corps, puis l'intro qui précède son début
	var a := PackedFloat32Array()
	a.resize(n)
	var g := 1.0
	if ring:
		for lap in 2:
			for i in range(n - 1, o - 1, -1):
				g = minf(r[i], g + att)
				a[i] = g
	for i in range(o - 1, -1, -1):
		g = minf(r[i], g + att)
		a[i] = g
	# avant (retour) : l'intro, puis le corps en anneau (le second tour repart de la fin du corps)
	g = 1.0
	for i in o:
		g = minf(a[i], g + rel)
		r[i] = g
	if ring:
		for lap in 2:
			for i in range(o, n):
				g = minf(a[i], g + rel)
				r[i] = g
	return r


## Pondération K (BS.1770) sur le signal ramené à demi-fréquence.
func _kweight(x: PackedFloat32Array) -> PackedFloat32Array:
	var fs := RATE * 0.5
	var half := x.size() >> 1
	var out := PackedFloat32Array()
	out.resize(half)
	# plateau aigu (+4 dB vers 1,7 kHz)
	var gdb := 3.99984
	var f0 := 1681.974
	var q := 0.7071752
	var aa := pow(10.0, gdb / 40.0)
	var w0 := TAU * f0 / fs
	var al := sin(w0) / (2.0 * q)
	var cs := cos(w0)
	var sa := 2.0 * sqrt(aa) * al
	var a0 := (aa + 1.0) - (aa - 1.0) * cs + sa
	var b0 := aa * ((aa + 1.0) + (aa - 1.0) * cs + sa) / a0
	var b1 := -2.0 * aa * ((aa - 1.0) + (aa + 1.0) * cs) / a0
	var b2 := aa * ((aa + 1.0) + (aa - 1.0) * cs - sa) / a0
	var a1 := 2.0 * ((aa - 1.0) - (aa + 1.0) * cs) / a0
	var a2 := ((aa + 1.0) - (aa - 1.0) * cs - sa) / a0
	# passe-haut (38 Hz)
	var hw := TAU * 38.13547 / fs
	var hal := sin(hw) / (2.0 * 0.5003270)
	var hc := cos(hw)
	var ha0 := 1.0 + hal
	var hb0 := (1.0 + hc) * 0.5 / ha0
	var hb1 := -(1.0 + hc) / ha0
	var hb2 := hb0
	var ha1 := -2.0 * hc / ha0
	var ha2 := (1.0 - hal) / ha0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var z1 := 0.0
	var z2 := 0.0
	var v1 := 0.0
	var v2 := 0.0
	for k in half:
		var xin: float = (x[2 * k] + x[2 * k + 1]) * 0.5
		var yo := b0 * xin + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = xin
		y2 = y1
		y1 = yo
		var zo := hb0 * yo + hb1 * z1 + hb2 * z2 - ha1 * v1 - ha2 * v2
		z2 = z1
		z1 = yo
		v2 = v1
		v1 = zo
		out[k] = zo
	return out


## Sonie intégrée (LUFS) de gc·calme + gt·tension : blocs de 400 ms (4 tranches), seuil absolu -70, relatif -10.
func _lufs(ec: PackedFloat32Array, et: PackedFloat32Array, ex: PackedFloat32Array, gc: float, gt: float) -> float:
	var nb := ec.size()
	var gg := gc * gc
	var tt := gt * gt
	var ct := gc * gt
	var blocks := PackedFloat32Array()
	for b in range(0, maxi(1, nb - 3)):
		var e := 0.0
		for q in range(b, mini(nb, b + 4)):
			e += gg * ec[q] + tt * et[q] + ct * ex[q]
		e /= 4.0
		blocks.append(e)
	var s := 0.0
	var cnt := 0
	for e in blocks:
		if -0.691 + 10.0 * log(maxf(e, 1e-12)) / log(10.0) > -70.0:
			s += e
			cnt += 1
	if cnt == 0:
		return -70.0
	var rel := -0.691 + 10.0 * log(s / cnt) / log(10.0) - 10.0
	s = 0.0
	cnt = 0
	for e in blocks:
		var l := -0.691 + 10.0 * log(maxf(e, 1e-12)) / log(10.0)
		if l > -70.0 and l > rel:
			s += e
			cnt += 1
	if cnt == 0:
		return -70.0
	return -0.691 + 10.0 * log(s / cnt) / log(10.0)


# ===================== fond continu =====================

## Fond (ressac, vent, bourdon, braises, eaux profondes) de la couche calme. Le bruit est engendré en continu
## depuis un pré-roulement ; au raccord de boucle, la fin du corps glisse vers les échantillons qui précèdent
## son début (fin de l'intro ou pré-roulement) : raccord continu. Le bourdon, périodique, s'ajoute à part.
func _bed(c: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_total_n)
	out.fill(0.0)
	var typ: int = int(c.get("bed", BED_NONE))
	if typ == BED_NONE:
		return out
	var amp: float = float(c.get("bed_amp", 0.0))
	var waves: int = int(c.get("waves", 4))
	var xf := int(0.15 * RATE)
	var pre := xf
	var n := _total_n + pre
	var g := PackedFloat32Array()
	g.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var ck := 0.0
	var ckp := 0.0
	var rs := 777 + typ * 31
	var k := 0
	while k < n:
		var i := k - pre
		var ph := 0.0
		var fade := 1.0
		if _loop:
			if i < _intro_n:
				ph = float(i - _intro_n + _body_n) / float(_body_n)
				if _intro_n > 0 and i >= 0:
					fade = float(i) / float(_intro_n)
			else:
				ph = float(i - _intro_n) / float(_body_n)
		else:
			ph = float(maxi(i, 0)) / float(_total_n)
		ph = fposmod(ph, 1.0)
		var cf := 0.05
		var gn := 0.0
		var gw := 0.0
		var wf := 800.0
		var pc := 0.0
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
				cf = 0.015 + 0.09 * e
				gn = amp * e * 1.8 / sqrt(cf)
			BED_WIND:
				var e := 0.55 + 0.3 * sin(TAU * ph * 3.0) + 0.15 * sin(TAU * ph * 7.0)
				cf = 0.02 + 0.03 * e
				gn = amp * e * 1.8 / sqrt(cf)
				gw = amp * float(c.get("whistle", 0.0)) * maxf(0.0, sin(TAU * ph * 2.0 + 1.0))
				wf = 700.0 + 350.0 * sin(TAU * ph * 5.0)
			BED_DRONE:
				cf = 0.03
				gn = amp * 0.5
			BED_FIRE:
				var e := 0.7 + 0.3 * sin(TAU * ph * 4.0)
				cf = 0.012
				gn = amp * e * 1.8 / sqrt(cf)
				pc = 0.0012 * e
			BED_DEEP:
				var e := 0.6 + 0.4 * sin(TAU * ph * 2.0) * sin(TAU * ph * 3.0)
				cf = 0.006 + 0.004 * e
				gn = amp * e * 1.8 / sqrt(cf)
		gn *= fade
		gw *= fade
		var wr := 0.995
		var wb1 := 2.0 * wr * cos(TAU * wf / RATE)
		var wb2 := wr * wr
		var end := mini(k + 64, n)
		for j in range(k, end):
			rs = (rs * 1103515245 + 12345) & 0x7fffffff
			var nz := float(rs) * INV_RS - 1.0
			lp1 += cf * (nz - lp1)
			lp2 += cf * (lp1 - lp2)
			var v := lp2 * gn
			if gw > 0.0:
				var yw := wb1 * y1 - wb2 * y2 + nz * 0.02
				y2 = y1
				y1 = yw
				v += yw * gw
			if pc > 0.0:
				rs = (rs * 1103515245 + 12345) & 0x7fffffff
				if float(rs) * INV_RS * 0.5 < pc:
					ck = (float(rs & 1023) / 1023.0 - 0.5) * amp * 9.0 * fade
				var hp := ck - ckp
				ckp = ck
				ck *= 0.82
				v += hp
			g[j] = v
		k = end
	if _loop and _body_n > xf:
		var o := _intro_n
		var e := _total_n
		for j in xf:
			var t := float(j + 1) / float(xf)
			var a := pre + e - xf + j
			g[a] = g[a] * sqrt(1.0 - t) + g[pre + o - xf + j] * sqrt(t)
	for i in _total_n:
		out[i] = g[pre + i]
	# bourdon : nombre entier de cycles sur le corps (périodique), pulsé sur les temps
	var drone_f: float = float(c.get("drone", 0.0))
	if drone_f > 0.0:
		var span := _body_n if _loop else _total_n
		var cycles := maxf(1.0, roundf(drone_f * span / RATE))
		var cyc2 := cycles + maxf(1.0, roundf(0.7 * span / RATE))  # seconde voix qui bat (~0,7 Hz)
		var w1 := TAU * cycles / span
		var w2 := TAU * cyc2 / span
		var da: float = float(c.get("drone_amp", amp))
		var pulse: float = float(c.get("pulse", 0.6))
		for i in _total_n:
			var rel := i - _intro_n if _loop else i
			var fr := fposmod(float(rel) / _spb, 1.0)
			var e := da * ((1.0 - pulse) + pulse * exp(-4.0 * fr))
			if _loop and i < _intro_n and _intro_n > 0:
				e *= float(i) / float(_intro_n)
			out[i] += (sin(w1 * rel) + 0.5 * sin(w2 * rel) + 0.35 * sin(2.0 * w1 * rel) + 0.2 * sin(3.0 * w1 * rel)) * e
	return out


# ===================== instruments =====================

func _note(kind: int, freq: float, dur: float, orn: int, v: int) -> PackedFloat32Array:
	var key := "%d_%d_%d_%d_%d" % [kind, int(freq * 8.0), int(dur * 100.0), orn, v]
	if _notes.has(key):
		return _notes[key]
	var t0 := Time.get_ticks_usec()
	var s := _synth(kind, freq, dur, orn, v)
	_synth_ms += (Time.get_ticks_usec() - t0) / 1000
	_notes[key] = s
	return s


func _synth(kind: int, f: float, dur: float, orn: int, v: int) -> PackedFloat32Array:
	match kind:
		K_KOTO, K_KOTO_M:
			var p0 := 0.0
			var late := 0.0
			var vib := 0.0
			match orn:
				O_UP:
					p0 = -2.0
				O_FALL:
					late = -1.0
				O_VIB:
					vib = 0.22
			if kind == K_KOTO_M:
				return _ks(f, dur, 0.35, 0.05, 0.45, 0.16 + 0.03 * v, 0.0, p0, late, 0.0, 0.25, 0.0, 0.0)
			var t60 := clampf(3.6 * pow(200.0 / f, 0.4), 1.1, 4.5)
			return _ks(f, dur, t60, 0.3, 0.6, 0.13 + 0.04 * v, 0.0, p0, late, vib, 0.35, 0.0, 0.0)
		K_SHAMI:
			var p0 := -1.0 if orn == O_UP else 0.0
			var late := -1.0 if orn == O_FALL else 0.0
			return _ks(f, dur, clampf(1.3 * sqrt(220.0 / f), 0.5, 1.8), 0.3, 0.9, 0.07 + 0.02 * v, 0.6, p0, late, 0.0, 0.7, 0.6, 190.0)
		K_BIWA:
			var p0 := -2.0 if orn == O_UP else 0.0
			var late := -1.0 if orn == O_FALL else 0.0
			var vib := 0.3 if orn == O_VIB else 0.0
			return _ks(f, dur, 3.0, 0.3, 0.8, 0.1 + 0.02 * v, 0.55, p0, late, vib, 1.0, 0.45, 120.0)
		K_SHAKU, K_FUE, K_HORA:
			return _wind(kind, f, dur, orn, v)
		K_SHO:
			return _sho(f, dur)
		K_ODAIKO:
			return _membrane(f, dur, [1.0, 1.59, 2.14, 2.92], [1.0, 0.65, 0.45, 0.3], [3.0, 4.5, 6.5, 9.0], 0.5, 0.05, 0.8, 0.15, 20.0, 0.3)
		K_TAIKO:
			return _membrane(f, dur, [1.0, 1.59, 2.14, 2.65], [1.0, 0.6, 0.42, 0.25], [6.0, 8.5, 11.0, 15.0], 0.35, 0.03, 0.7, 0.25, 28.0, 0.4)
		K_SHIME:
			return _membrane(f, dur, [1.0, 1.5, 2.0, 2.65], [1.0, 0.6, 0.35, 0.2], [26.0, 34.0, 44.0, 55.0], 0.12, 0.008, 0.8, 0.45, 55.0, 0.6)
		K_TSUZUMI:
			return _membrane(f, dur, [1.0, 1.59, 2.14, 2.92], [1.0, 0.35, 0.2, 0.08], [8.0, 14.0, 20.0, 26.0], -0.18, 0.05, 0.3, 0.3, 50.0, 0.3)
		K_KA:
			return _membrane(f, dur, [1.0, 2.04, 3.17, 4.6], [1.0, 0.6, 0.35, 0.2], [80.0, 110.0, 140.0, 180.0], 0.0, 0.01, 0.5, 0.6, 180.0, 0.7)
		K_HYO:
			return _membrane(f, dur, [1.0, 2.43, 3.9, 5.3], [1.0, 0.5, 0.25, 0.12], [40.0, 55.0, 75.0, 90.0], 0.0, 0.01, 0.4, 0.7, 260.0, 0.9)
		K_MOKU:
			return _membrane(f, dur, [1.0, 2.6, 4.1, 5.9], [1.0, 0.3, 0.12, 0.05], [24.0, 42.0, 60.0, 80.0], 0.03, 0.01, 0.2, 0.4, 120.0, 0.35)
		K_SUZU:
			return _suzu(f, dur)
		K_RIN:
			return _bell(f, dur, RIN_R, RIN_A, RIN_D, 0.25)
		K_KANE:
			# (f = hauteur du bourdonnement grave ; le son de frappe est à l'octave)
			var s := _bell(f * 2.0, dur, KANE_R, KANE_A, KANE_D, 0.6)
			return _thud(s, f * 1.8, 0.5)
		K_FURIN:
			return _bell(f, dur, FURIN_R, FURIN_A, FURIN_D, 0.3)
		K_ANVIL:
			return _bell(f, dur, ANVIL_R, ANVIL_A, ANVIL_D, 0.6)
	return PackedFloat32Array([0.0])


## Corde pincée (Karplus-Strong). t60 : tenue du fondamental (s), t_hi : tenue vers 3,5 kHz (filtre de perte
## résolu pour ces deux temps), bright : couleur du pincement, pos : position du plectre (fraction de corde),
## buzz : sawari, p0 : départ en demi-tons sous la note (ato-oshi, rejoint en 0,16 s), late : inflexion
## tardive (hiki-iro), vib : vibrato (yuri-iro), pick : bruit du plectre, thump : coup sur la peau (Hz thump_f).
func _ks(freq: float, dur: float, t60: float, t_hi: float, bright: float, pos: float, buzz: float,
		p0: float, late: float, vib: float, pick: float, thump: float, thump_f: float) -> PackedFloat32Array:
	var n := maxi(256, int(dur * RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	# filtre de perte y += c (x - y) : |H| vers 3,5 kHz réglé pour t_hi (par période), gain g pour t60
	var whi := TAU * minf(maxf(3500.0, freq * 3.0), RATE * 0.45) / RATE
	var ghi := pow(0.001, 1.0 / (freq * maxf(t_hi, 0.01)))
	var lo := 0.02
	var hi := 1.0
	for it in 22:
		var cm := (lo + hi) * 0.5
		var am := 1.0 - cm
		var hm := cm / sqrt(1.0 - 2.0 * am * cos(whi) + am * am)
		if hm < ghi:
			lo = cm
		else:
			hi = cm
	var damp := (lo + hi) * 0.5
	var w0 := TAU * freq / RATE
	var a1 := 1.0 - damp
	var h0 := damp / sqrt(1.0 - 2.0 * a1 * cos(w0) + a1 * a1)
	var g := minf(0.9995, pow(0.001, 1.0 / (freq * t60)) / h0)
	var lpd := atan2(a1 * sin(w0), 1.0 - a1 * cos(w0)) / w0
	var d0 := maxf(2.0, float(RATE) / freq - lpd)
	var dstart := d0 * pow(2.0, -p0 / 12.0)
	var size := 64
	while size < int(maxf(d0, dstart) * 1.25) + 8:
		size *= 2
	var mask := size - 1
	var buf := PackedFloat32Array()
	buf.resize(size)
	buf.fill(0.0)
	# excitation : bruit coloré, peigne de la position du plectre, sans composante continue
	var ln := maxi(2, int(dstart))
	var exc := PackedFloat32Array()
	exc.resize(ln)
	var rs := _rs
	var lp := 0.0
	for k in ln:
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		lp += bright * (float(rs) * INV_RS - 1.0 - lp)
		exc[k] = lp
	var pp := clampi(int(pos * ln), 1, ln - 1)
	for k in range(ln - 1, pp - 1, -1):
		exc[k] -= exc[k - pp]
	var mean := 0.0
	for k in ln:
		mean += exc[k]
	mean /= ln
	var pk := 0.0001
	for k in ln:
		exc[k] -= mean
		pk = maxf(pk, absf(exc[k]))
	for k in ln:
		buf[k] = exc[k] / pk
	var th := 1.0 - buzz * 0.7
	var wi := ln
	var y := 0.0
	var d := dstart
	var blk := 0.0
	var end := n
	var hx := 0.0
	var hy := 0.0
	var bend := p0 != 0.0 or late != 0.0 or vib != 0.0
	# retard fractionnaire par passe-tout (Thiran, ordre 1) : n'amortit pas les notes aiguës
	var ni := 0
	var cc := 0.0
	var ap := 0.0
	var x1 := 0.0
	var dl := -1.0
	for i in n:
		if (bend and (i & 15) == 0) or dl < 0.0:
			var t := float(i) / RATE
			var sm := 0.0
			if p0 != 0.0:
				var u := clampf(t / 0.16, 0.0, 1.0)
				sm += p0 * (1.0 - u * u * (3.0 - 2.0 * u))
			if late != 0.0:
				var u2 := clampf((t - 0.3) / 0.18, 0.0, 1.0)
				sm += late * u2 * u2 * (3.0 - 2.0 * u2)
			if vib != 0.0:
				sm += vib * sin(TAU * 5.0 * t) * clampf((t - 0.25) * 3.0, 0.0, 1.0)
			d = d0 * pow(2.0, -sm / 12.0)
		if d != dl:
			dl = d
			ni = maxi(1, int(d - 0.1))
			var fp := d - float(ni)
			cc = (1.0 - fp) / (1.0 + fp)
		var xn: float = buf[(wi - ni) & mask]
		ap = cc * xn + x1 - cc * ap
		x1 = xn
		y += damp * (ap - y)
		var o := y * g
		if o > th:
			o = th + (o - th) * 0.3
		buf[wi & mask] = o
		wi += 1
		# sortie sans composante continue (le sawari en crée une)
		hy = o - hx + 0.996 * hy
		hx = o
		out[i] = hy
		blk = maxf(blk, absf(o))
		if (i & 511) == 511:
			if blk < 0.0004 and i > 4 * ln:
				end = i + 1
				break
			blk = 0.0
	_rs = rs
	if end < n:
		out.resize(end)
	var rel := mini(int(0.03 * RATE), end / 4)
	for k in rel:
		out[end - 1 - k] *= float(k) / float(rel)
	if pick > 0.0:
		var pn := mini(end, int(0.007 * RATE))
		var prev := 0.0
		rs = _rs
		for i in pn:
			rs = (rs * 1103515245 + 12345) & 0x7fffffff
			var nz := float(rs) * INV_RS - 1.0
			out[i] += (nz - prev) * pick * 0.5 * (1.0 - float(i) / pn)
			prev = nz
		_rs = rs
	if thump > 0.0:
		var tn := mini(end, int(0.09 * RATE))
		var ph := 0.0
		for i in tn:
			var t := float(i) / RATE
			ph += TAU * thump_f * (1.0 + 0.6 * exp(-t * 60.0)) / RATE
			out[i] += sin(ph) * exp(-t * 42.0) * thump
	return _norm(out, 1.0)


## Souffles : shakuhachi, shinobue, horagai. Fondamental + harmoniques (dosage selon la force du souffle),
## souffle accordé (résonateur sur la note) et souffle d'air, enveloppe qui enfle, vibrato retardé.
func _wind(kind: int, freq: float, dur: float, orn: int, v: int) -> PackedFloat32Array:
	var h2 := 0.3
	var h3 := 0.16
	var h4 := 0.06
	var breath := 2.0
	var air := 0.018
	var vr := 4.6 + 0.3 * v
	var vd := 0.18  # demi-tons
	var vdel := 0.45
	var att := 0.08
	var rel := 0.2
	var scoop := 0.35
	var scoop_t := 0.05
	var fall := 0.0
	var growl := 0.0
	var chiff := 1.0
	match kind:
		K_FUE:
			h2 = 0.12
			h3 = 0.3
			h4 = 0.08
			breath = 1.4
			air = 0.03
			vr = 5.8 + 0.3 * v
			vd = 0.14
			vdel = 0.25
			att = 0.03
			rel = 0.1
			scoop = 0.2
			scoop_t = 0.025
			chiff = 1.5
		K_HORA:
			h2 = 0.55
			h3 = 0.38
			h4 = 0.25
			breath = 1.2
			air = 0.02
			vr = 2.5
			vd = 0.08
			vdel = 0.3
			att = 0.22
			rel = 0.35
			scoop = 1.5
			scoop_t = 0.12
			fall = -1.5
			growl = 0.55
			chiff = 0.6
	match orn:
		O_UP:
			scoop = 1.6 if kind != K_FUE else 1.0
			scoop_t = 0.07
		O_FALL:
			fall = -2.0
		O_VIB:
			vd *= 1.7
			vdel *= 0.5
		O_BREATH:
			breath *= 2.2
			air *= 3.0
			chiff = 2.5
	var n := maxi(256, int(dur * RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var rel_n := minf(rel * RATE, n * 0.45)
	var att_n := att * RATE
	var ph := 0.0
	var inc := 0.0
	var env := 0.0
	var br := 0.0
	var rr := 0.996
	var b1 := 0.0
	var b2 := rr * rr
	var rg := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var nlp := 0.0
	var gr := 1.0
	var rs := _rs
	var swell := dur > 0.9
	for i in n:
		if (i & 15) == 0:
			var t := float(i) / RATE
			var semi := 0.0
			if scoop != 0.0:
				semi -= scoop * exp(-t / scoop_t)
			if fall != 0.0:
				var u := clampf((float(i) / n - 0.5) / 0.42, 0.0, 1.0)
				semi += fall * u * u
			var vamp := clampf((t - vdel) * 2.5, 0.0, 1.0)
			var vs := sin(TAU * vr * t)
			semi += vs * vd * vamp
			inc = TAU * freq * pow(2.0, semi / 12.0) / RATE
			b1 = 2.0 * rr * cos(inc)
			rg = (1.0 - rr) * 2.0 * sin(inc)
			var ea := 1.0 - exp(-float(i) / maxf(1.0, att_n * 0.4))
			var er := clampf(float(n - i) / rel_n, 0.0, 1.0)
			var sw := 1.0
			if swell:
				var u3 := t / dur
				sw = 0.78 + 0.22 * sin(PI * clampf(u3 * 1.3, 0.0, 1.0))
			env = ea * er * sw * (1.0 + 0.12 * vs * vamp)
			br = breath * (0.5 + chiff * exp(-t / 0.09))
			if growl > 0.0:
				gr = 1.0 + growl * sin(TAU * 31.0 * t)
		ph += inc
		if ph > TAU:
			ph -= TAU
		var s := sin(ph)
		var c := cos(ph)
		var s2 := 2.0 * s * c
		var ss := s * s
		var s3 := s * (3.0 - 4.0 * ss)
		var s4 := 2.0 * s2 * (1.0 - 2.0 * ss)
		var tone := s + (h2 * s2 + h3 * s3 + h4 * s4) * (0.55 + 0.45 * env)
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		var nz := float(rs) * INV_RS - 1.0
		var yr := b1 * y1 - b2 * y2 + nz * rg
		y2 = y1
		y1 = yr
		nlp += 0.45 * (nz - nlp)
		out[i] = (tone * gr + yr * br + (nz - nlp) * air) * env
	_rs = rs
	return _norm(out, 0.42)


## Membranes et bois frappés : partiels (rapports, amplitudes, amortissements /s) sur une hauteur qui chute
## (drop : écart relatif au départ, drop_t : constante de temps), bruit de frappe filtré, clic de baguette.
func _membrane(f0: float, dur: float, ra: Array, am: Array, de: Array, drop: float, drop_t: float,
		nz: float, nz_c: float, nz_dec: float, click: float) -> PackedFloat32Array:
	var n := maxi(64, int(dur * RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var r1: float = ra[0]
	var r2: float = ra[1]
	var r3: float = ra[2]
	var r4: float = ra[3]
	var e1: float = am[0]
	var e2: float = am[1]
	var e3: float = am[2]
	var e4: float = am[3]
	var k1 := exp(-float(de[0]) / RATE)
	var k2 := exp(-float(de[1]) / RATE)
	var k3 := exp(-float(de[2]) / RATE)
	var k4 := exp(-float(de[3]) / RATE)
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	var p4 := 0.0
	var pe := 1.0
	var kp := exp(-1.0 / (maxf(drop_t, 0.001) * RATE))
	var na := nz
	var kn := exp(-nz_dec / RATE)
	var lp := 0.0
	var prev := 0.0
	var cl := click
	var kc := exp(-1.0 / (0.0012 * RATE))
	var rs := _rs
	var base := TAU * f0 / RATE
	for i in n:
		var fm := base * (1.0 + drop * pe)
		pe *= kp
		p1 += fm * r1
		p2 += fm * r2
		p3 += fm * r3
		p4 += fm * r4
		var vv := sin(p1) * e1 + sin(p2) * e2 + sin(p3) * e3 + sin(p4) * e4
		e1 *= k1
		e2 *= k2
		e3 *= k3
		e4 *= k4
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		var w := float(rs) * INV_RS - 1.0
		lp += nz_c * (w - lp)
		vv += lp * na + (w - prev) * cl * 0.5
		prev = w
		na *= kn
		cl *= kc
		out[i] = vv * minf(1.0, float(i) * 0.25)
	_rs = rs
	var rel := mini(int(0.02 * RATE), n / 3)
	for k in rel:
		out[n - 1 - k] *= float(k) / float(rel)
	return _norm(out, 1.0)


## Cloches : partiels inharmoniques amortis (oscillateurs récurrents), coup de frappe bref.
func _bell(freq: float, dur: float, ratios: Array, amps: Array, decays: Array, strike: float) -> PackedFloat32Array:
	var n := maxi(64, int(dur * RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	for p in ratios.size():
		var f: float = freq * float(ratios[p])
		if f >= RATE * 0.45:
			continue
		var w := TAU * f / RATE
		var kk := 2.0 * cos(w)
		var yy1 := 0.0
		var yy2 := -sin(w)
		var a: float = amps[p]
		var dec: float = decays[p]
		var gg := exp(-dec / RATE)
		var m := mini(n, int(log(maxf(a, 0.0003) / 0.0002) / dec * RATE) + 1)
		for i in m:
			var yv := kk * yy1 - yy2
			yy2 = yy1
			yy1 = yv
			out[i] += yv * a
			a *= gg
	var tn := mini(n, int(0.004 * RATE))
	var rs := _rs
	var prev := 0.0
	for i in tn:
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		var w2 := float(rs) * INV_RS - 1.0
		out[i] += (w2 - prev) * strike * (1.0 - float(i) / tn)
		prev = w2
	_rs = rs
	for i in mini(n, 6):
		out[i] *= float(i) / 6.0
	var rel := mini(int(0.5 * RATE), n / 3)
	for k in rel:
		out[n - 1 - k] *= float(k) / float(rel)
	return _norm(out, 1.0)


## Coup sourd ajouté au début (battant de la cloche, maillet).
func _thud(s: PackedFloat32Array, f: float, amt: float) -> PackedFloat32Array:
	var tn := mini(s.size(), int(0.25 * RATE))
	var ph := 0.0
	var lp := 0.0
	var rs := _rs
	for i in tn:
		var t := float(i) / RATE
		ph += TAU * f * (1.0 + 0.3 * exp(-t * 30.0)) / RATE
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		lp += 0.05 * (float(rs) * INV_RS - 1.0 - lp)
		s[i] += (sin(ph) * 0.6 + lp * 3.0) * exp(-t * 14.0) * amt * minf(1.0, float(i) / 30.0)
	_rs = rs
	return _norm(s, 1.0)


## Clochettes suzu secouées : trois grelots désaccordés, frappés à quelques ms d'écart.
func _suzu(freq: float, dur: float) -> PackedFloat32Array:
	var n := maxi(64, int(dur * RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	var offs := [0.0, 0.011, 0.024, 0.04]
	var mul := [1.0, 1.13, 1.27, 0.94]
	for b in 4:
		var one := _bell(freq * float(mul[b]), dur, SUZU_R, SUZU_A, SUZU_D, 0.4)
		var o := int(float(offs[b]) * RATE)
		var ga := 1.0 - 0.18 * b
		for i in range(0, n - o):
			if i >= one.size():
				break
			out[o + i] += one[i] * ga
	return _norm(out, 1.0)


## Shō : anche (table d'onde) à deux voix légèrement désaccordées, souffle lent qui enfle puis retombe.
func _sho(freq: float, dur: float) -> PackedFloat32Array:
	if _sho_tab.is_empty():
		_sho_tab.resize(1025)
		var pk := 0.0001
		for k in 1024:
			var vv := 0.0
			for hh in SHO_H.size():
				vv += float(SHO_H[hh]) * sin(TAU * float(hh + 1) * float(k) / 1024.0 + 0.3 * hh)
			_sho_tab[k] = vv
			pk = maxf(pk, absf(vv))
		for k in 1024:
			_sho_tab[k] /= pk
		_sho_tab[1024] = _sho_tab[0]
	var tab := _sho_tab
	var n := maxi(256, int(dur * RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var att := minf(1.1 * RATE, n * 0.4)
	var rel := minf(1.3 * RATE, n * 0.45)
	var inc := freq * 1024.0 / RATE
	var inc2 := inc * 1.0016
	var ph := 0.0
	var ph2 := 377.0
	var env := 0.0
	var lp := 0.0
	var rs := _rs
	for i in n:
		if (i & 63) == 0:
			var t := float(i) / RATE
			var ea := minf(1.0, float(i) / att)
			env = ea * ea * (3.0 - 2.0 * ea) * minf(1.0, float(n - i) / rel)
			env *= 0.88 + 0.12 * sin(TAU * 0.21 * t)
		ph += inc
		if ph >= 1024.0:
			ph -= 1024.0
		ph2 += inc2
		if ph2 >= 1024.0:
			ph2 -= 1024.0
		var i1 := int(ph)
		var f1 := ph - i1
		var i2 := int(ph2)
		var f2 := ph2 - i2
		var a: float = tab[i1] + (tab[i1 + 1] - tab[i1]) * f1
		var b: float = tab[i2] + (tab[i2 + 1] - tab[i2]) * f2
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		lp += 0.1 * (float(rs) * INV_RS - 1.0 - lp)
		out[i] = ((a + b) * 0.5 + lp * 0.12) * env
	_rs = rs
	return out


func _norm(s: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0
	for i in s.size():
		m = maxf(m, absf(s[i]))
	if m > 0.00001:
		var g := peak / m
		for i in s.size():
			s[i] *= g
	return s


# ===================== écriture =====================

func _tempo(bpm: float) -> void:
	_bs = 60.0 / bpm
	_spb = RATE * _bs


func _ev(kind: int, beat: float, freq: float, dur: float, amp: float, orn := O_NONE) -> void:
	var jit := 0
	var a := amp
	var vv := 0
	if kind != K_SHO:
		jit = int(_hum.randf_range(-1.0, 1.0) * 0.006 * RATE)
		a *= _hum.randf_range(0.92, 1.06)
		vv = _hum.randi() % 2
	a *= float(TRIM.get(kind, 1.0))
	_evs.append([kind, beat, freq, dur, a, orn, _layer, _intro_mode, jit, vv])


# Durée de note selon l'instrument (cordes et frappes : leur résonance naturelle ; souffles : quantifiée).
func _dur(kind: int, sec: float) -> float:
	match kind:
		K_KOTO:
			return 3.5
		K_KOTO_M:
			return 0.6
		K_SHAMI:
			return 1.6
		K_BIWA:
			return 4.0
		K_ODAIKO:
			return 1.6
		K_TAIKO:
			return 0.9
		K_SHIME, K_TSUZUMI:
			return 0.45
		K_KA, K_HYO:
			return 0.15
		K_MOKU:
			return 0.3
		K_SUZU:
			return 0.7
		K_RIN:
			return 5.0
		K_KANE:
			return 7.0
		K_FURIN:
			return 2.0
		K_ANVIL:
			return 1.4
		K_SHO:
			return maxf(0.5, roundf(sec * 4.0) / 4.0)
	return maxf(0.12, roundf(sec * 20.0) / 20.0)


# Degré de gamme (peut être négatif / sur plusieurs octaves) -> fréquence.
func _f(root: float, scale: Array, deg: int) -> float:
	var o := floori(deg / 5.0)
	var k := deg - o * 5
	var semi: int = o * 12 + int(scale[k])
	return root * pow(2.0, semi / 12.0)


## Mélodie écrite « degré:durée[ornement] » (durée en temps), « r:durée » = silence, « | » ignoré.
## Ornements : ^ par en dessous (atari, ato-oshi), v qui retombe (meri, hiki-iro), ~ vibrato (yuri),
## * souffle appuyé (muraiki), ' appoggiature supérieure (fue).
func _mp(s: String) -> Array:
	var out: Array = []
	var b := 0.0
	for tok in s.split(" ", false):
		if tok == "|":
			continue
		var t := String(tok)
		var orn := O_NONE
		match t.right(1):
			"^":
				orn = O_UP
			"v":
				orn = O_FALL
			"~":
				orn = O_VIB
			"*":
				orn = O_BREATH
			"'":
				orn = O_GRACE
		if orn != O_NONE:
			t = t.left(t.length() - 1)
		var p := t.split(":")
		var ln := float(p[1])
		if p[0] != "r":
			out.append([b, int(p[0]), ln, orn])
		b += ln
	return out


## Place une mélodie : at (temps), shift (degrés), legato (part de la durée tenue par les souffles).
func _mel(kind: int, ph: Array, at: float, root: float, sc: Array, shift: int, amp: float, legato := 0.96) -> void:
	for i in ph.size():
		var nt: Array = ph[i]
		var bt: float = nt[0]
		var deg: int = int(nt[1]) + shift
		var ln: float = nt[2]
		var orn: int = nt[3]
		var a := amp * (1.08 if i == 0 else 1.0)
		if orn == O_GRACE:
			var gb := 0.07 / _bs
			_ev(kind, at + bt - gb, _f(root, sc, deg + 1), _dur(kind, 0.1), a * 0.6)
			orn = O_NONE
		_ev(kind, at + bt, _f(root, sc, deg), _dur(kind, ln * _bs * legato), a, orn)


# Variation : quelques notes déplacées d'un degré (la première et la dernière restent).
func _vary(rng: RandomNumberGenerator, ph: Array, p: float) -> Array:
	var o: Array = ph.duplicate(true)
	for i in range(1, o.size() - 1):
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


# Phrase improvisée (marche par degrés conjoints, quelques sauts et silences) : [[temps, degré, durée, orn]].
func _phrase(rng: RandomNumberGenerator, beats: float, deg0: int, lo: int, hi: int, rh: Array, rest_p: float) -> Array:
	var out: Array = []
	var b := 0.0
	var d := deg0
	while b < beats - 0.01:
		var du: float = rh[rng.randi() % rh.size()]
		du = minf(du, beats - b)
		if out.is_empty() or rng.randf() >= rest_p:
			var orn := O_NONE
			if du >= 1.5 and rng.randf() < 0.5:
				orn = O_VIB
			elif rng.randf() < 0.12:
				orn = O_UP
			out.append([b, d, du, orn])
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


## Arpèges : pat = degrés relatifs à la base de la mesure (« _ » silence), un pas tous les `step` temps.
func _arp(kind: int, pat: String, root: float, sc: Array, prog: Array, bar0: int, bars: int, step: float, amp: float, oct := 0) -> void:
	var toks := pat.split(" ", false)
	for bar in bars:
		var base: int = int(prog[bar % prog.size()]) + oct
		var k := 0
		var t := 0.0
		while t < 3.999:
			var tk := String(toks[k % toks.size()])
			if tk != "_":
				var a := amp * (1.3 if k == 0 else 1.0)
				_ev(kind, (bar0 + bar) * 4.0 + t, _f(root, sc, base + int(tk)), _dur(kind, step * _bs), a)
			k += 1
			t += step


## Frappes écrites en doubles croches (16 pas par mesure ; un motif plus long couvre plusieurs mesures) :
## X accent, x normal, o doux, g fantôme, r roulement (deux triples croches), . silence ; « | » ignoré.
func _drums(kind: int, pat: String, freq: float, bar0: int, bars: int, amp: float) -> void:
	var p := pat.replace("|", "").replace(" ", "")
	var ln := p.length()
	for bar in bars:
		for k in 16:
			var ch := p[(bar * 16 + k) % ln]
			var b := (bar0 + bar) * 4.0 + k * 0.25
			match ch:
				"X":
					_ev(kind, b, freq, _dur(kind, 0.0), amp)
				"x":
					_ev(kind, b, freq, _dur(kind, 0.0), amp * 0.68)
				"o":
					_ev(kind, b, freq, _dur(kind, 0.0), amp * 0.42)
				"g":
					_ev(kind, b, freq, _dur(kind, 0.0), amp * 0.22)
				"r":
					_ev(kind, b, freq, _dur(kind, 0.0), amp * 0.5)
					_ev(kind, b + 0.125, freq, _dur(kind, 0.0), amp * 0.4)


## Nappes de shō : un accord (degrés relatifs) toutes les `span` mesures.
func _pad(root: float, sc: Array, prog: Array, chord: Array, bar0: int, bars: int, span: int, amp: float) -> void:
	var bar := 0
	while bar < bars:
		var base: int = int(prog[bar % prog.size()])
		var len_s := minf(span, bars - bar) * 4.0 * _bs + 0.6
		for ch in chord:
			_ev(K_SHO, (bar0 + bar) * 4.0, _f(root, sc, base + int(ch)), _dur(K_SHO, len_s), amp)
		bar += span


# Glissando (sararin du koto) : count notes, pas de degré dirn, écart gap (temps).
func _gliss(kind: int, root: float, sc: Array, beat: float, d0: int, count: int, dirn: int, gap: float, amp: float) -> void:
	for k in count:
		_ev(kind, beat + k * gap, _f(root, sc, d0 + k * dirn), _dur(kind, 0.5), amp * (0.6 + 0.4 * float(k) / count))


# Petites notes semées au hasard (étoiles, perles, flocons) : une chance p par mesure.
func _sprinkle(rng: RandomNumberGenerator, kind: int, root: float, sc: Array, bar0: int, bars: int, p: float, lo: int, hi: int, amp: float) -> void:
	for bar in bars:
		if rng.randf() < p:
			_ev(kind, (bar0 + bar) * 4.0 + float(rng.randi_range(1, 7)) * 0.5, _f(root, sc, rng.randi_range(lo, hi)), _dur(kind, 1.0), amp)


# Remplissage de taiko en fin de mesure (relance).
func _fill(kind: int, freq: float, bar: int, amp: float) -> void:
	_drums(kind, "........x.x.XxXX", freq, bar, 1, amp)


# ===================== pistes =====================

# Accueil : koto lent en arpèges, nappe de shō, mélodie de koto puis de shakuhachi, ressac lointain.
# Gamme yo en la, 64 BPM, 16 mesures (60 s), sans intro.
func _menu(rng: RandomNumberGenerator) -> Dictionary:
	_tempo(64.0)
	var root := 220.0
	var prog := [0, -1, 0, -2, 1, 0, -1, 0]
	_arp(K_KOTO, "0 2 4 2", root, YO, prog, 0, 16, 1.0, 0.12)
	_pad(root * 2.0, YO, prog, [0, 2, 4], 0, 16, 2, 0.022)
	var km := _mp("4:2 3:1 2:1 | 3:3 r:1 | 2:1 3:1 4:1 5:1 | 4:4~ | 5:2 4:1 3:1 | 2:2 1:1 2:1 | 0:3^ r:1")
	_mel(K_KOTO, km, 4.0, root * 2.0, YO, -5, 0.2)
	var sm := _mp("2:2^ 3:1 4:1 | 5:3~ r:1 | 4:1.5 3:0.5 2:2 | 3:4~ | 4:2 5:1 7:1 | 6:2~ 5:2 | 4:1 3:1 2:2v | 0:4~")
	_mel(K_SHAKU, sm, 32.0, root * 2.0, YO, 0, 0.34)
	for st in [12.0, 28.0, 44.0, 60.0]:
		_ev(K_FURIN, float(st) + 0.5, _f(root * 4.0, YO, rng.randi_range(0, 4)), 2.0, 0.05)
	return {"bpm": 64.0, "beats": 64.0, "intro": 0.0, "room": 0.86, "damp": 0.3,
		"bed": BED_SURF, "bed_amp": 0.02, "waves": 6, "lufs": LUFS_CALM, "lufs_fight": LUFS_CALM}


# Sanctuaire / marchand : gamme yo en sol, 84 BPM, 16 mesures (46 s), sans intro. Rin et mokugyo du temple,
# koto chantant, shamisen qui répond en pizzicati malicieux (le tanuki), shō, suzu en fin de phrase.
func _shrine(rng: RandomNumberGenerator) -> Dictionary:
	_tempo(84.0)
	var root := 196.0
	var prog := [0, 0, -1, 0, -2, -1, 0, 0]
	_ev(K_RIN, 0.0, _f(root * 2.0, YO, 4), 5.0, 0.16)
	_ev(K_RIN, 32.0, _f(root * 2.0, YO, 2), 5.0, 0.14)
	for bar in 16:
		_ev(K_MOKU, bar * 4.0, 560.0, 0.3, 0.06)
		_ev(K_MOKU, bar * 4.0 + 2.0, 520.0, 0.3, 0.04)
	_arp(K_KOTO, "0 4 2 4", root, YO, prog, 0, 16, 1.0, 0.085)
	_pad(root * 2.0, YO, prog, [0, 2, 4], 0, 16, 4, 0.016)
	var a := _mp("4:1 5:0.5 4:0.5 2:1 4:1 | 5:2 7:2^ | 6:1 5:1 4:1 2:1 | 4:4~ | 2:1 4:1 5:1 4:1 | 2:1 1:1 0:2 | 1:1 2:1 4:1 2:1 | 0:4")
	_mel(K_KOTO, a, 0.0, root * 2.0, YO, -5, 0.2)
	var b := _mp("7:0.5 5:0.5 4:1 r:2 | 5:0.5 4:0.5 2:1 r:2 | 4:0.5 5:0.5 7:1 5:1 4:1 | 2:4 | 4:0.5 2:0.5 1:1 r:2 | 2:0.5 4:0.5 5:1 r:2 | 4:1 2:1 1:1 2:1 | 0:4")
	_mel(K_SHAMI, b, 32.0, root * 2.0, YO, -5, 0.18)
	_mel(K_KOTO, _cadence(_vary(rng, a, 0.3), 0), 32.0, root * 2.0, YO, 0, 0.07)
	for st in [28.0, 60.0]:
		_ev(K_SUZU, float(st) + 3.0, 2600.0, 0.7, 0.07)
	return {"bpm": 84.0, "beats": 64.0, "intro": 0.0, "room": 0.82, "damp": 0.35,
		"bed": BED_WIND, "bed_amp": 0.012, "lufs": LUFS_CALM, "lufs_fight": LUFS_CALM}


# Monde 1, la Grande Vague (mer, aube) : gamme yo en ré, 84 BPM, ressac. Intro 2 mesures (shō, sararin).
# A (koto en vagues, shakuhachi), B (koto mélodique, shō), A' (shakuhachi varié) ; la vague se brise et repart.
# Tension : ōdaiko, nagado, shime, fuchi, ostinato de shamisen.
func _w1(rng: RandomNumberGenerator) -> Dictionary:
	_tempo(84.0)
	var root := 293.66
	var lo := root * 0.5
	var pa := [0, 0, -2, -1, 0, 0, -2, 1]
	var pb := [-2, -2, 0, 0, -1, -1, 1, 1]
	_intro_mode = true
	for c in [0, 2, 4]:
		_ev(K_SHO, -8.0, _f(root, YO, int(c)), _dur(K_SHO, 8.0 * _bs), 0.035)
	_ev(K_ODAIKO, -8.0, 56.0, 1.6, 0.3)
	_gliss(K_KOTO, lo, YO, -3.5, 0, 12, 1, 0.25, 0.14)
	_intro_mode = false
	_arp(K_KOTO, "0 2 4 5 4 2 4 2", lo, YO, pa, 0, 8, 0.5, 0.085)
	_arp(K_KOTO, "0 _ 4 _ 2 _ 5 _", lo, YO, pb, 8, 8, 0.5, 0.09)
	_arp(K_KOTO, "0 2 4 5 7 5 4 2", lo, YO, pa, 16, 8, 0.5, 0.08)
	_pad(root, YO, pb, [0, 2, 4], 8, 8, 2, 0.026)
	_pad(root, YO, pa, [0, 1, 3], 16, 8, 4, 0.016)
	var ma := _mp("2:1.5^ 3:0.5 4:1 5:1 | 4:3~ r:1 | 5:1 7:1 6:1 5:1 | 4:2 3:2~ | 2:1.5 3:0.5 4:1 3:1 | 2:2 1:1 0:1 | 1:1 2:1 3:1 4:1 | 2:4~")
	var mb := _mp("7:0.5 6:0.5 5:1 4:1 5:1 | 7:2^ 6:1 5:1 | 4:0.5 5:0.5 4:1 3:1 2:1 | 3:3~ r:1 | 5:0.5 6:0.5 7:1 8:1 7:1 | 6:2 5:1 4:1 | 5:1 4:1 3:1 2:1 | 3:2 4:2~")
	_mel(K_SHAKU, ma, 0.0, root, YO, 0, 0.34)
	_mel(K_KOTO, mb, 32.0, root, YO, -5, 0.22)
	_mel(K_SHAKU, _cadence(_vary(rng, ma, 0.25), 0), 64.0, root, YO, 0, 0.34)
	_gliss(K_KOTO, lo, YO, 94.0, 12, 8, -1, 0.25, 0.1)
	_sprinkle(rng, K_FURIN, root * 4.0, YO, 0, 24, 0.25, 0, 4, 0.03)
	# tension
	_layer = 1
	_drums(K_ODAIKO, "X.......x.......|X.....x.X.......", 56.0, 0, 8, 0.8)
	_drums(K_ODAIKO, "X...............|X.......X.......", 56.0, 8, 8, 0.8)
	_drums(K_ODAIKO, "X.......x.......|X.....x.X...x...", 56.0, 16, 8, 0.85)
	_drums(K_TAIKO, "....x.......x.x.|....x...x..xx.x.", 98.0, 0, 7, 0.55)
	_drums(K_TAIKO, "....x.......x...", 98.0, 8, 6, 0.45)
	_drums(K_TAIKO, "x.x.x.x.x.x.xxxx|XxXxXxXxXXXXXXXX", 98.0, 14, 2, 0.5)
	_drums(K_TAIKO, "....x.......x.x.|....x...x..xx.x.", 98.0, 16, 7, 0.55)
	_fill(K_TAIKO, 98.0, 7, 0.6)
	_fill(K_TAIKO, 104.0, 23, 0.6)
	_drums(K_SHIME, "x.g.x.g.x.g.x.gx", 410.0, 0, 8, 0.3)
	_drums(K_SHIME, "x...x...x...x.g.", 410.0, 8, 8, 0.24)
	_drums(K_SHIME, "x.gxx.g.x.gxx.gx", 410.0, 16, 8, 0.3)
	_drums(K_KA, "....x.......x...", 1150.0, 0, 24, 0.25)
	_arp(K_SHAMI, "0 0 2 0 3 0 2 1", lo, YO, pa, 0, 8, 0.5, 0.15)
	_arp(K_SHAMI, "0 _ 2 _ 3 _ 2 _", lo, YO, pb, 8, 8, 0.5, 0.13)
	_arp(K_SHAMI, "0 0 2 0 3 2 4 3", lo, YO, pa, 16, 8, 0.5, 0.15)
	_layer = 0
	return {"bpm": 84.0, "beats": 96.0, "intro": 8.0, "room": 0.85, "damp": 0.3,
		"bed": BED_SURF, "bed_amp": 0.06, "waves": 8}


# Monde 2, la forêt de bambous (nuit, Tanabata) : gamme in en mi, 72 BPM, vent. Shakuhachi seul façon honkyoku,
# koto grave, chocs de bambou ; B : koto mélodique sur koto étouffé ; A' : shakuhachi sur shō.
# Tension : kotsuzumi, shime, nagado, hyōshigi, ostinato de koto étouffé.
func _w2(rng: RandomNumberGenerator) -> Dictionary:
	_tempo(72.0)
	var root := 329.63
	var lo := root * 0.5
	var prog := [0, 0, -1, 0, -2, -2, -1, 0]
	_intro_mode = true
	_ev(K_SUZU, -7.0, 2500.0, 0.7, 0.06)
	_ev(K_KOTO, -8.0, _f(lo, IN_SC, -5), 3.5, 0.16)
	_ev(K_SHAKU, -5.5, _f(root, IN_SC, 0), _dur(K_SHAKU, 4.5 * _bs), 0.26, O_BREATH)
	_intro_mode = false
	for bar in 20:
		var b0 := bar * 4.0
		var base: int = int(prog[bar % 8]) - 5
		if bar < 8 or bar >= 14:
			_ev(K_KOTO, b0, _f(lo, IN_SC, base + 5), 3.5, 0.13)
			_ev(K_KOTO, b0 + 2.0, _f(lo, IN_SC, base + 7), 3.5, 0.08)
		# chocs de bambou (kon… kon)
		if rng.randf() < 0.55:
			_ev(K_MOKU, b0 + float(rng.randi_range(1, 7)) * 0.5, rng.randf_range(820.0, 980.0), 0.3, 0.06)
	var a := _mp("0:2^ 1:1v 0:1 | 2:4~ | 3:1.5 2:0.5 1:2v | 0:3 r:1 | 2:2^ 3:1 4:1 | 5:3~ 4:1 | 3:1 2:1 1:2v | 0:4~")
	_mel(K_SHAKU, a, 0.0, root, IN_SC, 0, 0.36)
	var b := _mp("5:1 4:0.5 3:0.5 4:2 | 2:1 3:1 4:1 5:1 | 7:2^ 6:1 5:1 | 4:3~ r:1 | 3:1 4:1 5:2 | 4:1 3:1 2:2")
	_mel(K_KOTO, b, 32.0, lo, IN_SC, 5, 0.22)
	_arp(K_KOTO_M, "0 2 3 2 4 2 3 1", lo, IN_SC, [0, 0, 1, 1, -1, 0], 8, 6, 0.5, 0.06)
	var a2 := _mp("2:2^ 3:1 4:1 | 5:3~ 4:1 | 3:1 2:1 1:2v | 0:2 1:1 2:1 | 1:2v 0:2 | 0:4~")
	_mel(K_SHAKU, a2, 56.0, root, IN_SC, 0, 0.36)
	_pad(root, IN_SC, [0, -1, -2], [0, 2, 4], 14, 6, 2, 0.022)
	for st in [28.0, 52.0, 76.0]:
		_ev(K_FURIN, float(st) + 2.5, _f(root * 4.0, IN_SC, rng.randi_range(0, 4)), 2.0, 0.04)
	_layer = 1
	_drums(K_TSUZUMI, "x.....x...x.....|x.....x.x...x...", 270.0, 0, 20, 0.45)
	_drums(K_SHIME, "g.x.g.x.g.x.g.xx", 430.0, 0, 8, 0.22)
	_drums(K_SHIME, "x.x.x.x.x.x.x.x.|x.x.x.x.xxx.x.x.", 430.0, 8, 6, 0.24)
	_drums(K_SHIME, "g.x.g.x.g.x.g.xx", 430.0, 14, 6, 0.22)
	_drums(K_TAIKO, "X.......X...x...", 104.0, 0, 20, 0.5)
	_drums(K_HYO, "............x.x.|................", 2100.0, 0, 20, 0.2)
	_fill(K_TAIKO, 104.0, 7, 0.55)
	_fill(K_TAIKO, 104.0, 13, 0.55)
	_fill(K_TAIKO, 110.0, 19, 0.6)
	_arp(K_KOTO_M, "0 2 3 0 4 3 2 1", lo, IN_SC, prog, 0, 20, 0.5, 0.07)
	_layer = 0
	return {"bpm": 72.0, "beats": 80.0, "intro": 8.0, "room": 0.87, "damp": 0.3,
		"bed": BED_WIND, "bed_amp": 0.04, "whistle": 0.6}


# Monde 3, la neige (Cent Contes : fantômes, cloches du temple) : gamme in en ré grave, 63 BPM. Intro (bonshō).
# A : le biwa conte, rin ; B : shakuhachi aigu et fantomatique, shō en grappe ; flocons de fūrin, vent qui siffle.
# Tension : cœur d'ōdaiko, hyōshigi du veilleur, shime feutré, ostinato de shamisen grave.
func _w3(rng: RandomNumberGenerator) -> Dictionary:
	_tempo(63.0)
	var root := 146.83
	_intro_mode = true
	_ev(K_KANE, -8.0, root * 0.5, 7.0, 0.3)
	_ev(K_HYO, -2.5, 1900.0, 0.15, 0.2)
	_ev(K_HYO, -2.25, 1900.0, 0.15, 0.16)
	_intro_mode = false
	var a := _mp("0:1^ 1:0.5 0:0.5 r:2 | 2:1 3:1 2:2v | r:1 4:1 3:1 2:1 | 1:3v r:1 | 0:1^ 1:0.5 0:0.5 r:2 | 4:1 5:1 4:2v | 3:1 2:1 1:1 0:1 | 0:4")
	_mel(K_BIWA, a, 0.0, root, IN_SC, 0, 0.3)
	_mel(K_BIWA, _vary(rng, a, 0.3), 32.0, root, IN_SC, 0, 0.18)
	var g := _mp("5:3~ r:1 | 6:2^ 5:1 4:1 | 3:4v | r:4 | 4:2^ 5:2~ | 6:1 5:1 4:2v | 3:2 2:2v | 0:4~")
	_mel(K_SHAKU, g, 32.0, root * 2.0, IN_SC, 0, 0.3)
	_ev(K_RIN, 0.0, _f(root * 4.0, IN_SC, 2), 5.0, 0.13)
	_ev(K_RIN, 16.0, _f(root * 4.0, IN_SC, 0), 5.0, 0.1)
	_ev(K_KANE, 32.0, root * 0.5, 7.0, 0.22)
	_ev(K_RIN, 48.0, _f(root * 4.0, IN_SC, 3), 5.0, 0.1)
	_pad(root * 4.0, IN_SC, [0, 0, -1, 0], [0, 1, 2], 8, 8, 2, 0.014)
	_pad(root * 2.0, IN_SC, [0, -1], [0, 2, 4], 0, 8, 4, 0.016)
	_sprinkle(rng, K_FURIN, root * 8.0, IN_SC, 0, 16, 0.45, 0, 4, 0.03)
	_layer = 1
	_drums(K_ODAIKO, "X..x............", 50.0, 0, 16, 0.75)
	_drums(K_TAIKO, "........x.....x.", 92.0, 0, 16, 0.4)
	_drums(K_SHIME, "g.g.g.g.x.g.g.g.", 380.0, 0, 16, 0.2)
	_drums(K_HYO, "............X.x.", 1900.0, 0, 16, 0.18)
	_arp(K_SHAMI, "0 _ 1 0 _ 2 1 _", root, IN_SC, [0, 0, -1, 0, 1, 0, -1, 0], 0, 16, 0.5, 0.13)
	_fill(K_TAIKO, 92.0, 7, 0.5)
	_fill(K_TAIKO, 92.0, 15, 0.5)
	_layer = 0
	return {"bpm": 63.0, "beats": 64.0, "intro": 8.0, "room": 0.9, "damp": 0.28,
		"bed": BED_WIND, "bed_amp": 0.045, "whistle": 1.0}


# Monde 4, le Fuji rouge (volcan, forge, braises) : gamme hirajōshi en ré, 116 BPM, braises et bourdon.
# Calme : koto grave qui couve, enclume lointaine, mélodie de koto (A), shakuhachi (A'), fue (B), koto (A'').
# Tension : ōdaiko lourd, nagado, shime, enclume sur les temps, shamisen en croches.
func _w4(rng: RandomNumberGenerator) -> Dictionary:
	_tempo(116.0)
	var root := 146.83
	var shifts := [0, 0, 0, 0, -1, -1, 0, 1]
	_intro_mode = true
	for k in 15:
		_ev(K_TAIKO, -8.0 + k * 0.5, 80.0, 0.9, 0.08 + 0.02 * k)
	_ev(K_ANVIL, -6.0, 1250.0, 1.4, 0.08)
	_ev(K_ANVIL, -2.0, 1250.0, 1.4, 0.09)
	_intro_mode = false
	_arp(K_KOTO, "0 2 1 2", root, HIRA, shifts, 0, 32, 1.0, 0.11)
	for bar in range(0, 32, 2):
		_ev(K_ANVIL, bar * 4.0, 1250.0, 1.4, 0.04)
	_pad(root * 2.0, HIRA, [0, -1, 0, 1], [0, 1, 3], 0, 32, 2, 0.016)
	var a := _mp("5:2 4:1 3:1 | 2:3 1:1 | 2:1 3:1 4:2 | 3:4~ | 5:2 6:1 7:1 | 6:2 5:2 | 4:1 3:1 2:1 1:1 | 0:4~")
	_mel(K_KOTO, a, 0.0, root * 2.0, HIRA, -5, 0.24)
	var s := _mp("7:4~ | 6:2 5:2 | 4:3^ 3:1 | 2:4v | 3:2 4:2 | 5:3~ 4:1 | 3:2 2:1 1:1 | 0:4~")
	_mel(K_SHAKU, s, 32.0, root * 2.0, HIRA, 0, 0.32)
	var f := _mp("2:1 3:1 4:2 | 5:1 4:1 3:2 | 2:1 1:1 0:2 | 1:4~ | 2:1 3:1 4:1 5:1 | 7:2 6:2~ | 5:1 4:1 3:1 2:1 | 3:4~")
	_mel(K_FUE, f, 64.0, root * 4.0, HIRA, 0, 0.24)
	_mel(K_KOTO, _cadence(_vary(rng, a, 0.3), 0), 96.0, root * 2.0, HIRA, -5, 0.24)
	_layer = 1
	_drums(K_ODAIKO, "X.......X.....x.|X.......X...x.x.", 50.0, 0, 16, 0.85)
	_drums(K_ODAIKO, "X...............|X.......x.x.x.x.", 50.0, 16, 8, 0.85)
	_drums(K_ODAIKO, "X.......X.....x.|X.......X...x.x.", 50.0, 24, 8, 0.9)
	_drums(K_TAIKO, "....X.......X...|....X..x....X.x.", 95.0, 0, 16, 0.55)
	_drums(K_TAIKO, "........X.......", 95.0, 16, 8, 0.5)
	_drums(K_TAIKO, "....X.......X...|....X..x....XxXx", 95.0, 24, 8, 0.6)
	_drums(K_SHIME, "x.x.X.x.x.x.X.x.", 420.0, 0, 16, 0.28)
	_drums(K_SHIME, "x.g.x.g.x.g.x.g.", 420.0, 16, 8, 0.22)
	_drums(K_SHIME, "xgxgXgxgxgxgXgxg", 420.0, 24, 8, 0.28)
	_drums(K_ANVIL, "....x.......x...", 1250.0, 0, 32, 0.09)
	for k in [7, 15, 23, 31]:
		_fill(K_TAIKO, 100.0, int(k), 0.6)
	_arp(K_SHAMI, "0 0 3 2 0 0 4 3", root, HIRA, shifts, 0, 16, 0.5, 0.16)
	_arp(K_SHAMI, "0 _ _ 3 _ _ 2 _", root, HIRA, shifts, 16, 8, 0.5, 0.14)
	_arp(K_SHAMI, "0 0 3 2 0 0 4 3", root, HIRA, [0, 0, 0, 0, -1, -1, 1, 2], 24, 8, 0.5, 0.17)
	_layer = 0
	return {"bpm": 116.0, "beats": 128.0, "intro": 8.0, "room": 0.8, "damp": 0.4,
		"bed": BED_FIRE, "bed_amp": 0.04, "drone": 73.42, "drone_amp": 0.03, "pulse": 0.5}


# Monde 5, le Fuji à l'encre (atelier, papier, encre) : gamme kumoi en la, 76 BPM. Un motif de koto et ses
# « vues », coups de pinceau (claquoirs feutrés), shō ; B : shakuhachi ; A' : le motif augmenté s'efface.
# Tension : nagado, shime, kotsuzumi, ostinato de koto étouffé.
func _w5(rng: RandomNumberGenerator) -> Dictionary:
	_tempo(76.0)
	var root := 220.0
	_intro_mode = true
	for c in [0, 2, 4]:
		_ev(K_SHO, -8.0, _f(root * 2.0, KUMOI, int(c)), _dur(K_SHO, 8.0 * _bs), 0.03)
	_ev(K_KOTO, -6.0, _f(root, KUMOI, 5), 3.5, 0.16)
	_ev(K_KOTO, -4.5, _f(root, KUMOI, 7), 3.5, 0.13)
	_ev(K_KOTO, -3.0, _f(root, KUMOI, 4), 3.5, 0.11)
	_intro_mode = false
	var m := _mp("5:1 4:1 2:0.5 3:0.5 4:1 | 2:3 r:1 | 3:1 4:1 5:1 7:1 | 6:2~ 5:2 | 4:1 3:1 2:1 4:1 | 3:2 2:1 0:1 | 1:1 2:1 3:2 | 2:4~")
	_mel(K_KOTO, m, 0.0, root, KUMOI, 0, 0.24)
	var bass := [0, -2, 0, -1, -2, -1, 0, 0, 0, -2]
	for k in 10:
		_ev(K_KOTO, k * 8.0, _f(root, KUMOI, -5 + int(bass[k])), 3.5, 0.15)
	for bar in 20:
		if bar < 8 or bar >= 14:
			_ev(K_HYO, bar * 4.0 + 1.0, 2400.0, 0.15, 0.03)
			_ev(K_HYO, bar * 4.0 + 3.0, 2600.0, 0.15, 0.025)
	_pad(root * 2.0, KUMOI, [0, -1, 1], [0, 2, 4], 8, 6, 2, 0.022)
	var s := _mp("4:2^ 5:1 4:1 | 3:3~ r:1 | 2:1 3:1 4:2 | 5:4~ | 4:1 3:1 2:1 1:1 | 0:4v")
	_mel(K_SHAKU, s, 32.0, root * 2.0, KUMOI, -5, 0.32)
	_arp(K_KOTO, "0 2 4 2", root, KUMOI, [0, -1, 1, 0, -2, 0], 8, 6, 1.0, 0.07)
	var aug := _augment(m, 2.0)
	for i in aug.size():
		var nt: Array = aug[i]
		var bt: float = nt[0]
		if bt >= 24.0 or (i > 3 and i % 2 == 1):
			continue
		_ev(K_KOTO, 56.0 + bt, _f(root, KUMOI, int(nt[1])), 3.5, lerpf(0.22, 0.1, clampf(bt / 22.0, 0.0, 1.0)))
	_sprinkle(rng, K_FURIN, root * 8.0, KUMOI, 0, 20, 0.2, 0, 4, 0.025)
	_layer = 1
	_drums(K_TAIKO, "X.......x...x...|X.....x.x.......", 100.0, 0, 20, 0.55)
	_drums(K_SHIME, "x.g.x.g.x.g.x.g.", 400.0, 0, 20, 0.22)
	_drums(K_TSUZUMI, "....x.......x...", 280.0, 0, 20, 0.32)
	_drums(K_ODAIKO, "X...............|................", 54.0, 0, 20, 0.6)
	_fill(K_TAIKO, 100.0, 7, 0.55)
	_fill(K_TAIKO, 100.0, 13, 0.55)
	_fill(K_TAIKO, 106.0, 19, 0.6)
	_arp(K_KOTO_M, "0 2 4 2 3 2 4 1", root, KUMOI, [0, 0, -1, 0, -2, -1, 0, 0], 0, 20, 0.5, 0.07)
	_layer = 0
	return {"bpm": 76.0, "beats": 80.0, "intro": 8.0, "room": 0.84, "damp": 0.35,
		"bed": BED_WIND, "bed_amp": 0.018}


# Monde 6, Kurama (forêt de cèdres, temple de montagne, tengu) : gamme kumoi en sol, 92 BPM, vent.
# Intro (horagai, anneaux du shakujō) ; A : shakuhachi sur koto grave ; B : le tengu (shinobue vif, koto
# étouffé) ; A' : bonshō du temple, shō, shakuhachi varié.
# Tension : ōdaiko, shime en doubles croches, fuchi, nagado, shamisen, anneaux sur les temps.
func _w6(rng: RandomNumberGenerator) -> Dictionary:
	_tempo(92.0)
	var root := 196.0
	var prog := [0, 0, -1, 0, -2, -1, 0, 0]
	_intro_mode = true
	_ev(K_HORA, -8.0, root, _dur(K_HORA, 3.5 * _bs), 0.3)
	_ev(K_SUZU, -3.5, 2300.0, 0.7, 0.07)
	_ev(K_ODAIKO, -1.0, 60.0, 1.6, 0.3)
	_intro_mode = false
	for bar in 24:
		var b0 := bar * 4.0
		var base: int = int(prog[bar % 8])
		if bar < 8 or bar >= 16:
			_ev(K_KOTO, b0, _f(root, KUMOI, base), 3.5, 0.14)
			_ev(K_KOTO, b0 + 2.0, _f(root, KUMOI, base + 2), 3.5, 0.09)
		if bar % 4 == 3:
			_ev(K_SUZU, b0 + 3.5, 2400.0, 0.7, 0.05)
	var a := _mp("0:2^ 2:1 3:1 | 4:3~ r:1 | 5:1 4:1 3:1 2:1 | 3:4v | 2:1 3:1 4:1 5:1 | 7:2^ 6:2~ | 5:1 4:1 3:2 | 2:4~")
	_mel(K_SHAKU, a, 0.0, root * 2.0, KUMOI, 0, 0.34)
	var b := _mp("5:0.5 6:0.5 7:1 6:0.5 5:0.5 4:1 | 5:2 7:2' | 8:1 7:0.5 6:0.5 5:2 | 4:4~ | 5:0.5 6:0.5 7:1 9:2^ | 8:1 7:1 6:2 | 5:1 4:1 3:1 4:1 | 5:4~")
	_mel(K_FUE, b, 32.0, root * 2.0, KUMOI, 0, 0.24)
	_arp(K_KOTO_M, "0 2 4 2 3 2 4 1", root, KUMOI, [0, 0, 1, -1, 0, 1, 0, -1], 8, 8, 0.5, 0.06)
	_ev(K_HORA, 32.0, root, _dur(K_HORA, 3.0 * _bs), 0.18)
	_ev(K_KANE, 64.0, root * 0.5, 7.0, 0.22)
	_pad(root * 2.0, KUMOI, [0, -1, -2, 0], [0, 2, 4], 16, 8, 2, 0.02)
	_mel(K_SHAKU, _cadence(_vary(rng, a, 0.3), 0), 64.0, root * 2.0, KUMOI, 0, 0.34)
	_layer = 1
	_drums(K_ODAIKO, "X.......X.......|X.....X.X...X...", 58.0, 0, 24, 0.8)
	_drums(K_SHIME, "xgxgXgxgxgxgXgxg", 440.0, 0, 24, 0.22)
	_drums(K_KA, "....x.......x...", 1200.0, 0, 24, 0.22)
	_drums(K_TAIKO, "..x...x...x.x.x.", 102.0, 8, 8, 0.45)
	_drums(K_TAIKO, "....x.......x...", 102.0, 0, 8, 0.45)
	_drums(K_TAIKO, "....x.......x.x.", 102.0, 16, 8, 0.5)
	for k in [7, 15, 23]:
		_fill(K_TAIKO, 108.0, int(k), 0.6)
	_drums(K_SUZU, "....x.......x...", 2300.0, 0, 24, 0.045)
	_arp(K_SHAMI, "0 0 2 0 3 2 0 1", root, KUMOI, prog, 0, 24, 0.5, 0.15)
	_layer = 0
	return {"bpm": 92.0, "beats": 96.0, "intro": 8.0, "room": 0.86, "damp": 0.32,
		"bed": BED_WIND, "bed_amp": 0.04, "whistle": 0.4}


# Monde 7, Ryūgū-jō (palais du roi dragon sous la mer) : gamme yo en la, 66 BPM, eaux profondes.
# Shō en accords aitake (gagaku), koto en arpèges d'eau (triolets), perles de suzu et fūrin ;
# B : fue grave façon ryūteki. Tension : grand taiko de gagaku, roulements de shime (kakko), ostinato étouffé.
func _w7(rng: RandomNumberGenerator) -> Dictionary:
	_tempo(66.0)
	var root := 220.0
	var prog := [0, 0, -1, 1, 0, -2, -1, 0]
	_intro_mode = true
	for c in [0, 1, 2, 4]:
		_ev(K_SHO, -8.0, _f(root * 2.0, YO, int(c)), _dur(K_SHO, 8.0 * _bs), 0.026)
	_gliss(K_KOTO, root, YO, -4.0, 10, 10, -1, 0.25, 0.14)
	_intro_mode = false
	_pad(root * 2.0, YO, prog, [0, 1, 2, 4], 0, 16, 2, 0.017)
	_arp(K_KOTO, "0 2 4 5 4 2", root, YO, prog, 0, 16, 2.0 / 3.0, 0.085)
	var a := _mp("4:2 5:1 7:1 | 6:3~ r:1 | 5:1 4:1 2:2 | 3:4~ | 4:1 5:1 6:1 7:1 | 8:2^ 7:2 | 6:1 5:1 4:2 | 5:4~")
	_mel(K_KOTO, a, 0.0, root, YO, 0, 0.24)
	var b := _mp("2:2^ 3:2 | 4:3~ 3:1 | 2:1 1:1 0:2v | 1:4 | 2:2 4:2 | 5:3~ 4:1 | 3:2 2:2 | 0:4~")
	_mel(K_FUE, b, 32.0, root * 2.0, YO, 0, 0.22)
	_mel(K_KOTO, _vary(rng, a, 0.35), 32.0, root, YO, 5, 0.07)
	for bar in 16:
		if rng.randf() < 0.6:
			_ev(K_SUZU, bar * 4.0 + float(rng.randi_range(1, 7)) * 0.5, 2900.0 + 120.0 * float(rng.randi_range(0, 3)), 0.7, 0.04)
	_sprinkle(rng, K_FURIN, root * 8.0, YO, 0, 16, 0.4, 0, 4, 0.03)
	_layer = 1
	_drums(K_ODAIKO, "X...............|X.......x.......", 60.0, 0, 16, 0.75)
	_drums(K_SHIME, "r...r...r.r.r...", 400.0, 0, 16, 0.22)
	_drums(K_TAIKO, "....x.......x...", 100.0, 0, 16, 0.45)
	_drums(K_KA, "..............x.", 1150.0, 0, 16, 0.2)
	_fill(K_TAIKO, 100.0, 7, 0.55)
	_fill(K_TAIKO, 106.0, 15, 0.6)
	_arp(K_KOTO_M, "0 2 4 2", root, YO, prog, 0, 16, 0.5, 0.075)
	_layer = 0
	return {"bpm": 66.0, "beats": 64.0, "intro": 8.0, "room": 0.9, "damp": 0.25,
		"bed": BED_DEEP, "bed_amp": 0.045}


# Monde 8, Yomi (le pays des morts) : gamme in en do dièse grave, 56 BPM, bourdon battant. Intro (bonshō,
# claquoirs) ; A : shakuhachi qui pleure (meri), biwa rare ; B : le biwa conte, shō en grappe dissonante.
# Tension : cœur d'ōdaiko, nagado, hyōshigi, ostinato de shamisen grave.
func _w8(rng: RandomNumberGenerator) -> Dictionary:
	_tempo(56.0)
	var root := 138.59
	_intro_mode = true
	_ev(K_KANE, -8.0, root * 0.5, 7.0, 0.32)
	_ev(K_HYO, -2.0, 1700.0, 0.15, 0.18)
	_ev(K_HYO, -1.75, 1700.0, 0.15, 0.14)
	_intro_mode = false
	var s := _mp("5:4~ | 4:2v 3:2 | 1:3v r:1 | 0:4~ | 2:2^ 3:2 | 4:3v 3:1 | 1:2 0:2v | 0:4~")
	_mel(K_SHAKU, s, 0.0, root * 2.0, IN_SC, 0, 0.32)
	for st in [0.0, 6.0, 14.0, 22.0, 28.0]:
		_ev(K_BIWA, float(st), _f(root, IN_SC, -5 + (rng.randi() % 3)), 4.0, 0.2, O_UP if rng.randf() < 0.4 else O_NONE)
	_ev(K_KANE, 0.0, root * 0.5, 7.0, 0.24)
	_ev(K_KANE, 32.0, root * 0.75, 7.0, 0.2)
	var b := _mp("0:1^ 1:1 0:2v | r:4 | 2:1 1:1 0:2 | -1:4v | 0:2^ 1:2 | 0:4")
	_mel(K_BIWA, b, 32.0, root, IN_SC, 0, 0.3)
	_mel(K_SHAKU, _mp("2:4~ | 1:4v | 3:4~ | 2:4v | 1:4 | 0:4~"), 32.0, root * 2.0, IN_SC, 0, 0.2)
	_pad(root * 4.0, IN_SC, [0, 0, -1], [0, 1, 2], 8, 6, 2, 0.012)
	_layer = 1
	_drums(K_ODAIKO, "X..x............", 46.0, 0, 14, 0.8)
	_drums(K_TAIKO, "........X.......", 86.0, 0, 14, 0.42)
	_drums(K_HYO, "............x.x.", 1700.0, 0, 14, 0.16)
	_drums(K_SHIME, "g...g...g...g.g.", 360.0, 0, 14, 0.18)
	_arp(K_SHAMI, "0 _ _ 1 0 _ _ _", root, IN_SC, [0, 0, -1, 0, 1, 0, -1], 0, 14, 0.5, 0.15)
	_fill(K_TAIKO, 86.0, 7, 0.45)
	_fill(K_TAIKO, 86.0, 13, 0.5)
	_layer = 0
	return {"bpm": 56.0, "beats": 56.0, "intro": 8.0, "room": 0.91, "damp": 0.28,
		"bed": BED_DRONE, "bed_amp": 0.03, "drone": root * 0.5, "drone_amp": 0.05, "pulse": 0.35}


# Gardien de monde : ōdaiko pressant, nagado, shime en doubles croches, fuchi, ostinato de shamisen, grappes de
# shō ; mélodie écrite (fue ou shakuhachi) puis réponse du koto (B), reprise un degré plus haut (A').
# Couleur du monde (ressac, clochettes, bonshō, enclume, pinceau, horagai, perles, bourdon).
# Intro 1 mesure (roulement), corps 24 mesures.
func _boss(rng: RandomNumberGenerator, w: int) -> Dictionary:
	var roots := [146.83, 146.83, 164.81, 146.83, 146.83, 110.0, 146.83, 164.81, 138.59]
	var bpms := [132.0, 132.0, 128.0, 120.0, 144.0, 136.0, 140.0, 126.0, 132.0]
	var mels := ["",
		"5:1 7:1 6:0.5 5:0.5 4:1 | 5:3^ r:1 | 4:0.5 5:0.5 4:0.5 3:0.5 2:1 3:1 | 4:2 2:2v | 5:1 7:1 8:1 7:1 | 6:2~ 5:1 4:1 | 3:1 4:1 5:1 3:1 | 2:4~",
		"0:0.5 2:0.5 3:1 2:1 0:1 | 4:2^ 3:1 2:1 | 3:0.5 4:0.5 5:1 4:1 3:1 | 2:4v | 5:1 4:1 5:1 7:1 | 8:2^ 7:2 | 5:1 4:1 3:1 2:1 | 0:4~",
		"0:2^ 1:1 2:1 | 3:3v r:1 | 5:1 4:1 3:1 1:1 | 2:4~ | 0:1 1:1 3:1 4:1 | 5:2^ 4:1 3:1 | 1:1 2:1 1:1 0:1 | 0:4v",
		"5:0.5 5:0.5 4:0.5 5:0.5 7:1 5:1 | 4:2 3:2v | 2:0.5 3:0.5 4:1 5:1 7:1 | 8:4~ | 7:1 5:1 4:1 3:1 | 4:2 5:2 | 7:1 8:1 7:1 5:1 | 4:4~",
		"2:1.5^ 3:0.5 4:1 2:1 | 1:2 0:2v | 2:1 4:1 5:1 4:1 | 3:4~ | 4:1 5:1 7:2^ | 6:1 5:1 4:2 | 3:1 2:1 1:1 2:1 | 0:4~",
		"7:0.5 8:0.5 7:1 5:1 4:1 | 5:2^ 7:2 | 8:0.5 9:0.5 8:1 7:1 5:1 | 4:4~ | 5:1 7:1 5:1 4:1 | 2:2 4:2' | 5:1 4:1 2:1 1:1 | 2:4~",
		"4:2^ 5:1 7:1 | 6:2~ 5:2 | 4:1 2:1 4:1 5:1 | 7:4~ | 8:1 7:1 6:1 5:1 | 4:2 5:2v | 4:1 2:1 1:1 2:1 | 0:4~",
		"0:3^ 1:1 | 0:2v -1:2 | 0:1 1:1 2:1 3:1 | 2:4v | 3:2^ 4:2 | 5:3v 4:1 | 3:1 2:1 1:1 0:1 | 0:4~"]
	var wi := clampi(w, 1, 8)
	var root: float = roots[wi]
	var bpm: float = bpms[wi]
	_tempo(bpm)
	var sc: Array = IN_SC
	if wi == 4 or wi == 6:
		sc = HIRA
	elif wi == 7:
		sc = KUMOI
	elif wi == 1:
		sc = YO
	var fue := wi == 2 or wi == 4 or wi == 6 or wi == 1
	var lead: int = K_FUE if fue else K_SHAKU
	var lroot: float = root * (4.0 if fue else 2.0)
	if lroot > 700.0:
		lroot *= 0.5
	_intro_mode = true
	for k in 7:
		_ev(K_TAIKO, -4.0 + k * 0.5, 96.0, 0.9, 0.18 + 0.07 * k)
	_ev(K_SHIME, -0.5, 430.0, 0.45, 0.3)
	_intro_mode = false
	var pa := [0, 0, 1, -1, 0, 0, 2, 1]
	var pb := [-1, -1, 0, 0, 1, 1, 2, 2]
	_drums(K_ODAIKO, "X.....x.X.......|X.....x.X...X.x.", 54.0, 0, 8, 0.85)
	_drums(K_ODAIKO, "X.......X.......", 54.0, 8, 8, 0.85)
	_drums(K_ODAIKO, "X.....x.X.......|X.....x.X...X.x.", 54.0, 16, 8, 0.9)
	_drums(K_TAIKO, "....X.......X...|....X..x....XxXx", 98.0, 0, 8, 0.5)
	_drums(K_TAIKO, "..x...x...x...x.|..x...x...x.x.x.", 98.0, 8, 6, 0.42)
	_drums(K_TAIKO, "x.x.x.x.xxxxxxxx|XxXxXxXxXXXXXXXX", 98.0, 14, 2, 0.5)
	_drums(K_TAIKO, "....X.......X...|....X..x....XxXx", 98.0, 16, 8, 0.55)
	_drums(K_SHIME, "XgxgXgxgXgxgXgxg", 440.0, 0, 8, 0.24)
	_drums(K_SHIME, "xgXgxgXgxgXgxgXg", 440.0, 8, 8, 0.22)
	_drums(K_SHIME, "XgxgXgxgXgxgXgxg", 440.0, 16, 8, 0.26)
	_drums(K_KA, "..x...x...x...x.", 1200.0, 0, 24, 0.18)
	_arp(K_SHAMI, "0 0 2 0 3 0 2 1", root, sc, pa, 0, 8, 0.5, 0.15)
	_arp(K_SHAMI, "0 3 2 0 4 3 2 1", root, sc, pb, 8, 8, 0.5, 0.14)
	_arp(K_SHAMI, "0 0 2 0 3 0 2 1", root, sc, pa, 16, 8, 0.5, 0.16)
	for bar in range(0, 24, 2):
		var pr: Array = pb if (bar >= 8 and bar < 16) else pa
		for c in [0, 1, 2]:
			_ev(K_SHO, bar * 4.0, _f(root * 2.0, sc, 5 + int(pr[bar % 8]) + int(c)), _dur(K_SHO, 8.0 * _bs), 0.016)
	var m1 := _mp(String(mels[wi]))
	_mel(lead, m1, 0.0, lroot, sc, 0, 0.3)
	var kb := _phrase(rng, 30.0, 7, 4, 11, [0.5, 0.5, 1.0, 1.0, 2.0], 0.1)
	_mel(K_KOTO, kb, 32.0, root, sc, 0, 0.2)
	_mel(lead, _vary(rng, _augment(_mp(String(mels[wi])).slice(0, 6), 2.0), 0.2), 34.0, lroot, sc, -1, 0.16)
	_mel(lead, _cadence(_vary(rng, m1, 0.25), 1), 64.0, lroot, sc, 1, 0.3)
	for k in 8:
		_ev(K_TAIKO, 94.0 + k * 0.25, 100.0, 0.9, 0.25 + 0.05 * k)
	# couleur du monde
	for bar in 24:
		var b0 := bar * 4.0
		match wi:
			1:
				if bar % 4 == 3:
					_gliss(K_KOTO, root * 2.0, sc, b0 + 2.0, 0, 8, 1, 0.125, 0.1)
			2:
				_ev(K_SUZU, b0 + 3.5, 2700.0, 0.7, 0.05)
			3:
				if bar % 8 == 0:
					_ev(K_KANE, b0, root * 0.5, 7.0, 0.24)
				if bar % 2 == 1:
					_ev(K_HYO, b0 + 3.0, 1900.0, 0.15, 0.14)
					_ev(K_HYO, b0 + 3.25, 1900.0, 0.15, 0.11)
			4:
				_ev(K_ANVIL, b0 + 1.0, 1250.0, 1.4, 0.08)
				_ev(K_ANVIL, b0 + 3.0, 1250.0, 1.4, 0.08)
			5:
				_ev(K_HYO, b0 + 1.0, 2400.0, 0.15, 0.06)
				_ev(K_HYO, b0 + 3.0, 2600.0, 0.15, 0.05)
				if bar % 4 == 3:
					_gliss(K_KOTO, root * 2.0, sc, b0 + 2.0, 9, 8, -1, 0.125, 0.1)
			6:
				_ev(K_SUZU, b0 + 1.5, 2300.0, 0.7, 0.05)
				if bar % 8 == 4:
					_ev(K_HORA, b0, root * 2.0, _dur(K_HORA, 3.0 * _bs), 0.16)
			7:
				if bar % 2 == 0:
					_gliss(K_KOTO, root * 2.0, sc, b0 + 2.5, 2, 6, 1, 0.125, 0.08)
				_ev(K_SUZU, b0 + 3.75, 3100.0, 0.7, 0.04)
			8:
				if bar % 4 == 0:
					_ev(K_KANE, b0, root * 0.5, 7.0, 0.26)
				_ev(K_HYO, b0 + 3.0, 1700.0, 0.15, 0.12)
	var bed := BED_NONE
	var bed_amp := 0.0
	var drone := 0.0
	match wi:
		1, 7:
			bed = BED_SURF if wi == 1 else BED_DEEP
			bed_amp = 0.035
		3, 6:
			bed = BED_WIND
			bed_amp = 0.03
		4:
			bed = BED_FIRE
			bed_amp = 0.03
			drone = root * 0.5
		8:
			bed = BED_DRONE
			bed_amp = 0.02
			drone = root * 0.5
	return {"bpm": bpm, "beats": 96.0, "intro": 4.0, "room": 0.82, "damp": 0.38,
		"bed": bed, "bed_amp": bed_amp, "waves": 4, "drone": drone, "drone_amp": 0.035, "pulse": 0.7,
		"lufs": LUFS_FIGHT, "lufs_fight": LUFS_FIGHT}


# Gardien de salle (Ō-kappa) : court et nerveux, 150 BPM, gamme in en sol, fue.
func _mini(rng: RandomNumberGenerator) -> Dictionary:
	_tempo(150.0)
	var root := 196.0
	_intro_mode = true
	for k in 12:
		_ev(K_SHIME, -4.0 + k * 0.25, 430.0, 0.45, 0.1 + 0.03 * k)
	_intro_mode = false
	var prog := [0, 0, 1, -1, 0, 0, 2, 1, 0, 1, -1, 0]
	_drums(K_ODAIKO, "X.......X.....x.", 56.0, 0, 12, 0.8)
	_drums(K_TAIKO, "....X.......X.x.", 100.0, 0, 12, 0.5)
	_drums(K_SHIME, "XgxgXgxgXgxgXgxg", 440.0, 0, 12, 0.24)
	_drums(K_HYO, "....x.......x...", 1900.0, 0, 12, 0.14)
	_arp(K_SHAMI, "0 2 1 0 3 2 1 2", root, IN_SC, prog, 0, 12, 0.5, 0.14, -2)
	var m := _mp("5:0.5 4:0.5 5:1 7:1 5:1 | 4:1 2:1 4:2 | 5:0.5 7:0.5 8:1 7:1 5:1 | 4:4v")
	_mel(K_FUE, m, 4.0, root * 2.0, IN_SC, 0, 0.28)
	_mel(K_FUE, _vary(rng, m, 0.4), 20.0, root * 2.0, IN_SC, 1, 0.28)
	_mel(K_FUE, _cadence(_vary(rng, m, 0.3), 5), 36.0, root * 2.0, IN_SC, 0, 0.28)
	for k in 4:
		_ev(K_TAIKO, 46.0 + k * 0.5, 104.0, 0.9, 0.3 + 0.08 * k)
	return {"bpm": 150.0, "beats": 48.0, "intro": 4.0, "room": 0.78, "damp": 0.4,
		"lufs": LUFS_FIGHT, "lufs_fight": LUFS_FIGHT}


# Victoire (~7 s) : roulement de shime qui enfle, ōdaiko, sararin montant, accord de shō, envol du fue,
# accord de koto, clochettes et rin.
func _win() -> Dictionary:
	_tempo(120.0)
	var root := 293.66
	for k in 8:
		_ev(K_SHIME, k * 0.25, 440.0, 0.45, 0.12 + 0.05 * k)
	_ev(K_TAIKO, 1.5, 100.0, 0.9, 0.4)
	_ev(K_ODAIKO, 2.0, 55.0, 1.6, 0.95)
	_ev(K_TAIKO, 2.0, 100.0, 0.9, 0.5)
	_gliss(K_KOTO, root * 0.5, YO, 2.0, 0, 11, 1, 0.0625, 0.2)
	for c in [0, 2, 4, 5]:
		_ev(K_SHO, 2.0, _f(root, YO, int(c)), 4.5, 0.05)
	_mel(K_FUE, _mp("5:0.5 7:0.5 8:1 7:0.5 8:0.5 | 10:5~"), 3.0, root, YO, 0, 0.3)
	_ev(K_ODAIKO, 6.0, 55.0, 1.6, 0.7)
	for c in [0, 2, 4, 5, 7]:
		_ev(K_KOTO, 6.0 + 0.04 * float(c), _f(root * 0.5, YO, int(c) + 5), 3.5, 0.15)
	_ev(K_SUZU, 6.0, 2600.0, 0.7, 0.1)
	_ev(K_RIN, 6.0, _f(root * 2.0, YO, 5), 5.0, 0.12)
	return {"bpm": 120.0, "beats": 10.0, "loop": false, "tail": 2.2, "room": 0.84, "damp": 0.32,
		"lufs": LUFS_JINGLE, "lufs_fight": LUFS_JINGLE}


# Défaite (~7 s) : coup grave, bonshō lointain, shakuhachi qui retombe (meri), biwa grave, souffle qui s'éteint.
func _lose() -> Dictionary:
	_tempo(60.0)
	var root := 146.83
	_ev(K_ODAIKO, 0.0, 48.0, 1.6, 0.85)
	_ev(K_KANE, 0.0, 73.42, 7.0, 0.32)
	_ev(K_SHAKU, 0.6, _f(root * 2.0, IN_SC, 6), 2.0, 0.3, O_FALL)
	_ev(K_SHAKU, 2.6, _f(root * 2.0, IN_SC, 3), 2.6, 0.24, O_FALL)
	_ev(K_BIWA, 2.4, _f(root, IN_SC, -1), 4.0, 0.22)
	_ev(K_BIWA, 2.7, _f(root, IN_SC, -5), 4.0, 0.26, O_FALL)
	_ev(K_ODAIKO, 2.4, 44.0, 1.6, 0.55)
	return {"bpm": 60.0, "beats": 5.0, "loop": false, "tail": 2.5, "room": 0.9, "damp": 0.3,
		"lufs": LUFS_JINGLE, "lufs_fight": LUFS_JINGLE}
