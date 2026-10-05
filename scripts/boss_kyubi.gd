extends Node3D
## Boss du monde 2 (Tanabata) — Kyūbi, le renard à neuf queues (70 PV), cf. design/UNIVERS.md.
##  Phase 1 — Illusions : 3 renards identiques. Le vrai a une ombre qui bouge et des yeux or.
##            Frapper un faux = il éclate en 6 feux follets lents. Frapper le vrai = 4 dmg
##            et les faux disparaissent 6 s.
##  Phase 2 (≤ 60 %) — Les neuf queues : 9 feux plantés en cercle (r ≈ 2.4) qui tirent à tour de rôle.
##            Kyūbi est protégé ; seul un Ensō (boucle fermée autour de lui) éteint les queues
##            incluses : 2 dmg par queue ; toutes éteintes = étourdi 3 s (vulnérable).
##  Phase 3 (≤ 25 %) — Fuite en zigzag à 6 m/s le long d'une route annoncée ;
##            un trait qui coupe la route devant lui le fait trébucher (3 dmg + étourdi 2.2 s).
## Interface identique à boss.gd : check_dash(), take_hit(), end_stroke(), danger_at(), touching_hero().

const Toon = preload("res://scripts/toon.gd")

const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (comme main.gd)
const ORANGE := Color("#E08A3C")
const WHITE := Color("#F3EEE4")
const ASH := Color("#5C5862")
const TAILS := 9
const FOX_SCALE := 1.2
const CENTER := Vector3(0, 0, -1.0)  # centre de l'anneau des queues
# anneau un peu ovale ; assez serré pour qu'un ensō de 14 m d'élan (r ≈ 2.2) autour de lui
# puisse inclure les queues (à 3.3 × 4.0, aucune n'était atteignable sans bonus d'élan)
const RING := Vector2(2.3, 2.5)
const BAND_LEN := 4.5
const TAIL_ANNOUNCE := 1.0  # annonce des tirs de queue (≥ 0.9 s)
const TAIL_PERIOD := 4.0
const ROUTE_ANNOUNCE := 1.0
const RUN_SPEED := 6.0
const LOOP_PTS := 120  # points mémorisés pour l'Ensō (_find_loop est quadratique)
const DANGER_MARGIN := 0.35  # marge de danger_at (comme is_danger de main)

var kind := "kyubi"
var main: Node
var hero: Node3D
var title := "Kyūbi"
var hp := 70.0
var max_hp := 70.0
var dead := false
var radius := 0.9
var max_hp_mult := 1.0  # difficulté du monde

var _phase := 1
var _state := "spawn"
var _timer := 1.2
var _t := 0.0
var _flash := 0.0
var _stun := 0.0
var _last_stroke := -1

# matériaux partagés
var _fur: StandardMaterial3D
var _white: StandardMaterial3D
var _ash: StandardMaterial3D

# renards : le vrai (_fox, racine = self) et les deux illusions
var _fox := {}
var _fakes: Array = []
var _anchor := Vector3.ZERO
var _fade := 0.0  # visibilité des renards (fondu des mélanges)
var _shuffle_dir := 0  # -1 disparition, 1 apparition, 0 rien
var _shuffle_t := 7.0
var _fakes_gone := 0.0
var _atk_t := 2.5

# zone annoncée (pilier de feu-renard)
var _zone: Node3D = null
var _zone_fill: Node3D  # visuel partagé de l'annonce (vfx.tele_disc)
var _zone_center := Vector3.ZERO
var _zone_r := 1.4
var _zone_t := 0.0
var _zone_total := 1.0

# phase 2 : queues plantées
var _tails: Array = []  # Dictionary par queue
var _tail_rise := 0.0
var _relight := 12.0
var _pts: Array = []  # Vector2 de la ruée depuis le dernier end_stroke (ruées enchaînées comprises)
var _shift_from := Vector3.ZERO

# phase 3 : fuite
var _route: Array = []  # points denses (Vector3)
var _route_i := 0
var _marks: Node3D
var _mark_idx: Array = []
var _cut := false
var _move_dir := Vector3(0, 0, 1)


func setup(k: String, m: Node) -> void:
	kind = k
	main = m
	hero = m.hero


func _ready() -> void:
	hp = 70.0
	radius = 0.9
	hp *= max_hp_mult
	max_hp = hp
	_fur = Toon.mat(ORANGE)
	_white = Toon.mat(WHITE)
	_ash = Toon.mat(ASH)
	_fox = _build_fox(self, true)
	for i in 2:
		var n := Node3D.new()
		n.top_level = true
		add_child(n)
		_fakes.append(_build_fox(n, false))
	_marks = Node3D.new()
	_marks.top_level = true
	add_child(_marks)
	_place_illusions()
	_fade = 0.0
	_state = "spawn"
	_timer = 1.2


# ------------------------------------------------------------------ construction

func _lp_sphere(r: float) -> SphereMesh:
	# sphère à facettes (look low-poly)
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 5
	return m


