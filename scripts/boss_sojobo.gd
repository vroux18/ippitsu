extends "res://scripts/boss_mini_base.gd"
## Boss du monde 6 (Kurama) — Sōjōbō, le roi des tengu (34 PV × monde, ~3.6 m).
##  Bouclier : le vent de son grand éventail (12). Un coup ne fait qu'effleurer.
##  Mécanique de trait en deux temps :
##   1. il lève une TORNADE de plumes qui dérive vers le héros : un trait qui la traverse la tranche,
##      sa garde de vent tombe 6 s (5 s sous 50 %) et un cercle or s'allume autour de lui ;
##   2. pendant ce temps, une BOUCLE fermée autour de lui brise tout le bouclier : à genoux 6 s,
##      vulnérable (dégâts ×2). Une boucle sans tornade tranchée ne fait qu'effleurer le vent.
##  Attaques : rafale de l'éventail (cône 8 m, 1.1 s), plumes en éventail (lueur 0.8 s),
##  pluie de feuilles (4 disques r0.9 autour du héros, 1.2 s) ; la tornade blesse au contact.
##  Le bouclier revenu, deux karasu-tengu descendent du ciel.
## Apparence (direction « Masque d'encre », règles en tête de yokai_ink_w1.gd) : le yamabushi du monde 6
## (yokai_ink_w6.gd) en ROI de 3,6 m, sur le rig des yōkai d'encre (ink_rig.gd) — corps d'encre large, mante
## et obi de cèdre à grandes écailles d'écume du ravin, liserés d'or, yuigesa à pompons d'or, miroir d'or ;
## MASQUE ROUGE DE TENGU CERNÉ D'OR au TRÈS LONG NEZ bagué d'or, sourcils et moustache de washi, yeux d'or,
## crinière et barbe blanches, tokin noir à flamme d'or, couronne de perles d'or ; deux AILES D'ENCRE à bord
## d'or dans le dos (elles battent) ; en main droite levée, l'ÉVENTAIL DE PLUMES GÉANT (hauchiwa) à cœur d'or.
## Seule l'apparence a changé : PV, vent, tornade, boucle, zones, rythme, interface et robot sont ceux d'avant.

const Yokai = preload("res://scripts/yokai_parts.gd")
const W6 = preload("res://scripts/yokai_ink_w6.gd")  # palette du monde 6 (cèdre, écume du ravin, braise, crinière)
const Loop = preload("res://scripts/boss_loop.gd")
const FEATHER := Color("#1E1C22")  # plumes (éclaboussures, tornade)
const WIND := Color("#DDE6DA")
const NOSE := Color("#8E2A1E")  # le long nez : braise sombre
const QUILL := Color("#4A4650")  # plumes de l'éventail
const HEIGHT := 3.6  # le yamabushi commun fait 1,8 m
const HINT_R := 2.6
const SHIELD := 12.0
const GALE_OPEN := 6.0
const TORNADO_R := 0.95  # distance trait-tornade pour la trancher
const TORNADO_HIT := 0.85  # contact : le héros posé dans la tornade est blessé
const TORNADO_LIFE := 7.0
const GUST_HALF := 0.5
const GUST_LEN := 8.0
const LEAF_R := 0.9

var _fan: Node3D  # l'éventail géant (en main droite du rig)
var _hint: Node3D
var _pts: Array = []
var _tornado := {}  # {node, pos, life, cd}
var _torn_t := 1.6  # avant la prochaine tornade
var _gale_t := 0.0  # garde de vent tombée (la boucle brise le bouclier)
var _atk_cd := 1.8
var _volley_t := -1.0
var _cycle := 0
var _home_x := 0.0


func _ready() -> void:
	title = "Sōjōbō"
	if position.is_zero_approx():
		position = Vector3(0, 0, -5.4)  # au fond de l'arène
	_home_x = position.x
	hp = 34.0 * max_hp_mult
	max_hp = hp
	radius = 1.3
	vulnerable_len = 6.0
	_build()
	_shield_init(SHIELD, Vector3(1.9, 2.5, 1.9), 1.8)
	_state = "spawn"
	_timer = 2.0


