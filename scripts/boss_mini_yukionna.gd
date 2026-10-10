extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 3 (Cent Contes) — Yuki-onna, la femme des neiges (24 PV × monde), flotte.
##  Le voile de givre est son bouclier (10) : un coup ne fait qu'effleurer.
##  Souffle glacé : cône 70° sur 6 m annoncé 1.1 s. Il laisse un SENTIER DE GIVRE de 5 cristaux,
##  du plus petit (loin d'elle) au plus grand (à ses pieds), pendant 4.5 s.
##  Mécanique de trait : trancher les cristaux DANS L'ORDRE, du petit au grand, en un seul trait
##  (au moins 4 dans l'ordre) brise tout le voile : figée 5.5 s, vulnérable (dégâts ×2). Dans le
##  désordre (2 cristaux ou plus) : un éclat de voile par cristal et le sentier fond.
##  Prépare la colonne de Gashadokuro. Puis : salve de 3 boules de neige (lueur 0.7 s).
## Apparence (direction « Masque d'encre », règles en tête de yokai_ink_w1.gd) : la yukionna commune de
## yokai_ink_w3.gd en GARDIENNE, deux fois plus haute (3,7 m) — corps d'encre bleutée sur le rig des yōkai
## d'encre (ink_rig.gd : flotteur, bras, gouttes, clips procéduraux), CHÂLE DE NEIGE IMMENSE bordé d'or qui
## couvre les épaules et traîne dans le dos, masque de ko-omote cerné d'or aux yeux mi-clos de lueur de glace,
## longues nappes de cheveux, COURONNE D'OR hérissée de cristaux de glace, glaçons qui pendent sous le corps.
## Seule l'apparence a changé : PV, voile, cristaux, zones, rythme, interface et robot sont ceux d'avant.

const Yokai = preload("res://scripts/yokai_parts.gd")
const W3 = preload("res://scripts/yokai_ink_w3.gd")  # palette du monde 3 (encre bleutée, glace, neige, étoffe)
const ICE := Color("#BFD6E3")
const SNOW := Color("#F3F5F7")
const LAVENDER := Color("#8C8FA8")
const HEIGHT := 3.7  # la commune fait 1,85 m (enemy.KIND_H)
const CRYSTALS := 5
const CRYS_NEAR := 1.5  # distance du plus grand cristal
const CRYS_STEP := 1.1
const CRYS_HIT := 0.8  # distance trait-cristal pour le toucher
const ORDER_MIN := 4
const SHIELD := 10.0
const CRYS_CHIP := 0.8  # voile ébréché par cristal pris dans le désordre
const BREATH_HALF := 0.61  # 35° de part et d'autre
const BREATH_LEN := 6.0
const BREATH_TELE := 1.1
const PATH_TIME := 4.5
const VOLLEY_TELE := 0.7
const HOVER := 0.5

var _veil: Node3D
var _crys: Array = []  # {node, spike, pos, lit}, du plus petit (0) au plus grand
var _order: Array = []
var _seen := {}
var _breath_dir := Vector3(0, 0, 1)
var _glow := 0.3
var _death_played := false


func _ready() -> void:
	title = "Yuki-onna"
	hp = 24.0 * max_hp_mult
	max_hp = hp
	radius = 0.8
	_build()
	_shield_init(SHIELD, Vector3(1.5, 2.1, 1.5), 1.9)
	_state = "spawn"
	_timer = 1.2


# ------------------------------------------------------------------ construction

