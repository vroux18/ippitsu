extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 5 (Trente-six Vues) — Bakekujira, la baleine squelette (24 PV × monde).
##  Elle nage sous la mer d'encre. Cycle : jet d'encre sous le héros (zone r1.4, 1.1 s), puis
##  ruée le long d'un couloir (bande annoncée 1.3 s, 6.5 m/s) ; son dos d'os est son bouclier (10) :
##  un coup ne fait qu'effleurer. Mécanique de trait : KAESHI. Un aller-retour (on va à ≥ 2 m et on
##  revient près du départ) tracé dans le couloir DEVANT sa tête la renvoie et brise tout le bouclier :
##  échouée sur le flanc 5.5 s, vulnérable sur toute sa longueur (dégâts ×2).
##  Prépare la phase 2 de Kuro-Nami (vagues renvoyées).
## Apparence (direction « Masque d'encre », famille du monde 5 : sumi pur, papier, indigo nuit, sceau) :
##  baleine d'encre vivante dont les côtes sont des traits de washi peints sur les flancs, crâne = masque
##  de nō allongé posé sur la tête (cerné d'or, sceau du peintre au front, gueule vermillon), obi d'indigo
##  à écailles de papier derrière la tête, nageoires et queue d'encre à pointes d'or, gouttes qui pendent
##  sous le ventre et s'étirent (pluie d'encre). Un maillage fusionné (Mesher) par pièce mobile.

const Yokai = preload("res://scripts/yokai_parts.gd")

const INK := Color("#0E1A2E")  # nappe d'encre (mer)
const INK5 := Color("#17151C")  # sumi pur du monde 5 (corps)
const PAPER_L := Color("#EAE2CF")  # washi du masque et des côtes
const PAPER := Color("#CFC6B2")  # écailles de papier de l'obi
const NIGHT := Color("#1B2A44")  # indigo nuit (obi)
const SEAL := Color("#9E3028")  # sceau du peintre
const VOID := Color("#07060A")  # creux des yeux
const FOAM := Color("#E9EEF0")
const BODY_LEN := 5.4  # de la tête à la queue
const BODY_W := 0.85  # demi-largeur (coups, contact)
const LANE_HALF := 1.3
const LANE_TELE := 1.3
const RUSH_SPEED := 6.5
const SPOUT_R := 1.4
const SPOUT_TELE := 1.1
const SHIELD := 10.0
const AHEAD_MIN := -1.0  # fenêtre « devant la tête » où l'aller-retour compte
const AHEAD_MAX := 6.5
const MAX_PTS := 400
const DEEP := -2.6

var rig: Node3D  # la baleine (roulis, profondeur)
var _pool: MeshInstance3D
var _mat: StandardMaterial3D  # toon à couleurs de sommets (flash des coups)
var _fins: Array = []  # pivots des nageoires
var _fluke: Node3D  # pivot de la queue
var _drips: MeshInstance3D  # gouttes sous le ventre (s'étirent)
var _pts: Array = []  # Vector3 de la ruée depuis le dernier end_stroke
var _dir := Vector3(0, 0, 1)
var _lane_x := 0.0
var _strand_at := Vector3.ZERO
var _wake := 0.0


func _ready() -> void:
	title = "Bakekujira"
	hp = 24.0 * max_hp_mult
	max_hp = hp
	radius = BODY_W
	_build()
	_shield_init(SHIELD, Vector3(1.4, 1.1, 3.3), 0.4)
	position = Vector3(0, 0, -2.5)
	_set_heading(Vector3(0, 0, 1))
	_state = "spawn"
	_timer = 1.4


# ------------------------------------------------------------------ construction

