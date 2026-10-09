extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 7 (Ryūgū-jō) — Umibōzu, le moine géant des abysses (22 PV × monde).
##  Sa peau d'encre luisante est son bouclier (10) : un coup ne fait qu'effleurer. Trois bulles d'écume
##  (quatre sous 50 %), numérotées par des encoches sumi, dérivent dans l'arène.
##  Mécanique de trait : un seul trait (ruées enchaînées comprises) qui les crève TOUTES DANS L'ORDRE
##  brise sa peau : renversé 5.5 s, vulnérable (dégâts ×2). Dans le désordre : un éclat de bouclier par
##  bulle et les bulles se reforment ailleurs. Prépare les cinq perles de Ryūjin.
##  Attaques : bulles crachées (lueur 0.8 s) ; vague (bande en travers de l'arène, 1.2 s) ;
##  plongée sous le héros (disque r1.8, 1.2 s), intouchable sous l'eau.
##  Apparence (direction « Masque d'encre ») : l'umibōzu commun (yokai_ink_w1.gd) en GÉANT d'encre outremer,
##  modelé en primitives fusionnées (Yokai.Mesher, couleurs de sommets) : dôme lisse sans masque, deux yeux
##  d'or immenses, kesa d'or en écharpe, chapelet d'or sur la poitrine, obi turquoise à grand seigaiha, bras
##  d'encre aux bracelets d'or, gouttes qui s'étirent sous lui, collier d'écume au ras de l'eau.

const Yokai = preload("res://scripts/yokai_parts.gd")

const BLACK := Color("#1A2228")
const FOAM_C := Color("#E9F4F2")
const INK_ULTRA := Color("#151E44")  # encre outremer de l'abysse
const CLOTH := Color("#145060")  # turquoise profond (étoffe du monde 7)
const WAVE := Color("#9EE0DA")  # écume turquoise du seigaiha
const LINE := Color("#C86E7E")  # corail rose
const U := 2.1  # échelle du modelé (H_REF 1,75 m -> ~3,7 m)
const HEAD_TILT := 0.45  # dôme relevé vers la caméra (vue plongeante)
const REST_R := Vector3(1.1, 0, 0.3)  # bras au repos (comme ink_rig.REST_ARMS["umibozu"])
const REST_L := Vector3(0.35, 0, -0.3)
const BUBBLE_HIT := 0.85  # distance trait-bulle pour la crever
const SHIELD := 10.0
const BUBBLE_CHIP := 0.8
const SPIT_TELE := 0.8
const SLAM_TELE := 1.2
const SLAM_HZ := 0.9  # demi-épaisseur de la vague
const DIVE_R := 1.8
const DIVE_TELE := 1.2
const SINK_T := 0.6

static var _ink_mat: StandardMaterial3D = null

var _head: Node3D
var _eyes: Array = []
var _arms: Array = []  # [droit, gauche] (pivots d'épaule)
var _drips: Array = []
var _bubbles: Array = []  # {node, orb, base, pos, ph, lit}, dans l'ordre 1, 2, 3…
var _order: Array = []
var _seen := {}
var _bubble_t := 0.4
var _cycle := 0
var _depth := 0.0  # 0 = émergé, -2.6 = sous l'eau
var _death_played := false


func _ready() -> void:
	title = "Umibōzu"
	hp = 22.0 * max_hp_mult
	max_hp = hp
	radius = 1.2
	_build()
	_shield_init(SHIELD, Vector3(1.6, 2.0, 1.6), 1.4)
	_state = "spawn"
	_timer = 1.4
	_depth = -2.6


# ------------------------------------------------------------------ construction

## Toon à contour épais (géant) aux couleurs de sommets : un seul matériau pour toute l'encre, l'or et l'étoffe.
static func ink_mat() -> StandardMaterial3D:
	if _ink_mat == null:
		_ink_mat = Toon.mat(Color.WHITE, true, 0.04)
		_ink_mat.vertex_color_use_as_albedo = true
		_ink_mat.vertex_color_is_srgb = true
	return _ink_mat


## Pièce fusionnée posée sur `parent` : surface toon, et aplat lumineux si `f` n'est pas vide.
static func piece(parent: Node3D, a: Yokai.Mesher, f: Yokai.Mesher = null) -> MeshInstance3D:
	var m: ArrayMesh = a.mesh() if f == null else Yokai.two(a, f)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	# `a` vide : la seule surface est l'aplat
	mi.set_surface_override_material(0, Yokai.ink_flat_mat() if a.arrays().is_empty() else ink_mat())
	if m.get_surface_count() > 1:
		mi.set_surface_override_material(1, Yokai.ink_flat_mat())
	parent.add_child(mi)
	return mi


