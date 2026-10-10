extends "res://scripts/boss_mini_base.gd"
## Boss du monde 8 (Yomi) — Izanami, la reine du pays des morts (34 PV × monde, ~3.6 m).
##  Bouclier : la corruption de Yomi (12). Un coup ne fait qu'effleurer.
##  Mécanique de trait en deux temps :
##   1. huit dieux du tonnerre (ikazuchi) flottent en couronne autour d'elle, chacun lié à son corps par
##      un fil de foudre : un trait qui croise un fil le TRANCHE (le dieu tombe, éclat de bouclier).
##      Les huit fils tranchés : elle est déliée 6 s et un ensō or s'allume autour d'elle ;
##   2. pendant ce temps, un ENSŌ (boucle fermée) tracé autour d'elle d'un AUTRE trait brise tout le
##      bouclier : effondrée 6 s, vulnérable (dégâts ×2). Le délai passé, les fils repoussent.
##  Attaques : chaque dieu encore lié appelle la foudre sous le héros (disque r1.0, 1.0 s) à tour de rôle ;
##  mains de Yomi (4 disques r0.8 autour du héros, 1.2 s) ; souffle de décomposition (cône 8 m, 1.1 s).

##  Apparence (direction « Masque d'encre ») : reine d'encre violacée modelée en primitives fusionnées
##  (Yokai.Mesher, couleurs de sommets) : long kimono d'encre qui s'évase jusqu'au sol, semé de flammes
##  d'âme lilas, obi violet à seigaiha liseré d'or ; MASQUE DE NŌ DE FEMME FENDU (moitié belle de washi pâle
##  au sourcil fin et aux lèvres prune, moitié décharnée grise à l'orbite creuse et aux dents d'os, fente sumi
##  au milieu) ; couronne d'or à pendeloques ; longue chevelure noire ; manches longues et MAINS LONGUES pâles
##  aux doigts effilés ; TRAÎNE D'ENCRE derrière elle, terminée par des flammes lilas qui s'étirent.
##  Les huit dieux du tonnerre, les fils et l'ensō (mécanique) ne changent pas.

const Yokai = preload("res://scripts/yokai_parts.gd")
const Loop = preload("res://scripts/boss_loop.gd")
const INK_IZA := Color("#241A30")  # encre violacée de la reine
const HAIR := Color("#14101A")
const CLOTH := Color("#5A3A7A")  # violet des haies (étoffe du monde 8)
const WAVE := Color("#B9A8E8")  # lilas des âmes
const SOUL_CORE := Color("#F0E8FF")
const MASK_IZA := Color("#F4EEF2")  # moitié belle : washi pâle rosé
const MASK_DEAD := Color("#C9C2C4")  # moitié décharnée : gris de cendre
const BONE := Color("#D8D2C4")
const HAND := Color("#E8E0EC")  # mains pâles de morte
const LIPS := Color("#8A2E4A")  # prune (le vermillon reste aux dangers)
const BOLT := Color("#C9B8FF")
const DEAD_GOD := Color("#4A464E")
const U := 2.1  # échelle du modelé (H_REF 1,75 m -> ~3,7 m)
const REST_R := Vector3(0.9, 0, 0.5)  # bras au repos : mains tendues en avant, paumes ouvertes
const REST_L := Vector3(0.9, 0, -0.5)
const GOD_N := 8
const GOD_R := 4.0  # rayon de la couronne des dieux
const THREAD_IN := 1.0  # le fil part à cette distance d'elle (on ne le tranche pas dans son corps)
const HINT_R := 2.2
const SHIELD := 12.0
const THREAD_CHIP := 0.4
const UNBOUND := 6.0
const BOLT_R := 1.0
const HAND_R := 0.8
const BREATH_HALF := 0.45
const BREATH_LEN := 8.0

static var _ink_mat: StandardMaterial3D = null

var _hair: Node3D
var _head: Node3D
var _arms: Array = []  # [droit, gauche] (pivots d'épaule)
var _flames: Array = []  # flammes lilas au bout de la traîne (pivots)
var _hint: Node3D
var _gods: Array = []  # {node, orb_mat, thread, angle, cut, fall}
var _pts: Array = []
var _unbound_t := 0.0
var _freed_stroke := -1  # trait qui a tranché le dernier fil (l'ensō doit venir d'un autre trait)
var _bolt_t := 2.0
var _bolt_i := 0
var _atk_cd := 2.4
var _cycle := 0


