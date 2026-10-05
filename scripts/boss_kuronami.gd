extends Node3D
## Monde 5 — boss final Kuro-Nami, la Vague Noire (design/UNIVERS.md), 150 PV en 3 phases de 50.
##  Phase 1 « Les griffes » : la vague du fond tend 5 doigts d'écume qui griffent l'arène
##           (bandes annoncées 1.0 s). Un trait qui LONGE un doigt posé (≥ 70 % de sa longueur)
##           le tranche = 10 dégâts. Les coups en travers ricochent.
##  Phase 2 « Kaeshi » : des vagues dévalent 3 couloirs (annonces 1.2 s). Un aller-retour
##           (retour au point de départ) devant une vague la renvoie = 8 dégâts.
##  Phase 3 « L'Ensō » : un œil d'encre au centre. Seul dégât : une boucle presque fermée
##           (rayon ≥ 2.5 m) autour de l'œil = 25 dégâts.
## Interface identique à boss.gd. check_dash renvoie toujours false : les positions de ruée
## sont enregistrées, puis analysées dans end_stroke (fin réelle de la ruée, traits enchaînés compris).

const Toon = preload("res://scripts/toon.gd")

const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (comme main.gd)
const INK := Color("#0E1A2E")  # vague noire / mer d'encre
const FOAM := Color("#E9EEF0")  # écume
const FOAM_SHADE := Color("#C9D6DC")

const FINGER_LEN := 11.0  # longueur d'un doigt déployé (dont ~10 m dans l'arène)
const FINGER_W := 1.2
const FINGER_BASE_Z := -9.4
const FINGER_X := [-3.4, -1.7, 0.0, 1.7, 3.4]
const FINGER_IDLE_PITCH := 1.3
const FINGER_AIM_PITCH := 0.75
const LANE_X := [-3.07, 0.0, 3.07]
const LANE_W := 2.9
const ENSO_R := 2.5
const EYE_R := 0.8
const MAX_PTS := 900  # au-delà, la ruée n'est plus enregistrée
const DANGER_MARGIN := 0.35  # marge de danger_at (comme is_danger de main)

var kind := "kuronami"
var main: Node
var hero: Node3D
var title := "Kuro-Nami"
var hp := 150.0
var max_hp := 150.0
var dead := false
var max_hp_mult := 1.0  # difficulté du monde

var _phase := 0
var _state := "intro"
var _timer := 1.6
var _t := 0.0
var _unit := 1.0  # 1 « PV de la bible » (150 au total) en PV réels
var _flash := 0.0
var _volley := 0
var _last_lane := -1
var _pending_shift := false
var _eye_grace := 0.0  # l'œil ne blesse pas au contact juste après une boucle autour de lui

var _pts: Array = []  # positions de la ruée en cours (Vector3, y = 0)
var _zones: Array = []  # annonces actives (bandes et disques)
var _fingers: Array = []  # Dictionary par doigt
var _waves: Array = []  # vagues des couloirs (phase 2)
var _drops: Array = []  # attaques de l'œil (phase 3)

var _m_ink: StandardMaterial3D
var _m_foam: StandardMaterial3D
var _m_shade: StandardMaterial3D
var _wave: Node3D  # la grande vague du fond
var _crests: Array = []
var _eye: Node3D
var _eye_ball: Node3D
var _eye_iris: Node3D
var _orbit: Node3D


func setup(k: String, m: Node) -> void:
	kind = k
	main = m
	hero = m.hero


func _ready() -> void:
	hp = 150.0
	hp *= max_hp_mult
	max_hp = hp
	_unit = max_hp / 150.0
	_m_ink = Toon.mat(INK)
	_m_foam = Toon.mat(FOAM)
	_m_shade = Toon.mat(FOAM_SHADE)
	_build_wave()
	_build_fingers()
	_build_eye()
	_wave.position.y = -4.5
	_state = "intro"
	_timer = 1.6


# ------------------------------------------------------------------ construction

func _build_wave() -> void:
	_wave = Node3D.new()
	add_child(_wave)
	_wave.position = Vector3(0, 0, -11.0)
	# le Fuji minuscule au loin, comme chez Hokusai
	Toon.part(_wave, Toon.cyl(0.0, 3.2, 2.6, 7), Toon.mat(Toon.PRUSSIAN), Vector3(-3.0, 1.0, -6.0))
	Toon.part(_wave, Toon.cyl(0.0, 1.0, 0.82, 7), Toon.mat(Toon.WASHI), Vector3(-3.0, 1.9, -6.0))
	# mer d'encre entre la vague et l'arène
	var sea := Toon.part(_wave, Toon.box(Vector3(19.0, 0.004, 3.4)), Toon.flat(Color(INK, 0.9)), Vector3(0, 0.02, 1.2))
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# colonnes de la vague, lèvre qui s'enroule vers l'arène, griffes d'écume
	for i in 12:
		var x := -8.25 + i * 1.5
		var h := 3.0 + 1.1 * absf(sin(i * 1.7)) + (1.3 if i == 4 or i == 8 else 0.0)
		var col := Node3D.new()
		_wave.add_child(col)
		col.position = Vector3(x, 0, randf_range(-0.3, 0.3))
		Toon.part(col, Toon.cyl(0.75, 1.05, h, 6), _m_ink, Vector3(0, h * 0.5 - 0.4, 0))
		Toon.part(col, Toon.sphere(0.8), _m_ink, Vector3(0, h - 0.3, 0.55), Vector3(0.95, 0.6, 1.3))
		Toon.part(col, Toon.sphere(0.45), _m_foam, Vector3(0, h - 0.05, 1.15), Vector3(1.1, 0.5, 1.0))
		for c in 3:
			var claw := Toon.part(col, Toon.cyl(0.0, 0.14, 0.6, 5), _m_foam, Vector3(-0.4 + c * 0.4, h - 0.25, 1.45))
			claw.rotation.x = 2.2
		_crests.append(col)