## Marionnette de la gardienne : le rig des yōkai d'encre (ink_rig.gd) habillé des pièces bâties ici (le genre
## « yukionna_o » n'existe dans aucun yokai_ink_wN.gd : _dress est remplacé, le reste du rig sert tel quel).
## Les noms d'animations KayKit du combat (Idle, Spellcast_Shoot, Hit_A, Death_A) deviennent ses clips.
class Rig extends "res://scripts/ink_rig.gd":
	static var _cache := {}  # léger -> pièces

	func setup(k: String, height := H_REF) -> void:
		super.setup(k, height)
		# bras tendus devant : le souffle part des deux mains (comme la yukionna commune)
		_rest_r = Vector3(1.5, 0, 0.35)
		_rest_l = Vector3(1.5, 0, -0.35)
		_eval(0.0)
		for j in SLOTS:
			_out[j] = _tgt[j]
		_apply()

	## Le masque regarde un peu plus la caméra que celui des communs (la couronne ne doit pas le cacher).
	func _apply() -> void:
		super._apply()
		_head.rotation.x += 0.22

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
		var w := 0.95
		var b := Yokai.Mesher.new(1.0)
		# corps de la yukionna commune, en variante dorée (liserés et oreilles d'or de l'élite)
		Yokai.ink_body(b, w, W3.INK_SNOW, W3.W3_CLOTH, W3.W3_WAVE, Toon.GOLD, lite, true)
		# châle immense : cône de neige drapé des épaules jusqu'à l'obi, bordé d'un liseré d'or ; deux pans qui
		# tombent devant de chaque côté du masque ; longue traîne de neige dans le dos
		b.cyl(Vector3(0, 0.98, 0.02), Vector3(0.74, 0.36, 0.68), SNOW, Vector3.ZERO, 0.42, 14)
		b.cyl(Vector3(0, 0.81, 0.02), Vector3(0.76, 0.035, 0.7), Toon.GOLD, Vector3.ZERO, 1.0, 14)
		b.cyl(Vector3(0, 0.6, 0.44), Vector3(0.5, 1.0, 0.12), SNOW, Vector3(0.16, 0, 0), 0.72, 10)
		for s in [-1.0, 1.0]:
			var x := float(s)
			b.cyl(Vector3(x * 0.44, 0.68, -0.2), Vector3(0.16, 0.72, 0.09), SNOW, Vector3(-0.08, 0, x * 0.1), 0.75, 8)
		if not lite:
			# flocons brodés sur le bord du châle (lisibles du dessus), broche d'or sur la poitrine
			for i in 10:
				var ang := TAU * (float(i) + 0.5) / 10.0
				b.ball(Vector3(sin(ang) * 0.66, 0.9, 0.02 + cos(ang) * 0.6), Vector3(0.05, 0.05, 0.02), W3.ICE_L, Vector3(0, ang, 0), 6)
			b.ball(Vector3(0, 0.9, -0.44 * w), Vector3(0.07, 0.07, 0.03), Toon.GOLD, Vector3.ZERO, 8)
		d["body"] = b.mesh()
		var a := Yokai.Mesher.new(1.0)
		var f := Yokai.Mesher.new(1.0)
		# masque de ko-omote cerné d'or, un peu plus haut que celui de la commune
		Yokai.mask_plate(a, W3.MASK_SNOW, 1.0, 1.08, true)
		Yokai.mask_brows(a, Toon.SUMI, false, 1.0)
		for sx in [-1.0, 1.0]:
			var x := float(sx)
			# yeux mi-clos : paupière noire, lueur de glace dessous
			a.box(Vector3(x * 0.11, 0.06, Yokai.FACE_Z), Vector3(0.12, 0.024, 0.015), Toon.SUMI, Vector3(0, 0, -x * 0.1))
			f.ball(Vector3(x * 0.11, 0.035, Yokai.FACE_Z - 0.01), Vector3(0.05, 0.016, 0.01), W3.ICE_L, Vector3.ZERO, 6)
		a.box(Vector3(0, -0.15, Yokai.FACE_Z), Vector3(0.08, 0.03, 0.02), W3.ICE_D)
		# larme d'or au front
		a.ball(Vector3(0, 0.27, Yokai.FACE_Z + 0.005), Vector3(0.025, 0.04, 0.012), Toon.GOLD, Vector3.ZERO, 6)
		# chevelure : calotte, deux longues nappes jusqu'à l'obi, mèches devant les épaules
		a.ball(Vector3(0, 0.14, 0.12), Vector3(0.4, 0.32, 0.36), Yokai.HAIR, Vector3.ZERO, 8)
		for sx in [-1.0, 1.0]:
			var x := float(sx)
			a.stick(Vector3(x * 0.33, 0.1, -0.06), Vector3(0.14, 1.25, 0.1), Yokai.HAIR, Vector3(PI, 0, x * 0.04))
			if not lite:
				a.stick(Vector3(x * 0.2, -0.08, -0.32), Vector3(0.05, 0.55, 0.04), Yokai.HAIR, Vector3(PI + 0.1, 0, x * 0.1))
		# couronne d'or : bandeau sur la chevelure, cristaux de glace plantés dedans, petites pointes d'or entre eux
		# (posée en arrière du masque et penchée en arrière : vue en plongée, elle ne cache pas le visage)
		a.cyl(Vector3(0, 0.27, 0.16), Vector3(0.31, 0.07, 0.29), Toon.GOLD, Vector3(-0.3, 0, 0), 0.88, 12)
		var n := 3 if lite else 7
		for i in n:
			var k := (float(i) / float(n - 1) - 0.5) * 2.0
			var h := 0.44 - 0.16 * absf(k)
			a.spike(Vector3(k * 0.27, 0.3 - 0.06 * absf(k), 0.18 + 0.04 * absf(k)), 0.055, h, W3.ICE_L, Vector3(-0.55, 0, -k * 0.5), 0.0, 4)
		if not lite:
			for i in 6:
				var k2 := (float(i) / 5.0 - 0.5) * 2.0
				a.spike(Vector3(k2 * 0.24, 0.3, 0.18 + 0.03 * absf(k2)), 0.025, 0.12, Toon.GOLD, Vector3(-0.55, 0, -k2 * 0.5), 0.0, 4)
			# disque d'or (soleil pâle) derrière la pointe centrale
			a.cyl(Vector3(0, 0.42, 0.32), Vector3(0.14, 0.02, 0.14), Toon.GOLD, Vector3(PI / 2.0 - 0.55, 0, 0), 1.0, 12)
		d["head"] = Yokai.two(a, f)
		# bras d'encre (comme Yokai.ink_arm) avec un bracelet d'or
		var ar := Yokai.Mesher.new(1.0)
		ar.cyl(Vector3(0, -0.2, 0), Vector3(0.085, 0.4, 0.085), W3.INK_SNOW, Vector3(PI, 0, 0), 0.7, 7)
		ar.ball(Vector3(0, -0.43, 0), Vector3(0.1, 0.085, 0.1), W3.INK_SNOW)
		ar.cyl(Vector3(0, -0.33, 0), Vector3(0.09, 0.035, 0.09), Toon.GOLD, Vector3.ZERO, 1.0, 8)
		d["arm"] = ar.mesh()
		# glaçons : pointe de glace qui pend d'une goutte d'encre
		var t := Yokai.Mesher.new(1.0)
		t.ball(Vector3.ZERO, Vector3(0.065, 0.065, 0.065), W3.INK_SNOW, Vector3.ZERO, 6)
		t.spike(Vector3(0, 0.02, 0), 0.055, 0.36, W3.ICE_L, Vector3(PI, 0, 0), 0.0, 5)
		d["drip"] = t.mesh()
		var m := 3 if lite else 6
		var pts := PackedVector3Array()
		for i in m:
			var ang := TAU * (float(i) + 0.3) / float(m)
			pts.append(Vector3(sin(ang) * 0.2, 0.4, cos(ang) * 0.18))
		d["drips"] = pts
		d["spread"] = 0.15
		return d