func _ready() -> void:
	title = "Izanami"
	if position.is_zero_approx():
		position = Vector3(0, 0, -3.2)
	hp = 34.0 * max_hp_mult
	max_hp = hp
	radius = 1.0
	vulnerable_len = 6.0
	_build()
	_shield_init(SHIELD, Vector3(1.5, 2.4, 1.5), 1.8)
	_state = "spawn"
	_timer = 2.2


# ------------------------------------------------------------------ construction

## Toon à contour épais (boss) aux couleurs de sommets : un seul matériau pour l'encre, le washi, l'or, l'os.
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
	mi.set_surface_override_material(0, Yokai.ink_flat_mat() if a.arrays().is_empty() else ink_mat())
	if m.get_surface_count() > 1:
		mi.set_surface_override_material(1, Yokai.ink_flat_mat())
	parent.add_child(mi)
	return mi


## Demi-ellipsoïde (côté +X, ouvert en x = 0) ajouté à `m` comme surface à part (couleurs de sommets, même toon) :
## la moitié décharnée du masque, posée juste au-dessus de la plaque pâle. Rend l'indice de la surface.
static func half_surface(m: ArrayMesh, pos: Vector3, radii: Vector3, col: Color, u: float) -> int:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.0
	sm.is_hemisphere = true
	sm.radial_segments = 10
	sm.rings = 5
	var src := sm.get_mesh_arrays()
	# l'hémisphère pointe vers +Y : tourné vers +X (son Y devient X, son X devient -Y)
	var b := Basis.from_euler(Vector3(0, 0, -PI / 2.0)) * Basis.from_scale(Vector3(radii.y, radii.x, radii.z))
	var nb := b.inverse().transposed()
	var xf := Transform3D(b.scaled(Vector3.ONE * u), pos * u)
	var vs: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	for k in vs.size():
		v.append(xf * vs[k])
		n.append((nb * ns[k]).normalized())
		c.append(col)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = src[Mesh.ARRAY_INDEX]
	var idx := m.get_surface_count()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return idx