func _build_fingers() -> void:
	var n := 9
	var seg_l := FINGER_LEN / float(n)
	for i in 5:
		var root := Node3D.new()
		add_child(root)
		var bx: float = FINGER_X[i]
		root.position = Vector3(bx, 0, FINGER_BASE_Z)
		# doigt couché le long de -Z local : âme d'encre, crête d'écume, phalanges claires
		for s in n:
			var u := float(s) / float(n - 1)
			var r := lerpf(0.5, 0.2, u)
			var y := 0.3 + 0.35 * sin(PI * (s + 0.5) / float(n))
			var zc := -(s + 0.5) * seg_l
			var bone := Toon.part(root, Toon.cyl(r * 0.85, r, seg_l * 1.08, 6), _m_ink, Vector3(0, y, zc))
			bone.rotation.x = -PI * 0.5
			Toon.part(root, Toon.sphere(r * 0.9), _m_foam, Vector3(0, y + r * 0.55, zc), Vector3(1.0, 0.45, 1.5))
			if s > 0:
				Toon.part(root, Toon.sphere(r * 1.05), _m_shade, Vector3(0, y, -s * seg_l), Vector3(1.0, 0.8, 0.6))
		# griffe recourbée au bout
		var tip := Toon.part(root, Toon.cyl(0.0, 0.26, 1.0, 6), _m_foam, Vector3(0, 0.45, -FINGER_LEN - 0.2))
		tip.rotation.x = -2.3
		root.rotation = Vector3(FINGER_IDLE_PITCH, PI, 0)
		root.scale = Vector3.ONE * 0.22
		_fingers.append({
			"node": root, "base": root.position, "alive": true, "state": "idle", "t": 0.0,
			"a": Vector3.ZERO, "b": Vector3.ZERO, "yaw": PI, "zone": {}, "hurt": 0.0, "touched": false,
		})


func _build_eye() -> void:
	_eye = Node3D.new()
	add_child(_eye)
	_eye.visible = false
	Toon.disc(_eye, 1.3, Color(INK, 0.85), 0.02)
	# cercle vermillon autour de l'œil sumi
	var ring := TorusMesh.new()
	ring.inner_radius = 0.8
	ring.outer_radius = 1.02
	ring.rings = 24
	ring.ring_segments = 6
	Toon.part(_eye, ring, Toon.mat(Toon.VERMILION), Vector3(0, 0.12, 0), Vector3(1, 0.6, 1))
	_eye_ball = Node3D.new()
	_eye.add_child(_eye_ball)
	Toon.part(_eye_ball, Toon.sphere(0.72), Toon.mat(Toon.SUMI), Vector3(0, 0.25, 0), Vector3(1.0, 0.55, 1.0))
	_eye_iris = Node3D.new()
	_eye_ball.add_child(_eye_iris)
	Toon.part(_eye_iris, Toon.sphere(0.3), Toon.mat(Toon.VERMILION, false), Vector3(0, 0.58, 0), Vector3(1.0, 0.35, 1.0))
	Toon.part(_eye_iris, Toon.sphere(0.11), Toon.flat(FOAM), Vector3(0.1, 0.68, -0.1))
	# petites crêtes qui tournent en spirale autour de l'œil
	_orbit = Node3D.new()
	_eye.add_child(_orbit)
	for i in 6:
		var a := TAU * i / 6.0
		var cr := Node3D.new()
		_orbit.add_child(cr)
		cr.position = Vector3(cos(a) * 1.55, 0, sin(a) * 1.55)
		cr.rotation.y = -a
		Toon.part(cr, Toon.cyl(0.0, 0.32, 0.9, 5), _m_ink, Vector3(0, 0.4, 0))
		var f := Toon.part(cr, Toon.cyl(0.0, 0.12, 0.45, 5), _m_foam, Vector3(0, 0.75, 0.18))
		f.rotation.x = 1.9
	# pointillés d'encre : le rayon minimal de l'ensō
	for i in 28:
		var a := TAU * i / 28.0
		var d := Toon.disc(_eye, 0.1, Color(INK, 0.4), 0.03)
		d.position = Vector3(cos(a) * ENSO_R, 0.03, sin(a) * ENSO_R)


func _make_lane_wave(x: float) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.position = Vector3(x, -1.4, -HALF.y - 0.6)
	var w := LANE_W - 0.2
	Toon.part(n, Toon.box(Vector3(w, 1.0, 0.9)), _m_ink, Vector3(0, 0.5, -0.2))
	var curl := Toon.part(n, Toon.cyl(0.55, 0.55, w, 7), _m_ink, Vector3(0, 1.15, 0.15))
	curl.rotation.z = PI * 0.5
	var lip := Toon.part(n, Toon.cyl(0.3, 0.3, w + 0.1, 7), _m_foam, Vector3(0, 1.45, 0.55))
	lip.rotation.z = PI * 0.5
	for c in 5:
		var claw := Toon.part(n, Toon.cyl(0.0, 0.15, 0.6, 5), _m_foam, Vector3(-w * 0.4 + c * w * 0.2, 1.3, 0.85))
		claw.rotation.x = 2.0
	var sh := Toon.part(n, Toon.box(Vector3(w, 0.004, 1.6)), Toon.flat(Color(INK, 0.25)), Vector3(0, 0.02, 0.2))
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


# ------------------------------------------------------------------ interface avec main