## Renard low-poly (regarde vers -Z). Renvoie {node, body, shadow, tails, cones, stars, alive, anchor}.
func _build_fox(root: Node3D, is_real: bool) -> Dictionary:
	var body := Node3D.new()
	root.add_child(body)
	body.scale = Vector3.ONE * FOX_SCALE
	var dark := Toon.mat(Toon.SUMI)
	var red := Toon.flat(Toon.VERMILION)
	# corps, poitrail blanc
	Toon.part(body, _lp_sphere(0.5), _fur, Vector3(0, 0.78, 0.05), Vector3(0.8, 0.75, 1.3))
	Toon.part(body, _lp_sphere(0.36), _white, Vector3(0, 0.82, -0.42), Vector3(0.95, 1.1, 0.8))
	# pattes à chaussettes d'encre
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Toon.part(body, Toon.cyl(0.07, 0.09, 0.55, 6), _fur, Vector3(sx * 0.2, 0.3, sz * 0.42 + 0.02))
			Toon.part(body, _lp_sphere(0.09), dark, Vector3(sx * 0.2, 0.07, sz * 0.42 - 0.02), Vector3(1, 0.7, 1.3))
	# cou + collier vermillon à clochette d'or
	var neck := Toon.part(body, Toon.cyl(0.2, 0.26, 0.5, 8), _fur, Vector3(0, 1.05, -0.45))
	neck.rotation.x = -0.5
	var collar := Toon.part(body, Toon.cyl(0.25, 0.25, 0.08, 8), Toon.mat(Toon.VERMILION), Vector3(0, 0.98, -0.5))
	collar.rotation.x = -0.5
	Toon.part(body, _lp_sphere(0.07), Toon.mat(Toon.GOLD), Vector3(0, 0.86, -0.7))
	# tête et masque blanc (kitsune-men)
	Toon.part(body, _lp_sphere(0.32), _fur, Vector3(0, 1.32, -0.62), Vector3(1.0, 0.9, 1.0))
	Toon.part(body, _lp_sphere(0.27), _white, Vector3(0, 1.32, -0.76), Vector3(1.0, 0.95, 0.7))
	var muzzle := Toon.part(body, Toon.cyl(0.0, 0.15, 0.42, 6), _white, Vector3(0, 1.24, -0.98))
	muzzle.rotation.x = -PI * 0.5
	Toon.part(body, _lp_sphere(0.05), dark, Vector3(0, 1.24, -1.19))
	# marques vermillon du masque
	for sx in [-1.0, 1.0]:
		var mk := Toon.part(body, Toon.box(Vector3(0.06, 0.02, 0.13)), red, Vector3(sx * 0.1, 1.47, -0.86))
		mk.rotation = Vector3(-0.4, 0, sx * 0.5)
		# yeux : or pour le vrai, fentes d'encre pour les illusions
		if is_real:
			Toon.part(body, _lp_sphere(0.06), Toon.flat(Toon.GOLD), Vector3(sx * 0.11, 1.37, -0.95))
		else:
			var slit := Toon.part(body, Toon.box(Vector3(0.11, 0.025, 0.03)), Toon.flat(Toon.SUMI), Vector3(sx * 0.11, 1.37, -0.95))
			slit.rotation.z = -sx * 0.25
		# oreilles
		var ear := Toon.part(body, Toon.cyl(0.0, 0.12, 0.36, 4), _fur, Vector3(sx * 0.16, 1.62, -0.58))
		ear.rotation.z = -sx * 0.25
		Toon.part(ear, Toon.cyl(0.0, 0.07, 0.22, 4), Toon.mat(WHITE, false), Vector3(0, -0.04, -0.05))
	# les neuf queues en éventail (cônes à bout blanc)
	var tail_root := Node3D.new()
	body.add_child(tail_root)
	tail_root.position = Vector3(0, 0.85, 0.6)
	var tails: Array = []
	var cones: Array = []
	for i in TAILS:
		var pv := Node3D.new()
		tail_root.add_child(pv)
		var u := float(i) / float(TAILS - 1) * 2.0 - 1.0
		pv.rotation = Vector3(0.75 + 0.3 * (1.0 - absf(u)), 0.0, u * 1.1)
		var cone := Toon.part(pv, Toon.cyl(0.07, 0.2, 0.95, 6), _fur, Vector3(0, 0.5, 0))
		Toon.part(pv, Toon.cyl(0.0, 0.08, 0.3, 6), _white, Vector3(0, 1.12, 0))
		tails.append(pv)
		cones.append(cone)
	# ombre au sol : celle du vrai bouge (se balance, s'étire)
	var shadow := Toon.disc(root, 0.75, Color(0, 0, 0, 0.18))
	shadow.scale = Vector3(1.0, 1.0, 1.3)
	# étoiles d'étourdissement (vrai seulement)
	var stars := Node3D.new()
	body.add_child(stars)
	stars.position = Vector3(0, 1.9, -0.6)
	stars.visible = false
	if is_real:
		for k in 3:
			var a := TAU * float(k) / 3.0
			Toon.part(stars, _lp_sphere(0.07), Toon.flat(Toon.GOLD), Vector3(cos(a) * 0.3, 0, sin(a) * 0.3))
	return {"node": root, "body": body, "shadow": shadow, "tails": tails, "cones": cones, "stars": stars, "alive": true, "anchor": Vector3.ZERO}


func _spawn_ground_tails() -> void:
	_clear_ground_tails()
	for i in TAILS:
		var a := TAU * float(i) / float(TAILS) - PI * 0.5
		var p := CENTER + Vector3(cos(a) * RING.x, 0, sin(a) * RING.y)
		var n := Node3D.new()
		n.top_level = true
		add_child(n)
		n.global_position = p
		Toon.disc(n, 0.5, Color(Toon.GOLD, 0.25), 0.02)
		var cone := Toon.part(n, Toon.cyl(0.06, 0.22, 1.1, 6), _fur, Vector3(0, 0.5, 0))
		cone.rotation = Vector3(0.2 * sin(a), 0, -0.2 * cos(a))
		Toon.part(n, Toon.cyl(0.0, 0.09, 0.3, 6), _white, Vector3(0, 1.15, 0))
		var flame := Node3D.new()
		n.add_child(flame)
		flame.position = Vector3(0, 1.45, 0)
		Toon.part(flame, Toon.sphere(0.26), Toon.flat(Color(Toon.VERMILION, 0.85)), Vector3.ZERO, Vector3(1, 1.35, 1))
		Toon.part(flame, Toon.sphere(0.14), Toon.flat(Toon.GOLD), Vector3(0, -0.04, 0), Vector3(1, 1.3, 1))
		n.scale = Vector3(1, 0.01, 1)
		_tails.append({"node": n, "cone": cone, "flame": flame, "lit": true, "pos": p,
			"fire": 1.8 + TAIL_PERIOD * float(i) / float(TAILS), "band": null, "fill": null, "dir": Vector3.ZERO})
	_tail_rise = 0.0
	_relight = 12.0
	_sync_body_tails()