func _build() -> void:
	var lite := Toon.lite
	Toon.disc(self, 1.3, Color(0, 0, 0, 0.22))
	body = Node3D.new()
	add_child(body)
	body.rotation.y = PI  # elle apparaît déjà tournée vers le héros (le modèle regarde vers -Z)
	# kimono d'encre : dôme de tête, épaules, buste, jupe qui s'évase jusqu'au sol, ourlet d'or
	var b := Yokai.Mesher.new(U)
	b.ball(Vector3(0, 1.17, 0), Vector3(0.36, 0.32, 0.34), HAIR, Vector3.ZERO, 10)
	for s in [-1.0, 1.0]:
		b.ball(Vector3(float(s) * 0.3, 1.0, 0), Vector3(0.14, 0.1, 0.13), INK_IZA)
	b.cyl(Vector3(0, 0.9, 0), Vector3(0.33, 0.3, 0.3), INK_IZA, Vector3.ZERO, 0.95, 12)
	b.cyl(Vector3(0, 0.4, 0), Vector3(0.6, 0.72, 0.54), INK_IZA, Vector3.ZERO, 0.52, 14)
	b.cyl(Vector3(0, 0.06, 0), Vector3(0.61, 0.035, 0.55), Toon.GOLD, Vector3.ZERO, 1.0, 14)
	# col (eri) de washi croisé sur la poitrine
	for s in [-1.0, 1.0]:
		b.box(Vector3(float(s) * 0.09, 0.98, -0.29), Vector3(0.06, 0.3, 0.025), Toon.WASHI, Vector3(0.15, 0, float(s) * 0.55))
	# obi violet à seigaiha lilas, liserés d'or
	b.cyl(Vector3(0, 0.76, 0), Vector3(0.36, 0.22, 0.33), CLOTH, Vector3.ZERO, 1.0, 12)
	b.cyl(Vector3(0, 0.875, 0), Vector3(0.375, 0.03, 0.345), Toon.GOLD, Vector3.ZERO, 1.0, 12)
	b.cyl(Vector3(0, 0.645, 0), Vector3(0.385, 0.03, 0.355), Toon.GOLD, Vector3.ZERO, 1.0, 12)
	var n := 6 if lite else 9
	for i in n:
		var ang := TAU * float(i) / float(n)
		b.ball(Vector3(sin(ang) * 0.365, 0.78, cos(ang) * 0.335), Vector3(0.075, 0.042, 0.018), WAVE, Vector3(0, ang, 0), 6)
	# flammes d'âme lilas semées sur la jupe (deux rangs décalés, un seul en mode léger)
	var rows := 1 if lite else 2
	for row in rows:
		var y := 0.42 - 0.2 * float(row)
		var rr := 0.43 + 0.065 * float(row)
		var nn := 8 if lite else 10
		for i in nn:
			var ang := TAU * (float(i) + 0.5 * float(row)) / float(nn)
			b.spike(Vector3(sin(ang) * rr, y, cos(ang) * rr * 0.9), 0.045, 0.14, WAVE, Vector3(0, ang, 0), 0.0, 4, 0.3)
	# traîne d'encre : nappe qui s'étale derrière elle (+Z), bord lilas
	b.ball(Vector3(0, 0.05, 0.75), Vector3(0.5, 0.06, 0.85), INK_IZA, Vector3.ZERO, 10)
	b.ball(Vector3(0, 0.04, 1.4), Vector3(0.32, 0.05, 0.55), INK_IZA, Vector3.ZERO, 8)
	if not lite:
		for s in [-1.0, 1.0]:
			b.ball(Vector3(float(s) * 0.38, 0.03, 1.1), Vector3(0.14, 0.03, 0.3), INK_IZA, Vector3(0, -float(s) * 0.3, 0), 6)
	piece(body, b)
	# flammes lilas au bout de la traîne (pivots : elles s'étirent au rythme des gouttes)
	var fpts := [Vector3(0, 0.06, 1.85), Vector3(0.24, 0.05, 1.55), Vector3(-0.26, 0.05, 1.5)]
	if lite:
		fpts = [Vector3(0, 0.06, 1.85), Vector3(0.24, 0.05, 1.5)]
	for p: Vector3 in fpts:
		var piv := Node3D.new()
		body.add_child(piv)
		piv.position = p * U
		var t := Yokai.Mesher.new(U)
		var c := Yokai.Mesher.new(U)
		t.ball(Vector3.ZERO, Vector3(0.11, 0.06, 0.11), INK_IZA, Vector3.ZERO, 6)
		t.spike(Vector3.ZERO, 0.13, 0.55, WAVE, Vector3.ZERO, 0.0, 6)
		c.spike(Vector3(0, 0.03, 0), 0.065, 0.34, SOUL_CORE, Vector3.ZERO, 0.0, 5)
		piece(piv, t, c)
		_flames.append(piv)
	# tête : masque de femme fendu, couronne d'or, chevelure
	_head = Node3D.new()
	body.add_child(_head)
	_head.position = Vector3(0, 1.22, 0) * U
	var a := Yokai.Mesher.new(U)
	var f := Yokai.Mesher.new(U)
	Yokai.mask_plate(a, MASK_IZA, 1.0, 1.0, true)
	# moitié belle (-X) : sourcil fin et haut, œil lilas mi-clos, demi-lèvres prune
	a.box(Vector3(-0.11, 0.2, Yokai.FACE_Z), Vector3(0.12, 0.02, 0.02), Toon.SUMI, Vector3(0, 0, 0.25))
	f.ball(Vector3(-0.115, 0.06, Yokai.FACE_Z), Vector3(0.05, 0.026, 0.012), WAVE, Vector3.ZERO, 8)
	f.ball(Vector3(-0.115, 0.06, Yokai.FACE_Z - 0.012), Vector3(0.018, 0.02, 0.01), Toon.SUMI, Vector3.ZERO, 6)
	a.ball(Vector3(-0.035, -0.16, Yokai.FACE_Z), Vector3(0.045, 0.022, 0.012), LIPS, Vector3.ZERO, 6)
	# moitié décharnée (+X) : orbite creuse à lueur lilas, joue creuse, mâchoire béante aux dents d'os
	a.ball(Vector3(0.12, 0.07, Yokai.FACE_Z + 0.005), Vector3(0.085, 0.1, 0.025), Toon.SUMI, Vector3.ZERO, 8)
	f.ball(Vector3(0.12, 0.06, Yokai.FACE_Z - 0.018), Vector3(0.03, 0.03, 0.01), WAVE, Vector3.ZERO, 6)
	a.box(Vector3(0.2, -0.08, Yokai.FACE_Z + 0.012), Vector3(0.07, 0.14, 0.02), Color("#A8A0A4"), Vector3(0, 0, 0.2))
	a.ball(Vector3(0.09, -0.17, Yokai.FACE_Z), Vector3(0.1, 0.07, 0.02), Toon.SUMI, Vector3.ZERO, 8)
	var teeth := 3 if lite else 5
	for i in teeth:
		var x := 0.02 + 0.15 * float(i) / float(teeth - 1)
		a.spike(Vector3(x, -0.12, Yokai.FACE_Z - 0.015), 0.013, 0.045, BONE, Vector3(PI, 0, 0), 0.0, 4)
		a.spike(Vector3(x + 0.012, -0.23, Yokai.FACE_Z - 0.015), 0.011, 0.035, BONE, Vector3.ZERO, 0.0, 4)
	# fente sumi en zigzag au milieu du visage
	for i in 6:
		var y := 0.3 - 0.12 * float(i)
		a.box(Vector3(0.012 * (1.0 if i % 2 == 0 else -1.0), y, Yokai.FACE_Z - 0.01), Vector3(0.016, 0.13, 0.015), Toon.SUMI, Vector3(0, 0, 0.2 * (1.0 if i % 2 == 0 else -1.0)))
	# couronne d'or (tenkan) : bandeau, pointes plates en éventail, flamme haute au centre, pendeloques
	a.cyl(Vector3(0, 0.3, Yokai.MASK_Z + 0.1), Vector3(0.27, 0.06, 0.26), Toon.GOLD, Vector3(0.2, 0, 0), 0.9, 12)
	var pts := 3 if lite else 5
	for i in pts:
		var ang := -1.0 + 2.0 * float(i) / float(pts - 1)
		var base := Vector3(sin(ang) * 0.25, 0.33 - 0.04 * absf(ang), Yokai.MASK_Z + 0.1 - cos(ang) * 0.23)
		a.spike(base, 0.045, 0.16, Toon.GOLD, Vector3(0.1 - 0.15 * absf(ang), 0, -ang * 0.35), 0.0, 4, 0.35)
	a.spike(Vector3(0, 0.36, Yokai.MASK_Z + 0.12), 0.04, 0.32, Toon.GOLD, Vector3(0.1, 0, 0), 0.0, 5, 0.45)
	f.ball(Vector3(0, 0.33, Yokai.MASK_Z - 0.14), Vector3(0.035, 0.04, 0.02), WAVE, Vector3.ZERO, 6)
	for s in [-1.0, 1.0]:
		a.stick(Vector3(float(s) * 0.3, 0.26, Yokai.MASK_Z + 0.04), Vector3(0.014, 0.4, 0.014), Toon.GOLD, Vector3(PI, 0, float(s) * 0.1))
		a.ball(Vector3(float(s) * 0.34, -0.14, Yokai.MASK_Z + 0.04), Vector3.ONE * 0.03, Toon.GOLD, Vector3.ZERO, 6)
	var hm := piece(_head, a, f)
	# moitié décharnée : demi-plaque grise posée juste au-dessus de la plaque pâle (surface à part)
	var hi := half_surface(hm.mesh, Vector3(0, 0, Yokai.MASK_Z), Vector3(0.306, 0.366, 0.106), MASK_DEAD, U)
	hm.set_surface_override_material(hi, ink_mat())
	# longue chevelure noire : nappe dans le dos jusqu'à la taille, deux mèches devant les épaules
	_hair = Node3D.new()
	body.add_child(_hair)
	_hair.position = Vector3(0, 1.22, 0.1) * U
	var h := Yokai.Mesher.new(U)
	h.stick(Vector3(0, 0.26, 0.2), Vector3(0.6, 1.15, 0.14), HAIR, Vector3(PI - 0.08, 0, 0))
	for s in [-1.0, 1.0]:
		h.stick(Vector3(float(s) * 0.34, 0.1, -0.08), Vector3(0.14, 0.95, 0.1), HAIR, Vector3(PI, 0, float(s) * 0.05))
	if not lite:
		h.ball(Vector3(0, 0.3, 0.1), Vector3(0.3, 0.12, 0.3), HAIR, Vector3.ZERO, 8)
	piece(_hair, h)
	# bras : manches longues d'encre bordées de lilas, mains pâles aux longs doigts
	for sx: float in [1.0, -1.0]:
		var piv := Node3D.new()
		body.add_child(piv)
		piv.position = Vector3(sx * 0.3, 1.0, 0) * U
		var am := Yokai.Mesher.new(U)
		am.cyl(Vector3(0, -0.2, 0), Vector3(0.075, 0.4, 0.075), INK_IZA, Vector3(PI, 0, 0), 0.75, 7)
		am.cyl(Vector3(0, -0.5, 0), Vector3(0.15, 0.4, 0.1), INK_IZA, Vector3.ZERO, 0.5, 8)
		am.cyl(Vector3(0, -0.69, 0), Vector3(0.155, 0.03, 0.105), WAVE, Vector3.ZERO, 1.0, 8)
		am.ball(Vector3(0, -0.78, 0), Vector3(0.06, 0.1, 0.04), HAND, Vector3.ZERO, 8)
		for k in 3:
			var kx := (float(k) - 1.0) * 0.035
			am.spike(Vector3(kx, -0.84, 0), 0.013, 0.18 - 0.03 * absf(float(k) - 1.0), HAND, Vector3(PI, 0, kx * 2.0), 0.0, 4)
		piece(piv, am)
		_arms.append(piv)
	# huit dieux du tonnerre en couronne, chacun lié par un fil
	for i in GOD_N:
		var ang := TAU * float(i) / float(GOD_N) + PI / float(GOD_N)
		var gn := Node3D.new()
		gn.top_level = true
		add_child(gn)
		var om := Toon.mat(BOLT, true, 0.03)
		om.emission_enabled = true
		om.emission = BOLT
		om.emission_energy_multiplier = 1.4
		Toon.part(gn, Toon.sphere(0.32), om, Vector3.ZERO)
		var tm := TorusMesh.new()
		tm.inner_radius = 0.36
		tm.outer_radius = 0.46
		tm.rings = 16
		tm.ring_segments = 4
		var drum := Toon.part(gn, tm, Toon.mat_shared(Color("#2A2430")), Vector3.ZERO)
		drum.rotation.x = PI * 0.5
		for k in 3:
			var sp := Toon.part(gn, Toon.cyl(0.0, 0.05, 0.3, 4), Toon.mat_shared(Toon.GOLD, false), Vector3(0, 0.35, 0))
			sp.rotation.z = (float(k) - 1.0) * 0.6
		var th := Toon.part(self, Toon.cyl(0.035, 0.035, 1.0, 4), main.vfx.glow_mat(BOLT, 2.4), Vector3.ZERO)
		th.top_level = true
		th.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gods.append({"node": gn, "orb": om, "thread": th, "angle": ang, "cut": false, "fall": 0.0})
	_hint = Loop.hint_ring(self, HINT_R, Toon.GOLD)
	_hint.visible = false
	_make_stars(body, 4.0)
	body.scale = Vector3.ONE * 0.01


