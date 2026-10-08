extends Node3D
## Boss du monde 3 (Cent Contes, design/UNIVERS.md) — Gashadokuro, squelette géant (90 PV).
##  Buste qui sort du sol au fond de l'arène (z ≈ -7), deux mains de 15 PV :
##   - Écrasement : rectangle 2×3 m annoncé 1.2 s, la main reste 2 s au sol → tranchable.
##   - Balayage : bande sur toute la largeur annoncée 1.0 s (se remplit depuis le côté de la main).
##  Les coups sur une main entament aussi le boss. Les deux mains détruites : le buste s'effondre
##  vers l'avant (annoncé), la colonne forme 9 vertèbres lumineuses (queue → crâne).
##  Un trait qui en passe ≥ 6 dans l'ordre = 25 dégâts, sinon 1 par vertèbre. Mains repoussent (60 %).
##  Phase ≤ 40 % : pluie de stèles (5 zones r1.0 décalées de 0.3 s).
## Interface identique à boss.gd : check_dash(), take_hit(), end_stroke(), danger_at(), touching_hero().
## Tous les visuels vivent sous `_rig` (top_level) : `position` du nœud racine sert seulement de
## point d'impact pour les effets de main.gd (déplacé sur la main / le crâne touchés).

const Toon = preload("res://scripts/toon.gd")

const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (comme main.gd)
const IVORY := Color("#E8DFC8")
const ICE := Color("#BFD6E3")
const LAVENDER := Color("#8C8FA8")
const SOCKET := Color("#23222B")
const SNOW := Color("#F3F5F7")
const STONE := Color("#9C9EB2")

const Z_BUST := -7.0  # pied du buste
const LEAN := 0.25  # buste penché vers l'avant (reste dans le cadre)
const FALLEN := 1.45  # inclinaison une fois effondré
const VERTS := 9
const V_R := 0.32
const SPINE_MIN := 6
const SPINE_DMG := 25.0
const HAND_HP := 15.0
const HAND_R := 1.2
const HAND_SCALE := 1.35
const HAND_OFF := 0.6  # le centre de l'empreinte est devant l'origine de la main
const RISE_TIME := 2.6
const SLAM_TELE := 1.2
const SLAM_STAY := 2.0
const SWEEP_TELE := 1.0
const SWEEP_TIME := 0.4
const STELE_TELE := 1.0
const COLLAPSE_TELE := 1.0
const FALL_TIME := 0.35
const DOWN_TIME := 8.0
const REGROW_TIME := 1.4
const DANGER_MARGIN := 0.35  # marge de danger_at (comme is_danger de main)

var kind := "gashadokuro"
var main: Node
var hero: Node3D
var title := "Gashadokuro"
var hp := 90.0
var max_hp := 90.0
var dead := false
var max_hp_mult := 1.0  # difficulté du monde

var _state := "rise"
var _timer := 0.0
var _t := 0.0
var _cycle := 0
var _slam_n := 0  # alternance des mains pour les écrasements
var _phase2 := false
var _summoned := false
var _flash := 0.0
var _puff_t := 0.0

# buste
var _rig: Node3D
var _torso: Node3D
var _skull: Node3D
var _jaw: Node3D
var _soul: MeshInstance3D
var _bone_mat: StandardMaterial3D
var _eyes: Array = []  # pupilles glacées
var _vert_lamps: Array = []  # lampes des vertèbres, de la queue (0) au crâne (8)
var _lamp_mats: Array = []
var _halos: Array = []
var _shoulders: Array = []  # marqueurs d'épaule (gauche, droite)
var _fall_k := 0.0  # 0 = debout, 1 = effondré
var _sway := 0.0
var _wobble := 0.0

# mains
var _hands: Array = []  # Dictionary par main (0 = gauche, 1 = droite)
var _hand_hp_max := 15.0
var _active := -1
var _pending := -1
var _slam_target := Vector3.ZERO
var _sweep_side := 1.0
var _sweep_z := 0.0

# zones annoncées et stèles
var _zones: Array = []
var _stele_queue: Array = []  # [délai, centre]
var _steles: Array = []

# trait sur la colonne
# (ruées enchaînées comprises : tout ce qui suit le dernier end_stroke forme un seul tracé)
var _spine_order: Array = []  # indices dans l'ordre de passage
var _spine_seen := {}  # {indice: true}
var _lit := {}
var _clanged := false


func setup(k: String, m: Node) -> void:
	kind = k
	main = m
	hero = m.hero


func _ready() -> void:
	hp = 90.0
	hp *= max_hp_mult
	max_hp = hp
	_hand_hp_max = HAND_HP * max_hp_mult
	_build()
	_state = "rise"
	_timer = 0.0
	_apply_pose()


# ------------------------------------------------------------------ construction

func _ball(r: float) -> SphereMesh:
	# sphère low-poly
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 5
	return m