func _clear_ground_tails() -> void:
	for t in _tails:
		_clear_band(t)
		var n: Node3D = t["node"]
		if is_instance_valid(n):
			main.splash(n.global_position + Vector3(0, 0.8, 0), Toon.GOLD, 6)
			n.queue_free()
	_tails.clear()


# ------------------------------------------------------------------ interface avec main

## Vrai si la ruée a..b touche le vrai Kyūbi pour la première fois de ce trait (dégâts gérés par main).
## Enregistre aussi les positions de la ruée (détection de l'Ensō en fin de trait).
func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if _phase == 2 and hero.dashing:
		_record(a, b)
	match _state:
		"p1":
			if _fade < 0.6:
				return false
			# une illusion touchée éclate en feux follets
			for f in _fakes:
				if not f["alive"]:
					continue
				var fn: Node3D = f["node"]
				if _seg_dist(fn.global_position, a, b) < radius + 0.5:
					_burst_fake(f)
			return _hit_real(a, b, stroke_id)
		"p2":
			if _stun > 0.0:
				return _hit_real(a, b, stroke_id)
			# voile de feu-renard : la lame ricoche
			if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.5:
				_last_stroke = stroke_id
				main.clang(position + Vector3(0, 0.8, 0))
				main.float_text(position, "×0", Toon.FOAM)
			return false
		"p3_tele", "p3_run":
			if not _cut and _crosses_route(a, b):
				if _state == "p3_run":
					_trip()
					return false
				_cut = true
				main.float_text(_route_point_ahead(), "✕", Toon.GOLD)
			return _hit_real(a, b, stroke_id)
		"p3_rest", "p3_stun":
			return _hit_real(a, b, stroke_id)
	return false


func take_hit(dmg: float, dir: Vector3) -> void:
	if dead:
		return
	var out := dmg
	if _phase == 1 and _fakes_alive() > 0:
		# le vrai démasqué : 4 dmg et les illusions se dissipent 6 s
		out += 3.0
		for f in _fakes:
			if f["alive"]:
				var fn: Node3D = f["node"]
				main.splash(fn.global_position + Vector3(0, 0.8, 0), Toon.FOAM, 10)
				f["alive"] = false
				fn.visible = false
		_fakes_gone = 6.0
		_fade = 1.0
		_shuffle_dir = 0
		main.float_text(position + Vector3(0, 0.4, 0), "真", Toon.GOLD)
	_damage(out)


## Fin du trait : en phase 2, cherche une boucle fermée (Ensō) qui entoure Kyūbi.
func end_stroke(_stroke_id: int) -> void:
	if _phase == 2 and not _pts.is_empty():
		# la dernière image de la ruée n'est pas passée par check_dash : sans elle la boucle
		# perdait son dernier mètre (fermeture ratée)
		var pa: Vector3 = main._prev_hero
		_record(pa, hero.position)
	var pts: Array = _pts
	_pts = []
	if dead or _phase != 2 or _state != "p2" or pts.size() < 6:
		return
	var c := Vector2(position.x, position.z)
	var loop := _find_loop(pts, c)
	if loop.size() < 3:
		return
	var n := 0
	for t in _tails:
		if not t["lit"]:
			continue
		var tp: Vector3 = t["pos"]
		if _in_loop(Vector2(tp.x, tp.z), loop):
			_extinguish(t)
			n += 1
	if n == 0:
		main.float_text(position, "○", Toon.FOAM)
		return
	var all_out := _lit_count() == 0
	main.float_text(position + Vector3(0, 0.4, 0), "円 ×%d" % n, Toon.GOLD)
	main.big_hit(position + Vector3(0, 0.6, 0))
	_relight = 12.0
	_damage(2.0 * n)
	if not dead and _phase == 2 and all_out:
		_stun = 3.0
		_sync_body_tails()


## Vrai si le point p est dans une attaque annoncée qui frappe d'ici eta secondes
## (pilier, bandes de tir des queues, route de fuite annoncée).
func danger_at(p: Vector3, eta: float) -> bool:
	if dead:
		return false
	var lim := eta + DANGER_MARGIN
	if _zone != null and _zone_t < lim:
		if Vector2(p.x - _zone_center.x, p.z - _zone_center.z).length() < _zone_r + DANGER_MARGIN:
			return true
	for t in _tails:
		if not t["lit"] or t["band"] == null or float(t["fire"]) >= lim:
			continue
		var tp: Vector3 = t["pos"]
		var d: Vector3 = t["dir"]
		var v := Vector3(p.x - tp.x, 0, p.z - tp.z)
		var along := v.dot(d)
		if along > -DANGER_MARGIN and along < BAND_LEN + DANGER_MARGIN and (v - d * along).length() < 0.35 + DANGER_MARGIN:
			return true
	if (_state == "p3_tele" or _state == "p3_run") and _route_i < _route.size():
		# le renard fonce le long de la route : danger quand il passe au moment de l'arrivée
		var acc := 0.0
		if _state == "p3_tele":
			acc = maxf(_timer, 0.0)
		var prev := Vector3(position.x, 0, position.z)
		for i in range(_route_i, _route.size()):
			var q: Vector3 = _route[i]
			acc += prev.distance_to(q) / RUN_SPEED
			prev = q
			if acc > lim:
				break
			if acc > eta - DANGER_MARGIN and Vector2(p.x - q.x, p.z - q.z).length() < 0.85 + DANGER_MARGIN:
				return true
	return false


func touching_hero(p: Vector3) -> bool:
	if dead:
		return false
	if _state == "p2" and _tail_rise >= 1.0:
		for t in _tails:
			if not t["lit"]:
				continue
			var tp: Vector3 = t["pos"]
			if Vector2(p.x - tp.x, p.z - tp.z).length() < 0.6:
				return true
		return false
	if _state == "p3_run":
		return Vector2(p.x - position.x, p.z - position.z).length() < 0.85
	return false