# ------------------------------------------------------------------ construction

## Marionnette du roi : le rig des yōkai d'encre (ink_rig.gd) habillé des pièces bâties ici (le genre « sojobo »
## n'existe dans aucun yokai_ink_wN.gd : _dress est remplacé, le reste du rig sert tel quel). Éventail levé en main
## droite (règle du tireur), ailes sur deux pivots du corps que `flap` fait battre. Les noms d'animations KayKit
## du combat deviennent ses clips ; à genoux (Blocking), le bras de l'éventail retombe.
class Rig extends "res://scripts/ink_rig.gd":
	static var _cache := {}  # léger -> pièces
	var flap := 0.0  # battement des ailes (rad)
	var fan: MeshInstance3D  # l'éventail (unités du monde, dans la main droite)
	var _wings: Array[Node3D] = []

	func setup(k: String, height := H_REF) -> void:
		super.setup(k, height)
		_rest_r = Vector3(2.0, 0, 0.35)
		_rest_l = Vector3(0.5, 0, -0.35)
		_eval(0.0)
		for j in SLOTS:
			_out[j] = _tgt[j]
		_apply()

	## Le masque regarde un peu plus la caméra (le long nez doit se lire du dessus) ; les ailes battent.
	func _apply() -> void:
		super._apply()
		_head.rotation.x += 0.15
		for i in _wings.size():
			var sx := -1.0 if i == 0 else 1.0
			_wings[i].rotation.z = sx * (0.3 + flap)

	## Garde (à genoux) : le bras de l'éventail retombe, le corps se plie davantage.
	func _eval(u: float) -> void:
		super._eval(u)
		if _clip == C_BLOCK:
			_tgt[S_ARM_R] = Vector3(0.3, 0, 0.6)
			_tgt[S_BODY] += Vector3(-0.2, 0, 0)

	func _dress() -> void:
		var key := 1 if Toon.lite else 0
		if not _cache.has(key):
			_cache[key] = _build_parts(Toon.lite)
		var d: Dictionary = _cache[key]
		_parts.clear()
		_part_id = PackedStringArray()
		_part_on(_body, "body", d)
		_part_on(_head, "head", d)
		_part_on(_arms[0], "arm", d)
		_part_on(_arms[1], "arm", d)
		fan = _part_on(_hands[1], "weapon_r", d)
		if fan != null:
			fan.position = Vector3(0, 0.02, 0)
		# ailes : un pivot par côté derrière les épaules
		for n in _wings:
			n.queue_free()
		_wings.clear()
		for s in [-1.0, 1.0]:
			var pv := Node3D.new()
			pv.position = Vector3(float(s) * 0.4, 1.06, 0.2)
			_body.add_child(pv)
			_wings.append(pv)
			_part_on(pv, "wing_l" if s < 0.0 else "wing_r", d)
		for n in _drips:
			n.queue_free()
		_drips.clear()
		_drip_spread = float(d.get("spread", 0.0))
		var pts: PackedVector3Array = d.get("drips", PackedVector3Array())
		for p in pts:
			var piv := Node3D.new()
			piv.position = p
			_body.add_child(piv)
			_drips.append(piv)
			_part_on(piv, "drip", d)

	## Pièces (unités du modèle, H_REF = 1,75 m, face vers -Z), deux surfaces : toon à contour, aplat lumineux.
	static func _build_parts(lite: bool) -> Dictionary:
		var d := {}
		var w := 1.15
		var b := Yokai.Mesher.new(1.0)
		Yokai.ink_body(b, w, Yokai.INK, W6.CLOTH, W6.WAVE, W6.LINE, lite, true)
		# mante de cèdre sur les épaules : collet cerclé d'or, grandes écailles d'écume du ravin (le motif du monde)
		b.cyl(Vector3(0, 1.0, 0), Vector3(0.5 * w, 0.16, 0.47 * w), W6.CLOTH, Vector3.ZERO, 0.8, 12)
		b.cyl(Vector3(0, 0.92, 0), Vector3(0.52 * w, 0.03, 0.49 * w), Toon.GOLD, Vector3.ZERO, 1.0, 12)
		b.cyl(Vector3(0, 1.075, 0), Vector3(0.41 * w, 0.03, 0.39 * w), Toon.GOLD, Vector3.ZERO, 1.0, 12)
		var sc := 6 if lite else 10
		for i in sc:
			var ang := TAU * (float(i) + 0.5) / float(sc)
			if cos(ang) < -0.3 and sin(ang) > -0.3 and sin(ang) < 0.3:
				continue  # la nuque reste nue (ailes)
			b.ball(Vector3(sin(ang) * 0.49 * w, 0.97, cos(ang) * 0.46 * w), Vector3(0.11, 0.07, 0.02), W6.WAVE, Vector3(0, ang, 0), 6)
		# pan de kimono dans le dos : étoffe de cèdre liserée d'or, deux grandes écailles
		b.box(Vector3(0, 0.72, 0.42 * w), Vector3(0.62, 0.72, 0.05), W6.CLOTH, Vector3(0.12, 0, 0))
		b.box(Vector3(0, 0.36, 0.46 * w), Vector3(0.64, 0.04, 0.06), Toon.GOLD, Vector3(0.12, 0, 0))
		if not lite:
			for s in [-1.0, 1.0]:
				b.ball(Vector3(float(s) * 0.15, 0.62, 0.45 * w), Vector3(0.14, 0.09, 0.02), W6.WAVE, Vector3(0.12, 0, 0), 6)
		# yuigesa : deux cordons croisés sur la poitrine, pompons d'or ; miroir d'or au milieu
		for s in [-1.0, 1.0]:
			var x := float(s)
			b.box(Vector3(x * 0.11, 0.86, -0.43 * w), Vector3(0.045, 0.46, 0.02), W6.TOKIN, Vector3(0.12, 0, x * 0.42))
			b.ball(Vector3(x * 0.24, 0.98, -0.41 * w), Vector3(0.075, 0.075, 0.05), Toon.GOLD, Vector3.ZERO, 6)
			b.ball(Vector3(x * 0.14, 0.72, -0.44 * w), Vector3(0.065, 0.065, 0.045), Toon.GOLD, Vector3.ZERO, 6)
		b.cyl(Vector3(0, 0.86, -0.455 * w), Vector3(0.1, 0.02, 0.1), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 1.0, 10)
		d["body"] = b.mesh()
		var a := Yokai.Mesher.new(1.0)
		var f := Yokai.Mesher.new(1.0)
		# masque rouge de tengu cerné d'or, large ; sourcils de washi épais et froncés, yeux d'or
		Yokai.mask_plate(a, W6.TENGU_RED, 1.3, 1.25, true)
		for s in [-1.0, 1.0]:
			var x := float(s)
			a.box(Vector3(x * 0.15, 0.19, Yokai.FACE_Z), Vector3(0.24, 0.065, 0.025), W6.MANE, Vector3(0, 0, x * 0.35))
		Yokai.mask_eyes(f, Yokai.EYE_GOLD, 0.065, 1.3)
		# le très long nez : fuseau de braise sombre bagué d'or, un peu baissé, bout rond
		var nrot := Vector3(-PI / 2.0 - 0.55, 0, 0)
		var nose := a.spike(Vector3(0, 0.02, Yokai.FACE_Z + 0.02), 0.1, 0.95, NOSE, nrot, 0.35, 7)
		a.ball(nose, Vector3(0.045, 0.045, 0.045), NOSE, Vector3.ZERO, 6)
		a.cyl(Vector3(0, 0.02, Yokai.FACE_Z + 0.02) + Basis.from_euler(nrot) * Vector3(0, 0.3, 0), Vector3(0.085, 0.035, 0.085), Toon.GOLD, nrot, 0.95, 8)
		# bouche serrée, moustache de washi tombante, barbe blanche en pointe
		a.box(Vector3(0, -0.2, Yokai.FACE_Z), Vector3(0.18, 0.035, 0.02), Toon.SUMI)
		for s in [-1.0, 1.0]:
			var x := float(s)
			a.stick(Vector3(x * 0.09, -0.15, Yokai.FACE_Z), Vector3(0.045, 0.26, 0.02), W6.MANE, Vector3(0, 0, x * 2.6))
		a.spike(Vector3(0, -0.3, Yokai.FACE_Z + 0.03), 0.13, 0.5, W6.MANE, Vector3(PI + 0.25, 0, 0), 0.0, 5, 0.5)
		# crinière blanche : calotte derrière le masque, longues mèches sur les côtés et dans le dos
		a.ball(Vector3(0, 0.24, Yokai.MASK_Z + 0.2), Vector3(0.46, 0.2, 0.36), W6.MANE, Vector3.ZERO, 8)
		for s in [-1.0, 1.0]:
			var x := float(s)
			a.stick(Vector3(x * 0.37, 0.16, -0.2), Vector3(0.12, 0.72, 0.08), W6.MANE, Vector3(PI, 0, -x * 0.12))
		var locks := 1 if lite else 3
		for i in locks:
			var k := float(i) - float(locks - 1) * 0.5
			a.stick(Vector3(k * 0.16, 0.22, 0.2), Vector3(0.14, 0.62, 0.07), W6.MANE, Vector3(PI - 0.35, 0, -k * 0.3))
		# tokin : boîte noire à pans sur le front, cordon d'or, flamme d'or ; couronne de perles d'or autour
		a.cyl(Vector3(0, 0.44, Yokai.MASK_Z + 0.08), Vector3(0.135, 0.18, 0.11), W6.TOKIN, Vector3(0.25, 0, 0), 0.7, 6)
		a.cyl(Vector3(0, 0.36, Yokai.MASK_Z + 0.08), Vector3(0.15, 0.03, 0.125), Toon.GOLD, Vector3(0.25, 0, 0), 1.0, 8)
		a.spike(Vector3(0, 0.53, Yokai.MASK_Z + 0.1), 0.045, 0.22, Toon.GOLD, Vector3(0.1, 0, 0), 0.0, 4, 0.5)
		var pearls := 8 if lite else 12
		for i in pearls:
			var ang := TAU * (float(i) + 0.5) / float(pearls)
			if cos(ang) < -0.5:
				continue  # pas devant le masque
			a.ball(Vector3(sin(ang) * 0.42, 0.4 + 0.04 * cos(ang), cos(ang) * 0.34 + 0.02), Vector3(0.045, 0.045, 0.045), Toon.GOLD, Vector3.ZERO, 6)
		d["head"] = Yokai.two(a, f)
		# bras d'encre à bracelet d'or
		var ar := Yokai.Mesher.new(1.0)
		ar.cyl(Vector3(0, -0.2, 0), Vector3(0.095, 0.4, 0.095), Yokai.INK, Vector3(PI, 0, 0), 0.7, 7)
		ar.cyl(Vector3(0, -0.31, 0), Vector3(0.09, 0.04, 0.09), Toon.GOLD, Vector3.ZERO, 1.0, 8)
		ar.ball(Vector3(0, -0.43, 0), Vector3(0.11, 0.095, 0.11), Yokai.INK)
		d["arm"] = ar.mesh()
		# ailes d'encre (pivot derrière l'épaule, l'aile part vers l'extérieur et un peu en arrière) : os, membrane
		# de plumes, couvertures, bord d'attaque d'or, rémiges en éventail à pointes d'or
		for s in [-1.0, 1.0]:
			var sx := float(s)
			var wg := Yokai.Mesher.new(1.0)
			wg.cyl(Vector3(sx * 0.45, 0.04, 0.02), Vector3(0.07, 0.9, 0.08), Yokai.INK, Vector3(0, 0, -sx * PI / 2.0), 0.7, 7)
			wg.box(Vector3(sx * 0.5, -0.1, 0.16), Vector3(0.95, 0.05, 0.42), W6.FEATHER, Vector3(0.15, 0, 0))
			wg.box(Vector3(sx * 0.32, -0.03, 0.1), Vector3(0.56, 0.06, 0.28), Yokai.INK, Vector3(0.15, 0, 0))
			wg.box(Vector3(sx * 0.5, -0.07, -0.06), Vector3(0.95, 0.035, 0.035), Toon.GOLD, Vector3(0.15, 0, 0))
			var pens := 4 if lite else 6
			for i in pens:
				var k := float(i) / float(pens - 1)  # 0 (près du corps) .. 1 (bout de l'aile)
				var base := Vector3(sx * (0.55 + 0.42 * k), -0.12, 0.3)
				var dir := Vector3(sx * (0.25 + 0.75 * k), -0.1, 0.95 - 0.55 * k)
				var ln := 0.62 - 0.2 * k
				var tip := wg.ray(base, dir, 0.06, ln, W6.FEATHER, 0.25, 4)
				if not lite:
					wg.ball(tip, Vector3(0.035, 0.035, 0.035), Toon.GOLD, Vector3.ZERO, 6)
			d["wing_l" if sx < 0.0 else "wing_r"] = wg.mesh()
		Yokai.ink_drip(d, Yokai.INK)
		d["weapon_r"] = _fan_mesh(lite)
		return d

	## Hauchiwa géant (unités du monde, +Y vers le bout) : manche de bois, cœur d'or, plumes qui rayonnent dans le
	## plan perpendiculaire au bras (bras levé, l'éventail fait face à la caméra), pointes de washi, rayons d'or.
	static func _fan_mesh(lite: bool) -> ArrayMesh:
		var m := Yokai.Mesher.new(1.0)
		m.cyl(Vector3(0, 0.26, 0), Vector3(0.035, 0.6, 0.035), Color("#3B2E25"), Vector3.ZERO, 1.0, 6)
		m.cyl(Vector3(0, 0.1, 0), Vector3(0.045, 0.05, 0.045), Toon.GOLD, Vector3.ZERO, 1.0, 6)
		var c := Vector3(0, 0.58, 0)
		var n := 6 if lite else 9
		for i in n:
			var ang := deg_to_rad(-120.0 + 240.0 * float(i) / float(n - 1))
			var dir := Vector3(sin(ang), 0, -cos(ang))
			m.ray(c, dir, 0.13, 0.78, QUILL, 0.45, 4)
			m.ray(c + Vector3(0, 0.008, 0) + dir * 0.52, dir, 0.075, 0.3, W6.MANE, 0.2, 4)
			if not lite:
				m.ray(c + Vector3(0, 0.012, 0) + dir * 0.1, dir, 0.02, 0.5, Toon.GOLD, 0.6, 4)
		m.ball(c, Vector3(0.11, 0.05, 0.11), Toon.GOLD, Vector3.ZERO, 8)
		return m.mesh()


