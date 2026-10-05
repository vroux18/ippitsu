extends Node3D
## Boss du monde 4 (design/UNIVERS.md) : Daidarabotchi, colosse de lave (110 PV, ~6 m).
## Mécanique de trait : « relier les points dans l'ordre ».
##  Il montre 3 (ligne), puis 5 (zigzag), puis 7 (spirale) noyaux or numérotés par des encoches
##  sumi. Un seul trait (ruées enchaînées comprises) qui les touche tous dans l'ordre = noyau
##  brisé : 30 dégâts, carapace ouverte 4.5 s (les coups normaux comptent), phase suivante.
##  Hors ordre : 1 dégât par noyau touché et les noyaux se réarrangent.
##  Le reste du temps, la roche basalte renvoie les coups (×0).
## Attaques : poing (carré 3×3, 1.3 s), pluie de cendres (6–8 zones r0.8, ~1.1 s),
##  crachat de lave (boules lentes, 0.9 s de lueur), souffle (cône 45° 8 m, 1.0 s) sous 30 %.
## main appelle : check_dash(), take_hit(), end_stroke(), danger_at(), touching_hero().

const Toon = preload("res://scripts/toon.gd")

const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (comme main.gd)
const BASALT := Color("#2A2422")
const BASALT_HI := Color("#3B3330")
const LAVA := Color("#C49A45")  # fissures de lave or
const EMBER := Color("#E0602A")  # yeux de braise
const BRAISE := Color("#8E2A1E")
const ASH := Color("#5A5550")
const ROCK_FLASH := Color("#7A6A62")  # roche éclaircie au coup reçu
const DANGER_MARGIN := 0.35  # marge de danger_at (comme is_danger de main)
const CORE_HIT := 0.75  # distance trait-noyau pour le toucher
const CORE_DMG := 30.0
const OPEN_TIME := 4.5
const POOL_R := 2.2  # bassin de lave : contact = dégâts
const HAND_HIT := 1.0
const HAND_REST := [Vector3(-2.7, 0.35, 2.3), Vector3(2.7, 0.35, 2.3)]  # mains posées (local)
const SHOULDER := [Vector3(-2.1, 3.4, 0.3), Vector3(2.1, 3.4, 0.3)]

var kind := "daidara"
var main: Node
var hero: Node3D
var title := "Daidarabotchi"
var hp := 110.0
var max_hp := 110.0
var dead := false
var max_hp_mult := 1.0  # difficulté du monde

var _state := "spawn"
var _timer := 2.4
var _t := 0.0
var _flash := 0.0
var _phase := 1
var _open := 0.0
var _atk_cd := 1.6
var _breath_ok := false

# corps
var rig: Node3D
var _torso: Node3D
var _head: Node3D
var _hands: Array = []  # Node3D, 0 = gauche, 1 = droite
var _arms: Array = []  # [bras, avant-bras] par côté
var _rock_mat: StandardMaterial3D
var _crack_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D

# noyaux
var _cores: Array = []  # {node, orb, mat, p, oy}
var _layout_id := 0
var _core_side := -1  # main qui porte un noyau (-1 : aucune)
var _cores_lock := 0.0
var _run := {}  # trait en cours : {layout, order, bad, body}
var _last_body_stroke := -1

# attaques
var _zones: Array = []  # {kind, node, fill, c, r, t, total, dir, rock, done}
var _fist := {}
var _volley_t := -1.0


func setup(k: String, m: Node) -> void:
	kind = k
	main = m
	hero = m.hero


func _ready() -> void:
	if position.is_zero_approx():
		position = Vector3(0, 0, -7.5)  # au fond de l'arène
	hp = 110.0
	hp *= max_hp_mult
	max_hp = hp
	_build()
	rig.position.y = -6.5  # il surgit du bassin de lave


# ------------------------------------------------------------------ construction

func _rock(r: float, sides := 6) -> SphereMesh:
	# roche low-poly (peu de faces)
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = sides
	m.rings = 3
	return m


func _gem(r: float) -> SphereMesh:
	# octaèdre allongé
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.6
	m.radial_segments = 4
	m.rings = 2
	return m


