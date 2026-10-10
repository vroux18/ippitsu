extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 4 (Fuji Rouge) — Ibaraki-dōji, l'oni au bras tranché (26 PV × monde).
##  L'anneau de forge qui le lie est son bouclier (10) : un coup ne fait qu'effleurer. Trois sceaux
##  de braise (quatre sous 50 %) flottent dans l'arène, numérotés par des encoches sumi (1 à 4).
##  Mécanique de trait : un seul trait (ruées enchaînées comprises) qui les touche TOUS DANS L'ORDRE
##  brise tout l'anneau : à genoux 5.5 s, vulnérable (dégâts ×2). Dans le désordre (2 sceaux ou plus) :
##  l'anneau n'est qu'ébréché et les sceaux se réarrangent. Prépare les noyaux de Daidarabotchi.
##  Attaques : charge en ligne (bande annoncée 1.0 s, 10 m/s) ; cercle de feu autour de lui
##  (r2.6, annoncé 1.2 s).
## Apparence (direction « Masque d'encre », règles en tête de yokai_ink_w1.gd) : l'oni à massue du monde 4
## (yokai_ink_w4.gd) en GARDIEN de 3,2 m — corps d'encre chaude sur le rig des yōkai d'encre (ink_rig.gd), obi de
## cendre à flammes ambre et liserés d'or, MASQUE ROUGE CERNÉ D'OR aux yeux d'or, rictus à crocs, deux cornes
## d'ivoire baguées d'or, crinière hérissée ; épaulière de fer rivetée d'or du côté du KANABŌ (main gauche) ;
## à droite, le MOIGNON D'ENCRE QUI GOUTTE, bandé de washi. Seule l'apparence a changé : PV, anneau, sceaux,
## zones, rythme, interface et robot sont ceux d'avant.

const Yokai = preload("res://scripts/yokai_parts.gd")
const W4 = preload("res://scripts/yokai_ink_w4.gd")  # palette du monde 4 (encre chaude, cendre, flamme ambre, braise)
const FLAME := Color("#D9A64A")  # ambre des sceaux et de l'anneau (palette : jamais orange)
const BRAISE := Color("#8E2A1E")
const IRON := Color("#3B3633")
const HEIGHT := 3.2  # l'oni à massue commun fait ~2 m
const SEAL_HIT := 0.8  # distance trait-sceau pour le toucher
const SHIELD := 10.0
const SEAL_CHIP := 0.8  # anneau ébréché par sceau pris dans le désordre
const RESEAL_TIME := 1.2
const CHARGE_TELE := 1.0
const CHARGE_SPEED := 10.0
const CHARGE_W := 0.9  # demi-largeur de la bande de charge
const RING_R := 2.6
const RING_TELE := 1.2

var _bind: Node3D
var _seals: Array = []  # {node, orb, pos, lit}, dans l'ordre 1, 2, 3…
var _order: Array = []
var _seen := {}
var _seal_t := 0.3
var _cycle := 0
var _charge_end := Vector3.ZERO
var _charge_dir := Vector3(0, 0, 1)
var _anim_lock := 0.0  # laisse finir une animation jouée une fois
var _death_played := false


func _ready() -> void:
	title = "Ibaraki-dōji"
	hp = 26.0 * max_hp_mult
	max_hp = hp
	radius = 1.0
	_build()
	_shield_init(SHIELD, Vector3(1.5, 2.0, 1.5), 1.6)
	_state = "spawn"
	_timer = 1.4


# ------------------------------------------------------------------ construction