func _build() -> void:
	body = Node3D.new()
	add_child(body)
	# nappe d'encre autour d'elle (sous l'eau : seule trace visible)
	_pool = Toon.disc(body, 1.0, Color(INK, 0.55), 0.015)
	_pool.scale = Vector3(1.5, 1.0, 3.1)
	rig = Node3D.new()
	body.add_child(rig)
	_mat = _ink_mat()
	var lite := Toon.lite
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	# corps d'encre : tête et tronc d'un bloc (la tête regarde vers -Z), fuseau qui s'effile vers la queue
	a.ball(Vector3(0, 0.55, -1.3), Vector3(0.86, 0.74, 1.65), INK5, Vector3.ZERO, 10)
	a.cyl(Vector3(0, 0.5, 1.05), Vector3(0.74, 2.9, 0.62), INK5, Vector3(PI / 2.0, 0, 0), 0.22, 10)
	a.ball(Vector3(0, 0.78, -0.3), Vector3(0.6, 0.42, 0.9), INK5, Vector3.ZERO, 8)  # bosse du dos
	# côtes : traits de washi peints, trois segments par côté qui partent de l'échine et descendent le flanc
	var ribs := 4 if lite else 6
	for k in ribs:
		var z := -0.95 + 0.48 * float(k)
		var sh := 1.0 - 0.09 * float(k)
		for sx in [-1.0, 1.0]:
			var s := float(sx)
			var w := 0.075 - 0.005 * float(k)
			var p := Vector3(0, 1.17 * sh + 0.08, z)
			for seg in [[1.25, 0.34], [2.15, 0.42], [2.75, 0.36]]:
				var ang := float(seg[0])
				var ln := float(seg[1]) * sh
				p = a.spike(p, w, ln, PAPER_L, Vector3(0, 0, -s * ang), 1.0, 4, 0.6)
	# échine : long trait de washi sur le dos
	a.box(Vector3(0, 1.1, 0.3), Vector3(0.06, 0.03, 2.6), PAPER_L, Vector3(0.08, 0, 0))
	# obi d'indigo nuit derrière la tête : liserés d'or, écailles de papier (grand motif)
	var zo := -0.55
	a.cyl(Vector3(0, 0.56, zo), Vector3(0.9, 0.42, 0.8), NIGHT, Vector3(PI / 2.0, 0, 0), 1.0, 12)
	for dz in [-0.2, 0.2]:
		a.cyl(Vector3(0, 0.56, zo + float(dz)), Vector3(0.92, 0.05, 0.82), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 1.0, 12)
	var n := 8 if lite else 12
	for i in n:
		var ang := TAU * (float(i) + 0.5) / float(n)
		if cos(ang) < -0.2:
			continue  # pas sous le ventre
		a.ball(Vector3(sin(ang) * 0.9, 0.56 + cos(ang) * 0.8, zo), Vector3(0.16, 0.09, 0.04), PAPER, Vector3(0, 0, -ang), 6)
	# crâne : masque de nō allongé posé sur le haut de la tête, relevé vers la caméra, cerné d'or
	var mz := -2.35
	var mr := Vector3(0.32, 0, 0)
	a.ball(Vector3(0, 0.95, mz), Vector3(0.8, 0.2, 1.2), Toon.GOLD, mr, 10)
	a.ball(Vector3(0, 1.0, mz), Vector3(0.72, 0.2, 1.1), PAPER_L, mr, 10)
	# yeux : creux d'encre, iris d'or (aplat), pupille sumi ; sourcils froncés
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		a.ball(Vector3(s * 0.33, 1.15, mz - 0.1), Vector3(0.2, 0.06, 0.26), VOID, mr, 8)
		f.ball(Vector3(s * 0.33, 1.19, mz - 0.1), Vector3(0.12, 0.05, 0.15), Yokai.EYE_GOLD, mr, 8)
		f.ball(Vector3(s * 0.33, 1.23, mz - 0.12), Vector3(0.05, 0.03, 0.07), Toon.SUMI, mr, 6)
		a.box(Vector3(s * 0.36, 1.22, mz - 0.46), Vector3(0.42, 0.06, 0.11), Toon.SUMI, Vector3(0.32, -s * 0.5, 0))
		if not lite:
			# larmes d'encre peintes sous les yeux
			a.box(Vector3(s * 0.4, 1.12, mz + 0.3), Vector3(0.04, 0.03, 0.4), Toon.SUMI, mr)
	# sceau du peintre au front, évent cerclé d'or sur la nuque
	a.box(Vector3(0, 1.1, mz + 0.65), Vector3(0.16, 0.04, 0.16), SEAL, mr)
	a.cyl(Vector3(0, 1.22, -1.35), Vector3(0.15, 0.06, 0.15), Toon.GOLD, Vector3.ZERO, 1.0, 10)
	# gueule : lèvre de washi, intérieur vermillon (la ruée blesse), fanons de papier
	a.box(Vector3(0, 0.7, -3.35), Vector3(1.2, 0.06, 0.08), PAPER_L, Vector3(0.32, 0, 0))
	a.box(Vector3(0, 0.55, -3.3), Vector3(1.1, 0.16, 0.12), Toon.VERMILION, Vector3(0.32, 0, 0))
	if not lite:
		for k in 5:
			a.spike(Vector3(-0.44 + 0.22 * float(k), 0.52, -3.38), 0.04, 0.16, FOAM, Vector3(PI + 0.3, 0, 0), 0.0, 4)
	_ink_part(rig, a, f, _mat)
	# nageoires d'encre (pivots : elles rament) : lame ink, trait washi, pointe d'or
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		var pv := Node3D.new()
		rig.add_child(pv)
		pv.position = Vector3(s * 0.7, 0.3, -1.1)
		pv.rotation.y = s * 0.45
		var m := Yokai.Mesher.new(1.0)
		m.ball(Vector3(s * 0.5, 0, 0), Vector3(0.62, 0.07, 0.26), INK5, Vector3.ZERO, 8)
		m.box(Vector3(s * 0.45, 0.05, 0), Vector3(0.7, 0.025, 0.05), PAPER_L)
		m.spike(Vector3(s * 0.95, 0, 0), 0.1, 0.4, Toon.GOLD, Vector3(0, 0, -s * PI / 2.0), 0.0, 4, 0.5)
		_ink_part(pv, m, Yokai.Mesher.new(1.0), _mat)
		_fins.append(pv)
	# queue (pivot : elle bat) : deux lobes d'encre, traits washi, pointes d'or
	_fluke = Node3D.new()
	rig.add_child(_fluke)
	_fluke.position = Vector3(0, 0.4, 2.45)
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3(0, 0, 0.1), Vector3(0.22, 0.14, 0.3), INK5, Vector3.ZERO, 6)
	for sx in [-1.0, 1.0]:
		var s := float(sx)
		t.ball(Vector3(s * 0.52, 0, 0.35), Vector3(0.6, 0.07, 0.3), INK5, Vector3(0, -s * 0.5, 0), 8)
		t.box(Vector3(s * 0.5, 0.05, 0.3), Vector3(0.7, 0.025, 0.05), PAPER_L, Vector3(0, -s * 0.5, 0))
		t.spike(Vector3(s * 0.95, 0, 0.6), 0.1, 0.4, Toon.GOLD, Vector3(0, 0, -s * PI / 2.0 + s * 0.5), 0.0, 4, 0.5)
	_ink_part(_fluke, t, Yokai.Mesher.new(1.0), _mat)
	# gouttes d'encre sous le ventre et les flancs (elles s'étirent : pluie d'encre)
	var d := Yokai.Mesher.new(1.0)
	var drops := [Vector3(0.55, 0.1, -2.0), Vector3(-0.6, 0.12, -1.4), Vector3(0.62, 0.1, -0.6), Vector3(-0.5, 0.15, 0.4),
		Vector3(0.35, 0.1, 1.3), Vector3(0.0, -0.1, -1.0)]
	if not lite:
		drops.append_array([Vector3(-0.7, 0.2, -2.4), Vector3(0.2, -0.05, 0.2), Vector3(-0.3, 0.05, 1.9)])
	for p in drops:
		d.ball(p, Vector3(0.11, 0.1, 0.11), INK5, Vector3.ZERO, 6)
		var tip := d.spike(p, 0.09, 0.42, INK5, Vector3(PI, 0, 0), 0.25, 5)
		d.ball(tip, Vector3(0.06, 0.07, 0.06), INK5, Vector3.ZERO, 6)
	_drips = _ink_part(rig, d, Yokai.Mesher.new(1.0), _mat)
	_make_stars(body, 2.0)
	rig.position.y = DEEP