func _ink(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m


func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := Toon.mat(col, false)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func _crack(parent: Node3D, pos: Vector3, size: Vector3, rz := 0.0) -> void:
	var c := Toon.part(parent, Toon.box(size), _crack_mat, pos)
	c.rotation.z = rz


func _build() -> void:
	_rock_mat = Toon.mat(BASALT, true, 0.05)
	var hi := Toon.mat(BASALT_HI, true, 0.04)
	_crack_mat = _glow_mat(LAVA, 0.6)
	_eye_mat = _glow_mat(EMBER, 1.2)

	# bassin de lave : sumi veiné d'or
	Toon.disc(self, 3.0, Color(LAVA, 0.5), 0.012)
	Toon.disc(self, 2.7, Color("#1E1A19"), 0.016)
	for i in 9:
		var a := TAU * float(i) / 9.0 + randf_range(-0.15, 0.15)
		var cr := Toon.part(self, Toon.box(Vector3(0.09, 0.01, randf_range(0.8, 1.5))), _crack_mat, Vector3(sin(a) * 1.9, 0.02, cos(a) * 1.9))
		cr.rotation.y = a
	for i in 5:
		var a2 := -1.2 + 0.6 * float(i)
		var b := Toon.part(self, _rock(randf_range(0.35, 0.6), 5), _rock_mat, Vector3(sin(a2) * 2.6, 0.05, cos(a2) * 2.6))
		b.rotation.y = randf() * TAU

	rig = Node3D.new()
	add_child(rig)
	_torso = Node3D.new()
	rig.add_child(_torso)
	# hanches et torse
	Toon.part(_torso, _rock(1.9, 7), _rock_mat, Vector3(0, 0.9, 0), Vector3(1.25, 0.7, 0.9))
	Toon.part(_torso, _rock(1.8, 7), _rock_mat, Vector3(0, 2.5, 0), Vector3(1.15, 1.0, 0.8))
	for sx in [-1.0, 1.0]:
		var pec := Toon.part(_torso, Toon.box(Vector3(1.2, 0.95, 0.5)), hi, Vector3(sx * 0.68, 3.0, 1.12))
		pec.rotation = Vector3(0.2, sx * 0.25, sx * 0.1)
		# épaules en blocs, piques de roche
		Toon.part(_torso, _rock(1.05, 6), _rock_mat, Vector3(sx * 2.05, 3.5, 0.2), Vector3(1.0, 0.85, 1.0))
		for j in 2:
			var sp := Toon.part(_torso, Toon.cyl(0.0, 0.3, 0.9, 5), hi, Vector3(sx * (1.9 + 0.45 * j), 4.3 - 0.15 * j, 0.1 - 0.3 * j))
			sp.rotation.z = -sx * (0.3 + 0.35 * j)
		_crack(_torso, Vector3(sx * 0.6, 1.75, 1.3), Vector3(0.1, 0.8, 0.12), sx * 0.6)
		_crack(_torso, Vector3(sx * 1.95, 3.55, 1.0), Vector3(0.08, 0.6, 0.1), sx * 0.9)
	# fissure du sternum et cœur de lave
	_crack(_torso, Vector3(0, 2.25, 1.45), Vector3(0.12, 1.5, 0.12))
	_crack(_torso, Vector3(0.25, 1.0, 1.62), Vector3(0.1, 0.7, 0.12), 0.4)
	var heart := Toon.part(_torso, _gem(0.32), _crack_mat, Vector3(0, 2.75, 1.5))
	heart.rotation.y = 0.785

	# tête
	_head = Node3D.new()
	_head.position = Vector3(0, 4.55, 0.35)
	_torso.add_child(_head)
	Toon.part(_head, _rock(0.95, 6), _rock_mat, Vector3.ZERO, Vector3(1.0, 0.95, 0.9))
	var brow := Toon.part(_head, Toon.box(Vector3(1.5, 0.3, 0.5)), hi, Vector3(0, 0.28, 0.55))
	brow.rotation.x = 0.25
	Toon.part(_head, Toon.box(Vector3(1.1, 0.45, 0.7)), _rock_mat, Vector3(0, -0.55, 0.3))
	for sx in [-1.0, 1.0]:
		Toon.part(_head, Toon.sphere(0.2), _ink(BRAISE), Vector3(sx * 0.36, 0.05, 0.7))
		Toon.part(_head, Toon.sphere(0.13), _eye_mat, Vector3(sx * 0.36, 0.05, 0.8))
	_crack(_head, Vector3(0, -0.36, 0.7), Vector3(0.7, 0.08, 0.1))
	# couronne de piques : le sommet du volcan
	for i in 5:
		var ca := -0.9 + 0.45 * float(i)
		var spike := Toon.part(_head, Toon.cyl(0.0, 0.22, 0.75, 5), hi, Vector3(sin(ca) * 0.6, 0.95 - absf(ca) * 0.2, -0.1))
		spike.rotation.z = -ca * 0.7

	# mains posées au sol devant lui, bras recalculés à chaque image
	for side in 2:
		var h := Node3D.new()
		rig.add_child(h)
		h.position = HAND_REST[side]
		Toon.part(h, _rock(0.8, 6), _rock_mat, Vector3.ZERO, Vector3(1.2, 0.7, 1.05))
		for j in 4:
			var kn := Toon.part(h, Toon.box(Vector3(0.28, 0.28, 0.3)), hi, Vector3(-0.45 + 0.3 * float(j), 0.2, 0.72))
			kn.rotation.y = randf_range(-0.2, 0.2)
		var top := Toon.part(h, Toon.box(Vector3(0.55, 0.06, 0.08)), _crack_mat, Vector3(0, 0.5, 0))
		top.rotation.y = 0.5 if side == 0 else -0.5
		_hands.append(h)
		var up := Toon.part(rig, Toon.cyl(0.5, 0.5, 1.0, 6), _rock_mat, Vector3.ZERO)
		var fore := Toon.part(rig, Toon.cyl(0.42, 0.5, 1.0, 6), _rock_mat, Vector3.ZERO)
		_arms.append([up, fore])
	_update_arms()


## Place un cylindre (hauteur 1) entre a et b, en repère local de rig.
func _limb(mi: MeshInstance3D, a: Vector3, b: Vector3, th: float) -> void:
	var d := b - a
	var l := maxf(d.length(), 0.01)
	var n := d / l
	var q := Quaternion.IDENTITY
	if absf(n.dot(Vector3.UP)) < 0.999:
		q = Quaternion(Vector3.UP, n)
	mi.transform = Transform3D(Basis(q) * Basis.from_scale(Vector3(th, l, th)), (a + b) * 0.5)


func _update_arms() -> void:
	for side in 2:
		var sx := -1.0 if side == 0 else 1.0
		var sh: Vector3 = SHOULDER[side]
		sh += _torso.position
		var h: Node3D = _hands[side]
		var hand_p := h.position
		var elbow := sh.lerp(hand_p, 0.5) + Vector3(sx * 0.9, 0.7, -0.3)
		var limbs: Array = _arms[side]
		_limb(limbs[0], sh, elbow, 1.0)
		_limb(limbs[1], elbow, hand_p + Vector3(0, 0.3, -0.35), 0.9)


func _hand_world(side: int) -> Vector3:
	var h: Node3D = _hands[side]
	return position + rig.position + h.position


func _hand_ground(side: int) -> Vector3:
	var hr: Vector3 = HAND_REST[side]
	return Vector3(position.x + hr.x, 0, position.z + hr.z)


# ------------------------------------------------------------------ noyaux

func _clamp_core(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -HALF.x + 0.8, HALF.x - 0.8), 0, clampf(p.z, position.z + 2.1, HALF.y - 2.1))