func _build() -> void:
	Toon.disc(self, 0.8, Color(0, 0, 0, 0.12))
	body = Node3D.new()
	add_child(body)
	body.rotation.y = PI  # elle entre face au héros (le corps regarde vers -Z ; _face la tourne ensuite)
	ch = Rig.new()
	body.add_child(ch)
	# le bas de l'encre s'effile à 0,6 m au-dessus de l'origine du rig : un peu enfoncé pour que les glaçons frôlent le sol
	ch.position = Vector3(0, -0.2, 0)
	ch.setup("yukionna_o", HEIGHT)
	ch.idle = "Idle"
	ch.play("Idle")
	# voile de givre : bulle de glace autour du corps, flocons qui tournent
	_veil = Node3D.new()
	body.add_child(_veil)
	Toon.part(_veil, Toon.sphere(1.0), Toon.flat(Color(ICE, 0.3)), Vector3(0, 1.8, 0), Vector3(1.35, 1.95, 1.35))
	for k in 6:
		var a := TAU * float(k) / 6.0
		var flake := Toon.part(_veil, Toon.box(Vector3(0.06, 0.06, 0.4)), Toon.flat(Color(SNOW, 0.9)), Vector3(cos(a) * 1.35, 1.8 + 0.7 * sin(a * 2.0), sin(a) * 1.35))
		flake.rotation.y = -a
	_make_stars(body, 4.1)
	body.scale = Vector3.ONE * 0.01


