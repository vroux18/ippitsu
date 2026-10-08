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

const MAGE = preload("res://assets/kaykit/Skeleton_Mage.glb")
const Loop = preload("res://scripts/boss_loop.gd")
const ROBE := Color("#3A3440")
const HAIR := Color("#0E0C10")
const BOLT := Color("#C9B8FF")
const DEAD_GOD := Color("#4A464E")
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

var _hair: Node3D
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

func _build() -> void:
	Toon.disc(self, 1.3, Color(0, 0, 0, 0.22))
	body = Node3D.new()
	add_child(body)
	ch = Character.new()
	body.add_child(ch)
	var ink: Texture2D = load("res://assets/kaykit/tex/skeleton_ink.png")
	ch.setup(MAGE, 3.6, [["", ink]], ["Skeleton_Mage_Hat"], BOLT)
	ch.idle = "Idle_Combat"
	ch.play("Idle_Combat")
	# longue chevelure noire, voile de deuil, couronne de foudre
	_hair = Node3D.new()
	body.add_child(_hair)
	_hair.position = Vector3(0, 2.6, 0.3)
	Toon.part(_hair, Toon.box(Vector3(1.0, 2.2, 0.15)), Toon.mat(HAIR), Vector3(0, -0.6, 0.05))
	for sx: float in [-1.0, 1.0]:
		var lock := Toon.part(_hair, Toon.box(Vector3(0.22, 1.6, 0.12)), Toon.mat(HAIR), Vector3(sx * 0.42, -0.2, -0.35))
		lock.rotation.z = sx * 0.06
	Toon.part(body, Toon.cyl(0.9, 1.4, 1.4, 10), Toon.mat(ROBE, true, 0.04), Vector3(0, 0.7, 0))
	for k in 6:
		var a := TAU * float(k) / 6.0
		var spike := Toon.part(body, Toon.cyl(0.0, 0.06, 0.4, 4), main.vfx.glow_mat(BOLT, 2.0), Vector3(cos(a) * 0.32, 3.75, sin(a) * 0.32))
		spike.rotation = Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3)
	# huit dieux du tonnerre en couronne, chacun lié par un fil
	for i in GOD_N:
		var ang := TAU * float(i) / float(GOD_N) + PI / float(GOD_N)
		var n := Node3D.new()
		n.top_level = true
		add_child(n)
		var om := Toon.mat(BOLT, true, 0.03)
		om.emission_enabled = true
		om.emission = BOLT
		om.emission_energy_multiplier = 1.4
		Toon.part(n, Toon.sphere(0.32), om, Vector3.ZERO)
		var tm := TorusMesh.new()
		tm.inner_radius = 0.36
		tm.outer_radius = 0.46
		tm.rings = 16
		tm.ring_segments = 4
		var drum := Toon.part(n, tm, Toon.mat(Color("#2A2430")), Vector3.ZERO)
		drum.rotation.x = PI * 0.5
		for k in 3:
			var sp := Toon.part(n, Toon.cyl(0.0, 0.05, 0.3, 4), Toon.mat(Toon.GOLD, false), Vector3(0, 0.35, 0))
			sp.rotation.z = (float(k) - 1.0) * 0.6
		var th := Toon.part(self, Toon.cyl(0.035, 0.035, 1.0, 4), main.vfx.glow_mat(BOLT, 2.4), Vector3.ZERO)
		th.top_level = true
		th.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gods.append({"node": n, "orb": om, "thread": th, "angle": ang, "cut": false, "fall": 0.0})
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
	main.float_text(position + Vector3(0, 2.6, 0), "円", Toon.GOLD)
	main.big_hit(position + Vector3(0, 1.8, 0))
	main.splash(position + Vector3(0, 2.2, 0), BOLT, 26)
	main.shake = maxf(float(main.shake), 0.5)
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
		main.shake = maxf(float(main.shake), 0.3)


func _on_die() -> void:
	_hint.visible = false
	for g in _gods:
		var gd: Dictionary = g
		var th = gd["thread"]
		th.visible = false
	ch.set_glow(0.0)


## Bouclier brisé : effondrée, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	_unbound_t = 0.0
	_state = "open"
	ch.set_glow(0.0)
	ch.play_once("Hit_A", 0.8)


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
		main.float_text(position + Vector3(0, 3.0, 0), "雷", Toon.GOLD)
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