## Marionnette du gardien : le rig des yōkai d'encre (ink_rig.gd) habillé des pièces bâties ici. Le bras droit est
## tranché : les poses des bras sont MIROIR de celles du rig (le kanabō est en main gauche, c'est elle qui frappe)
## et le bras droit porte le moignon. Les noms d'animations KayKit du combat deviennent ses clips.
class Rig extends "res://scripts/ink_rig.gd":
	static var _cache := {}  # léger -> pièces

	func setup(k: String, height := H_REF) -> void:
		super.setup(k, height)
		# avant miroir : « droit » = kanabō sur l'épaule, « gauche » = moignon levé devant
		_rest_r = Vector3(2.5, 0, 0.45)
		_rest_l = Vector3(0.9, 0, -0.6)
		_eval(0.0)
		for j in SLOTS:
			_out[j] = _tgt[j]
		_apply()

	## Le masque regarde un peu plus la caméra que celui des communs (la crinière ne doit pas le cacher).
	func _apply() -> void:
		super._apply()
		_head.rotation.x += 0.22

	## Poses clés en miroir : le bras gauche fait ce que le rig destine au droit (et inversement).
	func _key(k: int, b: Array[Vector3]) -> void:
		super._key(k, b)
		var l := b[S_ARM_L]
		var r := b[S_ARM_R]
		b[S_ARM_L] = Vector3(r.x, -r.y, -r.z)
		b[S_ARM_R] = Vector3(l.x, -l.y, -l.z)

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
		_part_on(_arms[1], "stump", d)
		# kanabō en main gauche (unités du monde), plus grand que celui des communs
		var w := _part_on(_hands[0], "weapon_l", d)
		if w != null:
			w.position = Vector3(0, 0.02, 0)
			w.scale = Vector3.ONE * 1.5
		for n in _drips:
			n.queue_free()
		_drips.clear()
		_drip_spread = 0.0
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
		var w := 1.2
		var b := Yokai.Mesher.new(1.0)
		Yokai.ink_body(b, w, W4.INK_ASH, W4.ASH_CLOTH, W4.FLAME, Toon.GOLD, lite, true)
		# épaulière de fer rivetée d'or sur l'épaule gauche (celle du kanabō) ; à droite, l'épaule du moignon :
		# un bourrelet d'encre bandé de washi
		b.box(Vector3(-0.5 * w, 1.12, 0), Vector3(0.3, 0.1, 0.36), W4.IRON_D, Vector3(0, 0, 0.4))
		b.box(Vector3(-0.56 * w, 1.0, 0), Vector3(0.12, 0.26, 0.34), W4.IRON_D, Vector3(0, 0, 0.25))
		b.ball(Vector3(-0.52 * w, 1.19, 0), Vector3(0.06, 0.06, 0.06), Toon.GOLD, Vector3.ZERO, 6)
		if not lite:
			for j in 2:
				b.ball(Vector3(-0.6 * w, 0.92 + 0.14 * float(j), -0.12 + 0.24 * float(j)), Vector3(0.035, 0.035, 0.035), Toon.GOLD, Vector3.ZERO, 6)
		b.ball(Vector3(0.44 * w, 1.06, 0), Vector3(0.2, 0.15, 0.19), W4.INK_ASH, Vector3.ZERO, 8)
		b.cyl(Vector3(0.46 * w, 1.03, 0), Vector3(0.19, 0.08, 0.18), Toon.WASHI, Vector3(0, 0, -0.5), 0.9, 8)
		# collier de prières en gros grains d'or (le gardien est riche)
		var n := 5 if lite else 9
		for i in n:
			var ang := -1.0 + 2.0 * float(i) / float(n - 1)
			b.ball(Vector3(sin(ang) * 0.4 * w, 0.98 - 0.08 * cos(ang), -cos(ang) * 0.4 * w), Vector3(0.05, 0.05, 0.05), Toon.GOLD, Vector3.ZERO, 6)
		d["body"] = b.mesh()
		var a := Yokai.Mesher.new(1.0)
		var f := Yokai.Mesher.new(1.0)
		# masque rouge d'oni cerné d'or, plus large que celui des communs ; sourcils froncés, yeux d'or
		Yokai.mask_plate(a, Yokai.MASK_ONI, 1.25, 1.2, true)
		Yokai.mask_brows(a, Toon.SUMI, true, 1.25)
		Yokai.mask_eyes(f, Yokai.EYE_GOLD, 0.06, 1.25)
		# rictus : large trait sumi, quatre crocs d'ivoire (deux vers le haut, deux vers le bas)
		a.box(Vector3(0, -0.16, Yokai.FACE_Z), Vector3(0.34, 0.055, 0.02), Toon.SUMI)
		for s in [-1.0, 1.0]:
			var x := float(s)
			a.spike(Vector3(x * 0.1, -0.135, Yokai.FACE_Z - 0.005), 0.022, 0.08, Yokai.HORN, Vector3(PI, 0, 0), 0.0, 4)
			a.spike(Vector3(x * 0.19, -0.185, Yokai.FACE_Z - 0.005), 0.02, 0.07, Yokai.HORN, Vector3.ZERO, 0.0, 4)
			# cornes d'ivoire baguées d'or, penchées en arrière et vers l'extérieur
			var rot := Vector3(-0.6, 0, -x * 0.45)
			a.spike(Vector3(x * 0.19, 0.3, Yokai.MASK_Z + 0.06), 0.075, 0.46, Yokai.HORN, rot, 0.0, 6)
			var bb := Basis.from_euler(rot)
			a.cyl(Vector3(x * 0.19, 0.3, Yokai.MASK_Z + 0.06) + bb * Vector3(0, 0.12, 0), Vector3(0.07, 0.04, 0.07), Toon.GOLD, rot, 0.9, 8)
		# crinière hérissée : calotte d'encre et pointes en couronne derrière le masque
		a.ball(Vector3(0, 0.18, 0.1), Vector3(0.4, 0.3, 0.36), W4.INK_ASH, Vector3.ZERO, 8)
		var m := 4 if lite else 7
		for i in m:
			var k := (float(i) / float(m - 1) - 0.5) * 2.0
			a.spike(Vector3(k * 0.3, 0.3, 0.12 + 0.06 * absf(k)), 0.07, 0.32 - 0.08 * absf(k), W4.INK_ASH, Vector3(-0.9, 0, -k * 0.7), 0.0, 5)
		d["head"] = Yokai.two(a, f)
		# bras gauche : encre, brassard de fer, bague d'or ; main en boule
		var ar := Yokai.Mesher.new(1.0)
		ar.cyl(Vector3(0, -0.2, 0), Vector3(0.11, 0.4, 0.11), W4.INK_ASH, Vector3(PI, 0, 0), 0.7, 7)
		ar.cyl(Vector3(0, -0.3, 0), Vector3(0.105, 0.14, 0.105), W4.IRON_D, Vector3.ZERO, 0.9, 8)
		ar.cyl(Vector3(0, -0.225, 0), Vector3(0.11, 0.03, 0.11), Toon.GOLD, Vector3.ZERO, 1.0, 8)
		ar.ball(Vector3(0, -0.43, 0), Vector3(0.13, 0.11, 0.13), W4.INK_ASH)
		d["arm"] = ar.mesh()
		# moignon droit : bras tranché court, bandé de washi, gouttes d'encre qui pendent de la plaie
		var st := Yokai.Mesher.new(1.0)
		st.cyl(Vector3(0, -0.1, 0), Vector3(0.11, 0.2, 0.11), W4.INK_ASH, Vector3(PI, 0, 0), 0.85, 7)
		st.cyl(Vector3(0, -0.17, 0), Vector3(0.105, 0.07, 0.105), Toon.WASHI, Vector3(0.1, 0, 0), 0.95, 8)
		st.ball(Vector3(0, -0.22, 0), Vector3(0.1, 0.06, 0.1), W4.INK_ASH, Vector3.ZERO, 7)
		for i in (2 if lite else 3):
			var ang := TAU * float(i) / 3.0
			st.spike(Vector3(sin(ang) * 0.05, -0.23, cos(ang) * 0.05), 0.03, 0.14 + 0.05 * float(i), W4.INK_ASH, Vector3(PI, 0, 0), 0.0, 4)
		d["stump"] = st.mesh()
		Yokai.ink_drip(d, W4.INK_ASH)
		d["drips"] = PackedVector3Array([Vector3(0.16, 0.36, -0.14), Vector3(-0.2, 0.35, 0.06), Vector3(0.06, 0.34, 0.2)]) if not lite \
			else PackedVector3Array([Vector3(0.16, 0.36, -0.14), Vector3(-0.17, 0.35, 0.1)])
		d["weapon_l"] = Yokai.weapon("kanabo")
		return d