func _spawn_path() -> void:
	_clear_path(false)
	var me := Vector3(position.x, 0, position.z)
	for i in CRYSTALS:
		# 0 = le plus loin (petit), CRYSTALS - 1 = à ses pieds (grand)
		var dist := CRYS_NEAR + CRYS_STEP * float(CRYSTALS - 1 - i)
		var p := me + _breath_dir * dist
		p = Vector3(clampf(p.x, -HALF.x + 0.5, HALF.x - 0.5), 0, clampf(p.z, -HALF.y + 0.5, HALF.y - 0.5))
		var n := Node3D.new()
		n.top_level = true
		add_child(n)
		n.global_position = p
		var size := 0.45 + 0.17 * float(i)
		Toon.disc(n, 0.3 + 0.12 * float(i), Color(ICE, 0.45), 0.02)
		var spike := Node3D.new()
		n.add_child(spike)
		Toon.part(spike, Toon.cyl(0.0, 0.22, 1.0, 5), Toon.mat_shared(ICE), Vector3(0, 0.5, 0))
		var side := Toon.part(spike, Toon.cyl(0.0, 0.12, 0.6, 5), Toon.mat_shared(SNOW), Vector3(0.16, 0.28, 0.05))
		side.rotation.z = -0.5
		spike.scale = Vector3.ONE * size
		_crys.append({"node": n, "spike": spike, "pos": p, "lit": false, "size": size})


## Le sentier fond (ou éclate vers elle si `burst`).
func _clear_path(burst: bool) -> void:
	for c: Dictionary in _crys:
		var n: Node3D = c["node"]
		if is_instance_valid(n):
			var p: Vector3 = c["pos"]
			main.splash(p + Vector3(0, 0.5, 0), ICE if burst else SNOW, 8 if burst else 4)
			n.queue_free()
	_crys.clear()
	_order = []
	_seen = {}


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if _state == "path" and hero.dashing:
		_crys_touch(a, b)
	if _state == "spawn" or _state == "dying":
		return false
	# figée : coup plein (×2) ; sous le voile de givre : il effleure et use le voile
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


## Fin du trait : les cristaux pris du petit au grand brisent le voile.
func end_stroke(_stroke_id: int) -> void:
	if not dead and _state == "path":
		# la dernière image de la ruée n'est pas forcément passée par check_dash
		var pa: Vector3 = main._prev_hero
		_crys_touch(pa, hero.position)
	var order: Array = _order
	_order = []
	_seen = {}
	for c: Dictionary in _crys:
		c["lit"] = false
	if dead or _state != "path" or order.size() < 2:
		# un seul cristal effleuré : rien ne se passe
		return
	if _lis(order) >= ORDER_MIN:
		_shatter()
		return
	# dans le désordre : le givre se brise, le voile n'est qu'ébréché
	var last: Dictionary = _crys[int(order[order.size() - 1])]
	var lp: Vector3 = last["pos"]
	main.clang(lp)
	_clear_path(false)
	_start_volley()
	_shield_dmg(CRYS_CHIP * float(order.size()))


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state == "spawn" or _state == "dying":
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.0, 0)