## Enregistre la ruée ; les dégâts sont calculés à la fin du trait (toujours false).
func check_dash(a: Vector3, b: Vector3, _stroke_id: int) -> bool:
	if dead or not hero.dashing:
		return false
	if _pts.is_empty():
		_pts.append(Vector3(a.x, 0, a.z))
	if _pts.size() < MAX_PTS:
		_pts.append(Vector3(b.x, 0, b.z))
	if _state == "p1":
		# petit retour quand la lame touche un doigt posé
		for f: Dictionary in _fingers:
			if bool(f["touched"]) or String(f["state"]) != "rest":
				continue
			var fa: Vector3 = f["a"]
			var fb: Vector3 = f["b"]
			var q := _closest(b, fa, fb)
			if _flat_dist(q, b) < FINGER_W * 0.5 + 0.45:
				f["touched"] = true
				main.small_hit(q + Vector3(0, 0.4, 0))
	return false


func take_hit(dmg: float, _dir: Vector3) -> void:
	_deal(dmg)


## Fin réelle de la ruée : on reconnaît la forme tracée selon la phase.
func end_stroke(_stroke_id: int) -> void:
	if dead:
		_pts.clear()
		return
	if not _pts.is_empty():
		_pts.append(Vector3(hero.position.x, 0, hero.position.z))
	if _pts.size() >= 2:
		match _state:
			"p1":
				_check_claws(_resample(0.2))
			"p2":
				_check_kaeshi()
			"p3":
				_check_enso(_resample(0.2))
	_pts.clear()
	for f: Dictionary in _fingers:
		f["touched"] = false


## Vrai si le point p est dans une attaque annoncée qui frappe d'ici eta secondes,
## ou dans une attaque en cours (griffe qui vient de s'abattre, vague qui dévale).
func danger_at(p: Vector3, eta: float) -> bool:
	if dead:
		return false
	var lim := eta + DANGER_MARGIN
	for z: Dictionary in _zones:
		var t: float = z["t"]
		if t >= lim:
			continue
		var r: float = z["r"]
		var q: Vector3
		if String(z["kind"]) == "band":
			var a: Vector3 = z["a"]
			var b: Vector3 = z["b"]
			q = _closest(p, a, b)
		else:
			q = z["c"]
		if _flat_dist(p, q) < r + DANGER_MARGIN:
			return true
	if _state == "p1":
		for f: Dictionary in _fingers:
			var h: float = f["hurt"]
			if h <= 0.0 or eta > h + DANGER_MARGIN:
				continue
			var fa: Vector3 = f["a"]
			var fb: Vector3 = f["b"]
			if _flat_dist(p, _closest(p, fa, fb)) < FINGER_W * 0.5 + 0.2 + DANGER_MARGIN:
				return true
	elif _state == "p2":
		# vague qui roule : elle couvre [z - 0.55, z + 0.55] et avance à vitesse constante
		var speed := 4.0 + 1.6 * _phase_prog()
		var t0 := maxf(eta - DANGER_MARGIN, 0.0)
		for w: Dictionary in _waves:
			if String(w["state"]) != "roll":
				continue
			var x: float = w["x"]
			var wz: float = w["z"]
			if absf(p.x - x) > LANE_W * 0.5 + 0.2 + DANGER_MARGIN:
				continue
			if p.z > wz + speed * t0 - 0.55 - DANGER_MARGIN and p.z < wz + speed * lim + 0.55 + DANGER_MARGIN:
				return true
	return false


func touching_hero(p: Vector3) -> bool:
	if dead:
		return false
	match _state:
		"p1":
			# la griffe qui vient de s'abattre blesse toute sa bande
			for f: Dictionary in _fingers:
				var h: float = f["hurt"]
				if h <= 0.0:
					continue
				var fa: Vector3 = f["a"]
				var fb: Vector3 = f["b"]
				if _flat_dist(p, _closest(p, fa, fb)) <= FINGER_W * 0.5 + 0.2:
					return true
		"p2":
			for w: Dictionary in _waves:
				if String(w["state"]) != "roll":
					continue
				var x: float = w["x"]
				var z: float = w["z"]
				if absf(p.x - x) <= LANE_W * 0.5 + 0.2 and absf(p.z - z) <= 0.55:
					return true
		"p3":
			if _eye.visible and _eye_grace <= 0.0 and Vector2(p.x, p.z).length() < EYE_R:
				return true
	return false


## Dégâts de zone (techniques, pouvoirs) : touche la partie vulnérable la plus proche de `center` dans `radius`.
## Renvoie le point touché, ou Vector3.INF si rien n'est touché (boss invulnérable à cet instant, hors de portée, mort).
## Dégâts simples : doigt posé (p1), vague qui roule (p2), œil (p3). Ni doigt tranché ni vague renvoyée.
func aoe_hit(center: Vector3, radius: float, dmg: float, fx := true) -> Vector3:
	if dead or _phase == 0 or _pending_shift:
		return Vector3.INF
	var found := false
	var best := INF
	var at := Vector3.ZERO
	match _state:
		"p1":
			for f: Dictionary in _fingers:
				if not bool(f["alive"]) or String(f["state"]) != "rest":
					continue
				var fa: Vector3 = f["a"]
				var fb: Vector3 = f["b"]
				var q := _closest(center, fa, fb)
				var d := _flat_dist(q, center) - FINGER_W * 0.5
				if d < radius and d < best:
					best = d
					found = true
					at = q + Vector3(0, 0.4, 0)
		"p2":
			for w: Dictionary in _waves:
				if String(w["state"]) != "roll":
					continue
				var x: float = w["x"]
				var wz: float = w["z"]
				if absf(wz) > HALF.y:
					continue
				var dx := maxf(absf(center.x - x) - LANE_W * 0.5, 0.0)
				var dz := maxf(absf(center.z - wz) - 0.55, 0.0)
				var d2 := Vector2(dx, dz).length()
				if d2 < radius and d2 < best:
					best = d2
					found = true
					at = Vector3(clampf(center.x, x - LANE_W * 0.5, x + LANE_W * 0.5), 0.8, wz)
		"p3":
			if _eye.visible and Vector2(center.x, center.z).length() - EYE_R < radius:
				found = true
				at = Vector3(0, 0.5, 0)
	if not found:
		return Vector3.INF
	var fl := _flash
	_deal(dmg)
	if not fx:
		_flash = fl
	return at