func _build() -> void:
	var lite := Toon.lite
	Toon.disc(self, 1.3, Color(0, 0, 0, 0.18))
	body = Node3D.new()
	add_child(body)
	body.rotation.y = PI  # il émerge déjà tourné vers le héros (le modèle regarde vers -Z)
	# corps : dôme d'encre outremer, large (w 1,25), obi turquoise à seigaiha, liserés et oreilles d'or (élite)
	var w := 1.25
	var b := Yokai.Mesher.new(U)
	Yokai.ink_body(b, w, INK_ULTRA, CLOTH, WAVE, Toon.GOLD, lite, true)
	# kesa : écharpe d'or en biais à travers le corps, bord sumi
	b.cyl(Vector3(0, 0.95, 0), Vector3(0.45 * w + 0.03, 0.08, 0.43 * w + 0.03), Toon.GOLD, Vector3(0, 0, 0.55), 1.0, 14)
	b.cyl(Vector3(0, 0.95, 0), Vector3(0.45 * w + 0.045, 0.03, 0.43 * w + 0.045), Toon.SUMI, Vector3(0, 0, 0.55), 1.0, 14)
	# chapelet (juzu) : grosses perles d'or en U sur la poitrine, perle mère en bas
	var n := 7 if lite else 11
	for i in n:
		var ang := -1.25 + 2.5 * float(i) / float(n - 1)
		b.ball(Vector3(sin(ang) * 0.47 * w, 1.1 - cos(ang) * 0.3, -0.42 - 0.1 * cos(ang)), Vector3.ONE * 0.055, Toon.GOLD, Vector3.ZERO, 6)
	b.ball(Vector3(0, 0.78, -0.45), Vector3(0.08, 0.09, 0.07), Toon.GOLD, Vector3.ZERO, 8)
	# collier d'écume au ras de l'eau (unités du monde / U)
	var nf := 8 if lite else 12
	for k in nf:
		var a2 := TAU * float(k) / float(nf)
		b.ball(Vector3(cos(a2) * 1.35, 0.15, sin(a2) * 1.1) / U, Vector3.ONE * (0.22 + 0.05 * float(k % 2)) / U, FOAM_C, Vector3.ZERO, 6)
	piece(body, b)
	# tête : dôme lisse qui prolonge le corps, cerne d'or à sa base, deux yeux d'or immenses (aplat séparé)
	_head = Node3D.new()
	body.add_child(_head)
	_head.position = Vector3(0, 1.22 * U, 0)
	_head.rotation.x = HEAD_TILT
	var h := Yokai.Mesher.new(U)
	h.ball(Vector3(0, 0.08, -0.06), Vector3(0.5, 0.46, 0.48), INK_ULTRA, Vector3.ZERO, 12)
	h.cyl(Vector3(0, -0.2, -0.06), Vector3(0.49, 0.04, 0.47), Toon.GOLD, Vector3.ZERO, 1.0, 14)
	if not lite:
		# six points de moxa d'or sur le crâne du moine
		for k in 6:
			var ang := -0.5 + 1.0 * float(k % 3) / 2.0
			var zz := -0.22 - 0.16 * float(k / 3)
			h.ball(Vector3(sin(ang) * 0.3, 0.47 - 0.1 * absf(ang) - 0.06 * float(k / 3), zz), Vector3(0.025, 0.012, 0.025), Toon.GOLD, Vector3.ZERO, 6)
	var f := Yokai.Mesher.new(U)
	for sx: float in [-1.0, 1.0]:
		# yeux posés SUR le dôme (z ≈ -0,50 à cette hauteur), tournés vers le haut : lisibles en vue plongeante
		f.ball(Vector3(sx * 0.2, 0.14, -0.5), Vector3(0.16, 0.17, 0.06), Yokai.EYE_GOLD, Vector3(-0.3, 0, 0), 10)
		f.ball(Vector3(sx * 0.2, 0.13, -0.555), Vector3(0.065, 0.085, 0.025), Toon.SUMI, Vector3(-0.3, 0, 0), 6)
		# arcade sumi froncée au-dessus de chaque œil
		h.ball(Vector3(sx * 0.2, 0.32, -0.45), Vector3(0.17, 0.035, 0.05), Toon.SUMI, Vector3(-0.4, 0, sx * 0.3), 6)
	piece(_head, h)
	# les yeux sont une pièce à part (aplat seul) : _on_die les éteint
	_eyes.append(piece(_head, Yokai.Mesher.new(U), f))
	# bras d'encre (pivot à l'épaule, pendent vers -Y), bracelet d'or au poignet
	for sx: float in [1.0, -1.0]:
		var piv := Node3D.new()
		body.add_child(piv)
		piv.position = Vector3(sx * 0.44 * w * U, 1.0 * U, -0.02 * U)
		var am := Yokai.Mesher.new(U)
		am.cyl(Vector3(0, -0.23, 0), Vector3(0.11, 0.46, 0.11), INK_ULTRA, Vector3(PI, 0, 0), 0.7, 7)
		am.cyl(Vector3(0, -0.4, 0), Vector3(0.095, 0.04, 0.095), Toon.GOLD, Vector3.ZERO, 1.0, 8)
		am.ball(Vector3(0, -0.5, 0), Vector3(0.13, 0.11, 0.13), INK_ULTRA)
		piece(piv, am)
		_arms.append(piv)
	# gouttes d'encre sous le corps (étirées en code)
	var pts := [Vector3(0.18, 0.36, -0.16), Vector3(-0.21, 0.35, 0.06), Vector3(0.06, 0.34, 0.2)]
	if lite:
		pts = [Vector3(0.18, 0.36, -0.16), Vector3(-0.19, 0.35, 0.1)]
	for p: Vector3 in pts:
		var piv := Node3D.new()
		body.add_child(piv)
		piv.position = p * U
		var dm := Yokai.Mesher.new(U)
		dm.ball(Vector3.ZERO, Vector3(0.08, 0.1, 0.08), INK_ULTRA, Vector3.ZERO, 6)
		dm.spike(Vector3.ZERO, 0.07, 0.24, INK_ULTRA, Vector3(PI, 0, 0), 0.3, 5)
		dm.ball(Vector3(0, -0.25, 0), Vector3(0.05, 0.06, 0.05), INK_ULTRA, Vector3.ZERO, 6)
		piece(piv, dm)
		_drips.append(piv)
	_make_stars(body, 3.4)