func _spread_ok(pts: Array, d: float) -> bool:
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			var p: Vector3 = pts[i]
			var q: Vector3 = pts[j]
			if p.distance_to(q) < d:
				return false
	return true


## Phase 1 : 3 noyaux presque en ligne, partant d'une main.
func _layout_line() -> Array:
	var s := randi() % 2
	_core_side = s
	var start := _hand_ground(s)
	var sgn := 1.0 if s == 0 else -1.0
	var target := Vector3(sgn * randf_range(0.0, 1.8), 0, randf_range(-0.2, 0.8))
	var dir := (target - start).normalized()
	var perp := Vector3(-dir.z, 0, dir.x)
	var pts: Array = [start]
	pts.append(_clamp_core(start + dir * 3.1 + perp * randf_range(-0.4, 0.4)))
	pts.append(_clamp_core(start + dir * 6.2))
	if randf() < 0.5:
		pts.reverse()
	return pts


## Phase 2 : 5 noyaux en zigzag (≈ 10 m), partant d'une main.
func _layout_zigzag() -> Array:
	var s := randi() % 2
	_core_side = s
	var start := _hand_ground(s)
	var sgn := 1.0 if s == 0 else -1.0
	var target := Vector3(sgn * randf_range(0.3, 1.2), 0, randf_range(1.2, 2.2))
	var dir := (target - start).normalized()
	var perp := Vector3(-dir.z, 0, dir.x) * (1.0 if randf() < 0.5 else -1.0)
	var offs := [0.0, 1.1, -1.1, 1.1, -1.1]
	var pts: Array = [start]
	for i in range(1, 5):
		var o: float = offs[i]
		pts.append(_clamp_core(start + dir * 1.75 * float(i) + perp * o))
	if randf() < 0.5:
		pts.reverse()
	return pts


## Phase 3 : 7 noyaux en spirale (≈ 14–15 m de trait).
func _layout_spiral() -> Array:
	_core_side = -1
	var c := Vector3(randf_range(-0.4, 0.4), 0, randf_range(-1.0, 0.4))
	var a0 := randf() * TAU
	var sgn := 1.0 if randf() < 0.5 else -1.0
	var pts: Array = []
	for i in 7:
		var r := 3.7 - 0.45 * float(i)
		var a := a0 + sgn * 1.1 * float(i)
		pts.append(_clamp_core(c + Vector3(cos(a) * r * 0.9, 0, sin(a) * r * 1.15)))
	if randf() < 0.35:
		pts.reverse()
	return pts


func _gen_points() -> Array:
	var pts: Array = []
	for attempt in 12:
		if _phase == 1:
			pts = _layout_line()
		elif _phase == 2:
			pts = _layout_zigzag()
		else:
			pts = _layout_spiral()
		if _spread_ok(pts, 1.6):
			break
	return pts


## Nouvelle disposition (début de phase ou réarrangement après un trait hors ordre).
func _new_layout() -> void:
	_layout_id += 1
	_clear_cores()
	var pts := _gen_points()
	for i in pts.size():
		var p: Vector3 = pts[i]
		var on_hand := _core_side >= 0 and p.distance_to(_hand_ground(_core_side)) < 0.05
		_cores.append(_make_core(p, i, on_hand, 0.08 * float(i)))
	_cores_lock = 0.45 + 0.08 * float(pts.size())


func _make_core(p: Vector3, idx: int, on_hand: bool, delay: float) -> Dictionary:
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	n.global_position = p
	Toon.disc(n, 0.62, Color(LAVA, 0.3), 0.02)
	Toon.disc(n, 0.4, Color(LAVA, 0.5), 0.024)
	var oy := 1.45 if on_hand else 0.75
	var m := Toon.mat(LAVA, true, 0.03)
	m.emission_enabled = true
	m.emission = LAVA
	m.emission_energy_multiplier = 0.5
	var orb := Toon.part(n, _gem(0.3), m, Vector3(0, oy, 0))
	# encoches sumi sur une plaque de washi inclinée vers la caméra : une barre par rang
	var plate := Node3D.new()
	plate.position = Vector3(0, 0.3, 1.35 if on_hand else 0.85)
	plate.rotation.x = 0.6
	n.add_child(plate)
	Toon.part(plate, Toon.cyl(0.53, 0.53, 0.02, 16), _ink(Toon.SUMI), Vector3(0, -0.006, 0))
	Toon.part(plate, Toon.cyl(0.48, 0.48, 0.02, 16), _ink(Toon.WASHI), Vector3.ZERO)
	var cnt := idx + 1
	var bar_mat := _ink(Toon.SUMI)
	for j in cnt:
		var x := (float(j) - float(cnt - 1) * 0.5) * 0.12
		var bar := Toon.part(plate, Toon.box(Vector3(0.07, 0.012, randf_range(0.3, 0.38))), bar_mat, Vector3(x, 0.014, 0))
		bar.rotation.y = randf_range(-0.08, 0.08)
	# apparition
	n.scale = Vector3.ONE * 0.01
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return {"node": n, "orb": orb, "mat": m, "p": Vector3(p.x, 0, p.z), "oy": oy}