func _build() -> void:
	Toon.disc(self, 1.0, Color(0, 0, 0, 0.16))
	body = Node3D.new()
	add_child(body)
	body.rotation.y = PI  # il entre face au héros (le corps regarde vers -Z ; _face le tourne ensuite)
	ch = Rig.new()
	body.add_child(ch)
	ch.setup("ibaraki", HEIGHT)
	ch.idle = "Idle_Combat"
	ch.play_once("Spawn_Ground_Skeletons", ch.length("Spawn_Ground_Skeletons") / 1.4, 0.0)
	# anneau de forge qui le lie (son armure) : or, quatre braises ambre
	_bind = Node3D.new()
	body.add_child(_bind)
	_bind.position = Vector3(0, 1.55, 0)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.08
	tm.rings = 32
	tm.ring_segments = 6
	Toon.part(_bind, tm, Toon.mat_shared(Toon.GOLD), Vector3.ZERO, Vector3(1, 0.6, 1))
	for k in 4:
		var a := TAU * float(k) / 4.0
		Toon.part(_bind, Toon.sphere(0.13), Toon.flat(FLAME), Vector3(cos(a) * 1.02, 0, sin(a) * 1.02))
	_make_stars(body, 3.7)


## Sceau de braise numéroté par `idx + 1` encoches sumi.
func _make_seal(idx: int, p: Vector3) -> Dictionary:
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	n.global_position = p
	Toon.disc(n, 0.62, Color(Toon.GOLD, 0.25), 0.02)
	var orb := Node3D.new()
	n.add_child(orb)
	orb.position.y = 0.9
	Toon.part(orb, Toon.sphere(0.34), Toon.flat(Toon.GOLD), Vector3.ZERO)
	Toon.part(orb, Toon.sphere(0.5), Toon.flat(Color(FLAME, 0.35)), Vector3.ZERO)
	var ink := Toon.mat_shared(Toon.SUMI, false)
	for k in idx + 1:
		var x := (float(k) - float(idx) * 0.5) * 0.2
		Toon.part(n, Toon.box(Vector3(0.08, 0.05, 0.4)), ink, Vector3(x, 1.6, 0))
	main.splash(p + Vector3(0, 0.9, 0), FLAME, 6)
	return {"node": n, "orb": orb, "pos": Vector3(p.x, 0, p.z), "lit": false}