## Dégâts de zone (techniques, pouvoirs) : touche la partie vulnérable la plus proche de `center` dans `reach`.
## Renvoie le point touché, ou Vector3.INF si rien n'est touché (boss invulnérable à cet instant, hors de portée, mort).
## (`reach` plutôt que `radius`, déjà pris par le rayon du boss)
## Seul le vrai renard encaisse : pas d'illusion qui éclate, pas de queue éteinte (réservé à l'Ensō).
func aoe_hit(center: Vector3, reach: float, dmg: float, fx := true) -> Vector3:
	if dead:
		return Vector3.INF
	var open := false
	match _state:
		"p1":
			open = _fade >= 0.6
		"p2":
			# voile de feu-renard : seulement une fois toutes les queues éteintes
			open = _stun > 0.0
		"p3_tele", "p3_run", "p3_rest", "p3_stun":
			open = true
	if not open:
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	var at := position + Vector3(0, 0.9, 0)
	var fl := _flash
	_damage(dmg)
	if not fx:
		_flash = fl
	return at


# ------------------------------------------------------------------ outils

func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var seg := b - a
	var t := 0.0
	if seg.length_squared() > 0.0001:
		t = clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
	var q := a + seg * t
	return Vector2(p.x - q.x, p.z - q.z).length()


func _hit_real(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if _last_stroke == stroke_id:
		return false
	if _seg_dist(position, a, b) < radius + 0.5:
		_last_stroke = stroke_id
		return true
	return false


func _fakes_alive() -> int:
	var n := 0
	for f in _fakes:
		if f["alive"]:
			n += 1
	return n


func _burst_fake(f: Dictionary) -> void:
	var fn: Node3D = f["node"]
	var p := fn.global_position
	f["alive"] = false
	fn.visible = false
	main.float_text(p, "幻", Toon.FOAM)
	main.splash(p + Vector3(0, 0.8, 0), Toon.GOLD, 14)
	main.clang(p)
	# six feux follets lents
	var off := randf() * TAU
	for k in 6:
		var ang := off + TAU * float(k) / 6.0
		var d := Vector3(cos(ang), 0, sin(ang))
		main.spawn_bullet(p + Vector3(0, 0.7, 0) + d * 0.6, d)


func _damage(d: float) -> void:
	hp -= d
	# chaque phase se joue : on ne saute pas de palier d'un coup
	if _phase == 1:
		hp = maxf(hp, max_hp * 0.6)
	elif _phase == 2:
		hp = maxf(hp, max_hp * 0.25)
	_flash = 0.15
	if hp <= 0.0:
		_die()
	elif _phase == 1 and hp <= max_hp * 0.6 + 0.001:
		_start_phase2()
	elif _phase == 2 and hp <= max_hp * 0.25 + 0.001:
		_start_phase3()


func _die() -> void:
	hp = 0.0
	dead = true
	_cancel()
	for t in _tails:
		_clear_band(t)
	_clear_marks()
	_state = "dying"
	_timer = 0.0
	var stars: Node3D = _fox["stars"]
	stars.visible = false
	main.boss_killed(self)


func _make_zone(center: Vector3, r: float, t: float) -> void:
	_cancel()
	_zone = Node3D.new()
	_zone.top_level = true
	add_child(_zone)
	_zone_center = Vector3(center.x, 0, center.z)
	_zone.global_position = _zone_center
	_zone_r = r
	_zone_t = t
	_zone_total = t
	_zone_fill = main.vfx.tele_disc(_zone, r)


func _cancel() -> void:
	if _zone != null:
		_zone.queue_free()
		_zone = null


func _update_zone(delta: float) -> void:
	if _zone == null:
		return
	_zone_t -= delta
	var k := clampf(1.0 - _zone_t / _zone_total, 0.01, 1.0)
	main.vfx.tele_update(_zone_fill, k, _zone_t)
	if _zone_t <= 0.0:
		# pilier de feu-renard
		var c := _zone_center
		var r := _zone_r
		_cancel()
		main.enemy_strike(c, r)
		main.splash(c + Vector3(0, 0.4, 0), Toon.GOLD, 12)


# ------------------------------------------------------------------ Ensō

func _record(a: Vector3, b: Vector3) -> void:
	if _pts.is_empty():
		_pts.append(Vector2(a.x, a.z))
	var last: Vector2 = _pts[_pts.size() - 1]
	var bb := Vector2(b.x, b.z)
	if last.distance_to(bb) >= 0.3 and _pts.size() < LOOP_PTS:
		_pts.append(bb)


## Plus grande boucle fermée du tracé qui contient c (auto-croisement, ou extrémité revenue à ≤ 1.4 m).
func _find_loop(pts: Array, c: Vector2) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := 0.0
	var n := pts.size()
	# 1) boucles par auto-croisement
	for j in range(2, n - 1):
		var a2: Vector2 = pts[j]
		var b2: Vector2 = pts[j + 1]
		for i in range(0, j - 1):
			var p1: Vector2 = pts[i]
			var p2: Vector2 = pts[i + 1]
			var hit = Geometry2D.segment_intersects_segment(p1, p2, a2, b2)
			if hit == null:
				continue
			var poly := PackedVector2Array()
			poly.append(hit)
			for k in range(i + 1, j + 1):
				poly.append(pts[k])
			var ar := _area(poly)
			if poly.size() >= 3 and ar > best_area and Geometry2D.is_point_in_polygon(c, poly):
				best = poly
				best_area = ar
	# 2) boucle presque fermée : la fin revient près d'un point antérieur
	var last: Vector2 = pts[n - 1]
	for i in range(0, n - 8):
		var q: Vector2 = pts[i]
		if q.distance_to(last) > 1.4:
			continue
		var poly2 := PackedVector2Array()
		for k in range(i, n):
			poly2.append(pts[k])
		var ar2 := _area(poly2)
		if ar2 > best_area and Geometry2D.is_point_in_polygon(c, poly2):
			best = poly2
			best_area = ar2
	return best


func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	var m := poly.size()
	for i in m:
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % m]
		s += p.x * q.y - q.x * p.y
	return absf(s) * 0.5