func _build() -> void:
	Toon.disc(self, 1.4, Color(0, 0, 0, 0.18))
	body = Node3D.new()
	add_child(body)
	body.rotation.y = PI  # il entre face au héros (le corps regarde vers -Z ; _face le tourne ensuite)
	ch = Rig.new()
	body.add_child(ch)
	ch.setup("sojobo", HEIGHT)
	ch.idle = "Idle_Combat"
	ch.play("Idle_Combat")
	_fan = ch.fan
	_hint = Loop.hint_ring(self, HINT_R, Toon.GOLD)
	_hint.visible = false
	_make_stars(body, 4.1)
	body.scale = Vector3.ONE * 0.01


## Tornade de plumes : tores blancs empilés qui tournent, plumes noires en orbite.
func _make_tornado(p: Vector3) -> void:
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	n.global_position = Vector3(p.x, 0, p.z)
	var m := Toon.flat(Color(WIND, 0.5))
	for k in 5:
		var tm := TorusMesh.new()
		var r := 0.35 + 0.16 * float(k)
		tm.inner_radius = r - 0.07
		tm.outer_radius = r + 0.07
		tm.rings = 20
		tm.ring_segments = 4
		var ring := Toon.part(n, tm, m, Vector3(0, 0.25 + 0.5 * float(k), 0), Vector3(1, 0.5, 1))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fm := Toon.mat_shared(FEATHER, false)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var r2 := 0.4 + 0.12 * float(k % 4)
		var f := Toon.part(n, Toon.box(Vector3(0.06, 0.03, 0.28)), fm, Vector3(cos(a) * r2, 0.3 + 0.3 * float(k), sin(a) * r2))
		f.rotation.y = -a
	Toon.disc(n, 0.9, Color(Toon.SUMI, 0.18), 0.02)
	_tornado = {"node": n, "pos": Vector3(p.x, 0, p.z), "life": TORNADO_LIFE if hp > max_hp * 0.5 else TORNADO_LIFE + 1.5, "cd": 0.0}
	main.splash(Vector3(p.x, 1.0, p.z), WIND, 12)
	main.sfx.play("whoosh", 0.7, -3.0)