func _spawn_seals() -> void:
	_free_seals(false)
	var n := 3 if hp > max_hp * 0.5 else 4
	var pts := _layout(n)
	for i in n:
		var p: Vector3 = pts[i]
		_seals.append(_make_seal(i, p))


func _free_seals(burst: bool) -> void:
	for s: Dictionary in _seals:
		var n: Node3D = s["node"]
		if is_instance_valid(n):
			if burst:
				var p: Vector3 = s["pos"]
				main.splash(p + Vector3(0, 0.9, 0), FLAME, 10)
			n.queue_free()
	_seals.clear()
	_order = []
	_seen = {}


## Places des sceaux : éparpillés (pas en ligne), loin de lui, espacés de 2.4 à 4 m dans l'ordre,
## et aucun sceau sur le chemin direct entre deux sceaux qui se suivent.
func _layout(n: int) -> Array:
	var me := Vector3(position.x, 0, position.z)
	var max_leg := 4.6 if n == 3 else 4.0
	for _attempt in 80:
		var pts: Array = []
		for i in n:
			for _k in 30:
				var q := Vector3(randf_range(-3.3, 3.3), 0, randf_range(-6.2, 5.2))
				if q.distance_to(me) < 2.4:
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
	# repli : zigzag fixe
	var fb: Array = [Vector3(-2.6, 0, -2.4), Vector3(2.4, 0, -0.6), Vector3(-2.3, 0, 1.4), Vector3(2.5, 0, 3.4)]
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
	if hero.dashing and not _seals.is_empty():
		_seal_touch(a, b)
	if _state == "spawn" or _state == "dying":
		return false
	# à genoux : coup plein (×2) ; lié par l'anneau : il effleure et use l'anneau
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


## Fin du trait : tous les sceaux dans l'ordre brisent l'anneau.
func end_stroke(_stroke_id: int) -> void:
	if not dead and not _seals.is_empty():
		# la dernière image de la ruée n'est pas forcément passée par check_dash
		var pa: Vector3 = main._prev_hero
		_seal_touch(pa, hero.position)
	var order: Array = _order
	_order = []
	_seen = {}
	for s: Dictionary in _seals:
		s["lit"] = false
	if dead or _seals.is_empty() or order.size() < 2:
		# un seul sceau effleuré : rien ne se passe
		return
	var ok := order.size() == _seals.size()
	for i in order.size():
		if int(order[i]) != i:
			ok = false
	if ok and _state != "broken":
		_break_bind()
		return
	# dans le désordre : les sceaux crachent des étincelles et se réarrangent, l'anneau s'ébrèche
	var last: Dictionary = _seals[int(order[order.size() - 1])]
	var lp: Vector3 = last["pos"]
	main.clang(lp + Vector3(0, 0.9, 0))
	_free_seals(true)
	_seal_t = 0.6
	_shield_dmg(SEAL_CHIP * float(order.size()))