## Bulle d'écume numérotée par `idx + 1` encoches sumi.
func _make_bubble(idx: int, p: Vector3) -> Dictionary:
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	n.global_position = p
	Toon.disc(n, 0.62, Color(FOAM_C, 0.3), 0.02)
	var orb := Node3D.new()
	n.add_child(orb)
	orb.position.y = 0.9
	Toon.part(orb, Toon.sphere(0.36), Toon.flat(Color(FOAM_C, 0.55)), Vector3.ZERO)
	Toon.part(orb, Toon.sphere(0.12), Toon.flat(Color(1, 1, 1, 0.9)), Vector3(-0.12, 0.14, -0.2))
	var ink := Toon.mat_shared(Toon.SUMI, false)
	for k in idx + 1:
		var x := (float(k) - float(idx) * 0.5) * 0.2
		Toon.part(n, Toon.box(Vector3(0.08, 0.05, 0.4)), ink, Vector3(x, 1.6, 0))
	main.splash(p + Vector3(0, 0.9, 0), FOAM_C, 6)
	return {"node": n, "orb": orb, "base": Vector3(p.x, 0, p.z), "pos": Vector3(p.x, 0, p.z), "ph": randf() * TAU, "lit": false}


func _spawn_bubbles() -> void:
	_free_bubbles(false)
	var n := 3 if hp > max_hp * 0.5 else 4
	var pts := _layout(n)
	for i in n:
		var p: Vector3 = pts[i]
		_bubbles.append(_make_bubble(i, p))


func _free_bubbles(burst: bool) -> void:
	for s: Dictionary in _bubbles:
		var n = s["node"]
		if is_instance_valid(n):
			if burst:
				var p: Vector3 = s["pos"]
				main.splash(p + Vector3(0, 0.9, 0), FOAM_C, 10)
			n.queue_free()
	_bubbles.clear()
	_order = []
	_seen = {}