func _god_pos(g: Dictionary) -> Vector3:
	var a: float = g["angle"]
	return Vector3(position.x + cos(a) * GOD_R, 0, position.z + sin(a) * GOD_R * 1.05)


func _thread_in(g: Dictionary) -> Vector3:
	var gp := _god_pos(g)
	var me := Vector3(position.x, 0, position.z)
	return me + (gp - me).normalized() * THREAD_IN


func _bound_count() -> int:
	var n := 0
	for g in _gods:
		var gd: Dictionary = g
		if not bool(gd["cut"]):
			n += 1
	return n


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead or _state == "spawn" or _state == "dying":
		return false
	if hero.dashing and _state == "fight":
		Loop.record(_pts, a, b)
		_cut_threads(a, b, stroke_id)
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


## Fin du trait : un ensō d'un autre trait, une fois déliée, brise le bouclier.
func end_stroke(stroke_id: int) -> void:
	if not dead and _state == "fight" and not _pts.is_empty():
		var pa: Vector3 = main._prev_hero
		Loop.record(_pts, pa, hero.position)
		_cut_threads(pa, hero.position, stroke_id)
	var pts: Array = _pts
	_pts = []
	if dead or pts.size() < 6 or vulnerable_t > 0.0 or _state != "fight":
		return
	if _unbound_t <= 0.0 or stroke_id == _freed_stroke:
		return
	var loop := Loop.find_loop(pts, Vector2(position.x, position.z))
	if loop.size() < 3:
		return
	main.float_icon(position + Vector3(0, 2.6, 0), "figures/enso", Toon.GOLD)
	main.big_hit(position + Vector3(0, 1.8, 0))
	main.splash(position + Vector3(0, 2.2, 0), BOLT, 26)
	main.shake = maxf(float(main.shake), 0.86)
	_shield_dmg(shield_max)