func _build() -> void:
	_rig = Node3D.new()
	_rig.top_level = true
	add_child(_rig)
	_bone_mat = Toon.mat(IVORY, true, 0.04)
	_bone_mat.emission_enabled = true
	_bone_mat.emission = ICE
	_bone_mat.emission_energy_multiplier = 0.0
	var dark := Toon.mat(SOCKET, false)

	# sol fendu et congères autour de la sortie
	var crack := Toon.disc(_rig, 2.4, Color(LAVENDER, 0.4), 0.012)
	crack.position = Vector3(0, 0.012, Z_BUST + 0.3)
	for i in 7:
		var a := float(i) / 7.0 * TAU + 0.3
		var c := Toon.part(_rig, Toon.box(Vector3(0.1, 0.01, 1.4)), Toon.flat(Color(Toon.SUMI, 0.55)), Vector3.ZERO)
		c.position = Vector3(sin(a) * 2.3, 0.016, Z_BUST + 0.3 + cos(a) * 2.3)
		c.rotation.y = a
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var snow := Toon.mat(SNOW)
	for sx in [-1.0, 1.0]:
		Toon.part(_rig, _ball(1.0), snow, Vector3(sx * 1.9, 0.0, Z_BUST + 0.6), Vector3(1.3, 0.42, 0.9))
	Toon.part(_rig, _ball(1.0), snow, Vector3(0.0, 0.0, Z_BUST - 1.0), Vector3(2.4, 0.5, 0.9))

	# buste : pivot au ras du sol, enterré au départ
	_torso = Node3D.new()
	_rig.add_child(_torso)
	_torso.position = Vector3(0, -7.5, Z_BUST)

	# colonne vertébrale (dos = -Z local : sur le dessus une fois effondré)
	for i in VERTS:
		var fi := float(i)
		var v := Node3D.new()
		_torso.add_child(v)
		v.position = Vector3(0.18 * sin(fi * 0.9), 0.35 + fi * 0.6, -0.45)
		var w := 1.0 - fi * 0.04
		Toon.part(v, Toon.box(Vector3(0.6 * w, 0.32, 0.5 * w)), _bone_mat, Vector3.ZERO)
		var spike := Toon.part(v, Toon.cyl(0.0, 0.13, 0.4, 4), _bone_mat, Vector3(0, 0, -0.38))
		spike.rotation.x = -PI / 2.0
		var lm := Toon.flat(ICE)
		var lamp := Toon.part(v, _ball(0.2 if i > 0 else 0.28), lm, Vector3(0, 0, -0.62))
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.visible = false
		_vert_lamps.append(lamp)
		_lamp_mats.append(lm)

	# cage thoracique : anneaux aplatis autour d'une lueur bleu glace
	var ribs := [1.0, 1.2, 1.28, 1.18, 0.98]
	for j in ribs.size():
		var rr := float(ribs[j])
		var tm := TorusMesh.new()
		tm.inner_radius = rr - 0.14
		tm.outer_radius = rr
		tm.rings = 10
		tm.ring_segments = 4
		var rib := Toon.part(_torso, tm, _bone_mat, Vector3(0, 1.3 + float(j) * 0.62, 0.3), Vector3(1.0, 1.0, 0.72))
		rib.rotation.x = 0.22
	Toon.part(_torso, Toon.box(Vector3(0.3, 2.5, 0.2)), _bone_mat, Vector3(0, 2.5, 1.12))
	_soul = Toon.part(_torso, _ball(0.55), Toon.flat(Color(ICE, 0.55)), Vector3(0, 2.5, 0.3))
	_soul.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# épaules, clavicules, omoplates
	Toon.part(_torso, Toon.box(Vector3(3.6, 0.28, 0.35)), _bone_mat, Vector3(0, 4.55, 0.05))
	for sx in [-1.0, 1.0]:
		Toon.part(_torso, _ball(0.4), _bone_mat, Vector3(sx * 1.9, 4.45, 0.0))
		var sc := Toon.part(_torso, Toon.box(Vector3(0.9, 1.2, 0.16)), _bone_mat, Vector3(sx * 0.95, 3.95, -0.62))
		sc.rotation.z = sx * 0.2
		var mk := Node3D.new()
		_torso.add_child(mk)
		mk.position = Vector3(sx * 1.95, 4.4, 0.0)
		_shoulders.append(mk)

	# crâne
	_skull = Node3D.new()
	_torso.add_child(_skull)
	_skull.position = Vector3(0, 6.0, 0.1)
	Toon.part(_skull, _ball(1.0), _bone_mat, Vector3(0, 0.2, 0), Vector3(1.0, 0.92, 1.05))
	Toon.part(_skull, Toon.box(Vector3(1.25, 0.6, 0.7)), _bone_mat, Vector3(0, -0.35, 0.45))
	Toon.part(_skull, Toon.box(Vector3(1.5, 0.18, 0.35)), _bone_mat, Vector3(0, 0.38, 0.82))
	for sx in [-1.0, 1.0]:
		Toon.part(_skull, _ball(0.28), dark, Vector3(sx * 0.4, 0.1, 0.86), Vector3(1.0, 0.85, 0.5))
		var eye := Toon.part(_skull, _ball(0.09), Toon.flat(ICE), Vector3(sx * 0.4, 0.1, 0.99))
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_eyes.append(eye)
	var nose := Toon.part(_skull, Toon.box(Vector3(0.18, 0.18, 0.1)), dark, Vector3(0, -0.22, 0.97))
	nose.rotation.z = PI / 4.0
	for k in 6:
		Toon.part(_skull, Toon.box(Vector3(0.14, 0.18, 0.1)), _bone_mat, Vector3(-0.4 + float(k) * 0.16, -0.62, 0.78))
	_jaw = Node3D.new()
	_skull.add_child(_jaw)
	_jaw.position = Vector3(0, -0.62, 0.1)
	Toon.part(_jaw, Toon.box(Vector3(1.05, 0.24, 0.85)), _bone_mat, Vector3(0, -0.2, 0.3))
	for k in 6:
		Toon.part(_jaw, Toon.box(Vector3(0.13, 0.16, 0.1)), _bone_mat, Vector3(-0.4 + float(k) * 0.16, -0.02, 0.66))

	# mains
	_hands.append(_build_hand(-1.0))
	_hands.append(_build_hand(1.0))