func touching_hero(p: Vector3) -> bool:
	if dead or _state != "rush":
		return false
	return Vector2(p.x - position.x, p.z - position.z).length() < radius + 0.35


func _extra_danger(p: Vector3, _eta: float) -> bool:
	if _state != "rush":
		return false
	return _seg_dist(p, position, _charge_end) < CHARGE_W + DANGER_MARGIN


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state == "spawn" or _state == "dying":
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.4, 0)


func _zone_fire(z: Dictionary) -> void:
	var tag := String(z["tag"])
	if tag == "charge":
		_state = "rush"
		ch.play("Walking_D_Skeletons", 2.6)
	elif tag == "ring":
		var c: Vector3 = z["c"]
		main.enemy_strike(c, RING_R)
		main.fire_ring(c, RING_R)
		ch.play_once("2H_Melee_Attack_Spinning", 1.6)
		_anim_lock = 0.7
		_state = "idle"
		_timer = 1.6 if hp > max_hp * 0.5 else 1.2


func _on_die() -> void:
	_free_seals(true)
	_bind.visible = false
	ch.set_glow(0.0)


## Anneau brisé : à genoux, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	_free_seals(true)
	_state = "broken"
	_bind.visible = false
	ch.play("Blocking", 0.6)


func _on_shield_back() -> void:
	if _state != "broken":
		return
	_state = "rebind"
	_timer = 0.6
	_bind.visible = true
	_bind.scale = Vector3.ONE * 0.05
	ch.play("Idle_Combat")


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var to := hero.position - position
	to.y = 0
	var dist := to.length()
	var dir := _dir_to_hero()
	if _anim_lock > 0.0:
		_anim_lock -= delta
	# les sceaux reviennent (sauf à genoux)
	if _seals.is_empty() and not dead and _state != "spawn" and _state != "broken" and _state != "rebind":
		_seal_t -= delta
		if _seal_t <= 0.0:
			_spawn_seals()
	match _state:
		"spawn":
			_timer -= delta
			if _timer <= 0.0:
				_state = "idle"
				_timer = 1.0
				_seal_t = 0.0
		"idle":
			_face(dir, delta)
			if dist > 3.5:
				position += dir * 1.4 * delta
				main.clamp_to_arena(self, radius)
				if _anim_lock <= 0.0:
					ch.play("Walking_A", 0.8)
			elif _anim_lock <= 0.0:
				ch.play("Idle_Combat")
			_timer -= delta
			if _timer <= 0.0:
				_cycle += 1
				if dist > 5.0 or (dist >= 3.0 and _cycle % 2 == 1):
					_start_charge(dir)
				else:
					_zone_disc(position, RING_R, RING_TELE, "ring")
					_state = "ring"
					_timer = RING_TELE
					ch.play("Idle_Combat")
		"charge":
			# l'élan est pris : la charge part quand la bande annoncée est pleine (_zone_fire)
			_face(_charge_dir, delta, 8.0)
			_timer -= delta
		"ring":
			_timer -= delta
		"rush":
			var left := Vector2(_charge_end.x - position.x, _charge_end.z - position.z).length()
			var mv := CHARGE_SPEED * delta
			if left <= mv:
				position = Vector3(_charge_end.x, 0, _charge_end.z)
				main.clamp_to_arena(self, radius)
				_state = "idle"
				_timer = 1.4 if hp > max_hp * 0.5 else 1.0
				ch.play("Idle_Combat")
				main.splash(position + Vector3(0, 0.3, 0), BRAISE, 10)
			else:
				position += _charge_dir * mv
		"broken":
			# à genoux : la fin de la fenêtre (vulnerable_t) le relève (_on_shield_back)
			pass
		"rebind":
			_timer -= delta
			_bind.scale = Vector3.ONE * clampf(1.0 - _timer / 0.6, 0.05, 1.0)
			if _timer <= 0.0:
				_bind.scale = Vector3.ONE
				_state = "idle"
				_timer = 1.0
				_seal_t = RESEAL_TIME
		"dying":
			_timer += delta
			if not _death_played:
				_death_played = true
				ch.hold()
				ch.play_once("Death_C_Skeletons", 1.2, 0.05)
			if _timer > 1.4:
				body.position.y -= delta * 1.5
			if _timer > 2.2:
				queue_free()
	_animate(delta)