func _clear_cores() -> void:
	for c in _cores:
		var n: Node3D = c["node"]
		if is_instance_valid(n):
			var tw := n.create_tween()
			tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.25)
			tw.tween_callback(n.queue_free)
	_cores.clear()


func _core_color(c: Dictionary, col: Color, energy: float) -> void:
	var m: StandardMaterial3D = c["mat"]
	m.albedo_color = col
	m.emission = col
	m.emission_energy_multiplier = energy


func _reset_core_colors() -> void:
	for c in _cores:
		_core_color(c, LAVA, 0.5)


func _animate_cores(delta: float) -> void:
	var started := not _run.is_empty() and (_run["order"] as Array).size() > 0
	for i in _cores.size():
		var c: Dictionary = _cores[i]
		var orb: MeshInstance3D = c["orb"]
		var oy: float = c["oy"]
		orb.rotation.y += delta * 1.6
		orb.position.y = oy + sin(_t * 2.4 + float(i)) * 0.08
		# le premier noyau bat comme un cœur : c'est le départ
		var s := 1.0
		if i == 0 and not started:
			s = 1.0 + 0.18 * maxf(0.0, sin(_t * 6.0))
		orb.scale = Vector3.ONE * s


# ------------------------------------------------------------------ interface avec main

## Vrai seulement quand la carapace est ouverte (après un noyau brisé) : main applique le coup.
## Sinon on note les noyaux touchés (dans l'ordre du trait) : le verdict tombe à end_stroke.
## Les ruées enchaînées (nouvel id avant la fin de la ruée) prolongent le même tracé.
func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead or _state == "spawn" or not hero.dashing:
		return false
	if _run.is_empty() or int(_run["layout"]) != _layout_id:
		_run = {"layout": _layout_id, "order": [], "bad": false, "body": false}
	_touch_cores(a, b)
	# le corps : basalte (×0) sauf carapace ouverte
	var touch := _seg_dist(position + Vector3(0, 0, 0.6), a, b) < POOL_R + 0.3
	for side in 2:
		if _seg_dist(_hand_world(side), a, b) < HAND_HIT:
			touch = true
	if touch:
		if _open > 0.0:
			if _last_body_stroke != stroke_id:
				_last_body_stroke = stroke_id
				return true
		else:
			_run["body"] = true
	return false


## Note les noyaux touchés par la ruée a..b, dans le sens du trait.
func _touch_cores(a: Vector3, b: Vector3) -> void:
	if _cores_lock > 0.0 or _state != "fight":
		return
	var order: Array = _run["order"]
	var found: Array = []
	for i in _cores.size():
		if order.has(i):
			continue
		var c: Dictionary = _cores[i]
		var p: Vector3 = c["p"]
		if _seg_dist(p, a, b) < CORE_HIT:
			found.append([_seg_t(p, a, b), i])
	found.sort_custom(func(x, y): return x[0] < y[0])
	for f in found:
		var i: int = f[1]
		var c: Dictionary = _cores[i]
		var p: Vector3 = c["p"]
		if i == order.size() and not _run["bad"]:
			# dans l'ordre : le noyau s'illumine, un peu d'élan rendu pour la suite
			_core_color(c, Toon.FOAM, 1.2)
			main.small_hit(p + Vector3(0, 0.7, 0))
			if i > 0:
				main.elan = minf(main.elan_max(), main.elan + 2.0)
		else:
			_run["bad"] = true
			_core_color(c, Toon.SUMI, 0.0)
			main.splash(p + Vector3(0, 0.7, 0), ASH, 6)
		order.append(i)


func take_hit(dmg: float, _dir: Vector3) -> void:
	if dead:
		return
	_damage(dmg)


## Fin du trait : verdict sur les noyaux touchés.
func end_stroke(_stroke_id: int) -> void:
	if _run.is_empty():
		return
	if not dead and int(_run["layout"]) == _layout_id:
		# la dernière image de la ruée (celle où elle s'achève) n'est pas passée par check_dash :
		# sans elle, un trait qui finit sur le dernier noyau le ratait
		var pa: Vector3 = main._prev_hero
		_touch_cores(pa, hero.position)
	var run: Dictionary = _run
	_run = {}
	if dead:
		return
	if int(run["layout"]) != _layout_id:
		return
	var order: Array = run["order"]
	if order.is_empty():
		if run["body"]:
			# la lame ricoche sur le basalte
			var bp := position + Vector3(0, 0, 2.2)
			main.clang(bp)
			main.float_text(bp, "×0", Toon.FOAM)
		return
	if not run["bad"] and order.size() == _cores.size():
		_break_cores()
		return
	# raté : 1 dégât par noyau touché
	var last: Dictionary = _cores[int(order[order.size() - 1])]
	var lp: Vector3 = last["p"]
	var dmg := float(order.size())
	main.float_text(lp, str(int(dmg)), Toon.FOAM)
	_damage(dmg)
	if dead:
		return
	if run["bad"]:
		# hors ordre : les noyaux se réarrangent
		main.clang(lp)
		_new_layout()
	else:
		# bon début mais trait trop court : on peut réessayer la même figure
		_reset_core_colors()