## Matériau toon à couleurs de sommets, contour d'encre, émission pour le flash des coups.
static func _ink_mat() -> StandardMaterial3D:
	var m := Toon.mat(Color.WHITE, true, 0.03)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.rim = 0.35
	m.rim_tint = 0.5
	m.emission_enabled = true
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.0
	return m


## Pièce d'encre à deux surfaces (toon, puis aplat lumineux des yeux) posée sur `parent`.
static func _ink_part(parent: Node3D, a: Yokai.Mesher, f: Yokai.Mesher, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Yokai.two(a, f)
	mi.set_surface_override_material(0, mat)
	if mi.mesh.get_surface_count() > 1:
		mi.set_surface_override_material(1, Yokai.ink_flat_mat())
	parent.add_child(mi)
	return mi


func _set_heading(d: Vector3) -> void:
	_dir = Vector3(d.x, 0, d.z).normalized()
	body.rotation.y = atan2(-_dir.x, -_dir.z)


func _head() -> Vector3:
	return Vector3(position.x, 0, position.z) + _dir * (BODY_LEN * 0.5)


func _tail() -> Vector3:
	return Vector3(position.x, 0, position.z) - _dir * (BODY_LEN * 0.5)


## Distance entre la ruée a..b et l'axe du corps.
func _axis_dist(a: Vector3, b: Vector3) -> float:
	var t := _tail()
	var h := _head()
	var cp := Geometry2D.get_closest_points_between_segments(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(t.x, t.z), Vector2(h.x, h.z))
	return cp[0].distance_to(cp[1])


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if hero.dashing:
		if _pts.is_empty():
			_pts.append(Vector3(a.x, 0, a.z))
		if _pts.size() < MAX_PTS:
			_pts.append(Vector3(b.x, 0, b.z))
	# échouée : coup plein (×2) sur toute sa longueur ; en ruée : le dos d'os effleuré use le bouclier
	if (_state == "stranded" or _state == "rush") and _last_stroke != stroke_id and _axis_dist(a, b) < BODY_W + 0.5:
		_last_stroke = stroke_id
		return true
	return false


## Fin du trait : un aller-retour devant sa tête la renvoie (Kaeshi).
func end_stroke(_stroke_id: int) -> void:
	if dead:
		_pts.clear()
		return
	if not _pts.is_empty():
		_pts.append(Vector3(hero.position.x, 0, hero.position.z))
	if _state == "rush" and vulnerable_t <= 0.0 and _pts.size() >= 3:
		_check_kaeshi()
	_pts.clear()


func touching_hero(p: Vector3) -> bool:
	if dead or _state != "rush":
		return false
	var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(_tail().x, _tail().z), Vector2(_head().x, _head().z))
	return q.distance_to(Vector2(p.x, p.z)) < BODY_W + 0.3