func _free_tornado(burst: bool) -> void:
	if _tornado.is_empty():
		return
	var n = _tornado["node"]
	if is_instance_valid(n):
		if burst:
			var p: Vector3 = _tornado["pos"]
			main.splash(p + Vector3(0, 1.0, 0), WIND, 20)
			main.splash(p + Vector3(0, 1.2, 0), FEATHER, 12)
		n.queue_free()
	_tornado = {}


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead or _state == "spawn" or _state == "dying":
		return false
	if hero.dashing and _state == "fight":
		Loop.record(_pts, a, b)
		if not _tornado.is_empty():
			var tp: Vector3 = _tornado["pos"]
			if _seg_dist(tp, a, b) < TORNADO_R:
				_cut_tornado()
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


## Fin du trait : une boucle autour de lui, garde de vent tombée, brise le bouclier.
func end_stroke(_stroke_id: int) -> void:
	if not dead and not _pts.is_empty():
		var pa: Vector3 = main._prev_hero
		Loop.record(_pts, pa, hero.position)
		if _state == "fight" and not _tornado.is_empty():
			var tp: Vector3 = _tornado["pos"]
			if _seg_dist(tp, pa, hero.position) < TORNADO_R:
				_cut_tornado()
	var pts: Array = _pts
	_pts = []
	if dead or pts.size() < 6 or vulnerable_t > 0.0 or _state != "fight":
		return
	var loop := Loop.find_loop(pts, Vector2(position.x, position.z))
	if loop.size() < 3:
		return
	if _gale_t > 0.0:
		main.float_icon(position + Vector3(0, 2.2, 0), "figures/enso", Toon.GOLD)
		main.big_hit(position + Vector3(0, 1.6, 0))
		main.splash(position + Vector3(0, 2.0, 0), FEATHER, 26)
		_shield_dmg(shield_max)
	else:
		# le vent le protège encore : la boucle n'effleure que sa garde
		main.clang(position + Vector3(0, 1.6, 0))
		main.float_icon(position + Vector3(0, 2.4, 0), "elements/vent", SHIELD_C)
		_shield_dmg(1.2)