func _build_hand(side: float) -> Dictionary:
	var n := Node3D.new()
	_rig.add_child(n)
	var m := Toon.mat(IVORY, true, 0.04)
	m.emission_enabled = true
	m.emission = ICE
	m.emission_energy_multiplier = 0.0
	# paume, phalanges griffues (doigts vers +Z), pouce côté intérieur, poignet
	Toon.part(n, Toon.box(Vector3(1.2, 0.34, 1.05)), m, Vector3(0, 0.26, 0.05))
	var lamps: Array = []
	for f in 4:
		var fx := -0.45 + float(f) * 0.3
		Toon.part(n, Toon.box(Vector3(0.21, 0.21, 0.6)), m, Vector3(fx, 0.22, 0.85))
		var tip := Toon.part(n, Toon.box(Vector3(0.18, 0.18, 0.5)), m, Vector3(fx, 0.12, 1.38))
		tip.rotation.x = 0.4
		var kn := Toon.part(n, _ball(0.12), Toon.flat(ICE), Vector3(fx, 0.47, 0.55))
		kn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		kn.visible = false
		lamps.append(kn)
	var thumb := Toon.part(n, Toon.box(Vector3(0.22, 0.22, 0.65)), m, Vector3(-side * 0.72, 0.22, 0.3))
	thumb.rotation.y = -side * 0.6
	Toon.part(n, _ball(0.34), m, Vector3(0, 0.32, -0.62))
	n.position = _home(side)
	n.visible = false
	# bras en deux os + coude (placés chaque image entre l'épaule et le poignet)
	var upper := Toon.part(_rig, Toon.cyl(0.2, 0.24, 1.0, 6), _bone_mat, Vector3.ZERO)
	var fore := Toon.part(_rig, Toon.cyl(0.15, 0.19, 1.0, 6), _bone_mat, Vector3.ZERO)
	var elbow := Toon.part(_rig, _ball(0.3), _bone_mat, Vector3.ZERO)
	var shadow := Toon.disc(_rig, 1.2, Color(0, 0, 0, 0.18), 0.015)
	upper.visible = false
	fore.visible = false
	elbow.visible = false
	shadow.visible = false
	return {"node": n, "mat": m, "lamps": lamps, "hp": _hand_hp_max, "alive": true, "side": side,
		"upper": upper, "fore": fore, "elbow": elbow, "shadow": shadow, "grow": 0.0, "last": -1,
		"flash": 0.0, "crumble": 0.0}


func _make_stele(c: Vector3) -> Node3D:
	# stèle de cimetière (haka) coiffée de neige, tombe du ciel
	var s := Node3D.new()
	_rig.add_child(s)
	s.position = Vector3(c.x, 7.0, c.z)
	s.rotation.y = randf_range(-0.3, 0.3)
	var stone := Toon.mat(STONE)
	Toon.part(s, Toon.box(Vector3(1.0, 0.25, 0.7)), stone, Vector3(0, 0.12, 0))
	Toon.part(s, Toon.box(Vector3(0.62, 1.6, 0.3)), stone, Vector3(0, 1.05, 0))
	Toon.part(s, Toon.box(Vector3(0.68, 0.14, 0.36)), Toon.mat(SNOW), Vector3(0, 1.92, 0))
	Toon.part(s, Toon.box(Vector3(0.08, 0.9, 0.02)), Toon.mat(Toon.SUMI, false), Vector3(0, 1.1, 0.16))
	s.visible = false
	return s


# ------------------------------------------------------------------ interface avec main

## Vrai si la ruée a..b touche une main au sol pour la 1re fois de ce trait (dégâts gérés par main).
## Effondré : les vertèbres touchées sont notées, les dégâts tombent à la fin du trait.
func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if _state == "down":
		# hors ruée (image qui suit la fin du trait, bond d'ensō) : rien ne compte
		if hero.dashing:
			_spine_touch(a, b)
		return false
	if _state == "slam_down" and _active >= 0:
		var h: Dictionary = _hands[_active]
		if h["alive"] and int(h["last"]) != stroke_id and _seg_dist(_slam_target, a, b) < HAND_R + 0.55:
			h["last"] = stroke_id
			_pending = _active
			position = Vector3(_slam_target.x, 0, _slam_target.z)
			return true
	_clang_check(a, b)
	return false


func take_hit(dmg: float, _dir: Vector3) -> void:
	if dead:
		return
	var idx := _pending
	_pending = -1
	if idx < 0:
		_damage(dmg)
		return
	var h: Dictionary = _hands[idx]
	if not h["alive"]:
		return
	h["hp"] = float(h["hp"]) - dmg
	h["flash"] = 0.15
	# chaque coup sur une main entame aussi le squelette
	_damage(dmg)
	if dead:
		return
	if float(h["hp"]) <= 0.0:
		_break_hand(idx)