func touching_hero(p: Vector3) -> bool:
	if dead or _state == "spawn" or _state == "dying":
		return false
	return Vector2(p.x - position.x, p.z - position.z).length() < radius + 0.25


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state == "spawn" or _state == "dying":
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.8, 0)


func _zone_fire(z: Dictionary) -> void:
	var tag := String(z["tag"])
	var c: Vector3 = z["c"]
	if tag == "bolt":
		main.enemy_strike(c, BOLT_R)
		main.vfx.sky_bolt(c, false)
	elif tag == "hand":
		main.enemy_strike(c, HAND_R)
		main.splash(c + Vector3(0, 0.3, 0), Color("#2A2430"), 8)
	elif tag == "breath":
		var d: Vector3 = z["dir"]
		if _in_zone(z, hero.position, 0.0):
			main.enemy_strike(Vector3(hero.position.x, 0, hero.position.z), 0.4)
		for k in 5:
			main.splash(c + d * (1.4 + 1.5 * float(k)) + Vector3(0, 0.4, 0), BOLT, 5)
		main.shake = maxf(float(main.shake), 0.31)


func _on_die() -> void:
	_hint.visible = false
	for g in _gods:
		var gd: Dictionary = g
		var th = gd["thread"]
		th.visible = false


## Bouclier brisé : effondrée, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	_unbound_t = 0.0
	_state = "open"