# ------------------------------------------------------------------ détection des formes

## Points de la ruée rééchantillonnés tous les `step` mètres.
func _resample(step: float) -> Array:
	var out: Array = []
	if _pts.is_empty():
		return out
	var first: Vector3 = _pts[0]
	out.append(first)
	for i in range(1, _pts.size()):
		var a: Vector3 = _pts[i - 1]
		var b: Vector3 = _pts[i]
		var n := int(ceil(_flat_dist(a, b) / step))
		for k in range(1, n + 1):
			out.append(a.lerp(b, float(k) / float(n)))
	return out


## Part de la longueur a..b longée par le trait (20 tranches, à `reach` m près).
func _coverage(samples: Array, a: Vector3, b: Vector3, reach: float) -> float:
	var seg := Vector2(b.x - a.x, b.z - a.z)
	var l2 := seg.length_squared()
	if l2 < 0.01:
		return 0.0
	var bins: Array = []
	bins.resize(20)
	bins.fill(false)
	var marked := 0
	for q: Vector3 in samples:
		var rel := Vector2(q.x - a.x, q.z - a.z)
		var t := clampf(rel.dot(seg) / l2, 0.0, 1.0)
		if (rel - seg * t).length() > reach:
			continue
		var bi := mini(19, int(t * 20.0))
		if not bool(bins[bi]):
			bins[bi] = true
			marked += 1
	return float(marked) / 20.0


func _check_claws(samples: Array) -> void:
	for f: Dictionary in _fingers:
		if not bool(f["alive"]) or String(f["state"]) != "rest":
			continue
		var a: Vector3 = f["a"]
		var b: Vector3 = f["b"]
		var cov := _coverage(samples, a, b, FINGER_W * 0.5 + 0.45)
		if cov >= 0.7:
			_cut_finger(f)
		elif cov >= 0.08:
			# coupé en travers : l'écume se referme
			var q := _closest(_pts[_pts.size() - 1], a, b)
			main.float_text(q + Vector3(0, 0.6, 0), "×0", FOAM)
			main.clang(q)


func _cut_finger(f: Dictionary) -> void:
	f["alive"] = false
	f["state"] = "cut"
	f["t"] = 0.4
	f["hurt"] = 0.0
	var a: Vector3 = f["a"]
	var b: Vector3 = f["b"]
	for k in 5:
		main.splash(a.lerp(b, (k + 0.5) / 5.0) + Vector3(0, 0.4, 0), FOAM, 8)
	var mid := a.lerp(b, 0.5)
	var d := 10.0 * _unit
	main.big_hit(mid)
	main.float_text(mid + Vector3(0, 0.8, 0), str(roundi(d)), Toon.VERMILION)
	_deal(d)


func _check_kaeshi() -> void:
	if _pts.size() < 3:
		return
	var start: Vector3 = _pts[0]
	var last: Vector3 = _pts[_pts.size() - 1]
	var far := 0.0
	for p: Vector3 in _pts:
		far = maxf(far, _flat_dist(p, start))
	# aller-retour : on va loin puis on revient près du départ
	if far < 2.0 or _flat_dist(start, last) > maxf(1.2, far * 0.35):
		return
	for w: Dictionary in _waves:
		if String(w["state"]) != "roll":
			continue
		var x: float = w["x"]
		var z: float = w["z"]
		var ahead := false
		for p: Vector3 in _pts:
			if absf(p.x - x) <= LANE_W * 0.5 + 0.4 and p.z >= z - 0.8 and p.z <= z + 5.0:
				ahead = true
				break
		if ahead:
			_kaeshi(w)


func _kaeshi(w: Dictionary) -> void:
	w["state"] = "back"
	var x: float = w["x"]
	var z: float = w["z"]
	var p := Vector3(x, 0.8, z)
	var d := 8.0 * _unit
	main.big_hit(p)
	main.splash(p, FOAM, 16)
	main.float_text(p + Vector3(0, 0.6, 0), "Kaeshi ! " + str(roundi(d)), Toon.VERMILION)
	_deal(d)


func _check_enso(samples: Array) -> void:
	var turn := 0.0
	var sum_r := 0.0
	var sum_r2 := 0.0
	var min_r := 99.0
	var cnt := 0
	var prev_a := 0.0
	var has_prev := false
	for q: Vector3 in samples:
		var r := Vector2(q.x, q.z).length()
		min_r = minf(min_r, r)
		if r < 0.3:
			has_prev = false
			continue
		var a := atan2(q.z, q.x)
		if has_prev:
			turn += wrapf(a - prev_a, -PI, PI)
		prev_a = a
		has_prev = true
		sum_r += r
		sum_r2 += r * r
		cnt += 1
	if absf(turn) >= PI:
		# la technique Ensō de main fait bondir le héros au centre du cercle, donc dans l'œil :
		# sans ce répit, chaque ensō réussi coûtait un cœur à l'atterrissage
		_eye_grace = 1.5
	if cnt < 6:
		return
	var mean := sum_r / float(cnt)
	var sd := sqrt(maxf(0.0, sum_r2 / float(cnt) - mean * mean))
	var round_k := 1.0 - sd / maxf(mean, 0.01)
	var closed := absf(turn) >= TAU * 0.82  # presque fermée (≥ ~295°)
	var wide := mean >= ENSO_R - 0.15 and min_r >= 1.3
	if closed and wide and round_k >= 0.6:
		var d := 25.0 * _unit
		_enso_fx(mean)
		main.big_hit(Vector3(0, 0.5, 0))
		main.splash(Vector3(0, 0.6, 0), INK, 24)
		main.float_text(Vector3(0, 1.6, 0), "Ensō ! " + str(roundi(d)), Toon.VERMILION)
		main.shake = maxf(float(main.shake), 0.6)
		_deal(d)
	elif absf(turn) >= PI:
		# une boucle ratée : on explique pourquoi
		var msg := "Trop serré" if not wide else "Pas fermé"
		main.float_text(Vector3(0, 1.4, 0), msg, FOAM)
		main.clang(Vector3(0, 0.5, 0))