## Fin du trait : la colonne encaisse selon la plus longue suite de vertèbres prises dans l'ordre.
func end_stroke(_stroke_id: int) -> void:
	_clanged = false
	if _state == "down" and not dead:
		# la dernière image de la ruée n'est pas encore passée par check_dash
		var pa: Vector3 = main._prev_hero
		_spine_touch(pa, hero.position)
	var order: Array = _spine_order
	_spine_order = []
	_spine_seen = {}
	if order.is_empty():
		return
	_lit.clear()
	if dead or _state != "down":
		return
	var sp := _skull.global_position
	var at := Vector3(sp.x, 0, sp.z)
	position = at
	if _lis(order) >= SPINE_MIN:
		var dmg := SPINE_DMG * max_hp_mult
		main.float_text(at + Vector3(0, 0.8, 0), str(int(dmg)), Toon.VERMILION)
		main.big_hit(at)
		main.splash(at + Vector3(0, 0.6, 0), ICE, 30)
		main.shake = maxf(float(main.shake), 0.6)
		_flash = 0.3
		_damage(dmg)
		if not dead:
			# le crâne a cédé : le buste se relève aussitôt
			_timer = minf(_timer, 0.6)
	else:
		# dans le désordre : 1 par vertèbre
		var d2 := float(order.size())
		main.float_text(at + Vector3(0, 0.8, 0), str(order.size()), Toon.FOAM)
		main.clang(at)
		_damage(d2)


## Vrai si le point p est dans une attaque annoncée qui frappe d'ici eta secondes
## (toutes les zones vivantes, stèles en attente comprises).
func danger_at(p: Vector3, eta: float) -> bool:
	if dead:
		return false
	var lim := eta + DANGER_MARGIN
	for z in _zones:
		if float(z["t"]) >= lim:
			continue
		var c: Vector3 = z["c"]
		var hx := float(z["hx"])
		var hz := float(z["hz"])
		if z["shape"] == "disc":
			if Vector2(p.x - c.x, p.z - c.z).length() < hx + DANGER_MARGIN:
				return true
		elif absf(p.x - c.x) < hx + DANGER_MARGIN and absf(p.z - c.z) < hz + DANGER_MARGIN:
			return true
	for q in _stele_queue:
		var sq: Array = q
		if float(sq[0]) + STELE_TELE >= lim:
			continue
		var sc: Vector3 = sq[1]
		if Vector2(p.x - sc.x, p.z - sc.z).length() < 1.0 + DANGER_MARGIN:
			return true
	return false


## Contact : le pied du buste quand il est debout.
func touching_hero(p: Vector3) -> bool:
	if dead or _state in ["rise", "fall", "down", "regrow"]:
		return false
	return Vector2(p.x, p.z - (Z_BUST + 0.4)).length() < 1.5


## Dégâts de zone (techniques, pouvoirs) : touche la partie vulnérable la plus proche de `center` dans `radius`.
## Renvoie le point touché, ou Vector3.INF si rien n'est touché (boss invulnérable à cet instant, hors de portée, mort).
## Main posée au sol (écrasement) : ses PV et ceux du squelette. Effondré : une vertèbre,
## dégâts simples (l'ordre queue → crâne ne compte que pour les traits).
func aoe_hit(center: Vector3, radius: float, dmg: float, fx := true) -> Vector3:
	if dead:
		return Vector3.INF
	var fl := _flash
	if _state == "slam_down" and _active >= 0:
		var idx := _active
		var h: Dictionary = _hands[idx]
		if not h["alive"]:
			return Vector3.INF
		if Vector2(_slam_target.x - center.x, _slam_target.z - center.z).length() >= radius + HAND_R:
			return Vector3.INF
		h["hp"] = float(h["hp"]) - dmg
		if fx:
			h["flash"] = 0.15
		_damage(dmg)
		if not fx:
			_flash = fl
		if not dead and float(h["hp"]) <= 0.0:
			_break_hand(idx)
		return Vector3(_slam_target.x, 0.5, _slam_target.z)
	if _state == "down":
		var found := false
		var best := INF
		var at := Vector3.ZERO
		for lamp in _vert_lamps:
			var ln: Node3D = lamp
			var p := ln.global_position
			var d := Vector2(p.x - center.x, p.z - center.z).length()
			if d < radius + V_R and d < best:
				best = d
				found = true
				at = p
		if not found:
			return Vector3.INF
		_damage(dmg)
		if not fx:
			_flash = fl
		return at
	return Vector3.INF


# ------------------------------------------------------------------ outils

func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	return Toon.seg_dist_xz(p, a, b)


func _home(side: float) -> Vector3:
	return Vector3(side * 2.7, 1.6 + sin(_t * 1.6 + side) * 0.18, -4.3)


func _clamp_floor(p: Vector3, mx: float, mz: float) -> Vector3:
	# garde la zone dans l'arène et devant le buste
	return Vector3(clampf(p.x, -HALF.x + mx, HALF.x - mx), 0, clampf(p.z, -5.0 + mz * 0.5, HALF.y - mz))


## Plus longue sous-suite strictement croissante (queue → crâne).
func _lis(order: Array) -> int:
	var best := 0
	var lens: Array = []
	for i in order.size():
		var l := 1
		for j in i:
			if int(order[j]) < int(order[i]):
				l = maxi(l, int(lens[j]) + 1)
		lens.append(l)
		best = maxi(best, l)
	return best


func _place_bone(mi: MeshInstance3D, a: Vector3, b: Vector3, th: float) -> void:
	# cylindre de hauteur 1 étiré de a à b
	var d := b - a
	var l := d.length()
	if l < 0.05 or th < 0.01:
		mi.visible = false
		return
	var y := d / l
	var up := Vector3.UP
	if absf(y.dot(up)) > 0.97:
		up = Vector3.RIGHT
	var x := y.cross(up).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x * th, y * l, z * th), (a + b) * 0.5)
	mi.visible = true