func _zone_fire(z: Dictionary) -> void:
	if String(z["tag"]) != "breath":
		return
	# le souffle tombe : le héros dans le cône est gelé (1 coup)
	if _in_zone(z, hero.position, 0.2):
		main._hurt_hero()
	var o: Vector3 = z["c"]
	for k in 4:
		main.splash(o + _breath_dir * (1.5 + 1.4 * float(k)) + Vector3(0, 0.4, 0), SNOW, 6)
	main.shake = maxf(float(main.shake), 0.08)
	_spawn_path()
	_state = "path"
	_timer = PATH_TIME
	_glow = 0.3


func _on_die() -> void:
	_clear_path(true)
	_veil.visible = false


## Voile brisé : figée, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	_clear_path(true)
	_state = "frozen"
	_glow = 0.3
	_veil.visible = false
	ch.play_once("Hit_A", 1.2)


func _on_shield_back() -> void:
	if _state != "frozen":
		return
	_state = "reform"
	_timer = 0.6
	_veil.visible = true
	_veil.scale = Vector3.ONE * 0.05


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var to := hero.position - position
	to.y = 0
	var dist := to.length()
	var dir := _dir_to_hero()
	match _state:
		"spawn":
			_timer -= delta
			body.scale = Vector3.ONE * clampf(1.0 - _timer / 1.2, 0.01, 1.0)
			if _timer <= 0.0:
				body.scale = Vector3.ONE
				_state = "drift"
				_timer = 1.2
		"drift":
			# glisse pour garder ses distances, plutôt dans la moitié haute
			var side := Vector3(-dir.z, 0, dir.x) * sin(_t * 0.7)
			var want := -1.0 if dist < 4.5 else (1.0 if dist > 6.5 else 0.0)
			var up := Vector3(0, 0, -1.0 if position.z > -1.5 else (1.0 if position.z < -6.5 else 0.0))
			position += (dir * want + side * 0.8 + up * 0.6) * 1.6 * delta
			main.clamp_to_arena(self, radius)
			_face(dir, delta)
			_timer -= delta
			if _timer <= 0.0:
				_breath_dir = dir
				_zone_fan(position, _breath_dir, BREATH_HALF, BREATH_LEN, BREATH_TELE, "breath")
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / BREATH_TELE)
				_state = "breath"
				_timer = BREATH_TELE
		"breath":
			_face(_breath_dir, delta, 8.0)
			_timer -= delta
			_glow = 0.3 + 0.9 * clampf(1.0 - _timer / BREATH_TELE, 0.0, 1.0)
		"path":
			_face(dir, delta, 3.0)
			_timer -= delta
			if _timer <= 0.0:
				_clear_path(false)
				_start_volley()
		"volley":
			_face(dir, delta, 6.0)
			_timer -= delta
			_glow = 0.3 + 0.8 * clampf(1.0 - _timer / VOLLEY_TELE, 0.0, 1.0)
			if _timer <= 0.0:
				_glow = 0.3
				for i in 3:
					var d := dir.rotated(Vector3.UP, deg_to_rad(-15.0 + 15.0 * float(i)))
					main.spawn_bullet(position + Vector3(0, 1.5, 0) + d * 0.9, d)
				_state = "drift"
				_timer = 1.6 if hp > max_hp * 0.5 else 1.1
		"frozen":
			# figée : la fin de la fenêtre (vulnerable_t) reforme le voile (_on_shield_back)
			pass
		"reform":
			_timer -= delta
			_veil.scale = Vector3.ONE * clampf(1.0 - _timer / 0.6, 0.05, 1.0)
			if _timer <= 0.0:
				_veil.scale = Vector3.ONE
				_state = "drift"
				_timer = 1.0
		"dying":
			_timer += delta
			if not _death_played:
				_death_played = true
				ch.hold()
				ch.play_once("Death_A", 1.0, 0.05)
			# elle se dissout en neige qui monte
			body.scale = Vector3.ONE * clampf(1.0 - (_timer - 0.8) / 1.2, 0.01, 1.0)
			if int(_timer * 8.0) != int((_timer - delta) * 8.0) and _timer < 2.0:
				main.splash(position + Vector3(0, 1.0 + _timer, 0), SNOW, 4)
			if _timer > 2.2:
				queue_free()
	_animate(delta)