func _enso_fx(r: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = maxf(0.2, r - 0.14)
	ring.outer_radius = r + 0.14
	ring.rings = 48
	ring.ring_segments = 4
	var m := Toon.flat(Color(Toon.VERMILION, 0.9))
	var fx := Toon.part(self, ring, m, Vector3(0, 0.08, 0), Vector3(1, 0.2, 1))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector3(1.35, 0.2, 1.35), 0.7)
	tw.tween_property(m, "albedo_color", Color(Toon.VERMILION, 0.0), 0.7)
	tw.chain().tween_callback(fx.queue_free)


# ------------------------------------------------------------------ outils

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _closest(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var seg := Vector3(b.x - a.x, 0, b.z - a.z)
	var t := 0.0
	if seg.length_squared() > 0.0001:
		t = clampf(Vector3(p.x - a.x, 0, p.z - a.z).dot(seg) / seg.length_squared(), 0.0, 1.0)
	return Vector3(a.x, 0, a.z) + seg * t


func _in_arena(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -HALF.x + 0.6, HALF.x - 0.6), 0, clampf(p.z, -HALF.y + 0.6, HALF.y - 0.6))


## Avancement dans la phase en cours (0 → 1).
func _phase_prog() -> float:
	var third := max_hp / 3.0
	var top := max_hp - third * float(maxi(_phase - 1, 0))
	return clampf((top - hp) / third, 0.0, 1.0)


func _deal(d: float) -> void:
	if dead or _phase == 0 or _state == "shift" or _state == "intro":
		return
	var floor_hp := max_hp * float(3 - _phase) / 3.0
	hp = maxf(hp - d, floor_hp)
	_flash = 0.3
	if hp <= floor_hp + 0.001:
		if _phase >= 3:
			_die()
		else:
			_pending_shift = true


func _die() -> void:
	hp = 0.0
	dead = true
	_state = "dying"
	_timer = 0.0
	_clear_all()
	main.boss_killed(self)


## Bande annoncée de a à b (largeur w), qui se remplit en t secondes.
func _band_zone(a: Vector3, b: Vector3, w: float, t: float) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var d := b - a
	d.y = 0
	var l := maxf(d.length(), 0.1)
	root.position = Vector3(a.x, 0, a.z)
	root.rotation.y = atan2(-d.x, -d.z)
	var bg := Toon.part(root, Toon.box(Vector3(w, 0.004, l)), Toon.flat(Color(Toon.VERMILION, 0.18)), Vector3(0, 0.03, -l * 0.5))
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var piv := Node3D.new()
	root.add_child(piv)
	piv.position.y = 0.035
	piv.scale = Vector3(1, 1, 0.01)
	var fill := Toon.part(piv, Toon.box(Vector3(w, 0.004, l)), Toon.flat(Color(Toon.VERMILION, 0.45)), Vector3(0, 0, -l * 0.5))
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var z := {
		"kind": "band", "root": root, "piv": piv, "fill": fill, "a": Vector3(a.x, 0, a.z),
		"b": Vector3(b.x, 0, b.z), "r": w * 0.5, "t": t, "total": t,
	}
	_zones.append(z)
	return z


## Disque annoncé (centre c, rayon r), qui se remplit en t secondes.
func _disc_zone(c: Vector3, r: float, t: float) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(c.x, 0, c.z)
	Toon.disc(root, r, Color(Toon.VERMILION, 0.18), 0.03)
	var fill := Toon.disc(root, r, Color(Toon.VERMILION, 0.45), 0.035)
	fill.scale = Vector3(0.01, 1, 0.01)
	var z := {"kind": "disc", "root": root, "fill": fill, "c": Vector3(c.x, 0, c.z), "r": r, "t": t, "total": t}
	_zones.append(z)
	return z


## Fait avancer une annonce ; vrai quand elle frappe.
func _zone_tick(z: Dictionary, delta: float) -> bool:
	var t: float = z["t"]
	t -= delta
	z["t"] = t
	var total: float = z["total"]
	var k := clampf(1.0 - t / total, 0.01, 1.0)
	var fill: MeshInstance3D = z["fill"]
	if String(z["kind"]) == "band":
		var piv: Node3D = z["piv"]
		piv.scale = Vector3(1, 1, k)
	else:
		fill.scale = Vector3(k, 1, k)
	var m := fill.material_override as StandardMaterial3D
	m.albedo_color = Color(FOAM, 0.85) if t < 0.15 else Color(Toon.VERMILION, 0.45)
	return t <= 0.0


func _free_zone(z: Dictionary) -> void:
	if z.is_empty():
		return
	var root: Node3D = z["root"]
	if is_instance_valid(root):
		root.queue_free()
	_zones.erase(z)