func touching_hero(p: Vector3) -> bool:
	if dead or _state == "spawn" or _state == "dying":
		return false
	return Vector2(p.x - position.x, p.z - position.z).length() < radius + 0.2


func _extra_danger(p: Vector3, _eta: float) -> bool:
	if _tornado.is_empty():
		return false
	var tp: Vector3 = _tornado["pos"]
	return Vector2(p.x - tp.x, p.z - tp.z).length() < TORNADO_HIT + DANGER_MARGIN


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state == "spawn" or _state == "dying":
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.8, 0)


func _zone_fire(z: Dictionary) -> void:
	var tag := String(z["tag"])
	if tag == "gust":
		var c: Vector3 = z["c"]
		var d: Vector3 = z["dir"]
		if _in_zone(z, hero.position, 0.0):
			main.enemy_strike(Vector3(hero.position.x, 0, hero.position.z), 0.4)
		main.vfx.wind_slash(c + d * 2.0, d, 1.6)
		main.vfx.wind_slash(c + d * 4.5, d, 1.3)
		main.vfx.wind_slash(c + d * 6.5, d, 1.0)
		main.shake = maxf(float(main.shake), 0.31)
	elif tag == "leaf":
		var c2: Vector3 = z["c"]
		main.enemy_strike(c2, LEAF_R)
		main.splash(c2 + Vector3(0, 0.3, 0), Color("#4E6E3E"), 8)