func _extra_danger(p: Vector3, _eta: float) -> bool:
	if _state != "rush":
		return false
	# dans le couloir, pas encore dépassé par la queue
	var t := _tail()
	return absf(p.x - _lane_x) < LANE_HALF + DANGER_MARGIN and (p.z - t.z) * _dir.z > -DANGER_MARGIN


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state != "stranded" and _state != "rush":
		return Vector3.INF
	var c2 := Vector2(center.x, center.z)
	var q := Geometry2D.get_closest_point_to_segment(c2, Vector2(_tail().x, _tail().z), Vector2(_head().x, _head().z))
	if q.distance_to(c2) >= reach + BODY_W:
		return Vector3.INF
	return Vector3(q.x, 0.7, q.y)


func _zone_fire(z: Dictionary) -> void:
	var tag := String(z["tag"])
	if tag == "spout":
		# jet d'encre du évent
		var c: Vector3 = z["c"]
		main.enemy_strike(c, SPOUT_R)
		main.splash(c + Vector3(0, 0.6, 0), INK, 18)
		if hp <= max_hp * 0.5:
			for k in 4:
				var a := TAU * (float(k) + 0.5) / 4.0
				var d := Vector3(cos(a), 0, sin(a))
				main.spawn_bullet(c + Vector3(0, 0.6, 0) + d * 0.5, d)
		_start_lane()
	elif tag == "lane":
		_state = "rush"
		rig.visible = true
		rig.rotation.z = 0.0
		rig.position.y = -0.35
		main.splash(_head() + Vector3(0, 0.4, 0), FOAM, 12)


func _on_die() -> void:
	_pts.clear()


## Bouclier d'os brisé (renvoyée, ou dos usé en pleine ruée) : échouée sur le flanc dans l'arène.
func _on_shield_break() -> void:
	_clear_zones()
	_state = "stranded"
	rig.visible = true
	var lim := HALF.y - BODY_LEN * 0.5 + 0.4
	_strand_at = Vector3(clampf(position.x, -HALF.x + 1.0, HALF.x - 1.0), 0, clampf(position.z, -lim, lim))