## Places des bulles : éparpillées, loin de lui, espacées de 2.4 à 4.6 m dans l'ordre, aucune bulle
## sur le chemin direct entre deux bulles qui se suivent.
func _layout(n: int) -> Array:
	var me := Vector3(position.x, 0, position.z)
	var max_leg := 4.6 if n == 3 else 4.0
	for _attempt in 80:
		var pts: Array = []
		for i in n:
			for _k in 30:
				var q := Vector3(randf_range(-3.3, 3.3), 0, randf_range(-6.2, 5.2))
				if q.distance_to(me) < 2.6:
					continue
				var good := true
				for o in pts:
					var op: Vector3 = o
					if op.distance_to(q) < 2.3:
						good = false
						break
				if good and i > 0:
					var prev: Vector3 = pts[i - 1]
					var dd := prev.distance_to(q)
					good = dd >= 2.4 and dd <= max_leg
				if good:
					pts.append(q)
					break
			if pts.size() != i + 1:
				break
		if pts.size() == n and _layout_clear(pts):
			return pts
	var fb: Array = [Vector3(-2.6, 0, -1.4), Vector3(2.4, 0, 0.4), Vector3(-2.3, 0, 2.4), Vector3(2.5, 0, 4.4)]
	return fb.slice(0, n)


func _layout_clear(pts: Array) -> bool:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		for j in pts.size():
			if j == i or j == i + 1:
				continue
			var q: Vector3 = pts[j]
			if _seg_dist(q, a, b) < 1.3:
				return false
	return true


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if hero.dashing and not _bubbles.is_empty() and _surfaced():
		_bubble_touch(a, b)
	if not _surfaced():
		return false
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


## Fin du trait : toutes les bulles dans l'ordre brisent sa peau d'encre.
func end_stroke(_stroke_id: int) -> void:
	if not dead and not _bubbles.is_empty() and _surfaced():
		var pa: Vector3 = main._prev_hero
		_bubble_touch(pa, hero.position)
	var order: Array = _order
	_order = []
	_seen = {}
	for s: Dictionary in _bubbles:
		s["lit"] = false
	if dead or _bubbles.is_empty() or order.size() < 2:
		return
	var ok := order.size() == _bubbles.size()
	for i in order.size():
		if int(order[i]) != i:
			ok = false
	if ok and _state != "broken":
		_burst_all()
		return
	# dans le désordre : les bulles éclatent et se reforment ailleurs, la peau s'ébrèche
	var last: Dictionary = _bubbles[int(order[order.size() - 1])]
	var lp: Vector3 = last["pos"]
	main.clang(lp + Vector3(0, 0.9, 0))
	_free_bubbles(true)
	_bubble_t = 0.6
	_shield_dmg(BUBBLE_CHIP * float(order.size()))


func touching_hero(p: Vector3) -> bool:
	if dead or not _surfaced():
		return false
	return Vector2(p.x - position.x, p.z - position.z).length() < radius + 0.1


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if not _surfaced():
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.6, 0)


func _zone_fire(z: Dictionary) -> void:
	var tag := String(z["tag"])
	if tag == "slam":
		var c: Vector3 = z["c"]
		if _in_zone(z, hero.position, 0.0):
			main.enemy_strike(Vector3(hero.position.x, 0, hero.position.z), 0.4)
		for k in 5:
			main.vfx.water_burst(Vector3(-3.6 + 1.8 * float(k), 0, c.z), 0.8)
		main.shake = maxf(float(main.shake), 0.31)
		_state = "idle"
		_timer = 1.8 if hp > max_hp * 0.5 else 1.4
	elif tag == "dive":
		var c2: Vector3 = z["c"]
		position = Vector3(c2.x, 0, c2.z)
		main.clamp_to_arena(self, radius)
		main.enemy_strike(c2, DIVE_R)
		main.vfx.water_burst(c2, DIVE_R)
		_state = "rise"
		_timer = SINK_T


func _on_die() -> void:
	_free_bubbles(true)
	for e in _eyes:
		var em: MeshInstance3D = e
		em.visible = false


## Peau brisée : renversé, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	_free_bubbles(true)
	_state = "broken"
	_depth = 0.0


func _on_shield_back() -> void:
	if _state != "broken":
		return
	_state = "idle"
	_timer = 1.0
	_bubble_t = 0.8