func _on_die() -> void:
	_free_tornado(true)
	_hint.visible = false
	_fan.visible = false
	ch.set_glow(0.0)


## Bouclier brisé : à genoux, éventail tombé, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	_free_tornado(true)
	_volley_t = -1.0
	_gale_t = 0.0
	ch.set_glow(0.0)
	_state = "open"
	_fan.visible = false
	ch.play("Blocking", 0.6)


func _on_shield_back() -> void:
	if _state != "open":
		return
	_state = "fight"
	_fan.visible = true
	_atk_cd = 1.6
	_torn_t = 1.5
	ch.play("Idle_Combat")
	main.spawn_minions(["karasu", "karasu"])


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var dir := _dir_to_hero()
	match _state:
		"spawn":
			_timer -= delta
			body.scale = Vector3.ONE * clampf(1.0 - _timer / 2.0, 0.01, 1.0)
			if fmod(_t, 0.3) < delta:
				main.splash(position + Vector3(randf_range(-1.5, 1.5), 0.5, randf_range(-1.0, 1.0)), FEATHER, 6)
			if _timer <= 0.0:
				body.scale = Vector3.ONE
				_state = "fight"
				_atk_cd = 1.6
				_torn_t = 1.2
		"fight":
			_face(dir, delta, 3.0)
			# il glisse lentement d'un côté à l'autre du fond de l'arène
			var tx := _home_x + sin(_t * 0.35) * 1.4
			position.x = move_toward(position.x, tx, delta * 0.8)
			if _gale_t > 0.0:
				_gale_t -= delta
				if _gale_t <= 0.0:
					main.float_icon(position + Vector3(0, 2.4, 0), "elements/vent", SHIELD_C)
					_torn_t = 1.5
			elif _tornado.is_empty():
				_torn_t -= delta
				if _torn_t <= 0.0:
					_spawn_tornado()
			if _volley_t >= 0.0:
				_volley_t -= delta
				if _flash <= 0.0:
					ch.set_glow(0.6 * clampf(1.0 - _volley_t / 0.8, 0.0, 1.0), Toon.VERMILION)
				if _volley_t < 0.0:
					_volley_t = -1.0
					ch.set_glow(0.0)
					_fire_volley(dir)
			elif _zones.is_empty():
				_atk_cd -= delta
				if _atk_cd <= 0.0:
					_attack(dir)
		"open":
			# à genoux : la fin de la fenêtre (vulnerable_t) le relève (_on_shield_back)
			pass
		"dying":
			_timer += delta
			body.rotation.x = minf(_timer * 0.6, 0.6)
			if _timer > 1.2:
				body.position.y -= delta * 1.6
			if _timer > 2.6:
				queue_free()
	_update_tornado(delta)
	_animate()