## Fin de la fenêtre : les fils repoussent, deux affamés sortent de terre.
func _on_shield_back() -> void:
	if _state != "open":
		return
	_regrow()
	_state = "fight"
	_atk_cd = 1.8
	_bolt_t = 1.6
	main.spawn_minions(["gaki", "gaki"] if hp > max_hp * 0.5 else ["gaki", "shiryo"])


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var dir := _dir_to_hero()
	match _state:
		"spawn":
			_timer -= delta
			body.scale = Vector3.ONE * clampf(1.0 - _timer / 2.2, 0.01, 1.0)
			if fmod(_t, 0.3) < delta:
				main.splash(position + Vector3(randf_range(-1.5, 1.5), 0.4, randf_range(-1.0, 1.0)), BOLT, 5)
			if _timer <= 0.0:
				body.scale = Vector3.ONE
				_state = "fight"
				_atk_cd = 2.0
				_bolt_t = 1.4
		"fight":
			_face(dir, delta, 2.5)
			if _unbound_t > 0.0:
				_unbound_t -= delta
				if _unbound_t <= 0.0:
					_regrow()
			# foudre des dieux encore liés, à tour de rôle
			_bolt_t -= delta
			if _bolt_t <= 0.0:
				_bolt_t = 1.5 if hp > max_hp * 0.5 else 1.1
				_call_bolt()
			if _zones.size() <= 1:
				_atk_cd -= delta
				if _atk_cd <= 0.0:
					_attack(dir)
		"open":
			# effondrée : la fin de la fenêtre (vulnerable_t) la relève (_on_shield_back)
			pass
		"dying":
			_timer += delta
			body.rotation.x = minf(_timer * 0.5, 0.5)
			if _timer > 1.2:
				body.position.y -= delta * 1.4
			if _timer > 2.8:
				queue_free()
	_animate(delta)


func _attack(dir: Vector3) -> void:
	_cycle += 1
	if _cycle % 2 == 0:
		var c := Vector3(hero.position.x, 0, hero.position.z)
		var a0 := randf() * TAU
		for k in 4:
			var a := a0 + TAU * float(k) / 4.0
			var q := c + Vector3(cos(a), 0, sin(a)) * 1.4
			q = Vector3(clampf(q.x, -HALF.x + 0.5, HALF.x - 0.5), 0, clampf(q.z, -HALF.y + 0.5, HALF.y - 0.5))
			_zone_disc(q, HAND_R, 1.2 + 0.1 * float(k), "hand")
	else:
		_zone_fan(Vector3(position.x, 0, position.z), dir, BREATH_HALF, BREATH_LEN, 1.1, "breath")
	_atk_cd = 2.6 if hp > max_hp * 0.5 else 2.0