func _on_shield_back() -> void:
	if _state != "stranded":
		return
	_state = "dive"
	_timer = 0.8


func _sh_yaw() -> float:
	return body.rotation.y


func _sh_hidden() -> bool:
	return not rig.visible or rig.position.y < -1.0


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	match _state:
		"spawn":
			# elle crève la surface une fois, puis replonge
			_timer -= delta
			var k := clampf(1.0 - _timer / 1.4, 0.0, 1.0)
			rig.position.y = lerpf(DEEP, 0.0, sin(PI * k))
			if _timer <= 0.0:
				_go_under(0.9)
		"under":
			_timer -= delta
			if _timer <= 0.0:
				_zone_disc(Vector3(hero.position.x, 0, hero.position.z), SPOUT_R, SPOUT_TELE, "spout")
				_state = "spout"
				_timer = SPOUT_TELE
		"spout":
			_timer -= delta
		"lane":
			_timer -= delta
		"rush":
			position += _dir * RUSH_SPEED * delta
			_wake -= delta
			if _wake <= 0.0:
				_wake = 0.12
				var hp_ := _head()
				if absf(hp_.z) < HALF.y:
					main.splash(hp_ + Vector3(0, 0.2, 0), FOAM, 3)
			if position.z * _dir.z > HALF.y + BODY_LEN * 0.5 + 1.5:
				_go_under(0.6)
		"stranded":
			position = position.lerp(_strand_at, minf(1.0, delta * 8.0))
			rig.rotation.z = lerpf(rig.rotation.z, 1.25, minf(1.0, delta * 8.0))
			rig.position.y = lerpf(rig.position.y, 0.3, minf(1.0, delta * 8.0))
			# la fin de la fenêtre (vulnerable_t) la fait replonger (_on_shield_back)
		"dive":
			_timer -= delta
			var kd := clampf(1.0 - _timer / 0.8, 0.0, 1.0)
			rig.position.y = lerpf(0.3, DEEP, kd)
			rig.rotation.z = lerpf(1.25, 0.0, kd)
			if _timer <= 0.0:
				_go_under(0.7)
		"dying":
			_timer += delta
			rig.rotation.z = lerpf(rig.rotation.z, 1.6, minf(1.0, delta * 3.0))
			if _timer > 1.0:
				rig.position.y -= delta * 1.6
			if int(_timer * 6.0) != int((_timer - delta) * 6.0) and _timer < 2.0:
				main.splash(position + Vector3(0, 0.5, 0), INK, 5)
			if _timer > 2.4:
				queue_free()
	_animate(delta)


func _go_under(t: float) -> void:
	_state = "under"
	_timer = t
	rig.visible = false
	rig.position.y = DEEP
	rig.rotation.z = 0.0
	# elle refait surface plus tard ailleurs : on la ramène au milieu (sa nappe d'encre se voit)
	var p := Vector3(clampf(position.x, -2.5, 2.5), 0, clampf(position.z, -5.0, 5.0))
	position = p


## Couloir de ruée : sur la colonne du héros, depuis le bord le plus éloigné de lui.
func _start_lane() -> void:
	_lane_x = clampf(hero.position.x, -HALF.x + LANE_HALF, HALF.x - LANE_HALF)
	var dz := 1.0 if hero.position.z >= 0.0 else -1.0
	_set_heading(Vector3(0, 0, dz))
	position = Vector3(_lane_x, 0, -dz * (HALF.y + 1.0 + BODY_LEN * 0.5))
	_zone_rect(Vector3(_lane_x, 0, 0), _dir, LANE_HALF, HALF.y, LANE_TELE, "lane", Vector2(0, -1))
	_state = "lane"
	_timer = LANE_TELE