func _add_zone(shape: String, c: Vector3, hx: float, hz: float, total: float, side: float) -> Dictionary:
	var n := Node3D.new()
	_rig.add_child(n)
	n.position = Vector3(c.x, 0, c.z)
	# annonce au langage commun (vfx) ; le balayage se remplit depuis le côté de la main
	var fill: Node3D
	if shape == "disc":
		fill = main.vfx.tele_disc(n, hx)
	else:
		fill = main.vfx.tele_rect(n, hx, hz, Vector2(side, 0))
	var z := {"node": n, "fill": fill, "shape": shape, "c": Vector3(c.x, 0, c.z), "hx": hx, "hz": hz,
		"t": total, "total": total, "side": side}
	_zones.append(z)
	return z


func _clear_zones() -> void:
	for z in _zones:
		var n: Node3D = z["node"]
		n.queue_free()
		if z.has("stele"):
			var s: Node3D = z["stele"]
			s.queue_free()
	_zones.clear()
	_stele_queue.clear()


func _clear_halos() -> void:
	for h in _halos:
		var n: Node3D = h
		n.queue_free()
	_halos.clear()


func _puff(delta: float, color: Color) -> void:
	_puff_t -= delta
	if _puff_t <= 0.0:
		_puff_t = 0.18
		main.splash(Vector3(randf_range(-1.8, 1.8), 0.2, Z_BUST + randf_range(-0.4, 1.4)), color, 6)


func _damage(d: float) -> void:
	hp -= d
	_flash = maxf(_flash, 0.15)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		_clear_zones()
		_clear_halos()
		for lamp in _vert_lamps:
			var ln: Node3D = lamp
			ln.visible = false
		for h in _hands:
			if h["alive"]:
				h["alive"] = false
				h["crumble"] = 0.6
		_state = "dying"
		_timer = 0.0
		var sp := _skull.global_position
		position = Vector3(sp.x, 0, sp.z)
		main.boss_killed(self)
	elif not _phase2 and hp <= max_hp * 0.4:
		# phase 2 : pluie de stèles, et des affamés sortent des côtes
		_phase2 = true
		if not _summoned:
			_summoned = true
			main.spawn_minions(["oni", "oni"])


func _break_hand(i: int) -> void:
	var h: Dictionary = _hands[i]
	h["alive"] = false
	h["crumble"] = 0.6
	var n: Node3D = h["node"]
	var p := Vector3(n.position.x, 0.4, n.position.z + HAND_OFF)
	main.big_hit(p)
	main.splash(p, IVORY, 26)
	main.splash(p, ICE, 12)
	for k in h["lamps"]:
		var ln: Node3D = k
		ln.visible = false
	if _active == i and _state in ["slam_down", "slam_up"]:
		_go_idle()
	var both := true
	for hh in _hands:
		if hh["alive"]:
			both = false
	if both:
		_start_collapse()


func _clang_check(a: Vector3, b: Vector3) -> void:
	# la lame ricoche sur les os invulnérables : retour lisible
	if _clanged or _state in ["rise", "fall", "down", "dying"]:
		return
	var pts: Array = []
	if _fall_k < 0.1:
		pts.append(Vector3(0, 0, Z_BUST + 0.4))
	for i in 2:
		var h: Dictionary = _hands[i]
		if not h["alive"] or float(h["grow"]) < 0.5:
			continue
		if i == _active and _state == "slam_down":
			continue
		var n: Node3D = h["node"]
		if n.position.y < 2.2:
			pts.append(n.position)
	for p in pts:
		var q: Vector3 = p
		if _seg_dist(q, a, b) < 1.2:
			_clanged = true
			main.clang(Vector3(q.x, 0.5, q.z))
			return


func _spine_touch(a: Vector3, b: Vector3) -> void:
	var seg := b - a
	var found: Array = []
	for i in VERTS:
		if _spine_seen.has(i):
			continue
		var lamp: Node3D = _vert_lamps[i]
		var p := lamp.global_position
		if _seg_dist(p, a, b) < V_R + 0.5:
			var tt := 0.0
			if seg.length_squared() > 0.0001:
				tt = (p - a).dot(seg) / seg.length_squared()
			found.append([tt, i])
	# plusieurs vertèbres dans un même segment : dans le sens de la ruée
	found.sort_custom(func(x, y): return x[0] < y[0])
	for f in found:
		var idx := int(f[1])
		_spine_seen[idx] = true
		_spine_order.append(idx)
		_lit[idx] = true
		var lamp2: Node3D = _vert_lamps[idx]
		main.small_hit(lamp2.global_position)


# ------------------------------------------------------------------ déroulé du combat

func _go_idle() -> void:
	_state = "idle"
	_active = -1
	_timer = 0.9 if _phase2 else 1.3


func _next_attack() -> void:
	_cycle += 1
	var live: Array = []
	for i in 2:
		var h: Dictionary = _hands[i]
		if h["alive"]:
			live.append(i)
	if live.is_empty():
		_start_collapse()
		return
	if _phase2 and _cycle % 4 == 0:
		_start_steles()
		return
	var sweep: bool = (_cycle % 4 == 2) if _phase2 else (_cycle % 3 == 0)
	if sweep:
		_active = int(live[_cycle % live.size()])
		var h2: Dictionary = _hands[_active]
		_sweep_side = float(h2["side"])
		_sweep_z = clampf(hero.position.z, -4.0, HALF.y - 1.3)
		_add_zone("rect", Vector3(0, 0, _sweep_z), HALF.x, 1.3, SWEEP_TELE, _sweep_side)
		_state = "sweep_tele"
		_timer = SWEEP_TELE
	else:
		# compteur à part : en phase 2, _cycle n'est jamais pair pour un écrasement
		_slam_n += 1
		_active = int(live[_slam_n % live.size()])
		_slam_target = _clamp_floor(hero.position, 1.0, 1.5)
		_add_zone("rect", _slam_target, 1.0, 1.5, SLAM_TELE, 0.0)
		_state = "slam_tele"
		_timer = SLAM_TELE