## Vrai si le point p est dans une attaque annoncée qui frappe d'ici eta secondes
## (toutes les zones vivantes, avec leur vraie forme : carré du poing, disques, cône du souffle).
func danger_at(p: Vector3, eta: float) -> bool:
	if dead:
		return false
	var lim := eta + DANGER_MARGIN
	for z in _zones:
		if float(z["t"]) >= lim:
			continue
		var c: Vector3 = z["c"]
		var r := float(z["r"])
		var v := Vector3(p.x - c.x, 0, p.z - c.z)
		match String(z["kind"]):
			"breath":
				var dir: Vector3 = z["dir"]
				var along := v.dot(dir)
				if along > -DANGER_MARGIN and v.length() < r + DANGER_MARGIN:
					var side := (v - dir * along).length()
					if side < maxf(along, 0.0) * tan(deg_to_rad(22.5)) + DANGER_MARGIN:
						return true
			"fist":
				# carré annoncé 3×3, frappe en disque de rayon r
				if v.length() < r + DANGER_MARGIN or (absf(v.x) < 1.5 + DANGER_MARGIN and absf(v.z) < 1.5 + DANGER_MARGIN):
					return true
			_:
				if v.length() < r + DANGER_MARGIN:
					return true
	return false


## Contact : le bassin de lave à ses pieds.
func touching_hero(p: Vector3) -> bool:
	if dead or _state == "spawn":
		return false
	return Vector2(p.x - position.x, p.z - position.z).length() < POOL_R


## Dégâts de zone (techniques, pouvoirs) : touche la partie vulnérable la plus proche de `center` dans `radius`.
## Renvoie le point touché, ou Vector3.INF si rien n'est touché (boss invulnérable à cet instant, hors de portée, mort).
## Seulement carapace ouverte (corps ou mains) : les noyaux ne se brisent qu'avec un trait dans l'ordre.
func aoe_hit(center: Vector3, radius: float, dmg: float, fx := true) -> Vector3:
	if dead or _state != "open" or _open <= 0.0:
		return Vector3.INF
	var c2 := Vector2(center.x, center.z)
	var body := position + Vector3(0, 0, 0.6)
	var best := Vector2(body.x, body.z).distance_to(c2) - POOL_R
	var at := position + Vector3(0, 2.2, 1.4)
	for side in 2:
		var hw := _hand_world(side)
		var d := Vector2(hw.x, hw.z).distance_to(c2) - HAND_HIT
		if d < best:
			best = d
			at = hw + Vector3(0, 0.5, 0)
	if best >= radius:
		return Vector3.INF
	var fl := _flash
	_damage(dmg)
	if not fx:
		_flash = fl
	return at


# ------------------------------------------------------------------ outils

func _seg_t(p: Vector3, a: Vector3, b: Vector3) -> float:
	var seg := b - a
	if seg.length_squared() <= 0.0001:
		return 0.0
	return clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var q := a + (b - a) * _seg_t(p, a, b)
	return Vector2(p.x - q.x, p.z - q.z).length()


func _damage(d: float) -> void:
	hp -= d
	_flash = 0.15
	if hp <= 0.0:
		hp = 0.0
		dead = true
		_cancel_all()
		_clear_cores()
		_run = {}
		_state = "dying"
		_timer = 0.0
		main.boss_killed(self)
	elif not _breath_ok and hp <= max_hp * 0.3:
		_breath_ok = true


func _break_cores() -> void:
	var dmg := CORE_DMG * max_hp_mult
	var last: Dictionary = _cores[_cores.size() - 1]
	var lp: Vector3 = last["p"]
	for c in _cores:
		var p: Vector3 = c["p"]
		main.splash(p + Vector3(0, 0.8, 0), LAVA, 12)
	_clear_cores()
	main.big_hit(lp)
	main.float_text(lp, str(int(dmg)), Toon.VERMILION)
	_damage(dmg)
	if dead:
		return
	# le colosse chancelle : carapace ouverte, attaques annulées
	_cancel_all()
	_open = OPEN_TIME
	_state = "open"
	main.shake = maxf(float(main.shake), 0.6)


# ------------------------------------------------------------------ zones annoncées

func _fan_mesh(half_angle: float, length: float, steps := 10) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in steps:
		var a0 := -half_angle + 2.0 * half_angle * float(i) / float(steps)
		var a1 := -half_angle + 2.0 * half_angle * float(i + 1) / float(steps)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(sin(a0), 0, cos(a0)) * length)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(sin(a1), 0, cos(a1)) * length)
	return st.commit()