func _check_kaeshi() -> void:
	var start: Vector3 = _pts[0]
	var last: Vector3 = _pts[_pts.size() - 1]
	var far := 0.0
	for p: Vector3 in _pts:
		far = maxf(far, Vector2(p.x - start.x, p.z - start.z).length())
	# aller-retour : on va loin puis on revient près du départ
	if far < 2.0 or Vector2(last.x - start.x, last.z - start.z).length() > maxf(1.2, far * 0.35):
		return
	var head := _head()
	for p: Vector3 in _pts:
		var ahead := (p.z - head.z) * _dir.z
		if absf(p.x - _lane_x) <= LANE_HALF + 0.4 and ahead >= AHEAD_MIN and ahead <= AHEAD_MAX:
			_kaeshi()
			return


## Renvoyée : le bouclier d'os tombe d'un coup, elle s'échoue bien dans l'arène (_on_shield_break).
func _kaeshi() -> void:
	var head := _head()
	main.float_icon(head + Vector3(0, 0.6, 0), "figures/aller_retour", Toon.VERMILION)
	main.big_hit(head + Vector3(0, 0.4, 0))
	main.splash(head + Vector3(0, 0.6, 0), FOAM, 22)
	main.shake = maxf(float(main.shake), 0.86)
	_shield_dmg(shield_max)


## Nappe d'encre (visible sous l'eau), petite houle du dos, nageoires qui rament, queue qui bat, gouttes
## qui s'étirent, flash des coups (émission).
func _animate(delta: float) -> void:
	var under := _state == "under" or _state == "spout" or _state == "lane"
	_pool.visible = _state != "dying" or _timer < 1.6
	var ps := 0.75 + 0.1 * sin(_t * 3.0) if under else 1.0
	_pool.scale = Vector3(1.5 * ps, 1.0, 3.1 * ps)
	if _state == "rush":
		rig.position.y = -0.35 + sin(_t * 5.0) * 0.08
	var fl := 1.05 if _flash > 0.0 else 1.0
	rig.scale = Vector3.ONE * fl
	_mat.emission_energy_multiplier = move_toward(_mat.emission_energy_multiplier, 0.7 if _flash > 0.0 else 0.0, delta * 8.0)
	var swim := _state == "rush" or _state == "spawn" or _state == "dive"
	var rate := 7.0 if swim else 2.0
	var amp := 0.35 if swim else 0.12
	for i in _fins.size():
		var pv: Node3D = _fins[i]
		var sx := -1.0 if i == 0 else 1.0
		pv.rotation.z = sx * (0.15 + sin(_t * rate) * amp)
	_fluke.rotation.x = sin(_t * rate + 1.2) * amp * 0.8
	_drips.scale = Vector3(1.0, 1.0 + 0.25 * (0.5 + 0.5 * sin(_t * 2.6)), 1.0)


# ------------------------------------------------------------------ robot testeur

## Ruée : aller-retour dans le couloir devant sa tête (le bouclier tombe) ;
## échouée (vulnérable) : iaï à travers, encore et encore.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	if _state == "stranded":
		if vulnerable_t < 0.3:
			return none
		return _bot_line(h, Vector3(_strand_at.x, 0, _strand_at.z), 7.3)
	if _state != "rush":
		return none
	var head := _head()
	var ahead_h := (h.z - head.z) * _dir.z
	if absf(h.x - _lane_x) <= LANE_HALF and ahead_h >= 0.5 and ahead_h <= AHEAD_MAX - 1.0:
		# déjà devant elle : aller-retour vers le centre de l'arène, retour au départ
		var sx := -signf(h.x) if absf(h.x) > 0.3 else 1.0
		var t := _bot_clamp(h + Vector3(sx * 3.0, 0, 0))
		if t.distance_to(h) < 2.3:
			t = _bot_clamp(h + _dir * 3.0)
		if t.distance_to(h) < 2.3:
			t = _bot_clamp(h - _dir * 3.0)
		return _bot_dense([h, t, h])
	var pick := Vector3.INF
	var pick_d := 1e9
	for dz in [4.0, 3.2, 4.8, 2.6]:
		for dx in [0.0, -0.9, 0.9]:
			var q := _bot_clamp(Vector3(_lane_x + float(dx), 0, head.z + _dir.z * float(dz)))
			if absf(q.x - _lane_x) > LANE_HALF or (q.z - head.z) * _dir.z < 1.5:
				continue
			var d := h.distance_to(q)
			if d >= 2.3 and d <= 7.0 and d < pick_d:
				pick_d = d
				pick = q
	if pick == Vector3.INF:
		return none
	return _bot_dense([h, pick, h])