## Dans la boucle, ou à moins de 0.5 m de son bord (tolérance tactile).
func _in_loop(p: Vector2, poly: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(p, poly):
		return true
	var m := poly.size()
	for i in m:
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % m])
		if q.distance_to(p) < 0.5:
			return true
	return false


func _lit_count() -> int:
	var n := 0
	for t in _tails:
		if t["lit"]:
			n += 1
	return n


func _extinguish(t: Dictionary) -> void:
	t["lit"] = false
	_clear_band(t)
	var fl: Node3D = t["flame"]
	fl.visible = false
	var cone: MeshInstance3D = t["cone"]
	cone.material_override = _ash
	var tp: Vector3 = t["pos"]
	main.splash(tp + Vector3(0, 1.3, 0), Toon.SUMI, 8)
	_sync_body_tails()


func _relight_all() -> void:
	var i := 0
	for t in _tails:
		if not t["lit"]:
			t["lit"] = true
			var fl: Node3D = t["flame"]
			fl.visible = true
			var cone: MeshInstance3D = t["cone"]
			cone.material_override = _fur
			t["fire"] = 1.6 + 0.45 * i
			var tp: Vector3 = t["pos"]
			main.splash(tp + Vector3(0, 1.4, 0), Toon.GOLD, 8)
			i += 1
	_relight = 12.0
	_sync_body_tails()


## Les queues du corps reflètent les feux encore allumés.
func _sync_body_tails() -> void:
	var cones: Array = _fox["cones"]
	for i in cones.size():
		var cone: MeshInstance3D = cones[i]
		var lit := true
		if _phase == 2 and i < _tails.size():
			lit = bool(_tails[i]["lit"])
		cone.material_override = _fur if lit else _ash


func _make_band(t: Dictionary) -> void:
	var tp: Vector3 = t["pos"]
	var to := hero.position - tp
	to.y = 0
	var dir := (tp - CENTER).normalized()
	if to.length() > 0.1:
		dir = to.normalized()
	var bn := Node3D.new()
	bn.top_level = true
	add_child(bn)
	bn.global_position = Vector3(tp.x, 0, tp.z)
	bn.rotation.y = atan2(dir.x, dir.z)
	# bande annoncée : part de la queue (z = 0) et se remplit vers +z
	var fill: Node3D = main.vfx.tele_rect(bn, 0.35, BAND_LEN * 0.5, Vector2(0, -1))
	fill.position.z = BAND_LEN * 0.5
	t["band"] = bn
	t["fill"] = fill
	t["dir"] = dir


func _clear_band(t: Dictionary) -> void:
	if t["band"] != null:
		var bn: Node3D = t["band"]
		if is_instance_valid(bn):
			bn.queue_free()
	t["band"] = null
	t["fill"] = null


# ------------------------------------------------------------------ phases

func _place_illusions() -> void:
	# trois places mélangées dans la moitié haute de l'arène
	var xs: Array = [-3.0, 0.0, 3.0]
	xs.shuffle()
	var slots: Array = []
	for k in 3:
		var z := randf_range(-6.5, -2.0)
		var x := float(xs[k]) + randf_range(-0.4, 0.4)
		if Vector2(x - hero.position.x, z - hero.position.z).length() < 2.5:
			z = clampf(hero.position.z - 3.0, -HALF.y + 1.2, HALF.y - 1.2)
		slots.append(Vector3(x, 0, z))
	_anchor = slots[0]
	position = _anchor
	for i in _fakes.size():
		var f: Dictionary = _fakes[i]
		var fn: Node3D = f["node"]
		f["anchor"] = slots[i + 1]
		fn.global_position = slots[i + 1]


func _start_phase2() -> void:
	_phase = 2
	_state = "shift2"
	_timer = 1.4
	_cancel()
	_stun = 0.0
	_fade = 1.0
	_shuffle_dir = 0
	for f in _fakes:
		if f["alive"]:
			var fn: Node3D = f["node"]
			main.splash(fn.global_position + Vector3(0, 0.8, 0), Toon.FOAM, 10)
		f["alive"] = false
		var hn: Node3D = f["node"]
		hn.visible = false
	_shift_from = position
	main.float_text(position + Vector3(0, 0.4, 0), "九尾", Toon.GOLD)
	main.set("shake", maxf(float(main.get("shake")), 0.4))
	_spawn_ground_tails()


func _start_phase3() -> void:
	_phase = 3
	_state = "shift3"
	_timer = 1.0
	_cancel()
	_stun = 0.0
	_clear_ground_tails()
	_sync_body_tails()
	main.float_text(position + Vector3(0, 0.4, 0), "逃", Toon.VERMILION)
	main.set("shake", maxf(float(main.get("shake")), 0.4))


func _plan_route() -> void:
	# zigzag d'un mur à l'autre vers l'autre bout de l'arène
	var p0 := Vector3(position.x, 0, position.z)
	var zend := 6.0 if p0.z < 0.0 else -6.0
	var sgn := -1.0 if p0.x > 0.0 else 1.0
	var way: Array = [p0]
	var legs := 4
	for k in range(1, legs + 1):
		var z := lerpf(p0.z, zend, float(k) / float(legs))
		way.append(Vector3(sgn * randf_range(2.2, 3.7), 0, z))
		sgn = -sgn
	_route.clear()
	for k in way.size() - 1:
		var a: Vector3 = way[k]
		var b: Vector3 = way[k + 1]
		var steps := maxi(1, int(a.distance_to(b) / 0.25))
		for s in steps:
			_route.append(a.lerp(b, float(s) / float(steps)))
	_route.append(way[way.size() - 1])
	_clear_marks()
	for i in range(0, _route.size(), 3):
		var rp: Vector3 = _route[i]
		var m: MeshInstance3D = main.vfx.tele_dot(_marks, 0.2)
		m.position = Vector3(rp.x, m.position.y, rp.z)
		m.visible = false
		_mark_idx.append(i)
	_route_i = 0
	_cut = false
	_state = "p3_tele"
	_timer = ROUTE_ANNOUNCE