func _sh_hidden() -> bool:
	return _depth < -0.8


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var dir := _dir_to_hero()
	# les bulles reviennent (sauf renversé ou sous l'eau)
	if _bubbles.is_empty() and not dead and _surfaced() and _state != "broken":
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_spawn_bubbles()
	match _state:
		"spawn":
			_timer -= delta
			_depth = lerpf(-2.6, 0.0, clampf(1.0 - _timer / 1.4, 0.0, 1.0))
			if _timer <= 0.0:
				_depth = 0.0
				_state = "idle"
				_timer = 1.2
				_bubble_t = 0.0
		"idle":
			_face(dir, delta, 2.5)
			_timer -= delta
			if _timer <= 0.0:
				_cycle += 1
				match _cycle % 3:
					1:
						_state = "spit"
						_timer = SPIT_TELE
					2:
						var cz := clampf(hero.position.z, -HALF.y + 1.0, HALF.y - 1.0)
						_zone_rect(Vector3(0, 0, cz), Vector3(1, 0, 0), SLAM_HZ, HALF.x, SLAM_TELE, "slam", Vector2(-1, 0))
						_state = "slam"
					_:
						_state = "sink"
						_timer = SINK_T
		"spit":
			_face(dir, delta, 4.0)
			_timer -= delta
			if _timer <= 0.0:
				for i in 3:
					var d := dir.rotated(Vector3.UP, deg_to_rad(-18.0 + 18.0 * float(i)))
					main.spawn_bullet(position + Vector3(0, 1.8, 0) + d * 1.3, d)
				_state = "idle"
				_timer = 2.0 if hp > max_hp * 0.5 else 1.6
		"slam":
			# la vague arrive (_zone_fire le remet à l'affût)
			_face(dir, delta, 2.5)
		"sink":
			_timer -= delta
			_depth = lerpf(0.0, -2.6, clampf(1.0 - _timer / SINK_T, 0.0, 1.0))
			if _timer <= 0.0:
				var t: Vector3 = main.arena.clamp_walk(Vector3(hero.position.x, 0, hero.position.z), radius)
				_zone_disc(t, DIVE_R, DIVE_TELE, "dive")
				_state = "under"
		"under":
			_depth = -2.6
			if fmod(_t, 0.3) < delta:
				main.vfx.ring(Vector3(position.x, 0.06, position.z), FOAM_C, 0.8)
		"rise":
			_timer -= delta
			_depth = lerpf(-2.6, 0.0, clampf(1.0 - _timer / SINK_T, 0.0, 1.0))
			if _timer <= 0.0:
				_depth = 0.0
				_state = "idle"
				_timer = 1.6 if hp > max_hp * 0.5 else 1.2
		"broken":
			# renversé : la fin de la fenêtre (vulnerable_t) le relève (_on_shield_back)
			_depth = move_toward(_depth, -0.6, delta)
		"dying":
			_timer += delta
			_depth = move_toward(_depth, -3.0, delta * 1.4)
			if _timer > 2.2:
				queue_free()
	_animate(delta)


func _surfaced() -> bool:
	return _state == "idle" or _state == "spit" or _state == "slam" or _state == "broken"


## Toutes les bulles dans l'ordre : la peau d'encre cède d'un coup.
func _burst_all() -> void:
	main.float_text(position + Vector3(0, 2.4, 0), "泡", Toon.GOLD)
	main.big_hit(position + Vector3(0, 1.6, 0))
	main.splash(position + Vector3(0, 2.0, 0), FOAM_C, 30)
	main.shake = maxf(float(main.shake), 0.86)
	_free_bubbles(true)
	_shield_dmg(shield_max)


func _bubble_touch(a: Vector3, b: Vector3) -> void:
	var seg := b - a
	var found: Array = []
	for i in _bubbles.size():
		if _seen.has(i):
			continue
		var s: Dictionary = _bubbles[i]
		var p: Vector3 = s["pos"]
		if _seg_dist(p, a, b) < BUBBLE_HIT:
			var tt := 0.0
			if seg.length_squared() > 0.0001:
				tt = (p - a).dot(seg) / seg.length_squared()
			found.append([tt, i])
	# plusieurs bulles dans un même segment : dans le sens de la ruée
	found.sort_custom(func(x, y): return x[0] < y[0])
	for f in found:
		var idx := int(f[1])
		_seen[idx] = true
		_order.append(idx)
		var s2: Dictionary = _bubbles[idx]
		s2["lit"] = true
		var p2: Vector3 = s2["pos"]
		main.small_hit(p2 + Vector3(0, 0.9, 0))