func _clear_all() -> void:
	for z: Dictionary in _zones:
		var root: Node3D = z["root"]
		if is_instance_valid(root):
			root.queue_free()
	_zones.clear()
	for f: Dictionary in _fingers:
		f["zone"] = {}
		f["hurt"] = 0.0
		if String(f["state"]) != "cut":
			var fn: Node3D = f["node"]
			fn.visible = false
			f["state"] = "gone"
			f["alive"] = false
	for w: Dictionary in _waves:
		var wn: Node3D = w["node"]
		if is_instance_valid(wn):
			wn.queue_free()
	_waves.clear()
	_drops.clear()


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_t += delta
	_animate_decor(delta)
	match _state:
		"intro":
			_timer -= delta
			var k := clampf(1.0 - _timer / 1.6, 0.0, 1.0)
			_wave.position.y = lerpf(-4.5, 0.0, 1.0 - pow(1.0 - k, 3.0))
			if _timer <= 0.0:
				_wave.position.y = 0.0
				_start_phase(1)
		"p1":
			_phase1(delta)
		"p2":
			_phase2(delta)
		"p3":
			_phase3(delta)
		"shift":
			# la vague gronde et se reforme
			_timer -= delta
			_wave.position.y = sin(_t * 9.0) * 0.25 * clampf(_timer, 0.0, 1.0)
			for f: Dictionary in _fingers:
				_finger_step(f, delta)
			if _timer <= 0.0:
				_wave.position.y = 0.0
				_start_phase(_phase + 1)
		"dying":
			_timer += delta
			_wave.position.y = lerpf(0.0, -5.0, clampf(_timer / 2.6, 0.0, 1.0))
			_eye.scale = Vector3.ONE * maxf(0.01, 1.0 - _timer / 1.2)
			if int(_timer * 5.0) != int((_timer - delta) * 5.0):
				main.splash(Vector3(randf_range(-4.0, 4.0), 0.6, -8.2), INK, 8)
			if _timer > 2.8:
				queue_free()
	if _pending_shift and not dead:
		_begin_shift()