func _attack(dir: Vector3) -> void:
	_cycle += 1
	var fast := hp <= max_hp * 0.5
	match _cycle % 3:
		0:
			_zone_fan(position, dir, GUST_HALF, GUST_LEN, 1.1, "gust")
			ch.play_once("2H_Melee_Attack_Spinning", 1.0)
		1:
			_volley_t = 0.8
		_:
			var c := Vector3(hero.position.x, 0, hero.position.z)
			var a0 := randf() * TAU
			for k in 4:
				var q := c
				if k > 0:
					var a := a0 + TAU * float(k) / 3.0
					q = c + Vector3(cos(a), 0, sin(a)) * 1.7
				q = Vector3(clampf(q.x, -HALF.x + 0.5, HALF.x - 0.5), 0, clampf(q.z, -HALF.y + 0.5, HALF.y - 0.5))
				_zone_disc(q, LEAF_R, 1.2 + 0.08 * float(k), "leaf")
	_atk_cd = (1.7 if fast else 2.3) + (1.0 if _gale_t > 0.0 else 0.0)


func _fire_volley(dir: Vector3) -> void:
	var n := 7 if hp > max_hp * 0.5 else 9
	var spread := deg_to_rad(70.0 if n == 7 else 96.0)
	for i in n:
		var ang := -spread * 0.5 + spread * float(i) / float(n - 1)
		var d := dir.rotated(Vector3.UP, ang)
		main.spawn_bullet(position + Vector3(0, 1.6, 0) + d * 1.6, d)