func _start_steles() -> void:
	_state = "stele"
	_active = -1
	_timer = STELE_TELE + 0.3 * 4.0 + 0.4
	var p0: Vector3 = hero.position
	for i in 5:
		var c := p0
		if i > 0:
			c = p0 + Vector3(randf_range(-2.8, 2.8), 0, randf_range(-2.8, 2.8))
		_stele_queue.append([0.3 * float(i), _clamp_floor(c, 1.0, 1.0)])


func _start_collapse() -> void:
	# le buste vacille puis s'effondre vers l'avant : bande annoncée sous la colonne
	_state = "totter"
	_active = -1
	_timer = COLLAPSE_TELE
	_add_zone("rect", Vector3(0, 0, -3.0), 1.3, 3.3, COLLAPSE_TELE + FALL_TIME, 0.0)


func _impact() -> void:
	_fall_k = 1.0
	_sway = 0.0
	_wobble = 0.0
	_apply_pose()
	_state = "down"
	_timer = DOWN_TIME
	main.shake = maxf(float(main.shake), 0.7)
	_lit.clear()
	for i in VERTS:
		var lamp: Node3D = _vert_lamps[i]
		lamp.visible = true
		var p := lamp.global_position
		var halo := Toon.disc(_rig, 0.55 if i > 0 else 0.8, Color(ICE, 0.3), 0.02)
		halo.position = Vector3(p.x, 0.02, p.z)
		_halos.append(halo)
		if i % 2 == 0:
			main.splash(Vector3(p.x, 0.3, p.z), Toon.FOAM, 8)


func _start_regrow() -> void:
	_state = "regrow"
	_timer = REGROW_TIME
	_lit.clear()
	for lamp in _vert_lamps:
		var ln: Node3D = lamp
		ln.visible = false
	_clear_halos()
	for h in _hands:
		var n: Node3D = h["node"]
		h["alive"] = true
		h["hp"] = _hand_hp_max * 0.6
		h["grow"] = 0.0
		h["crumble"] = 0.0
		h["last"] = -1
		n.position = _home(float(h["side"]))
		n.rotation = Vector3.ZERO


func _apply_pose() -> void:
	_torso.rotation = Vector3(lerpf(LEAN, FALLEN, _fall_k) + _sway, 0.0, _wobble)
	# effondré, le crâne se relève pour regarder la caméra
	_skull.rotation.x = -_fall_k * 1.25


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash -= delta
	_bone_mat.emission_energy_multiplier = 0.9 if _flash > 0.0 else 0.0
	_update_state(delta)
	_update_stele_queue(delta)
	_update_zones(delta)
	_update_steles(delta)
	_update_hands(delta)
	_update_look(delta)


func _update_state(delta: float) -> void:
	match _state:
		"rise":
			_timer += delta
			var k := clampf(_timer / RISE_TIME, 0.0, 1.0)
			_torso.position.y = lerpf(-7.5, -0.3, 1.0 - pow(1.0 - k, 3.0))
			if k < 1.0:
				main.shake = maxf(float(main.shake), 0.12)
				_puff(delta, Toon.FOAM)
			for h in _hands:
				h["grow"] = clampf((_timer - RISE_TIME) / 0.7, 0.0, 1.0)
			if _timer >= RISE_TIME + 0.7:
				_go_idle()
		"idle":
			_timer -= delta
			if _timer <= 0.0:
				_next_attack()
		"slam_tele":
			_timer -= delta
			if _timer <= 0.0:
				# la main s'abat (les dégâts viennent de la zone qui expire en même temps)
				_state = "slam_down"
				_timer = SLAM_STAY
				main.shake = maxf(float(main.shake), 0.35)
				main.splash(_slam_target + Vector3(0, 0.2, 0), Toon.FOAM, 16)
		"slam_down":
			_timer -= delta
			if _timer <= 0.0:
				_state = "slam_up"
				_timer = 0.5
		"slam_up":
			_timer -= delta
			if _timer <= 0.0:
				_go_idle()
		"sweep_tele":
			_timer -= delta
			if _timer <= 0.0:
				_state = "sweep"
				_timer = SWEEP_TIME
		"sweep":
			_timer -= delta
			if _active >= 0:
				var hs: Dictionary = _hands[_active]
				var hn: Node3D = hs["node"]
				_puff_t -= delta
				if _puff_t <= 0.0:
					_puff_t = 0.06
					main.splash(Vector3(hn.position.x, 0.2, hn.position.z), Toon.FOAM, 5)
			if _timer <= 0.0:
				_state = "sweep_back"
				_timer = 0.7
		"sweep_back":
			_timer -= delta
			if _timer <= 0.0:
				_go_idle()
		"stele":
			_timer -= delta
			if _timer <= 0.0 and _stele_queue.is_empty():
				_go_idle()
		"totter":
			_timer -= delta
			var k2 := clampf(1.0 - _timer / COLLAPSE_TELE, 0.0, 1.0)
			_sway = -0.14 * k2
			_wobble = sin(_t * 16.0) * 0.05 * k2
			if _timer <= 0.0:
				_state = "fall"
				_timer = FALL_TIME
		"fall":
			_timer -= delta
			var k3 := clampf(1.0 - _timer / FALL_TIME, 0.0, 1.0)
			_fall_k = k3 * k3
			_sway = -0.14 * (1.0 - k3)
			_wobble = 0.0
			if _timer <= 0.0:
				_impact()
		"down":
			_timer -= delta
			if _timer <= 0.0:
				_start_regrow()
		"regrow":
			_timer -= delta
			var k4 := clampf(1.0 - _timer / REGROW_TIME, 0.0, 1.0)
			_fall_k = 1.0 - smoothstep(0.0, 1.0, k4)
			for h in _hands:
				h["grow"] = k4
			if _timer <= 0.0:
				_fall_k = 0.0
				_go_idle()
		"dying":
			_timer += delta
			_wobble = sin(_t * 22.0) * 0.05
			if _timer > 0.5:
				_torso.position.y -= delta * 2.4
			_puff(delta, IVORY)
			if _timer > 3.2:
				queue_free()