func _clear_marks() -> void:
	if _marks == null:
		return
	for m in _marks.get_children():
		m.queue_free()
	_mark_idx.clear()


func _crosses_route(a: Vector3, b: Vector3) -> bool:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	if a2.distance_to(b2) < 0.001:
		return false
	var end := mini(_route_i + 60, _route.size() - 1)
	for k in range(_route_i, end):
		var p: Vector3 = _route[k]
		var q: Vector3 = _route[k + 1]
		var hit = Geometry2D.segment_intersects_segment(Vector2(p.x, p.z), Vector2(q.x, q.z), a2, b2)
		if hit != null:
			return true
	return false


func _route_point_ahead() -> Vector3:
	if _route.is_empty():
		return position
	var p: Vector3 = _route[mini(_route_i + 8, _route.size() - 1)]
	return p


func _trip() -> void:
	# route coupée : il trébuche
	_state = "p3_stun"
	_stun = 2.2
	_clear_marks()
	main.float_text(position + Vector3(0, 0.4, 0), "Coupé !", Toon.GOLD)
	main.big_hit(position + Vector3(0, 0.6, 0))
	_damage(3.0)


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash -= delta
	if not dead:
		_update_zone(delta)
	match _state:
		"spawn":
			_timer -= delta
			_fade = clampf(1.0 - _timer / 1.2, 0.0, 1.0)
			if _timer <= 0.0:
				_fade = 1.0
				_state = "p1"
				_shuffle_t = 7.0
				_atk_t = 1.5
		"p1":
			_phase1(delta)
		"shift2":
			_timer -= delta
			var k := clampf(1.0 - _timer / 1.4, 0.0, 1.0)
			position = _shift_from.lerp(CENTER, k * k * (3.0 - 2.0 * k))
			_tail_rise = k
			if _timer <= 0.0:
				_tail_rise = 1.0
				_state = "p2"
				main.float_text(CENTER + Vector3(0, 0.4, 0), "○ Ensō", Toon.GOLD)
		"p2":
			_phase2(delta)
		"shift3":
			_timer -= delta
			if _timer <= 0.0:
				_plan_route()
		"p3_tele":
			_timer -= delta
			var kk := 1.0 - _timer / ROUTE_ANNOUNCE
			var cnt := _marks.get_child_count()
			for i in cnt:
				var mk: MeshInstance3D = _marks.get_child(i)
				mk.visible = float(i) / float(maxi(cnt, 1)) <= kk * 1.25
				main.vfx.tele_dot_flash(mk, _timer < 0.15)
			if _timer <= 0.0:
				_state = "p3_run"
				if _cut:
					_trip()
		"p3_run":
			_run(delta)
		"p3_rest":
			_timer -= delta
			_face(hero.position - position, delta)
			if _timer <= 0.0 and _zone == null:
				_plan_route()
		"p3_stun":
			_stun -= delta
			if _stun <= 0.0:
				_stun = 0.0
				_state = "p3_rest"
				_timer = 1.2
				_make_zone(hero.position, 1.4, 1.1)
		"dying":
			_timer += delta
			var body: Node3D = _fox["body"]
			body.rotation.y += delta * (4.0 + _timer * 6.0)
			body.position.y = _timer * 0.8
			if _timer > 0.9:
				body.scale = Vector3.ONE * FOX_SCALE * clampf(1.0 - (_timer - 0.9) / 1.0, 0.01, 1.0)
			if int(_timer * 10.0) != int((_timer - delta) * 10.0) and _timer < 1.8:
				main.splash(position + Vector3(0, 1.0 + _timer * 0.8, 0), Toon.GOLD if randf() < 0.5 else ORANGE, 4)
			if _timer > 2.2:
				queue_free()
	if not dead:
		_animate(delta)


func _phase1(delta: float) -> void:
	var fakes := _fakes_alive()
	if _fakes_gone > 0.0:
		_fakes_gone -= delta
	# mélange des illusions (fondu sortant, nouvelles places, fondu entrant)
	if _shuffle_dir == 0 and _zone == null:
		if fakes > 0:
			_shuffle_t -= delta
			if _shuffle_t <= 0.0:
				_shuffle_dir = -1
		elif _fakes_gone <= 0.0:
			_shuffle_dir = -1
	if _shuffle_dir == -1:
		_fade -= delta / 0.4
		if _fade <= 0.0:
			_fade = 0.0
			for f in _fakes:
				f["alive"] = true
				var fn: Node3D = f["node"]
				fn.visible = true
			_place_illusions()
			_shuffle_dir = 1
	elif _shuffle_dir == 1:
		_fade += delta / 0.4
		if _fade >= 1.0:
			_fade = 1.0
			_shuffle_dir = 0
			_shuffle_t = 7.0
	# déplacement
	var sway := Vector3(sin(_t * 0.8) * 0.35, 0, cos(_t * 0.6) * 0.2)
	if fakes == 0 and _shuffle_dir == 0:
		# démasqué : il rôde à distance
		var to := hero.position - position
		to.y = 0
		var dist := to.length()
		var dir := to / maxf(dist, 0.001)
		var side := Vector3(-dir.z, 0, dir.x) * sin(_t * 0.7)
		var want := -1.0 if dist < 3.5 else (1.0 if dist > 5.5 else 0.0)
		position += (dir * want + side * 0.8) * 1.8 * delta
		main.clamp_to_arena(self, radius)
		_anchor = position - sway
	else:
		position = _anchor + sway
		for f in _fakes:
			var fn: Node3D = f["node"]
			var anc: Vector3 = f["anchor"]
			fn.global_position = anc + sway
	# attaque : pilier de feu-renard sous le héros
	if _shuffle_dir == 0:
		_atk_t -= delta
		if _atk_t <= 0.0 and _zone == null:
			_make_zone(hero.position, 1.4, 1.1)
			_atk_t = 3.2 if fakes > 0 else 2.4