## Un dieu encore lié appelle la foudre sous le héros.
func _call_bolt() -> void:
	if _bound_count() == 0:
		return
	for k in GOD_N:
		_bolt_i = (_bolt_i + 3) % GOD_N
		var g: Dictionary = _gods[_bolt_i]
		if not bool(g["cut"]):
			var c: Vector3 = main.arena.clamp_walk(Vector3(hero.position.x, 0, hero.position.z), 0.3)
			_zone_disc(c, BOLT_R, 1.0, "bolt")
			var gn = g["node"]
			main.vfx.bolt(gn.global_position, c + Vector3(0, 0.2, 0), 2)
			return


## Ruée a..b : chaque fil croisé est tranché ; les huit tranchés, elle est déliée.
func _cut_threads(a: Vector3, b: Vector3, stroke_id: int) -> void:
	if _unbound_t > 0.0:
		return
	var me := Vector3(position.x, 0, position.z)
	var cut_now := 0
	for g in _gods:
		var gd: Dictionary = g
		if bool(gd["cut"]):
			continue
		var gp := _god_pos(gd)
		var ti := me + (gp - me).normalized() * THREAD_IN
		if Loop.cuts(a, b, ti, gp):
			gd["cut"] = true
			cut_now += 1
			var mid := ti.lerp(gp, 0.5)
			main.small_hit(mid + Vector3(0, 1.8, 0))
			main.vfx.sparks(mid + Vector3(0, 1.8, 0), Vector3.UP, 6, BOLT)
	if cut_now == 0:
		return
	main.sfx.play("strike", 1.5, -6.0)
	if _bound_count() == 0:
		_unbound_t = UNBOUND
		_freed_stroke = stroke_id
		main.float_icon(position + Vector3(0, 3.0, 0), "elements/foudre", Toon.GOLD)
		main.float_text(position + Vector3(0, 2.2, 0), "DÉLIÉE", Toon.GOLD)
	else:
		_shield_dmg(THREAD_CHIP * float(cut_now))


## Les fils repoussent : les dieux remontent dans la couronne.
func _regrow() -> void:
	_unbound_t = 0.0
	for g in _gods:
		var gd: Dictionary = g
		if bool(gd["cut"]):
			gd["cut"] = false
			var gp := _god_pos(gd)
			main.vfx.sparks(gp + Vector3(0, 0.6, 0), Vector3.UP, 5, BOLT)