func _update_stele_queue(delta: float) -> void:
	for i in range(_stele_queue.size() - 1, -1, -1):
		var q: Array = _stele_queue[i]
		q[0] = float(q[0]) - delta
		if float(q[0]) <= 0.0:
			var c: Vector3 = q[1]
			var z := _add_zone("disc", c, 1.0, 1.0, STELE_TELE, 0.0)
			z["stele"] = _make_stele(c)
			_stele_queue.remove_at(i)


func _update_zones(delta: float) -> void:
	for i in range(_zones.size() - 1, -1, -1):
		var z: Dictionary = _zones[i]
		var t := float(z["t"]) - delta
		z["t"] = t
		var k := clampf(1.0 - t / float(z["total"]), 0.0, 1.0)
		var fill: Node3D = z["fill"]
		main.vfx.tele_update(fill, k, t)
		if z.has("stele"):
			var s: Node3D = z["stele"]
			s.visible = t < 0.45
			var u := clampf(t / 0.45, 0.0, 1.0)
			s.position.y = 7.0 * u * u
		if t <= 0.0:
			_strike_zone(z)
			var n: Node3D = z["node"]
			n.queue_free()
			_zones.remove_at(i)


func _strike_zone(z: Dictionary) -> void:
	var c: Vector3 = z["c"]
	var hx := float(z["hx"])
	var hz := float(z["hz"])
	if z["shape"] == "disc":
		main.enemy_strike(c, hx)
	else:
		# rectangle : on frappe au point du rectangle le plus proche du héros
		var p: Vector3 = hero.position
		var q := Vector3(clampf(p.x, c.x - hx, c.x + hx), 0, clampf(p.z, c.z - hz, c.z + hz))
		main.enemy_strike(q, 0.12)
	main.splash(c + Vector3(0, 0.3, 0), Toon.FOAM, 12)
	if z.has("stele"):
		var s: Node3D = z["stele"]
		s.visible = true
		s.position.y = 0.0
		main.splash(c + Vector3(0, 0.3, 0), STONE, 8)
		_steles.append({"node": s, "life": 2.2})


func _update_steles(delta: float) -> void:
	for i in range(_steles.size() - 1, -1, -1):
		var e: Dictionary = _steles[i]
		var life := float(e["life"]) - delta
		e["life"] = life
		var s: Node3D = e["node"]
		if life < 0.5:
			s.position.y -= delta * 4.0
		if life <= 0.0:
			s.queue_free()
			_steles.remove_at(i)


func _hand_goal(i: int) -> Vector3:
	var h: Dictionary = _hands[i]
	var side := float(h["side"])
	var home := _home(side)
	if i != _active:
		if _state == "stele":
			return home + Vector3(0, 1.2, 0)  # mains levées : il invoque les stèles
		return home
	match _state:
		"slam_tele":
			return Vector3(_slam_target.x, 3.4, _slam_target.z - HAND_OFF)
		"slam_down":
			return Vector3(_slam_target.x, 0.0, _slam_target.z - HAND_OFF)
		"sweep_tele":
			return Vector3(side * (HALF.x + 0.4), 0.5, _sweep_z)
		"sweep":
			var k := clampf(1.0 - _timer / SWEEP_TIME, 0.0, 1.0)
			return Vector3(lerpf(side, -side, k) * (HALF.x + 0.4), 0.5, _sweep_z)
	return home