func _animate_decor(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
	for i in _crests.size():
		var col: Node3D = _crests[i]
		col.position.y = sin(_t * 1.3 + i * 0.8) * 0.15
		col.rotation.x = sin(_t * 0.9 + i) * 0.04 + (0.12 if _flash > 0.0 else 0.0)


func _start_phase(p: int) -> void:
	_phase = p
	_pts.clear()
	_volley = 0
	match p:
		1:
			_state = "p1"
			_timer = 0.8
			main.float_text(Vector3(0, 1.5, -5.0), "Les griffes", FOAM)
		2:
			_state = "p2"
			_timer = 1.0
			main.float_text(Vector3(0, 1.5, -5.0), "Kaeshi", FOAM)
			main.spawn_minions(["oni", "oni"])
		_:
			_state = "p3"
			_timer = 1.8
			_eye.visible = true
			_eye.scale = Vector3.ONE * 0.01
			main.float_text(Vector3(0, 1.8, 0), "L'Ensō", FOAM)
			main.splash(Vector3(0, 0.5, 0), INK, 20)


func _begin_shift() -> void:
	_pending_shift = false
	_clear_all()
	_state = "shift"
	_timer = 2.2
	main.shake = maxf(float(main.shake), 0.5)


# --- phase 1 : les griffes

func _phase1(delta: float) -> void:
	var busy := false
	for f: Dictionary in _fingers:
		_finger_step(f, delta)
		var st: String = f["state"]
		if st != "idle" and st != "gone":
			busy = true
	if not busy:
		_timer -= delta
		if _timer <= 0.0:
			_volley += 1
			_launch_claws()
			_timer = 0.7


func _alive_fingers() -> int:
	var n := 0
	for f: Dictionary in _fingers:
		if bool(f["alive"]):
			n += 1
	return n


func _launch_claws() -> void:
	var idle: Array = []
	for f: Dictionary in _fingers:
		if bool(f["alive"]) and String(f["state"]) == "idle":
			idle.append(f)
	if idle.is_empty():
		return
	idle.shuffle()
	var alive_n := _alive_fingers()
	var count := 2 if alive_n >= 3 else alive_n
	count = mini(count, idle.size())
	for i in count:
		var f: Dictionary = idle[i]
		var base: Vector3 = f["base"]
		# la première griffe vise le héros, les autres balaient au hasard
		var target := hero.position if i == 0 else Vector3(randf_range(-4.0, 4.0), 0, randf_range(-1.5, 1.5))
		var d := Vector3(target.x - base.x, 0, target.z - base.z)
		if d.length() < 0.5 or d.z < 0.3:
			d = Vector3(0, 0, 1)
		d = d.normalized()
		# garde la pointe dans l'arène
		var dx := clampf(d.x * FINGER_LEN, -HALF.x + 0.4 - base.x, HALF.x - 0.4 - base.x)
		var dz := sqrt(maxf(FINGER_LEN * FINGER_LEN - dx * dx, 1.0))
		var dir := Vector3(dx, 0, dz) / FINGER_LEN
		var t0 := (-HALF.y + 0.2 - base.z) / maxf(dir.z, 0.2)
		var a := base + dir * t0
		var b := base + dir * FINGER_LEN
		f["a"] = Vector3(a.x, 0, a.z)
		f["b"] = Vector3(b.x, 0, b.z)
		f["yaw"] = atan2(-dir.x, -dir.z)
		f["zone"] = _band_zone(a, b, FINGER_W, 1.0)
		f["state"] = "warn"
		f["t"] = 1.0


func _finger_step(f: Dictionary, delta: float) -> void:
	var n: Node3D = f["node"]
	var st: String = f["state"]
	var t: float = f["t"]
	var yaw: float = f["yaw"]
	var hurt: float = f["hurt"]
	if hurt > 0.0:
		f["hurt"] = hurt - delta
	match st:
		"idle":
			# replié sur la vague, il frémit
			n.rotation = Vector3(FINGER_IDLE_PITCH + sin(_t * 2.0 + n.position.x) * 0.08, lerp_angle(n.rotation.y, PI, minf(1.0, delta * 4.0)), 0)
			n.scale = n.scale.lerp(Vector3.ONE * 0.22, minf(1.0, delta * 4.0))
		"warn":
			var z: Dictionary = f["zone"]
			var k := clampf(1.0 - t / 1.0, 0.0, 1.0)
			n.rotation = Vector3(lerpf(FINGER_IDLE_PITCH, FINGER_AIM_PITCH, k), lerp_angle(n.rotation.y, yaw, minf(1.0, delta * 10.0)), 0)
			n.scale = Vector3.ONE * lerpf(0.22, 1.0, k)
			f["t"] = t - delta
			if _zone_tick(z, delta):
				_free_zone(z)
				f["zone"] = {}
				f["state"] = "slam"
				f["t"] = 0.12
		"slam":
			t -= delta
			f["t"] = t
			n.scale = Vector3.ONE
			n.rotation = Vector3(lerpf(0.0, FINGER_AIM_PITCH, clampf(t / 0.12, 0.0, 1.0)), yaw, 0)
			if t <= 0.0:
				n.rotation.x = 0.0
				f["state"] = "rest"
				f["t"] = 2.6
				f["hurt"] = 0.15
				var tip: Vector3 = f["b"]
				main.enemy_strike(tip, 0.9)
				main.splash(tip + Vector3(0, 0.3, 0), FOAM, 10)
		"rest":
			# posé dans l'arène : la fenêtre pour le trancher dans sa longueur
			n.rotation.x = 0.015 + 0.015 * sin(_t * 3.0 + n.position.x)
			t -= delta
			f["t"] = t
			if t <= 0.0:
				f["state"] = "back"
				f["t"] = 0.5
		"back":
			t -= delta
			f["t"] = t
			var k := clampf(1.0 - t / 0.5, 0.0, 1.0)
			n.rotation = Vector3(lerpf(0.0, FINGER_IDLE_PITCH, k), lerp_angle(yaw, PI, k), 0)
			n.scale = Vector3.ONE * lerpf(1.0, 0.22, k)
			if t <= 0.0:
				f["state"] = "idle"
				f["yaw"] = PI
		"cut":
			t -= delta
			f["t"] = t
			n.scale = Vector3.ONE * maxf(0.01, t / 0.4)
			if t <= 0.0:
				n.visible = false
				f["state"] = "gone"


# --- phase 2 : kaeshi

func _phase2(delta: float) -> void:
	for i in range(_waves.size() - 1, -1, -1):
		var w: Dictionary = _waves[i]
		if _wave_step(w, delta):
			var wn: Node3D = w["node"]
			wn.queue_free()
			_waves.remove_at(i)
	_timer -= delta
	if _timer <= 0.0:
		_send_waves()


func _send_waves() -> void:
	var open_lanes: Array = []
	for lane in 3:
		var busy := false
		for w: Dictionary in _waves:
			if int(w["lane"]) == lane and (String(w["state"]) == "warn" or float(w["z"]) < -3.0):
				busy = true
		if not busy:
			open_lanes.append(lane)
	if open_lanes.is_empty():
		_timer = 0.5
		return
	open_lanes.shuffle()
	if open_lanes.size() > 1 and int(open_lanes[0]) == _last_lane:
		open_lanes.push_back(open_lanes.pop_front())
	var count := 1
	# jamais les 3 couloirs à la fois : il reste toujours un passage
	if _phase_prog() > 0.35 and open_lanes.size() >= 2 and randf() < 0.5:
		count = 2
	for i in count:
		var lane_i: int = open_lanes[i]
		_spawn_lane_wave(lane_i)
		_last_lane = lane_i
	_timer = lerpf(2.8, 2.1, _phase_prog()) + (0.6 if count == 2 else 0.0)


func _spawn_lane_wave(lane: int) -> void:
	var x: float = LANE_X[lane]
	var zone := _band_zone(Vector3(x, 0, -HALF.y), Vector3(x, 0, HALF.y), LANE_W, 1.2)
	var n := _make_lane_wave(x)
	_waves.append({"lane": lane, "x": x, "z": -HALF.y - 0.6, "state": "warn", "node": n, "zone": zone})


## Vrai quand la vague sort de l'arène.
func _wave_step(w: Dictionary, delta: float) -> bool:
	var n: Node3D = w["node"]
	var st: String = w["state"]
	var z: float = w["z"]
	if st == "warn":
		# la vague se lève au bout du couloir pendant l'annonce
		var zone: Dictionary = w["zone"]
		var tt: float = zone["t"]
		n.position.y = lerpf(-1.4, 0.0, clampf(1.0 - tt / 1.2, 0.0, 1.0))
		if _zone_tick(zone, delta):
			_free_zone(zone)
			w["zone"] = {}
			w["state"] = "roll"
			n.position.y = 0.0
			main.splash(n.position + Vector3(0, 1.2, 0), FOAM, 8)
		return false
	if st == "roll":
		z += (4.0 + 1.6 * _phase_prog()) * delta
		w["z"] = z
		n.position = Vector3(n.position.x, sin(_t * 6.0) * 0.06, z)
		return z > HALF.y + 1.5
	# renvoyée : elle repart vers le fond, retournée
	z -= 11.0 * delta
	w["z"] = z
	n.position = Vector3(n.position.x, n.position.y, z)
	n.rotation.y = lerp_angle(n.rotation.y, PI, minf(1.0, delta * 8.0))
	return z < -HALF.y - 2.5


# --- phase 3 : l'ensō

func _phase3(delta: float) -> void:
	if _eye_grace > 0.0:
		_eye_grace -= delta
	_eye.scale = _eye.scale.lerp(Vector3.ONE, minf(1.0, delta * 3.0))
	_orbit.rotation.y += delta * 0.9
	# l'iris suit le héros, l'œil cligne
	var to := Vector3(hero.position.x, 0, hero.position.z)
	var look := Vector3.ZERO
	if to.length() > 0.01:
		look = to.normalized() * minf(0.25, to.length() * 0.1)
	_eye_iris.position = _eye_iris.position.lerp(look, minf(1.0, delta * 6.0))
	var lid := 0.15 if fmod(_t, 3.7) < 0.12 else 1.0
	var pulse := 1.15 if _flash > 0.0 else 1.0
	_eye_ball.scale = Vector3(pulse, lid * pulse, pulse)
	for i in range(_drops.size() - 1, -1, -1):
		var dr: Dictionary = _drops[i]
		var z: Dictionary = dr["zone"]
		if _zone_tick(z, delta):
			var c: Vector3 = z["c"]
			var r: float = z["r"]
			if String(dr["type"]) == "tears":
				# larmes d'encre en couronne
				for k in 8:
					var a := TAU * k / 8.0 + _t
					var d := Vector3(cos(a), 0, sin(a))
					main.spawn_bullet(Vector3(d.x * 1.2, 0.8, d.z * 1.2), d)
			else:
				main.enemy_strike(c, r)
				main.splash(c + Vector3(0, 0.3, 0), INK, 10)
			_free_zone(z)
			_drops.remove_at(i)
	if _drops.is_empty():
		_timer -= delta
		if _timer <= 0.0:
			_eye_attack()
			_timer = 1.4


func _eye_attack() -> void:
	_volley += 1
	if _volley % 2 == 0:
		_drops.append({"type": "tears", "zone": _disc_zone(Vector3.ZERO, 1.5, 1.0)})
		_drops.append({"type": "rain", "zone": _disc_zone(_in_arena(hero.position), 1.2, 1.1)})
	else:
		var n := 3 + int(_phase_prog() >= 0.5)
		for i in n:
			var c := hero.position if i == 0 else Vector3(randf_range(-HALF.x, HALF.x), 0, randf_range(-HALF.y + 1.0, HALF.y - 1.0))
			_drops.append({"type": "rain", "zone": _disc_zone(_in_arena(c), 1.3, 1.1)})


# ------------------------------------------------------------------ robot testeur

const BOT_HALF := Vector2(4.3, 8.3)  # bornes des points du robot (comme main._clamp_point)
const BOT_ENSO_R := 2.5


## Trait qu'un bon joueur tracerait maintenant (points au sol depuis le héros), ou vide = attendre.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	if dead or _pending_shift:
		return none
	match _state:
		"p1":
			return _bot_claw(h)
		"p2":
			return _bot_kaeshi(h)
		"p3":
			return _bot_enso(h)
	return none


## Phase 1 : longer un doigt posé sur 80 % de sa longueur, en partant du bout le plus proche.
func _bot_claw(h: Vector3) -> PackedVector3Array:
	var best := PackedVector3Array()
	var best_l := 1e9
	for f: Dictionary in _fingers:
		if not bool(f["alive"]) or String(f["state"]) != "rest" or float(f["t"]) < 0.5 or float(f["hurt"]) > 0.0:
			continue
		var a: Vector3 = f["a"]
		var b: Vector3 = f["b"]
		for opt in [[0.0, 0.82], [1.0, 0.18]]:
			var o: Array = opt
			var s := a.lerp(b, float(o[0]))
			var e := a.lerp(b, float(o[1]))
			var l := h.distance_to(s) + s.distance_to(e)
			if l < best_l:
				best_l = l
				best = _bot_dense([h, s, e])
	return best


## Phase 2 : aller-retour devant une (ou deux) vague(s) qui roule(nt), retour au point de départ.
func _bot_kaeshi(h: Vector3) -> PackedVector3Array:
	var targets: Array = []
	for w: Dictionary in _waves:
		if String(w["state"]) != "roll":
			continue
		var x: float = w["x"]
		var z: float = w["z"]
		if z < -HALF.y - 0.6 or z > HALF.y - 2.2:
			continue
		var pick := Vector3.INF
		var pick_d := 1e9
		for dz in [2.6, 3.6, 4.4, 1.8]:
			for dx in [0.0, -1.3, 1.3]:
				var t := _bot_clamp(Vector3(x + float(dx), 0, z + float(dz)))
				if absf(t.x - x) > LANE_W * 0.5 + 0.2 or t.z < z + 1.2:
					continue
				var d := h.distance_to(t)
				if d >= 2.3 and d <= 6.5 and d < pick_d:
					pick_d = d
					pick = t
		if pick != Vector3.INF:
			targets.append(pick)
	if targets.is_empty():
		return PackedVector3Array()
	var t0: Vector3 = targets[0]
	var way: Array = [h, t0]
	if targets.size() > 1:
		var t1: Vector3 = targets[1]
		if h.distance_to(t0) + t0.distance_to(t1) + t1.distance_to(h) <= 14.0:
			way.append(t1)
	way.append(h)
	return _bot_dense(way)


## Phase 3 : ensō de rayon 2.5 autour de l'œil (312°, ≈ 13.6 m), après placement sur le cercle.
func _bot_enso(h: Vector3) -> PackedVector3Array:
	var r := Vector2(h.x, h.z).length()
	var phi := PI * 0.5
	if r > 0.3:
		phi = atan2(h.z, h.x)
	if r < 1.75 or r > 3.35:
		return _bot_dense([h, Vector3(cos(phi), 0, sin(phi)) * BOT_ENSO_R])
	var way: Array = [h]
	var sweep := deg_to_rad(312.0)
	for i in range(0, 53):
		var th := phi + sweep * float(i) / 52.0
		way.append(Vector3(cos(th), 0, sin(th)) * BOT_ENSO_R)
	return _bot_dense(way)


func _bot_clamp(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -BOT_HALF.x, BOT_HALF.x), 0, clampf(p.z, -BOT_HALF.y, BOT_HALF.y))


## Polyligne finale : au sol, bornée à l'arène, points espacés de 0.4 m au plus.
func _bot_dense(way: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in way.size():
		var p: Vector3 = way[i]
		if i == 0:
			out.append(Vector3(p.x, 0, p.z))
			continue
		p = _bot_clamp(p)
		var last: Vector3 = out[out.size() - 1]
		var n := int(ceil(last.distance_to(p) / 0.4))
		for k in range(1, n + 1):
			out.append(last.lerp(p, float(k) / float(n)))
	return out