## Dieux qui flottent (ou tombés), fils tendus, cheveux qui ondulent, ensō or quand elle est déliée.
func _animate(delta: float) -> void:
	var neck := position + Vector3(0, 2.4 + body.position.y, 0)
	for i in _gods.size():
		var g: Dictionary = _gods[i]
		var gn = g["node"]
		var gp := _god_pos(g)
		var cut: bool = g["cut"]
		var fall: float = g["fall"]
		fall = move_toward(fall, 1.0 if cut or dead else 0.0, delta * 2.5)
		g["fall"] = fall
		var y := lerpf(2.2 + sin(_t * 2.0 + float(i)) * 0.15, 0.25, fall)
		gn.global_position = gp + Vector3(0, y, 0)
		gn.rotation.y += delta * (2.0 - 1.6 * fall)
		var om: StandardMaterial3D = g["orb"]
		om.albedo_color = BOLT.lerp(DEAD_GOD, fall)
		om.emission_energy_multiplier = 1.4 * (1.0 - fall)
		var th = g["thread"]
		th.visible = not cut and not dead and _state != "spawn"
		if th.visible:
			var a: Vector3 = gn.global_position
			var d := neck - a
			var l := maxf(d.length(), 0.01)
			var q := Quaternion.IDENTITY
			if absf(d.normalized().dot(Vector3.UP)) < 0.999:
				q = Quaternion(Vector3.UP, d.normalized())
			th.global_transform = Transform3D(Basis(q) * Basis.from_scale(Vector3(1, l, 1)), (a + neck) * 0.5)
	_hair.rotation.x = sin(_t * 1.3) * 0.05
	# pose : mains tendues au repos ; levées puis abattues pour les mains de Yomi ; ouvertes et tête penchée
	# pour le souffle ; bras ballants effondrée ; tête renversée à la mort ; flammes de la traîne qui s'étirent
	var want_r := REST_R + Vector3(0.08 * sin(_t * 1.2), 0, 0.05 * sin(_t * 0.9))
	var want_l := REST_L + Vector3(0.08 * sin(_t * 1.2 + 1.0), 0, -0.05 * sin(_t * 0.9))
	var nod := 0.05 * sin(_t * 1.2)
	for z in _zones:
		var zd: Dictionary = z
		var k := clampf(1.0 - float(zd["t"]) / float(zd["total"]), 0.0, 1.0)
		var tag := String(zd["tag"])
		if tag == "hand":
			var lift := sin(k * PI)
			want_r = Vector3(0.9 + 1.6 * lift, 0, 0.5)
			want_l = Vector3(0.9 + 1.6 * lift, 0, -0.5)
			nod = -0.15 * lift
		elif tag == "breath":
			want_r = Vector3(0.6, 0, 0.5 + 0.7 * k)
			want_l = Vector3(0.6, 0, -0.5 - 0.7 * k)
			nod = 0.35 * k
	if _state == "open":
		want_r = Vector3(0.15, 0, 0.3)
		want_l = Vector3(0.15, 0, -0.3)
		nod = 0.4
	elif _state == "dying":
		want_r = Vector3(2.4, 0, 0.6)
		want_l = Vector3(2.4, 0, -0.6)
		nod = -0.5
	var k2 := minf(1.0, delta * 6.0)
	var ar: Node3D = _arms[0]
	var al: Node3D = _arms[1]
	ar.rotation = ar.rotation.lerp(want_r, k2)
	al.rotation = al.rotation.lerp(want_l, k2)
	_head.rotation.x = lerpf(_head.rotation.x, nod, k2)
	for i in _flames.size():
		var fn: Node3D = _flames[i]
		var ph := _t * 2.2 + float(i) * 1.9
		fn.scale = Vector3(1, 1.0 + 0.35 * sin(ph), 1)
		fn.rotation = Vector3(0.25 + 0.1 * sin(ph * 0.7), 0, 0.12 * cos(ph * 0.9 + 0.5))
	_hint.visible = _state == "fight" and _unbound_t > 0.0
	_hint.rotation.y = -_t * 0.5
	if _state == "open":
		body.position.y = -0.4
		body.rotation.z = sin(_t * 9.0) * 0.04
	elif _state != "dying":
		body.position.y = sin(_t * 1.2) * 0.08
		body.rotation.z = 0.0
	if _state != "spawn" and _state != "dying":
		body.scale = Vector3.ONE * (1.05 if _flash > 0.0 else 1.0)


# ------------------------------------------------------------------ robot testeur

## Fils : un cercle entre elle et les dieux (il croise les huit fils) ; déliée : placement puis ensō de
## 400° autour d'elle (le bouclier tombe) ; effondrée (vulnérable) : iaï à travers, encore et encore.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	var c := Vector3(position.x, 0, position.z)
	if _state == "open":
		if vulnerable_t < 0.3:
			return none
		return _bot_line(h, c, 7.3)
	if _state != "fight":
		return none
	if _unbound_t > 0.6:
		return _bot_loop(h, c, HINT_R)
	if _unbound_t > 0.0:
		return none
	return _bot_loop(h, c, 2.0)


## Boucle autour de c (rayon r) : d'abord se placer sur le cercle, puis 400° d'un seul trait.
func _bot_loop(h: Vector3, c: Vector3, r: float) -> PackedVector3Array:
	var off := h - c
	var d := off.length()
	var phi := atan2(off.z, off.x) if d > 0.05 else PI * 0.5
	if d < r - 0.6 or d > r + 0.6:
		for k in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6]:
			var th := phi + deg_to_rad(30.0) * float(k)
			var q := c + Vector3(cos(th), 0, sin(th)) * r
			if _bot_inside(q, 0.25):
				return _bot_dense([h, q])
		return PackedVector3Array()
	var way: Array = [h]
	for i in range(0, 41):
		var th2 := phi + deg_to_rad(400.0) * float(i) / 40.0
		way.append(c + Vector3(cos(th2), 0, sin(th2)) * r)
	return _bot_dense(way)