func _update_hands(delta: float) -> void:
	for i in 2:
		var h: Dictionary = _hands[i]
		var n: Node3D = h["node"]
		var side := float(h["side"])
		var upper: MeshInstance3D = h["upper"]
		var fore: MeshInstance3D = h["fore"]
		var elbow: MeshInstance3D = h["elbow"]
		var shadow: MeshInstance3D = h["shadow"]
		var m: StandardMaterial3D = h["mat"]
		if not h["alive"]:
			upper.visible = false
			fore.visible = false
			elbow.visible = false
			shadow.visible = false
			var cr := float(h["crumble"])
			if cr > 0.0:
				# la main se disloque et s'enfonce
				cr -= delta
				h["crumble"] = cr
				n.scale = Vector3.ONE * HAND_SCALE * maxf(cr / 0.6, 0.02)
				n.position.y -= delta * 2.0
				n.rotation.z += delta * side * 2.0
				if cr <= 0.0:
					n.visible = false
			else:
				n.visible = false
			continue
		var grow := float(h["grow"])
		var on := grow > 0.01
		n.visible = on
		elbow.visible = on
		shadow.visible = on
		if not on:
			upper.visible = false
			fore.visible = false
			continue
		var goal := _hand_goal(i)
		var snap := i == _active and _state in ["slam_down", "sweep"]
		if snap:
			n.position = goal
		else:
			var rate := 11.0 if (i == _active and _state == "slam_tele") else 6.0
			n.position = n.position.lerp(goal, 1.0 - exp(-rate * delta))
		var yaw := -side * 0.25
		if i == _active and _state in ["sweep_tele", "sweep"]:
			yaw = atan2(-side, 0.0)
		elif i == _active and _state in ["slam_tele", "slam_down"]:
			yaw = 0.0
		n.rotation = Vector3(0.0, lerp_angle(n.rotation.y, yaw, 1.0 - exp(-8.0 * delta)), 0.0)
		# éclat au coup reçu, lueur glacée quand la main est tranchable
		var fl := float(h["flash"])
		if fl > 0.0:
			h["flash"] = fl - delta
		var vul := i == _active and _state == "slam_down"
		n.scale = Vector3.ONE * HAND_SCALE * grow * (1.12 if fl > 0.0 else 1.0)
		m.emission_energy_multiplier = 1.0 if fl > 0.0 else (0.3 + 0.2 * sin(_t * 8.0) if vul else 0.0)
		for k in h["lamps"]:
			var ln: Node3D = k
			ln.visible = vul
		# bras : épaule → coude → poignet
		var mk: Node3D = _shoulders[i]
		var sh := mk.global_position
		var wr: Vector3 = n.transform * Vector3(0, 0.32, -0.62)
		var el := (sh + wr) * 0.5 + Vector3(side * 1.1, 1.0, 0.3)
		_place_bone(upper, sh, el, grow)
		_place_bone(fore, el, wr, grow)
		elbow.position = el
		elbow.scale = Vector3.ONE * grow
		shadow.position = Vector3(n.position.x, 0.015, n.position.z + 0.4)
		var ss := clampf(1.3 - n.position.y * 0.15, 0.4, 1.3) * grow
		shadow.scale = Vector3(ss, 1, ss)


func _update_look(delta: float) -> void:
	_apply_pose()
	# le crâne suit le héros du regard tant qu'il est debout
	var yaw := 0.0
	if _fall_k < 0.05 and not dead:
		var sp := _skull.global_position
		yaw = clampf(atan2(hero.position.x - sp.x, hero.position.z - sp.z), -0.6, 0.6)
	_skull.rotation.y = lerp_angle(_skull.rotation.y, yaw, 1.0 - exp(-3.0 * delta))
	# mâchoire : claque des dents, grande ouverte quand il vacille
	var jaw := 0.08 + 0.1 * maxf(0.0, sin(_t * 9.0))
	if _state == "totter" or _state == "fall":
		jaw = 0.5
	elif _state == "down" or _state == "stele":
		jaw = 0.1 + 0.18 * maxf(0.0, sin(_t * 22.0))
	_jaw.rotation.x = jaw
	_soul.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 3.0))
	var eye_s := 1.7 if _state == "down" else 1.0
	for e in _eyes:
		var en: Node3D = e
		en.scale = Vector3.ONE * eye_s
	# vertèbres : vague de lumière de la queue vers le crâne (indique le sens du trait)
	if _state == "down":
		var blink := _timer > 1.5 or fmod(_t, 0.2) < 0.13
		for i in VERTS:
			var lamp: Node3D = _vert_lamps[i]
			var lm: StandardMaterial3D = _lamp_mats[i]
			lamp.visible = blink
			var s := 1.0 + 0.45 * maxf(0.0, sin(_t * 5.0 - float(i) * 0.8))
			if _lit.has(i):
				s = 1.5
				lm.albedo_color = Color.WHITE
			else:
				lm.albedo_color = ICE
			lamp.scale = Vector3.ONE * s


# ------------------------------------------------------------------ robot testeur

## Trait qu'un bon joueur tracerait maintenant (points au sol depuis le héros), ou vide = attendre.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	if dead:
		return none
	if _state == "slam_down" and _active >= 0 and _timer > 0.2:
		var hd: Dictionary = _hands[_active]
		if not hd["alive"]:
			return none
		# main posée : trait droit (iaï) à travers elle, sans finir au pied du buste
		var tgt := Vector3(_slam_target.x, 0, _slam_target.z)
		var line := _bot_line(h, tgt, 7.3)
		var end: Vector3 = line[line.size() - 1]
		if Vector2(end.x, end.z - (Z_BUST + 0.4)).length() < 1.9:
			return _bot_dense([h, tgt, tgt + Vector3(0, 0, 1.2)])
		return line
	if _state == "down" and _timer > 0.5:
		# colonne : de la queue au crâne, d'un seul trait
		var lamps: Array = []
		for lamp in _vert_lamps:
			var ln: Node3D = lamp
			var gp := ln.global_position
			lamps.append(Vector3(gp.x, 0, gp.z))
		var l0: Vector3 = lamps[0]
		var l8: Vector3 = lamps[VERTS - 1]
		var axis := (l8 - l0).normalized()
		var start := _bot_clamp(l0 - axis * 1.0)
		if h.distance_to(start) > 1.2:
			# placement derrière la queue, en contournant la colonne
			return _bot_route([h, start], lamps, 1.1)
		var way: Array = [h]
		way.append_array(lamps)
		way.append(l8 + axis * 1.2)
		return _bot_dense(way)
	return none


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