func _make_zone(k: String, c: Vector3, r: float, total: float, dir := Vector3.ZERO) -> Dictionary:
	var node := Node3D.new()
	node.top_level = true
	add_child(node)
	node.global_position = Vector3(c.x, 0, c.z)
	var base: MeshInstance3D
	var fill: MeshInstance3D
	var rock: Node3D = null
	if k == "fist":
		var sq := Toon.box(Vector3(3.0, 0.004, 3.0))
		base = Toon.part(node, sq, Toon.flat(Color(Toon.VERMILION, 0.18)), Vector3(0, 0.03, 0))
		fill = Toon.part(node, sq, Toon.flat(Color(Toon.VERMILION, 0.45)), Vector3(0, 0.035, 0))
	elif k == "breath":
		node.rotation.y = atan2(dir.x, dir.z)
		var fan := _fan_mesh(deg_to_rad(22.5), r)
		base = Toon.part(node, fan, Toon.flat(Color(Toon.VERMILION, 0.18)), Vector3(0, 0.03, 0))
		fill = Toon.part(node, fan, Toon.flat(Color(Toon.VERMILION, 0.45)), Vector3(0, 0.035, 0))
	else:
		base = Toon.disc(node, r, Color(Toon.VERMILION, 0.18), 0.03)
		fill = Toon.disc(node, r, Color(Toon.VERMILION, 0.45), 0.035)
		# le bloc de cendre qui tombe du ciel
		rock = Toon.part(node, _rock(0.32, 5), _rock_mat, Vector3(0, 9.0, 0))
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.scale = Vector3(0.01, 1, 0.01)
	var z := {"kind": k, "node": node, "fill": fill, "c": Vector3(c.x, 0, c.z), "r": r, "t": total, "total": total, "dir": dir, "rock": rock, "done": false}
	_zones.append(z)
	return z


func _update_zones(delta: float) -> void:
	for i in range(_zones.size() - 1, -1, -1):
		var z: Dictionary = _zones[i]
		var t: float = float(z["t"]) - delta
		z["t"] = t
		var total: float = z["total"]
		var k := clampf(1.0 - t / total, 0.01, 1.0)
		var fill: MeshInstance3D = z["fill"]
		fill.scale = Vector3(k, 1, k)
		var fm := fill.material_override as StandardMaterial3D
		fm.albedo_color = Color(Toon.FOAM, 0.85) if t < 0.15 else Color(Toon.VERMILION, 0.45)
		var rock: Node3D = z["rock"]
		if rock != null:
			rock.position.y = lerpf(9.0, 0.35, k * k)
			rock.rotation.x += delta * 4.0
		if t <= 0.0:
			_zones.remove_at(i)
			_resolve(z)


func _resolve(z: Dictionary) -> void:
	var node: Node3D = z["node"]
	var c: Vector3 = z["c"]
	z["done"] = true
	match String(z["kind"]):
		"fist":
			main.enemy_strike(c, 1.75)
			main.shake = maxf(float(main.shake), 0.5)
			main.splash(c + Vector3(0, 0.3, 0), ASH, 16)
			main.splash(c + Vector3(0, 0.3, 0), LAVA, 8)
			_scorch(c, 1.5)
		"ash":
			main.enemy_strike(c, 0.8)
			main.splash(c + Vector3(0, 0.2, 0), ASH, 6)
		"breath":
			var dir: Vector3 = z["dir"]
			if _in_cone(hero.position, c, dir, float(z["r"])):
				main.enemy_strike(hero.position, 0.6)
			for j in 6:
				var p := c + dir * (1.2 + 1.3 * float(j)) + Vector3(0, 0.5, 0)
				main.splash(p, EMBER, 5)
				main.splash(p, LAVA, 3)
			main.shake = maxf(float(main.shake), 0.35)
			_flame(c, dir, float(z["r"]))
	node.queue_free()


func _in_cone(p: Vector3, apex: Vector3, dir: Vector3, length: float) -> bool:
	var v := p - apex
	v.y = 0
	var l := v.length()
	if l < 0.01:
		return true
	if l > length:
		return false
	return (v / l).dot(dir) > cos(deg_to_rad(22.5))


## Tache de roussi après le poing (décor, s'efface).
func _scorch(c: Vector3, r: float) -> void:
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	n.global_position = c
	var d := Toon.disc(n, r, Color(0.08, 0.07, 0.07, 0.55), 0.02)
	var m := d.material_override as StandardMaterial3D
	for i in 4:
		var a := randf() * TAU
		var cr := Toon.part(n, Toon.box(Vector3(0.07, 0.01, randf_range(0.6, 1.2))), _crack_mat, Vector3(sin(a) * 0.6, 0.025, cos(a) * 0.6))
		cr.rotation.y = a
	var tw := n.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.0)
	tw.tween_callback(n.queue_free)


## Langue de feu du souffle (décor, s'efface).
func _flame(apex: Vector3, dir: Vector3, length: float) -> void:
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	n.global_position = Vector3(apex.x, 0, apex.z)
	n.rotation.y = atan2(dir.x, dir.z)
	var f := Toon.part(n, _fan_mesh(deg_to_rad(22.5), length), Toon.flat(Color(EMBER, 0.7)), Vector3(0, 0.05, 0))
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := f.material_override as StandardMaterial3D
	var tw := n.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(n.queue_free)


func _cancel_all() -> void:
	for z in _zones:
		var node: Node3D = z["node"]
		if is_instance_valid(node):
			node.queue_free()
		z["done"] = true
	_zones.clear()
	_volley_t = -1.0
	if not _fist.is_empty() and String(_fist["phase"]) != "back":
		var h: Node3D = _hands[int(_fist["side"])]
		_fist["phase"] = "back"
		_fist["from"] = h.position
		_fist["t"] = 0.6