func _start_charge(dir: Vector3) -> void:
	_charge_dir = dir
	var me := Vector3(position.x, 0, position.z)
	# s'arrête avant le bord (rayon compris)
	var room := _bot_room(me, dir) - 0.8
	var l := clampf(room, 2.0, 9.0)
	_charge_end = me + dir * l
	_zone_rect(me + dir * (l * 0.5), dir, CHARGE_W, l * 0.5, CHARGE_TELE, "charge", Vector2(0, -1))
	_state = "charge"
	_timer = CHARGE_TELE
	ch.play_once("2H_Melee_Attack_Chop", ch.length("2H_Melee_Attack_Chop") * 0.4 / CHARGE_TELE)


## Tous les sceaux dans l'ordre : l'anneau de forge cède d'un coup.
func _break_bind() -> void:
	main.float_icon(position + Vector3(0, 1.8, 0), "hud/oni", Toon.GOLD)
	main.big_hit(position + Vector3(0, 1.2, 0))
	main.splash(position + Vector3(0, 1.6, 0), FLAME, 30)
	main.shake = maxf(float(main.shake), 0.86)
	_shield_dmg(shield_max)


func _seal_touch(a: Vector3, b: Vector3) -> void:
	var seg := b - a
	var found: Array = []
	for i in _seals.size():
		if _seen.has(i):
			continue
		var s: Dictionary = _seals[i]
		var p: Vector3 = s["pos"]
		if _seg_dist(p, a, b) < SEAL_HIT:
			var tt := 0.0
			if seg.length_squared() > 0.0001:
				tt = (p - a).dot(seg) / seg.length_squared()
			found.append([tt, i])
	# plusieurs sceaux dans un même segment : dans le sens de la ruée
	found.sort_custom(func(x, y): return x[0] < y[0])
	for f in found:
		var idx := int(f[1])
		_seen[idx] = true
		_order.append(idx)
		var s2: Dictionary = _seals[idx]
		s2["lit"] = true
		var p2: Vector3 = s2["pos"]
		main.small_hit(p2 + Vector3(0, 0.9, 0))


## Chaleur de forge, anneau qui tourne, sceaux qui flottent (blancs une fois touchés).
func _animate(_delta: float) -> void:
	if _flash <= 0.0 and not dead:
		var windup := _state == "charge" or _state == "ring"
		var heat := 0.12
		if windup:
			heat = 0.12 + 0.6 * clampf(1.0 - _timer / (CHARGE_TELE if _state == "charge" else RING_TELE), 0.0, 1.0)
		ch.set_glow(heat, Toon.VERMILION if windup else BRAISE)
	_bind.rotation.y = _t * 1.2
	body.rotation.z = sin(_t * 12.0) * 0.04 if _state == "broken" else 0.0
	for i in _seals.size():
		var s: Dictionary = _seals[i]
		var orb: Node3D = s["orb"]
		orb.position.y = 0.9 + sin(_t * 2.4 + float(i)) * 0.1
		orb.scale = Vector3.ONE * (1.35 if bool(s["lit"]) else 1.0)


# ------------------------------------------------------------------ robot testeur

## Sceaux : un trait qui les relie dans l'ordre (en contournant les suivants : l'anneau tombe) ;
## à genoux (vulnérable) : iaï à travers, encore et encore.
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
	if _seals.is_empty() or _state == "spawn" or _state == "rebind":
		return none
	var pts: Array = [h]
	for i in _seals.size():
		var s: Dictionary = _seals[i]
		var tgt: Vector3 = s["pos"]
		var avoid: Array = []
		for j in range(i + 1, _seals.size()):
			var o: Dictionary = _seals[j]
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