func _start_volley() -> void:
	_state = "volley"
	_timer = VOLLEY_TELE
	ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / VOLLEY_TELE)


## Le sentier pris dans l'ordre brise tout le voile.
func _shatter() -> void:
	main.float_text(position + Vector3(0, 1.6, 0), "雪", Toon.GOLD)
	main.big_hit(position + Vector3(0, 1.0, 0))
	main.splash(position + Vector3(0, 1.4, 0), ICE, 30)
	main.shake = maxf(float(main.shake), 0.69)
	_shield_dmg(shield_max)


func _crys_touch(a: Vector3, b: Vector3) -> void:
	var seg := b - a
	var found: Array = []
	for i in _crys.size():
		if _seen.has(i):
			continue
		var c: Dictionary = _crys[i]
		var p: Vector3 = c["pos"]
		if _seg_dist(p, a, b) < CRYS_HIT:
			var tt := 0.0
			if seg.length_squared() > 0.0001:
				tt = (p - a).dot(seg) / seg.length_squared()
			found.append([tt, i])
	# plusieurs cristaux dans un même segment : dans le sens de la ruée
	found.sort_custom(func(x, y): return x[0] < y[0])
	for f in found:
		var idx := int(f[1])
		_seen[idx] = true
		_order.append(idx)
		var c2: Dictionary = _crys[idx]
		c2["lit"] = true
		var p2: Vector3 = c2["pos"]
		main.small_hit(p2 + Vector3(0, 0.4, 0))


## Flottement, lueur glacée (l'encre ne s'allume qu'à la charge du souffle), cristaux qui pulsent du petit vers le grand.
func _animate(delta: float) -> void:
	if _state == "frozen":
		body.position.y = move_toward(body.position.y, 0.0, delta * 3.0)
		body.rotation.z = sin(_t * 12.0) * 0.05
	elif _state != "dying":
		body.position.y = HOVER + sin(_t * 2.0) * 0.12
		body.rotation.z = 0.0
		if _state != "spawn":
			body.scale = Vector3.ONE * (1.06 if _flash > 0.0 else 1.0)
	if _flash <= 0.0:
		ch.set_glow(maxf(_glow - 0.3, 0.0) * 0.8, ICE)
	for i in _crys.size():
		var c: Dictionary = _crys[i]
		var spike: Node3D = c["spike"]
		var s := float(c["size"])
		if bool(c["lit"]):
			spike.scale = Vector3.ONE * s * 1.3
		else:
			spike.scale = Vector3.ONE * s * (1.0 + 0.2 * maxf(0.0, sin(_t * 5.0 - float(i) * 0.9)))
		spike.rotation.y = _t * 0.6 + float(i)


# ------------------------------------------------------------------ robot testeur

## Sentier : placement au-delà du petit cristal (en les contournant), puis trait du petit au grand
## qui finit à travers elle (le voile tombe). Figée (vulnérable) : iaï à travers, encore et encore.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	var me := Vector3(position.x, 0, position.z)
	if _state == "frozen":
		if vulnerable_t < 0.3:
			return none
		return _bot_line(h, me, 7.3)
	if _state != "path" or _crys.size() < 2 or _timer < 0.4:
		return none
	var c0: Dictionary = _crys[0]
	var c1: Dictionary = _crys[1]
	var p0: Vector3 = c0["pos"]
	var p1: Vector3 = c1["pos"]
	var out := p0 - p1
	out.y = 0
	if out.length_squared() < 0.01:
		out = -_breath_dir
	var lead := _bot_clamp(p0 + out.normalized() * 1.3)
	if h.distance_to(lead) > 1.2:
		var avoid: Array = []
		for c: Dictionary in _crys:
			avoid.append(c["pos"])
		return _bot_route([h, lead], avoid, 1.0)
	var way: Array = [h]
	for c: Dictionary in _crys:
		way.append(c["pos"])
	var last: Vector3 = way[way.size() - 1]
	var fwd := me - last
	fwd.y = 0
	if fwd.length_squared() < 0.01:
		fwd = -out
	way.append(me)
	way.append(me + fwd.normalized() * 1.2)
	return _bot_dense(way)