# ------------------------------------------------------------------ attaques

func _choose_attack() -> void:
	var opts: Array = ["ash", "volley"]
	if hero.position.z < 2.0:
		opts.append("fist")
		opts.append("fist")
	if _breath_ok:
		opts.append("breath")
		opts.append("breath")
	var pick: String = opts[randi() % opts.size()]
	match pick:
		"fist":
			_start_fist()
		"ash":
			_start_ash()
		"volley":
			_volley_t = 0.9
		"breath":
			_start_breath()
	_atk_cd = 2.8 - 0.4 * float(_phase)


func _start_fist() -> void:
	var side := 0 if hero.position.x < position.x else 1
	if _core_side >= 0:
		side = 1 - _core_side  # la main qui porte un noyau reste posée
	var c := Vector3(clampf(hero.position.x, -HALF.x + 1.5, HALF.x - 1.5), 0, clampf(hero.position.z, position.z + 3.0, 1.5))
	var z := _make_zone("fist", c, 1.75, 1.3)
	_fist = {"side": side, "zone": z, "c": c, "phase": "tele", "t": 0.0, "from": Vector3.ZERO}


func _start_ash() -> void:
	var n := 6 + randi() % 3
	var pts: Array = [Vector3(clampf(hero.position.x, -HALF.x + 0.6, HALF.x - 0.6), 0, clampf(hero.position.z, -HALF.y + 0.6, HALF.y - 0.6))]
	for attempt in 60:
		if pts.size() >= n:
			break
		var p := Vector3(randf_range(-HALF.x + 0.6, HALF.x - 0.6), 0, randf_range(position.z + 2.6, HALF.y - 0.6))
		var ok := true
		for q in pts:
			if p.distance_to(q) < 1.8:
				ok = false
				break
		if ok:
			pts.append(p)
	# chutes décalées : la pluie tombe en cascade
	for i in pts.size():
		_make_zone("ash", pts[i], 0.8, 1.05 + 0.07 * float(i))


func _start_breath() -> void:
	var apex := position + Vector3(0, 0, 2.3)
	var to := hero.position - apex
	var ang := clampf(atan2(to.x, to.z), -1.0, 1.0)
	_make_zone("breath", apex, 8.0, 1.0, Vector3(sin(ang), 0, cos(ang)))


func _fire_volley() -> void:
	var src := position + Vector3(0, 1.2, 2.7)
	var to := hero.position - src
	to.y = 0
	var d := Vector3(0, 0, 1) if to.length_squared() < 0.01 else to.normalized()
	var n := 3 + 2 * _phase  # 5, 7, 9 boules
	var step := deg_to_rad(60.0) / float(n - 1)
	for i in n:
		var a := -deg_to_rad(30.0) + step * float(i)
		var dd := d.rotated(Vector3.UP, a)
		main.spawn_bullet(src + dd * 0.4, dd)


func _update_fist(delta: float) -> void:
	if _fist.is_empty():
		return
	var side: int = _fist["side"]
	var h: Node3D = _hands[side]
	var rest: Vector3 = HAND_REST[side]
	var c: Vector3 = _fist["c"]
	var cl := c - position - rig.position
	cl.y = 0
	var above := cl + Vector3(0, 3.4, 0)
	var down := cl + Vector3(0, 0.55, 0)
	var z: Dictionary = _fist["zone"]
	match String(_fist["phase"]):
		"tele":
			# le poing se lève au-dessus de la zone puis s'abat
			var t: float = z["t"]
			var total: float = z["total"]
			if z["done"]:
				h.position = down
				_fist["phase"] = "hold"
				_fist["t"] = 0.8
			elif t > 0.12:
				h.position = rest.lerp(above, smoothstep(0.0, 0.7, 1.0 - t / total))
			else:
				h.position = above.lerp(down, clampf(1.0 - t / 0.12, 0.0, 1.0))
		"hold":
			_fist["t"] = float(_fist["t"]) - delta
			if float(_fist["t"]) <= 0.0:
				_fist["phase"] = "back"
				_fist["from"] = h.position
				_fist["t"] = 0.6
		"back":
			_fist["t"] = float(_fist["t"]) - delta
			var start_p: Vector3 = _fist["from"]
			var k := 1.0 - clampf(float(_fist["t"]) / 0.6, 0.0, 1.0)
			h.position = start_p.lerp(rest, smoothstep(0.0, 1.0, k))
			if float(_fist["t"]) <= 0.0:
				h.position = rest
				_fist = {}


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_t += delta
	if _cores_lock > 0.0:
		_cores_lock -= delta
	if _flash > 0.0:
		_flash -= delta
		_rock_mat.albedo_color = ROCK_FLASH if _flash > 0.0 else BASALT
	_update_zones(delta)
	_update_fist(delta)
	_animate_cores(delta)
	match _state:
		"spawn":
			_timer -= delta
			var k := clampf(1.0 - _timer / 2.4, 0.0, 1.0)
			rig.position.y = lerpf(-6.5, 0.0, 1.0 - pow(1.0 - k, 3.0))
			main.shake = maxf(float(main.shake), 0.15)
			if fmod(_t, 0.3) < delta:
				main.splash(position + Vector3(randf_range(-2.5, 2.5), 0.3, randf_range(0.5, 2.5)), LAVA, 6)
			if _timer <= 0.0:
				rig.position.y = 0.0
				_state = "fight"
				_atk_cd = 1.6
				_new_layout()
		"fight":
			if _volley_t >= 0.0:
				_volley_t -= delta
				if _volley_t < 0.0:
					_volley_t = -1.0
					_fire_volley()
			elif _zones.is_empty() and _fist.is_empty():
				_atk_cd -= delta
				if _atk_cd <= 0.0:
					_choose_attack()
		"open":
			# carapace ouverte : la lave suinte, les coups normaux portent
			_open -= delta
			if fmod(_t, 0.25) < delta:
				main.splash(position + Vector3(randf_range(-1.5, 1.5), randf_range(1.5, 3.5), 1.4), LAVA, 4)
			if _open <= 0.0:
				_open = 0.0
				if _phase < 3:
					_phase += 1
					main.spawn_minions(["oni", "oni"] if _phase == 2 else ["brute", "oni", "oni"])
				else:
					main.spawn_minions(["oni", "oni"])
				_state = "fight"
				_atk_cd = 1.4
				_new_layout()
		"dying":
			_timer += delta
			rig.position.x = sin(_t * 40.0) * 0.08 * clampf(1.0 - _timer / 3.0, 0.0, 1.0)
			if _timer > 0.6:
				rig.position.y -= delta * (1.0 + _timer) * 1.2
			if fmod(_t, 0.2) < delta:
				main.splash(position + Vector3(randf_range(-2.0, 2.0), maxf(0.3, 3.0 + rig.position.y), 1.5), LAVA, 6)
			if _timer > 3.4:
				queue_free()
	_animate_body(delta)
	_update_arms()