func _phase2(delta: float) -> void:
	if _tail_rise < 1.0:
		_tail_rise = minf(1.0, _tail_rise + delta)
	if _stun > 0.0:
		_stun -= delta
		if _stun <= 0.0:
			_stun = 0.0
			# les queues se rallument
			_relight_all()
			_tail_rise = 0.0
		return
	if _lit_count() < TAILS:
		_relight -= delta
		if _relight <= 0.0:
			_relight_all()
	if _tail_rise < 1.0:
		return
	for t in _tails:
		if not t["lit"]:
			continue
		t["fire"] = float(t["fire"]) - delta
		var f := float(t["fire"])
		if f <= TAIL_ANNOUNCE and t["band"] == null:
			_make_band(t)
		if t["band"] != null:
			var fill: Node3D = t["fill"]
			var k := clampf(1.0 - f / TAIL_ANNOUNCE, 0.01, 1.0)
			main.vfx.tele_update(fill, k, f)
		if f <= 0.0:
			var tp: Vector3 = t["pos"]
			var d: Vector3 = t["dir"]
			_clear_band(t)
			main.spawn_bullet(tp + Vector3(0, 0.9, 0) + d * 0.4, d)
			t["fire"] = f + TAIL_PERIOD


func _run(delta: float) -> void:
	var dist := RUN_SPEED * delta
	while dist > 0.0 and _route_i < _route.size():
		var target: Vector3 = _route[_route_i]
		var to := target - position
		to.y = 0
		var d := to.length()
		if d <= dist:
			position = Vector3(target.x, 0, target.z)
			dist -= d
			_route_i += 1
		else:
			position += to / d * dist
			_move_dir = to / d
			dist = 0.0
	# les marques déjà parcourues s'effacent
	var cnt := mini(_marks.get_child_count(), _mark_idx.size())
	for i in cnt:
		var mk: Node3D = _marks.get_child(i)
		if int(_mark_idx[i]) < _route_i:
			mk.visible = false
	if _route_i >= _route.size():
		_clear_marks()
		_state = "p3_rest"
		_timer = 1.4
		_make_zone(hero.position, 1.4, 1.1)


func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0
	if dir.length_squared() < 0.0001:
		return
	var body: Node3D = _fox["body"]
	body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 6.0))


## Animation des renards : respiration, queues qui ondulent, ombre vivante du vrai.
func _animate(delta: float) -> void:
	var running := _state == "p3_run"
	var bob := absf(sin(_t * 14.0)) * 0.12 if running else sin(_t * 3.0) * 0.04
	var foxes: Array = [_fox]
	for f in _fakes:
		if f["alive"]:
			foxes.append(f)
	for f in foxes:
		var body: Node3D = f["body"]
		var root: Node3D = f["node"]
		body.position.y = bob
		var tails: Array = f["tails"]
		for i in tails.size():
			var pv: Node3D = tails[i]
			pv.rotation.y = sin(_t * (5.0 if running else 2.0) + i * 0.7) * 0.18
		if root != self:
			var fp := root.global_position
			var to := hero.position - fp
			to.y = 0
			if to.length_squared() > 0.0001:
				body.rotation.y = lerp_angle(body.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 5.0))
			root.scale = Vector3.ONE * maxf(_fade, 0.01)
	# le vrai
	var b: Node3D = _fox["body"]
	if running:
		_face(_move_dir, delta)
	elif _state != "p3_rest":
		_face(hero.position - position, delta)
	var stunned := _stun > 0.0
	b.rotation.z = sin(_t * 12.0) * 0.08 if stunned else 0.0
	var stars: Node3D = _fox["stars"]
	stars.visible = stunned
	stars.rotation.y = _t * 4.0
	var fl := 1.08 if _flash > 0.0 else 1.0
	b.scale = Vector3.ONE * FOX_SCALE * fl * maxf(_fade, 0.01)
	var sh: MeshInstance3D = _fox["shadow"]
	sh.position = Vector3(sin(_t * 1.7) * 0.3, 0.01, 0.25 + cos(_t * 1.1) * 0.3)
	sh.scale = Vector3(1.0, 1.0, 1.3 + 0.35 * sin(_t * 2.3)) * maxf(_fade, 0.01)
	# feux des queues plantées : montée et flamme qui vacille
	for t in _tails:
		var n: Node3D = t["node"]
		var rise := clampf(_tail_rise, 0.01, 1.0) if t["lit"] else 1.0
		n.scale = Vector3(1, rise, 1)
		var flame: Node3D = t["flame"]
		var fk := 1.0 + 0.12 * sin(_t * 11.0 + n.global_position.x * 3.0)
		flame.scale = Vector3(fk, 2.0 - fk, fk)


# ------------------------------------------------------------------ robot testeur

