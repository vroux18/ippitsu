extends "res://scripts/boss_mini_base.gd"
## Boss du monde 6 (Kurama) — Sōjōbō, le roi des tengu (34 PV × monde, ~3.4 m).
##  Bouclier : le vent de son grand éventail (12). Un coup ne fait qu'effleurer.
##  Mécanique de trait en deux temps :
##   1. il lève une TORNADE de plumes qui dérive vers le héros : un trait qui la traverse la tranche,
##      sa garde de vent tombe 6 s (5 s sous 50 %) et un cercle or s'allume autour de lui ;
##   2. pendant ce temps, une BOUCLE fermée autour de lui brise tout le bouclier : à genoux 6 s,
##      vulnérable (dégâts ×2). Une boucle sans tornade tranchée ne fait qu'effleurer le vent.
##  Attaques : rafale de l'éventail (cône 8 m, 1.1 s), plumes en éventail (lueur 0.8 s),
##  pluie de feuilles (4 disques r0.9 autour du héros, 1.2 s) ; la tornade blesse au contact.
##  Le bouclier revenu, deux karasu-tengu descendent du ciel.

const WARRIOR = preload("res://assets/kaykit/Skeleton_Warrior.glb")
const Loop = preload("res://scripts/boss_loop.gd")
const FEATHER := Color("#1E1C22")
const HAIR := Color("#EFE6D2")
const FACE := Color("#B8352A")
const WIND := Color("#DDE6DA")
const HINT_R := 2.6
const SHIELD := 12.0
const GALE_OPEN := 6.0
const TORNADO_R := 0.95  # distance trait-tornade pour la trancher
const TORNADO_HIT := 0.85  # contact : le héros posé dans la tornade est blessé
const TORNADO_LIFE := 7.0
const GUST_HALF := 0.5
const GUST_LEN := 8.0
const LEAF_R := 0.9

var _wings: Array = []
var _fan: Node3D
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

func _build() -> void:
	Toon.disc(self, 1.4, Color(0, 0, 0, 0.18))
	body = Node3D.new()
	add_child(body)
	ch = Character.new()
	body.add_child(ch)
	var red: Texture2D = load("res://assets/kaykit/tex/skeleton_red.png")
	var gold: Texture2D = load("res://assets/kaykit/tex/skeleton_gold.png")
	ch.setup(WARRIOR, 3.4, [["Cloak", red], ["", gold]], ["Skeleton_Warrior_Helmet"], Toon.GOLD)
	ch.idle = "Idle_Combat"
	ch.play("Idle_Combat")
	# visage rouge au très long nez, crinière et barbe blanches, tokin noir
	var face := Toon.mat(FACE)
	var nose := Toon.part(body, Toon.cyl(0.04, 0.12, 0.9, 7), face, Vector3(0, 2.95, -0.7))
	nose.rotation.x = -PI / 2.0 + 0.15
	var hair := Toon.mat(HAIR)
	Toon.part(body, Toon.box(Vector3(0.9, 0.9, 0.3)), hair, Vector3(0, 2.75, 0.35))
	var beard := Toon.part(body, Toon.cyl(0.32, 0.05, 0.8, 6), hair, Vector3(0, 2.45, -0.3))
	beard.rotation.x = 0.2
	for sx: float in [-1.0, 1.0]:
		var brow := Toon.part(body, Toon.cyl(0.02, 0.08, 0.45, 5), hair, Vector3(sx * 0.2, 3.2, -0.38))
		brow.rotation.z = -sx * 1.1
	Toon.part(body, Toon.box(Vector3(0.3, 0.24, 0.3)), Toon.mat(Color("#1E1C20")), Vector3(0, 3.45, -0.1))
	# pompons d'ascète sur la poitrine
	for k in 3:
		Toon.part(body, Toon.sphere(0.11), Toon.mat(HAIR), Vector3((float(k) - 1.0) * 0.22, 2.05, -0.5))
	# grandes ailes noires
	for sx: float in [-1.0, 1.0]:
		var pv := Node3D.new()
		body.add_child(pv)
		pv.position = Vector3(sx * 0.4, 2.5, 0.4)
		var wing := Toon.part(pv, Toon.box(Vector3(2.2, 0.1, 0.9)), Toon.mat(FEATHER), Vector3(sx * 1.1, 0, 0.15))
		wing.rotation.y = sx * 0.3
		for k in 5:
			var f := Toon.part(pv, Toon.box(Vector3(0.22, 0.08, 0.8)), Toon.mat(Color("#2E2A34")), Vector3(sx * (0.5 + 0.4 * float(k)), -0.06, 0.7))
			f.rotation.y = sx * 0.12 * float(k)
		_wings.append(pv)
	# grand éventail de plumes (hauchiwa) tenu devant lui
	_fan = Node3D.new()
	body.add_child(_fan)
	_fan.position = Vector3(1.1, 1.9, -0.6)
	Toon.part(_fan, Toon.cyl(0.04, 0.05, 0.8, 6), Toon.mat(Color("#3B2E25")), Vector3(0, -0.4, 0))
	for k in 9:
		var a := deg_to_rad(-60.0 + 15.0 * float(k))
		var fe := Toon.part(_fan, Toon.box(Vector3(0.16, 0.85, 0.04)), Toon.mat(FEATHER), Vector3(sin(a) * 0.45, cos(a) * 0.45, 0))
		fe.rotation.z = -a
		Toon.part(_fan, Toon.sphere(0.07), Toon.mat(HAIR, false), Vector3(sin(a) * 0.9, cos(a) * 0.9, 0))
	_hint = Loop.hint_ring(self, HINT_R, Toon.GOLD)
	_hint.visible = false
	_make_stars(body, 3.9)
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
	var fm := Toon.mat(FEATHER, false)
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
		main.float_text(position + Vector3(0, 2.2, 0), "円", Toon.GOLD)
		main.big_hit(position + Vector3(0, 1.6, 0))
		main.splash(position + Vector3(0, 2.0, 0), FEATHER, 26)
		_shield_dmg(shield_max)
	else:
		# le vent le protège encore : la boucle n'effleure que sa garde
		main.clang(position + Vector3(0, 1.6, 0))
		main.float_text(position + Vector3(0, 2.4, 0), "風", SHIELD_C)
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
		main.shake = maxf(float(main.shake), 0.3)
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
					main.float_text(position + Vector3(0, 2.4, 0), "風", SHIELD_C)
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
	main.float_text(tp + Vector3(0, 1.2, 0), "風", Toon.GOLD)
	main.small_hit(tp + Vector3(0, 1.0, 0))
	main.float_text(position + Vector3(0, 2.6, 0), "GARDE OUVERTE", Toon.GOLD)
	main.sfx.play("strike", 1.3, -4.0)


func _animate() -> void:
	var flap := 0.5 if _state == "spawn" else 0.12
	for i in _wings.size():
		var pv: Node3D = _wings[i]
		var sx := -1.0 if i % 2 == 0 else 1.0
		pv.rotation.z = sx * (0.3 + sin(_t * 2.2) * flap)
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