## Tête qui respire (tremble renversé), bras qui montent pour cracher et s'ouvrent renversé, gouttes qui
## s'étirent, bulles qui dérivent doucement (blanches une fois crevées).
func _animate(delta: float) -> void:
	if _state != "dying":
		body.position.y = _depth + sin(_t * 1.6) * 0.06
	else:
		body.position.y = _depth
	var shake := sin(_t * 12.0) * 0.08 if _state == "broken" else 0.0
	var nod := 0.1 * sin(_t * 1.6)
	if _state == "spit":
		nod = -0.15 * clampf(1.0 - _timer / SPIT_TELE, 0.0, 1.0)
	elif _state == "broken":
		nod = 0.3
	_head.rotation = Vector3(HEAD_TILT + nod, 0, shake)
	# bras : repos, levés pour cracher (charge), ouverts renversé, pendants à la mort
	var want_r := REST_R
	var want_l := REST_L
	if _state == "spit":
		var k := clampf(1.0 - _timer / SPIT_TELE, 0.0, 1.0)
		want_r = Vector3(2.5 * k + REST_R.x * (1.0 - k), 0, 0.5)
		want_l = Vector3(2.5 * k + REST_L.x * (1.0 - k), 0, -0.5)
	elif _state == "broken":
		want_r = Vector3(0.6, 0, 1.0 + 0.1 * sin(_t * 12.0))
		want_l = Vector3(0.6, 0, -1.0 - 0.1 * sin(_t * 12.0))
	elif _state == "dying":
		want_r = Vector3(0.2, 0, 0.2)
		want_l = Vector3(0.2, 0, -0.2)
	else:
		want_r += Vector3(0.08 * sin(_t * 1.6), 0, 0)
		want_l += Vector3(0.08 * sin(_t * 1.6 + 1.0), 0, 0)
	var k2 := minf(1.0, delta * 6.0)
	var ar: Node3D = _arms[0]
	var al: Node3D = _arms[1]
	ar.rotation = ar.rotation.lerp(want_r, k2)
	al.rotation = al.rotation.lerp(want_l, k2)
	var stretch := 1.5 if _state == "sink" or _state == "rise" else 1.0
	for i in _drips.size():
		var n: Node3D = _drips[i]
		var ph := _t * 2.6 + float(i) * 1.7
		n.scale = Vector3(1, stretch * (1.0 + 0.3 * sin(ph)), 1)
		n.rotation = Vector3(0.1 * sin(ph * 0.7), 0, 0.1 * cos(ph * 0.9 + 0.5))
	body.visible = _depth > -2.4
	var sc := 1.06 if _flash > 0.0 else 1.0
	body.scale = Vector3.ONE * sc
	for i in _bubbles.size():
		var s: Dictionary = _bubbles[i]
		var base: Vector3 = s["base"]
		var ph: float = s["ph"]
		var p := base + Vector3(cos(_t * 0.35 + ph), 0, sin(_t * 0.35 + ph)) * 0.35
		s["pos"] = p
		var n = s["node"]
		if is_instance_valid(n):
			n.global_position = p
		var orb = s["orb"]
		orb.position.y = 0.9 + sin(_t * 2.2 + float(i)) * 0.1
		orb.scale = Vector3.ONE * (1.3 if bool(s["lit"]) else 1.0)


# ------------------------------------------------------------------ robot testeur

## Bulles : un trait qui les relie dans l'ordre (en contournant les suivantes : la peau cède) ;
## renversé (vulnérable) : iaï à travers, encore et encore.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	var me := Vector3(position.x, 0, position.z)
	if _state == "broken":
		if vulnerable_t < 0.3:
			return none
		return _bot_line(h, me, 7.3)
	if _bubbles.is_empty() or not _surfaced():
		return none
	var pts: Array = [h]
	for i in _bubbles.size():
		var s: Dictionary = _bubbles[i]
		var tgt: Vector3 = s["pos"]
		var avoid: Array = []
		for j in range(i + 1, _bubbles.size()):
			var o: Dictionary = _bubbles[j]
			avoid.append(o["pos"])
		var from: Vector3 = pts[pts.size() - 1]
		_bot_leg(pts, from, _bot_clamp(tgt), avoid, 1.1, 3)
	var last: Vector3 = pts[pts.size() - 1]
	var prev: Vector3 = pts[pts.size() - 2]
	var ext := last - prev
	ext.y = 0
	if ext.length_squared() > 0.01:
		pts.append(last + ext.normalized() * 0.8)
	return _bot_dense(pts)