## Trait qu'un bon joueur tracerait maintenant (points au sol depuis le héros), ou vide = attendre.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	var me := Vector3(position.x, 0, position.z)
	if dead:
		return none
	match _state:
		"p1":
			if _fade < 0.6 or _shuffle_dir == -1:
				return none
			# le vrai renard (yeux or), en contournant les illusions
			var fakes: Array = []
			for f in _fakes:
				if f["alive"]:
					var fn: Node3D = f["node"]
					fakes.append(Vector3(fn.global_position.x, 0, fn.global_position.z))
			if fakes.is_empty():
				return _bot_line(h, me, 7.3)
			var d := me - h
			var dir := Vector3(0, 0, -1)
			if d.length() > 0.1:
				dir = d.normalized()
			return _bot_route([h, me, me + dir * 1.2], fakes, radius + 0.8)
		"p2":
			if _stun > 0.0:
				return _bot_line(h, me, 7.3)
			return _bot_tail_stroke(h)
		"p3_tele", "p3_run":
			if _cut:
				return none
			# couper la route devant lui, en travers
			var k := _route_i + (8 if _state == "p3_tele" else 14)
			if k >= _route.size() - 2:
				return none
			var r0: Vector3 = _route[k]
			var r1: Vector3 = _route[k + 1]
			var q := (r0 + r1) * 0.5
			var tg := r1 - r0
			tg.y = 0
			var nrm := Vector3(-tg.z, 0, tg.x).normalized()
			var p1 := q - nrm * 1.2
			var p2 := q + nrm * 1.2
			if h.distance_to(p2) < h.distance_to(p1):
				var sw := p1
				p1 = p2
				p2 = sw
			return _bot_dense([h, p1, p2])
		"p3_rest", "p3_stun":
			return _bot_line(h, me, 7.3)
	return none


## Phase 2 : ensō le long de l'intérieur de l'anneau (345°), depuis mi-rayon, qui revient près
## de son départ (boucle presque fermée de _find_loop) : ≈ 14.5 m, 8 à 9 queues d'un coup.
## Placement d'abord si le héros n'est pas à mi-rayon.
func _bot_tail_stroke(h: Vector3) -> PackedVector3Array:
	var c := Vector3(position.x, 0, position.z)
	var ex := RING.x - 0.25
	var ez := RING.y - 0.25
	var u := Vector2((h.x - c.x) / ex, (h.z - c.z) / ez)
	var phi := atan2(u.y, u.x)
	var rho := u.length()
	if rho < 0.35 or rho > 0.8:
		# placement à mi-rayon, entre deux queues (de l'autre côté si on est collé à lui)
		var step := TAU / float(TAILS)
		var aim := phi + (PI if rho < 0.35 else 0.0)
		var k := roundf((aim + PI * 0.5 - step * 0.5) / step)
		var pm := -PI * 0.5 + step * 0.5 + k * step
		var rr := 0.6 if rho < 0.35 else 0.45
		return _bot_dense([h, c + Vector3(cos(pm) * ex, 0, sin(pm) * ez) * rr])
	var way: Array = [h]
	var sweep := deg_to_rad(345.0)
	for i in range(0, 41):
		var th := phi + sweep * float(i) / 40.0
		way.append(c + Vector3(cos(th) * ex, 0, sin(th) * ez))
	# on revient vers le départ, loin des queues
	way.append(c + Vector3(cos(phi) * ex, 0, sin(phi) * ez) * 0.7)
	return _bot_dense(way)


const BOT_HALF := Vector2(4.3, 8.3)  # bornes des points du robot (comme main._clamp_point)


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


## Relie les points de passage en contournant les points `avoid` (à `clear` m près).
func _bot_route(way: Array, avoid: Array, clear: float) -> PackedVector3Array:
	var first: Vector3 = way[0]
	var pts: Array = [Vector3(first.x, 0, first.z)]
	for i in range(1, way.size()):
		var a: Vector3 = pts[pts.size() - 1]
		var b: Vector3 = way[i]
		_bot_leg(pts, a, _bot_clamp(b), avoid, clear, 3)
	return _bot_dense(pts)


func _bot_leg(out: Array, a: Vector3, b: Vector3, avoid: Array, clear: float, depth: int) -> void:
	var seg := b - a
	seg.y = 0
	var l2 := seg.length_squared()
	var best_t := 2.0
	var hit := Vector3.ZERO
	if depth > 0 and l2 > 0.0001:
		for o in avoid:
			var p: Vector3 = o
			p.y = 0
			if p.distance_to(a) < clear or p.distance_to(b) < clear:
				continue
			var t := clampf((p - a).dot(seg) / l2, 0.0, 1.0)
			if (a + seg * t).distance_to(p) < clear and t < best_t:
				best_t = t
				hit = p
	if best_t > 1.0:
		out.append(b)
		return
	# détour : on passe à côté de l'obstacle le plus proche du départ
	var q := a + seg * best_t
	var n := q - hit
	n.y = 0
	if n.length() < 0.05:
		n = Vector3(-seg.z, 0, seg.x)
		if n.dot(-q) < 0.0:
			n = -n
	var w := _bot_clamp(hit + n.normalized() * (clear + 0.35))
	_bot_leg(out, a, w, avoid, clear, depth - 1)
	_bot_leg(out, w, b, avoid, clear, depth - 1)


## Place libre devant p dans la direction dir avant le bord de l'arène.
func _bot_room(p: Vector3, dir: Vector3) -> float:
	var t := 99.0
	if dir.x > 0.001:
		t = minf(t, (BOT_HALF.x - p.x) / dir.x)
	elif dir.x < -0.001:
		t = minf(t, (-BOT_HALF.x - p.x) / dir.x)
	if dir.z > 0.001:
		t = minf(t, (BOT_HALF.y - p.z) / dir.z)
	elif dir.z < -0.001:
		t = minf(t, (-BOT_HALF.y - p.z) / dir.z)
	return maxf(t, 0.0)


## Trait droit qui traverse tgt, long d'au moins min_len si l'arène le permet (iaï dès 7 m).
func _bot_line(h: Vector3, tgt: Vector3, min_len: float) -> PackedVector3Array:
	var d := tgt - h
	d.y = 0
	var dist := d.length()
	var dir := Vector3(-h.x, 0, -h.z)
	if dist > 0.3:
		dir = d / dist
	if dir.length_squared() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var l := minf(maxf(min_len, dist + 1.2), _bot_room(h, dir))
	if l < dist + 0.5:
		# cible collée au bord : on la traverse puis on revient vers le centre
		var back := Vector3(-tgt.x, 0, -tgt.z)
		if back.length_squared() < 0.01:
			back = Vector3(0, 0, 1)
		return _bot_dense([h, tgt, tgt + back.normalized() * 2.0])
	return _bot_dense([h, h + dir * l])