func _animate_body(delta: float) -> void:
	# respiration, regard vers le héros (ou vers son souffle), lueurs
	_torso.position.y = sin(_t * 1.3) * 0.06
	var slump := 0.22 if _state == "open" else (0.35 if _state == "dying" else 0.0)
	_torso.rotation.x = lerpf(_torso.rotation.x, slump, minf(1.0, delta * 4.0))
	var charge := 0.0
	var look := hero.position - (position + Vector3(0, 0, 0.35))
	if _volley_t >= 0.0:
		charge = 1.0 - _volley_t / 0.9
	for z in _zones:
		if z["kind"] == "breath":
			var total: float = z["total"]
			charge = clampf(1.0 - float(z["t"]) / total, 0.0, 1.0)
			look = z["dir"]
	var yaw := clampf(atan2(look.x, look.z), -0.7, 0.7)
	_head.rotation.y = lerp_angle(_head.rotation.y, yaw, minf(1.0, delta * 3.0))
	_head.rotation.x = -0.25 * charge  # il relève la tête pour cracher
	var glow := 0.6 + 0.25 * sin(_t * 3.0)
	if _open > 0.0 or _state == "dying":
		glow = 2.2 + 0.6 * sin(_t * 10.0)
	_crack_mat.emission_energy_multiplier = glow + 1.5 * charge
	_eye_mat.emission_energy_multiplier = 1.2 + 2.5 * charge


# ------------------------------------------------------------------ robot testeur

## Trait qu'un bon joueur tracerait maintenant (points au sol depuis le héros), ou vide = attendre.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	if dead:
		return none
	var pool := Vector3(position.x, 0, position.z)
	if _state == "open":
		# carapace ouverte : trait droit (iaï) devant le bassin, d'une main à l'autre
		var body := pool + Vector3(0, 0, 0.6)
		var sx := -1.0 if h.x > body.x else 1.0
		var near_end := body + Vector3(-sx * 3.8, 0, 1.9)
		var far_end := body + Vector3(sx * 3.8, 0, 1.9)
		if h.distance_to(near_end) < 0.8:
			return _bot_dense([h, far_end])
		return _bot_dense([h, body + Vector3(0, 0, 2.0), far_end])
	if _state != "fight" or _cores.size() < 2 or _cores_lock > 0.0:
		return none
	var pts: Array = []
	for c in _cores:
		var cd: Dictionary = c
		var p: Vector3 = cd["p"]
		pts.append(Vector3(p.x, 0, p.z))
	var first: Vector3 = pts[0]
	var second: Vector3 = pts[1]
	if h.distance_to(first) > 2.6:
		# placement juste avant le premier noyau, sans en toucher aucun
		var entry := _bot_off_pool(_bot_clamp(first - (second - first).normalized() * 1.1))
		return _bot_route([h, entry], pts, 1.0)
	# un seul trait qui relie les noyaux dans l'ordre, en évitant ceux qui viennent après
	var way: Array = [h]
	for i in pts.size():
		var a: Vector3 = way[way.size() - 1]
		var b: Vector3 = pts[i]
		_bot_leg(way, a, b, pts.slice(i + 1), 1.0, 3)
	var last: Vector3 = pts[pts.size() - 1]
	var prev: Vector3 = pts[pts.size() - 2]
	way.append(_bot_off_pool(_bot_clamp(last + (last - prev).normalized() * 0.9)))
	return _bot_dense(way)


## Repousse un point d'arrivée hors du bassin de lave (contact = dégâts).
func _bot_off_pool(p: Vector3) -> Vector3:
	var c := Vector3(position.x, 0, position.z)
	var v := p - c
	v.y = 0
	if v.length() >= POOL_R + 0.4:
		return p
	if v.length_squared() < 0.01:
		v = Vector3(0, 0, 1)
	return _bot_clamp(c + v.normalized() * (POOL_R + 0.5))


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