## Nouvelle tornade entre lui et le héros, jamais sur le héros.
func _spawn_tornado() -> void:
	var hp2 := Vector3(hero.position.x, 0, hero.position.z)
	var best := Vector3(0, 0, position.z + 4.0)
	for attempt in 24:
		var q := Vector3(randf_range(-3.2, 3.2), 0, randf_range(position.z + 3.0, minf(position.z + 10.0, HALF.y - 1.5)))
		if q.distance_to(hp2) >= 2.0:
			best = q
			break
	_make_tornado(best)


## La tornade dérive vers le héros, blesse au contact, puis se dissipe.
func _update_tornado(delta: float) -> void:
	if _tornado.is_empty():
		return
	var n = _tornado["node"]
	var p: Vector3 = _tornado["pos"]
	var life: float = float(_tornado["life"]) - delta
	_tornado["life"] = life
	var cd: float = maxf(float(_tornado["cd"]) - delta, 0.0)
	var to := Vector3(hero.position.x - p.x, 0, hero.position.z - p.z)
	if to.length() > 0.4:
		p += to.normalized() * 0.7 * delta
	p = Vector3(clampf(p.x, -HALF.x + 0.6, HALF.x - 0.6), 0, clampf(p.z, -HALF.y + 0.6, HALF.y - 0.6))
	_tornado["pos"] = p
	if is_instance_valid(n):
		n.global_position = p
		n.rotation.y += delta * 7.0
	if cd <= 0.0 and not hero.dashing and Vector2(hero.position.x - p.x, hero.position.z - p.z).length() < TORNADO_HIT:
		cd = 1.0
		main.enemy_strike(Vector3(hero.position.x, 0, hero.position.z), 0.3)
	_tornado["cd"] = cd
	if life <= 0.0:
		_free_tornado(false)
		_torn_t = 1.2


## Tornade tranchée : la garde de vent tombe, le cercle or s'allume autour de lui.
func _cut_tornado() -> void:
	var tp: Vector3 = _tornado["pos"]
	_free_tornado(true)
	_gale_t = GALE_OPEN if hp > max_hp * 0.5 else GALE_OPEN - 1.0
	main.float_icon(tp + Vector3(0, 1.2, 0), "elements/vent", Toon.GOLD)
	main.small_hit(tp + Vector3(0, 1.0, 0))
	main.float_text(position + Vector3(0, 2.6, 0), "GARDE OUVERTE", Toon.GOLD)
	main.sfx.play("strike", 1.3, -4.0)


## Ailes qui battent (grand à l'apparition), éventail qui oscille, cercle-guide quand sa garde est tombée.
func _animate() -> void:
	var flap := 0.5 if _state == "spawn" else 0.12
	ch.flap = sin(_t * 2.2) * flap
	if _state == "open" or _state == "dying":
		ch.flap = -0.5 + sin(_t * 1.2) * 0.04
	_fan.rotation.z = sin(_t * 1.6) * 0.25
	_hint.visible = _state == "fight" and _gale_t > 0.0
	_hint.rotation.y = _t * 0.5
	if _state == "open":
		body.rotation.z = sin(_t * 10.0) * 0.05
		body.position.y = -0.25
	elif _state != "dying":
		body.rotation.z = 0.0
		body.position.y = sin(_t * 1.4) * 0.05
	if _state != "spawn" and _state != "dying":
		body.scale = Vector3.ONE * (1.05 if _flash > 0.0 else 1.0)


# ------------------------------------------------------------------ robot testeur

## Garde de vent : trait à travers la tornade ; garde tombée : placement puis boucle de 400° autour
## de lui (le bouclier tombe) ; à genoux (vulnérable) : iaï à travers, encore et encore.
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
	if _gale_t > 0.6:
		return _bot_loop(h, c, HINT_R)
	if _tornado.is_empty():
		return none
	var tp: Vector3 = _tornado["pos"]
	var d := tp - h
	d.y = 0
	if d.length() < 0.3:
		d = Vector3(-tp.x, 0, -tp.z)
	if d.length_squared() < 0.01:
		d = Vector3(0, 0, 1)
	return _bot_dense([h, tp + d.normalized() * 1.2])


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
